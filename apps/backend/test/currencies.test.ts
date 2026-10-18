import { describe, expect, it, vi } from 'vitest'
import { Hono, type Context, type Next } from 'hono'
import type { AppEnv, Role } from '../src/modules/auth'

const getSettings = vi.hoisted(() => vi.fn())
vi.mock('../src/core/db', () => ({ prisma: {} }))
vi.mock('../src/core/redis', () => ({ cacheInvalidate: vi.fn() }))
vi.mock('../src/shared/r2', () => ({ r2Configured: () => false }))
vi.mock('../src/modules/userSettings', async () => {
  const { Hono: UserHono } = await import('hono')
  return { userSettingsRoutes: new UserHono() }
})
vi.mock('../src/shared/bankAccounts', async () => {
  const { z } = await import('zod')
  return {
    bankDetailsSchema: z.object({ kind: z.literal('bank_account') }),
    mobileDetailsSchema: z.object({}),
    assertUniqueBank: vi.fn(),
    linkBankFund: vi.fn(),
    assertUniqueMobile: vi.fn(),
  }
})
vi.mock('../src/shared/settings', () => ({
  getSettings,
  putPcsRates: vi.fn(),
  putSetting: vi.fn(),
  putRaw: vi.fn(),
}))
vi.mock('../src/modules/auth', () => ({ requireRole: (...roles: Role[]) => async (c: Context<AppEnv>, next: Next) => {
  if (!roles.includes(c.get('user').role)) return c.json({ error: 'Forbidden' }, 403)
  await next()
} }))

const { settingsRoutes } = await import('../src/modules/settings')

function appFor(role: Role) {
  const app = new Hono<AppEnv>()
  app.use('*', async (c, next) => {
    c.set('user', { id: 'user-1', name: 'Unit', email: 'unit@example.invalid', role, roleLabel: role })
    await next()
  })
  return app.route('/', settingsRoutes)
}

describe('currency settings', () => {
  it('returns exchange rates to an admin and refuses hub staff', async () => {
    getSettings.mockResolvedValue({ exchangeRates: { BDT: 1, CNY: 16 } })
    const admin = await appFor('admin').request('/currencies')
    expect(admin.status).toBe(200)
    expect(await admin.json()).toEqual({ baseCurrency: 'BDT', rates: { BDT: 1, CNY: 16 } })

    const hub = await appFor('hub').request('/currencies')
    expect(hub.status).toBe(403)
    expect(await hub.json()).toEqual({ error: 'Forbidden' })
  })
})
