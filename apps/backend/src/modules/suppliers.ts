import { moneyBody, sourceFields, sourceAt, withSavedMoney } from '../shared/money'
import { changeCredit, money } from '../shared/customerCredit'
import { creditPayment } from '../shared/ledger'
import { Hono } from 'hono'
import type { Prisma, SupplierTerms } from '@prisma/client'
import { z } from 'zod'
import { prisma } from '../core/db'
import { badRequest, notFound } from '../core/errors'
import { requireRole, type AppEnv } from './auth'
import { effectiveKg } from '../shared/compute'
import { effectiveBill, num, sourceDto, numOrNull, shipmentRow } from '../shared/serialize'
import { getSettings } from '../shared/settings'
import { recordShipmentPayment } from './shipments'

const INCLUDE = {
  shipments: { include: { supplier: true, flight: true, receipts: true, expenses: true, costs: true, invoice: true } },
} as const

type SupplierFull = Prisma.SupplierGetPayload<{ include: typeof INCLUDE }>

/** The finalized invoice total wins over the computed bill. */
const bill = (s: SupplierFull['shipments'][number]): number => effectiveBill(s)

/** Outstanding after partial payments, never negative. */
const remaining = (s: SupplierFull['shipments'][number]): number =>
  Math.max(0, Math.round((bill(s) - num(s.paidAmount)) * 100) / 100)

function summary(x: SupplierFull) {
  const issued=x.shipments.filter(s=>s.invoice?.state==='issued'&&!s.invoice.needsReview)
  const billed = issued.reduce((a, s) => a + bill(s), 0)
  const balance = issued.reduce((a, s) => a + remaining(s), 0)
  const paid = Math.round((billed - balance) * 100) / 100
  const discountTotal = x.shipments.reduce((a, s) => a + num(s.invoice?.discount ?? null), 0)
  return {
    creditBalance: num(x.creditBalance), pricingPending:x.shipments.length-issued.length,
    discountTotal,
    code: x.code,
    name: x.name,
    phone: x.phone,
    address: x.address,
    terms: x.terms,
    archivedAt: x.archivedAt?.toISOString() ?? null,
    orderCount: x.shipments.length,
    deliveredCount: x.shipments.filter((s) => s.status === 'delivered').length,
    shippedKg:
      Math.round(x.shipments.reduce((a, s) => a + effectiveKg(num(s.bookedKg), numOrNull(s.weighedKg)), 0) * 10) / 10,
    billed,
    paid,
    balance,
  }
}

/** Statement of a monthly-terms supplier for one YYYY-MM cycle. */
export async function buildStatement(code: string, month: string) {
  const supplier = await prisma.supplier.findUnique({ where: { code }, include: INCLUDE })
  if (!supplier) throw notFound('Customer not found')
  const rows = supplier.shipments.filter((s) => s.createdAt.toISOString().startsWith(month) && s.invoice?.state==='issued' && !s.invoice.needsReview)
  const monthLabel = new Date(`${month}-01T00:00:00Z`).toLocaleDateString('en-GB', {
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  })
  return {
    title: `Monthly statement — ${monthLabel}`,
    number: `STMT-${month.slice(2).replace('-', '')}-${code}`,
    to: `${supplier.name} (${code})`,
    lines: rows.map((s) => ({
      label: `${s.code} · ${s.categories.join(', ')} · ${s.description}${
        num(s.invoice?.discount ?? null) > 0 ? ` (−৳${num(s.invoice!.discount).toLocaleString('en-IN')} discount)` : ''
      }${s.payStatus === 'paid' ? ' (paid)' : s.payStatus === 'partial' ? ` (paid ৳${num(s.paidAmount).toLocaleString('en-IN')})` : ''}`,
      amount: bill(s),
    })),
    total: rows.reduce((a, s) => a + remaining(s), 0),
  }
}

