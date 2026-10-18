import { r2Configured } from '../shared/r2'
import { userSettingsRoutes } from './userSettings'
import { assertUniqueBank, bankDetailsSchema, linkBankFund, assertUniqueMobile, mobileDetailsSchema } from '../shared/bankAccounts'
import { badRequest } from '../core/errors'
import { Hono } from 'hono'
import { z } from 'zod'
import { prisma } from '../core/db'
import { cacheInvalidate } from '../core/redis'
import { notFound } from '../core/errors'
import { requireRole, type AppEnv } from './auth'
import { getSettings, putPcsRates, putSetting, putRaw } from '../shared/settings'

import type { PayMethod } from '@prisma/client'

const payMethodDto = (m: PayMethod & {account?: {currency: string} | null}) => ({
  currency: m.account?.currency ?? 'BDT',
  id: m.id,
  kind: m.kind,
  provider: m.provider,
  label: m.label,
  number: m.number,
  note: m.note,
  qrImage: m.qrImage,
  bankName: m.bankName,
  accountNumber: m.accountNumber,
  accountName: m.accountName,
  branch: m.branch,
  district: m.district,
  enabled: m.enabled,
})

/** ~300 KB of data URL; enough for any scanned QR, small enough for a row. */
const qrImageSchema = z
  .string()
  .max(400_000, 'QR image too large — keep it under ~300 KB')
  .startsWith('data:image/', 'QR must be an image')

const payMethodSchema = z.discriminatedUnion('kind', [
  z.object({
    kind: z.literal('mobile_banking'),
    provider: z.string().trim().min(1, 'Provider required').max(60),
    label: z.string().max(80).default(''),
    number: z.string().trim().min(1, 'Number required').max(80),
    note: z.string().max(200).default(''),
    qrImage: qrImageSchema.nullable().optional(),
  }),
  z.object({
    kind: z.literal('bank_account'),
    ...bankDetailsSchema.shape,
  }),
])

export const settingsRoutes = new Hono<AppEnv>()
  .route('/users', userSettingsRoutes)
  .get('/setup-status', requireRole('admin'), async c => {
    const [rate, accounts, paymentMethods, users, cleanup] = await Promise.all([
      prisma.setting.findUnique({ where: { key: 'rate' } }), prisma.account.count(),
      prisma.payMethod.count({ where: { enabled: true, accountId: { not: null } } }),
      prisma.user.count({ where: { active: true } }),
      prisma.setting.findUnique({ where: { key: 'maintenance.media.lastSuccess' } }),
    ])
    return c.json({ rateConfirmed: Boolean(rate && Number(rate.value) > 0), accounts, paymentMethods, users,
      storageConfigured: r2Configured(), cleanupEnabled: process.env.MEDIA_CLEANUP_ENABLED === 'true', lastCleanupAt: cleanup?.value ?? null })
  })
  .get('/currencies', async c => c.json({ baseCurrency:'BDT', rates:(await getSettings()).exchangeRates }))
  .get('/', requireRole('admin'), async (c) => {
    return c.json({ settings: await getSettings() })
  })

  .patch('/', requireRole('admin'), async (c) => {
    const body = z
      .object({
        rate: z.number().positive().max(1000000).optional(),
        threshold: z.number().min(0).optional(),
        investBdt: z.number().min(0).optional(),
        investCny: z.number().min(0).optional(),
        pcsRates: z.record(z.string().min(1).max(60), z.number().min(0)).optional(),
      })
      .parse(await c.req.json())
    for (const key of ['rate', 'threshold', 'investBdt', 'investCny'] as const) {
      const value = body[key]
      if (value !== undefined) await putSetting(key, value)
    }
    if (body.pcsRates !== undefined) await putPcsRates(body.pcsRates)
    await cacheInvalidate('dashboard')
    await cacheInvalidate('track')
    return c.json({ settings: await getSettings() })
  })

  // -------------------------------------------------------------------
  // Payment methods shown on the public tracking page.
  // -------------------------------------------------------------------

  .get('/pay-methods', requireRole('admin'), async (c) => {
    const methods = await prisma.payMethod.findMany({ orderBy: { order: 'asc' }, include:{account:true} })
    return c.json({ methods: methods.map(payMethodDto) })
  })

  .post('/pay-methods', requireRole('admin'), async (c) => {
    const raw = await c.req.json()
    const body = payMethodSchema.parse(raw)
    const currency = z.enum(['BDT','CNY']).default('BDT').parse(raw.currency)
    if (body.kind === 'bank_account') await assertUniqueBank(bankDetailsSchema.parse(body))
    else await assertUniqueMobile(mobileDetailsSchema.parse(body))
    const last = await prisma.payMethod.findFirst({ orderBy: { order: 'desc' } })
    let method = await prisma.payMethod.create({
      data: { ...body, order: (last?.order ?? -1) + 1 },
    })
    method = await linkBankFund(method, currency)
    await cacheInvalidate('dashboard')
    await cacheInvalidate('track')
    return c.json({ method: payMethodDto({...method,account:{currency}}) }, 201)
  })

  .patch('/pay-methods/:id', requireRole('admin'), async (c) => {
    const method = await prisma.payMethod.findUnique({ where: { id: c.req.param('id')! }, include:{account:true} })
    if (!method) throw notFound('Payment method not found')
    const raw = (await c.req.json()) as Record<string, unknown>
    if (raw.currency !== undefined && raw.currency !== (method.account?.currency ?? 'BDT')) throw badRequest('Account currency cannot be changed. Add a separate payment method for the other currency.')
    // A bare enabled toggle skips the full-shape validation; anything more is
    // a re-submission of the typed form and validates as such.
    const enabled = z.object({ enabled: z.boolean().optional() }).parse(raw).enabled
    const hasFields = Object.keys(raw).some((k) => k !== 'enabled')
    const fields = hasFields ? payMethodSchema.parse({ kind: method.kind, ...raw }) : undefined
    if (fields && method.accountId && fields.kind !== method.kind) throw badRequest('Change the linked account type from Finance')
    if (fields?.kind === 'bank_account') await assertUniqueBank(bankDetailsSchema.parse(fields), method.id)
    if (fields?.kind === 'mobile_banking') await assertUniqueMobile(mobileDetailsSchema.parse(fields), method.id)
    let updated = await prisma.payMethod.update({
      where: { id: method.id },
      data: { ...(fields ?? {}), ...(enabled !== undefined ? { enabled } : {}) },
    })
    await cacheInvalidate('track')
    updated = await linkBankFund(updated)
    await cacheInvalidate('dashboard')
    return c.json({ method: payMethodDto({...updated,account:method.account}) })
  })

  .delete('/pay-methods/:id', requireRole('admin'), async (c) => {
    const method = await prisma.payMethod.findUnique({ where: { id: c.req.param('id')! }, include:{account:true} })
    if (!method) throw notFound('Payment method not found')
    await prisma.payMethod.delete({ where: { id: method.id } })
    await cacheInvalidate('track')
    return c.json({ ok: true })
  })