export const supplierRoutes = new Hono<AppEnv>()
  .get('/', requireRole('admin'), async (c) => {
    // Archived customers stay out of lists and pickers unless asked for.
    const where = c.req.query('includeArchived') === '1' ? {} : { archivedAt: null }
    const suppliers = await prisma.supplier.findMany({ where, include: INCLUDE, orderBy: { createdAt: 'asc' } })
    return c.json({ suppliers: suppliers.map(summary) })
  })

  /** The code a new customer gets when none is typed, shown in the form before saving. */
  .get('/next-code', requireRole('admin'), async (c) => c.json({ code: await nextSupplierCode() }))

  .post('/', requireRole('admin'), async (c) => {
    const body = z
      .object({
        code: z.string().optional(),
        name: z.string().min(1, 'Name required'),
        phone: z.string().default('—'),
        address: z.string().default('—'),
        terms: z.enum(['instant', 'monthly']).default('instant'),
      })
      .parse(await c.req.json())

    const code = body.code?.trim() || (await nextSupplierCode())
    const existing = await prisma.supplier.findUnique({ where: { code } })
    if (existing) throw badRequest(`Customer ${code} already exists`)
    await prisma.supplier.create({
      data: { code, name: body.name, phone: body.phone, address: body.address, terms: body.terms as SupplierTerms },
    })
    return c.json({ code }, 201)
  })

  .get('/next-code', requireRole('admin'), async (c) => {
    return c.json({ code: await nextSupplierCode() })
  })

  .patch('/:code', requireRole('admin'), async (c) => {
    const supplier = await prisma.supplier.findUnique({ where: { code: c.req.param('code')! } })
    if (!supplier) throw notFound('Customer not found')
    const body = z
      .object({
        code: z.string().min(1).optional(),
        name: z.string().min(1).optional(),
        phone: z.string().optional(),
        address: z.string().optional(),
        terms: z.enum(['instant', 'monthly']).optional(),
      })
      .parse(await c.req.json())

    if (body.code && body.code !== supplier.code) {
      const clash = await prisma.supplier.findUnique({ where: { code: body.code } })
      if (clash) throw badRequest(`Customer ${body.code} already exists`)
    }
    const updated = await prisma.supplier.update({
      where: { id: supplier.id },
      data: { ...body, terms: body.terms as SupplierTerms | undefined },
    })
    return c.json({ code: updated.code })
  })

  /** Hide a customer who has history (or bring them back); nothing is removed. */
  .post('/:code/archive', requireRole('admin'), async (c) => {
    const { archived } = z.object({ archived: z.boolean() }).parse(await c.req.json())
    const supplier = await prisma.supplier.findUnique({ where: { code: c.req.param('code')! } })
    if (!supplier) throw notFound('Customer not found')
    await prisma.supplier.update({ where: { id: supplier.id }, data: { archivedAt: archived ? new Date() : null } })
    return c.json({ ok: true, archived })
  })

  .delete('/:code', requireRole('admin'), async (c) => {
    const supplier = await prisma.supplier.findUnique({
      where: { code: c.req.param('code')! },
      include: { shipments: { select: { code: true } } },
    })
    if (!supplier) throw notFound('Customer not found')
    if (supplier.shipments.length > 0) {
      throw badRequest(`${supplier.code} has ${supplier.shipments.length} shipment(s) — delete or reassign them first`)
    }
    if(await prisma.customerCredit.count({where:{supplierId:supplier.id}})||await prisma.statementLink.count({where:{supplierId:supplier.id}}))throw badRequest('Customer has financial or statement history and cannot be deleted')
    await prisma.supplier.delete({ where: { id: supplier.id } })
    return c.json({ ok: true })
  })

  .get('/:code', requireRole('admin'), async (c) => {
    const supplier = await prisma.supplier.findUnique({
      where: { code: c.req.param('code') },
      include: {
        ...INCLUDE,
        invoices: { include: { shipment: { select: { code: true } } }, orderBy: { issuedAt: 'desc' } },
      },
    })
    if (!supplier) throw notFound('Customer not found')
    const settings = await getSettings()
    const recentPayments = await prisma.payment.findMany({
      where: { OR:[{shipment: { supplierId: supplier.id }},{supplierId:supplier.id}] },
      include: { shipment: { select: { code: true } } },
      orderBy: { createdAt: 'desc' },
      take: 12,
    })
    return c.json({
      supplier: {
        ...summary(supplier),
        orders: supplier.shipments
          .sort((a, b) => a.code.localeCompare(b.code))
          .map((s) => shipmentRow(s, 'admin', settings.threshold)),
        payments: recentPayments.map((p) => ({
          ...sourceDto(p,num(p.amount)),kind:p.kind,reference:p.reference,
          code: p.shipment?.code ?? '—',
          method: p.method,
          amount: num(p.amount),
          at: p.createdAt.toISOString(),
        })),
        invoices: supplier.invoices.filter(inv=>inv.state==='issued').map((inv) => ({
          number: inv.number,
          shipmentCode: inv.shipment.code,
          total: num(inv.total),
          discount: num(inv.discount),
          issuedAt: inv.issuedAt.toISOString().slice(0, 10),
        })),
      },
    })
  })

  .post('/:code/payments', requireRole('admin'), async (c) => {
    const { amount, method } = z
      .object({ amount: z.number().positive('Amount required').max(9999999999).multipleOf(0.01), method: z.string().min(1).max(200).default('Cash') })
      .parse(moneyBody(await c.req.json(), ['amount']))
    const supplier = await prisma.supplier.findUnique({ where: { code: c.req.param('code')! }, include: INCLUDE })
    if (!supplier) throw notFound('Customer not found')

    // Oldest bills settle first — the convention monthly-terms suppliers expect.
    const outstanding = supplier.shipments
      .filter((s) => remaining(s) > 0 && s.invoice?.state==='issued' && !s.invoice.needsReview)
      .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime() || a.code.localeCompare(b.code))
    const balance = outstanding.reduce((a, s) => a + remaining(s), 0)
    // Any unallocated amount remains available for future bills or a refund.

    let left = Math.round(amount * 100) / 100
    const allocations: { code: string; amount: number }[] = []
    for (const s of outstanding) {
      if (left <= 0.005) break
      const pay = Math.min(remaining(s), left)
      await recordShipmentPayment(s, pay, method, c.get('user').name)
      allocations.push({ code: s.code, amount: pay })
      left = Math.round((left - pay) * 100) / 100
    }
    if(left>0){await creditPayment(method,left,`${supplier.code} advance`,undefined,'customer-credit',undefined,{supplierId:supplier.id});await changeCredit(supplier.id,left,'advance','Unallocated payment')}
    return c.json({ ok: true, allocations, creditAdded:money(left) }, 201)
  })

  .get('/:code/statement', requireRole('admin'), async (c) => {
    const month = c.req.query('month') ?? new Date().toISOString().slice(0, 7)
    if (!/^\d{4}-\d{2}$/.test(month)) throw badRequest('month must be YYYY-MM')
    return c.json({ statement: await buildStatement(c.req.param('code')!, month) })
  })

/** SUP-014 → 14; continues from the highest existing SUP number. */
async function nextSupplierCode(): Promise<string> {
  const rows = await prisma.supplier.findMany({ select: { code: true } })
  const max = rows
    .filter((r) => r.code.startsWith('SUP-'))
    .reduce((a, r) => Math.max(a, Number(r.code.replace(/\D/g, '')) || 0), 0)
  return `SUP-${String(max + 1).padStart(3, '0')}`
}
