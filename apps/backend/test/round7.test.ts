import { createHash } from 'node:crypto'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono } from 'hono'
import type { AppEnv, Role } from '../src/modules/auth'

vi.hoisted(() => {
  process.env.DATABASE_URL ??= 'postgresql://unit:unit@localhost:5432/unit'
  process.env.REDIS_URL ??= 'redis://localhost:6379'
  process.env.LINK_ENCRYPTION_KEY ??= 'ab'.repeat(32)
})

/** In-memory Redis: plain keys with their last TTL, and sorted sets. */
const kv = vi.hoisted(() => ({
  values: new Map<string, string>(),
  ttls: new Map<string, number>(),
  zsets: new Map<string, Map<string, number>>(),
}))

const db = vi.hoisted(() => ({
  user: { findUnique: vi.fn() },
  flight: { findUnique: vi.fn(), findMany: vi.fn() },
  expense: { create: vi.fn(), update: vi.fn(), findFirst: vi.fn(), findMany: vi.fn(), count: vi.fn() },
  account: { findMany: vi.fn(), update: vi.fn() },
  ledgerReversal: { create: vi.fn() },
  shipment: { findUnique: vi.fn(), findMany: vi.fn(), create: vi.fn(), update: vi.fn(), delete: vi.fn() },
  supplier: { findUnique: vi.fn(), findUniqueOrThrow: vi.fn(), findMany: vi.fn(), aggregate: vi.fn(), update: vi.fn() },
  customerCredit: { create: vi.fn(), count: vi.fn() },
  invoice: { upsert: vi.fn(), update: vi.fn(), delete: vi.fn() },
  invoiceRevision: { count: vi.fn(), create: vi.fn(), deleteMany: vi.fn() },
  creditNote: { create: vi.fn(), count: vi.fn() },
  shipmentLog: { create: vi.fn() },
  payment: { findMany: vi.fn() },
  customerRefund: { findMany: vi.fn() },
  fundTransfer: { findMany: vi.fn() },
  statementLink: { findMany: vi.fn(), create: vi.fn() },
  todo: { findMany: vi.fn() },
  flyer: { findMany: vi.fn() },
}))

vi.mock('../src/core/db', () => ({ prisma: db, atomicMutation: async (work: () => Promise<unknown>) => work() }))
vi.mock('../src/core/redis', () => {
  const zset = (key: string) => {
    const set = kv.zsets.get(key) ?? new Map<string, number>()
    kv.zsets.set(key, set)
    return set
  }
  const redis = {
    get: vi.fn(async (key: string) => kv.values.get(key) ?? null),
    set: vi.fn(async (key: string, value: string, _mode: string, ttl: number) => {
      kv.values.set(key, value)
      kv.ttls.set(key, ttl)
      return 'OK'
    }),
    del: vi.fn(async (...keys: string[]) => {
      let removed = 0
      for (const key of keys) {
        if (kv.values.delete(key) || kv.zsets.delete(key)) removed++
        kv.ttls.delete(key)
      }
      return removed
    }),
    expire: vi.fn(async (key: string, ttl: number) => {
      if (!kv.values.has(key) && !kv.zsets.has(key)) return 0
      kv.ttls.set(key, ttl)
      return 1
    }),
    exists: vi.fn(async (key: string) => (kv.values.has(key) ? 1 : 0)),
    zadd: vi.fn(async (key: string, score: number, member: string) => {
      zset(key).set(member, score)
      return 1
    }),
    zrange: vi.fn(async (key: string) => [...zset(key).entries()].sort((a, b) => a[1] - b[1]).map(([member]) => member)),
    zrem: vi.fn(async (key: string, member: string) => (zset(key).delete(member) ? 1 : 0)),
  }
  return { redis, rateLimit: vi.fn(async () => true), cacheInvalidate: vi.fn(), cacheGetJson: vi.fn(async () => null), cacheSetJson: vi.fn() }
})
vi.mock('@node-rs/argon2', () => ({
  verify: vi.fn(async (hash: string, password: string) => hash === `hashed:${password}`),
  hash: vi.fn(async (password: string) => `hashed:${password}`),
}))
vi.mock('../src/shared/settings', () => ({
  getSettings: vi.fn(async () => ({ rate: 17, exchangeRates: { BDT: 1, CNY: 17 }, threshold: 0.5, investBdt: 0, investCny: 0 })),
}))

const { authRoutes, requireAuth, SESSION_TTL_SECONDS, REMEMBER_TTL_SECONDS, DEVICE_TTL_SECONDS } = await import('../src/modules/auth')
const { flightRoutes } = await import('../src/modules/flights')
const { shipmentRoutes } = await import('../src/modules/shipments')
const { dashboardRoutes } = await import('../src/modules/dashboard')
const { handleError } = await import('../src/core/errors')
const { latePayments, LATE_DAYS } = await import('../src/shared/latePayments')
const { financialSummary } = await import('../src/shared/financialSummary')
const { flightProfitBreakdown, shipmentProfitBreakdown } = await import('../src/shared/profit')
const { issuePendingInvoices, startInvoiceCatchUp, PENDING_AUTOMATIC_BILL } = await import('../src/shared/shipmentBilling')
const { statementAdminRoutes } = await import('../src/modules/statements')

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Any = any
const sha256 = (value: string) => createHash('sha256').update(value).digest('hex')
const day = (offset: number) => new Date(Date.now() + offset * 86_400_000)
/** List reads return `rows`; the bill catch-up query (its `where.AND`) finds nothing. */
const listing = (rows: unknown[]) => async (args?: Any) => (args?.where?.AND ? [] : rows)
const send = (method: string, body?: unknown, token?: string) => ({
  method,
  headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
  body: body === undefined ? undefined : JSON.stringify(body),
})

function appFor(role: Role, path: string, routes: Hono<AppEnv>) {
  const app = new Hono<AppEnv>()
  app.onError(handleError)
  app.use('*', async (c, next) => {
    c.set('user', { id: `${role}-1`, name: `Unit ${role}`, email: `${role}@example.invalid`, role, roleLabel: role })
    await next()
  })
  return app.route(path, routes)
}

beforeEach(() => {
  vi.clearAllMocks()
  kv.values.clear()
  kv.ttls.clear()
  kv.zsets.clear()
})

// ─────────────────────────────────────────────────────────────────────────
// Auth: remember me and fingerprint device keys
// ─────────────────────────────────────────────────────────────────────────

describe('Remember me and fingerprint sign-in', () => {
  let user: Any
  const authApp = () => {
    const app = new Hono<AppEnv>()
    app.onError(handleError)
    app.route('/auth', authRoutes)
    app.get('/me', requireAuth, (c) => c.json({ user: c.get('user') }))
    return app
  }
  const login = async (app: Hono<AppEnv>, remember?: boolean) => {
    const response = await app.request('/auth/login', send('POST', { email: user.email, password: 'secret-1', ...(remember === undefined ? {} : { remember }) }))
    expect(response.status).toBe(200)
    return ((await response.json()) as { token: string }).token
  }
  const addDevice = async (app: Hono<AppEnv>, token: string, label = 'Pixel 7') => {
    const response = await app.request('/auth/device', send('POST', { label }, token))
    expect(response.status).toBe(201)
    return ((await response.json()) as { deviceToken: string }).deviceToken
  }
  const deviceLogin = (app: Hono<AppEnv>, deviceToken: string) => app.request('/auth/device-login', send('POST', { deviceToken }))

  beforeEach(() => {
    user = { id: 'u-1', email: 'admin@example.invalid', name: 'Admin', role: 'admin', active: true, sessionVersion: 0, passwordHash: 'hashed:secret-1' }
    db.user.findUnique.mockImplementation(async ({ where }: Any) => ((where.id && where.id === user.id) || (where.email && where.email === user.email) ? { ...user } : null))
  })

  it('keeps a 12-hour session without remember and a 30-day sliding one with it', async () => {
    const app = authApp()
    const plain = await login(app)
    expect(kv.ttls.get(`session:${plain}`)).toBe(SESSION_TTL_SECONDS)
    const remembered = await login(app, true)
    expect(kv.ttls.get(`session:${remembered}`)).toBe(REMEMBER_TTL_SECONDS)
    expect(JSON.parse(kv.values.get(`session:${remembered}`)!).ttl).toBe(REMEMBER_TTL_SECONDS)

    // Each request slides the session forward by the lifetime it was made with.
    kv.ttls.set(`session:${remembered}`, 5)
    kv.ttls.set(`session:${plain}`, 5)
    expect((await app.request('/me', { headers: { authorization: `Bearer ${remembered}` } })).status).toBe(200)
    expect((await app.request('/me', { headers: { authorization: `Bearer ${plain}` } })).status).toBe(200)
    expect(kv.ttls.get(`session:${remembered}`)).toBe(REMEMBER_TTL_SECONDS)
    expect(kv.ttls.get(`session:${plain}`)).toBe(SESSION_TTL_SECONDS)
  })

  it('creates a device key once, stores only its digest, and signs in for 30 days', async () => {
    const app = authApp()
    const token = await login(app)
    const deviceToken = await addDevice(app, token)
    expect(deviceToken).toMatch(/^[A-Za-z0-9_-]{43}$/)
    expect([...kv.values.values()].some((value) => value.includes(deviceToken))).toBe(false)
    const record = JSON.parse(kv.values.get(`device:${sha256(deviceToken)}`)!)
    expect(record).toMatchObject({ userId: 'u-1', sessionVersion: 0, passwordVersion: sha256('hashed:secret-1'), label: 'Pixel 7' })
    expect(typeof record.createdAt).toBe('string')
    expect(kv.ttls.get(`device:${sha256(deviceToken)}`)).toBe(DEVICE_TTL_SECONDS)

    const signedIn = await deviceLogin(app, deviceToken)
    expect(signedIn.status).toBe(200)
    const body = (await signedIn.json()) as { token: string; user: { email: string } }
    expect(body.user.email).toBe(user.email)
    expect(kv.ttls.get(`session:${body.token}`)).toBe(REMEMBER_TTL_SECONDS)
    expect(kv.ttls.get(`device:${sha256(deviceToken)}`)).toBe(DEVICE_TTL_SECONDS)
  })

  it('needs a signed-in session to create a device key', async () => {
    const response = await authApp().request('/auth/device', send('POST', { label: 'Pixel 7' }))
    expect(response.status).toBe(401)
    expect([...kv.values.keys()].some((key) => key.startsWith('device:'))).toBe(false)
  })

  it('keeps the device key when signing out', async () => {
    const app = authApp()
    const token = await login(app)
    const deviceToken = await addDevice(app, token)
    expect((await app.request('/auth/logout', send('POST', {}, token))).status).toBe(200)
    expect(kv.values.has(`session:${token}`)).toBe(false)
    expect(kv.values.has(`device:${sha256(deviceToken)}`)).toBe(true)
    expect((await deviceLogin(app, deviceToken)).status).toBe(200)
  })

  it('revokes a key idempotently and then refuses it', async () => {
    const app = authApp()
    const deviceToken = await addDevice(app, await login(app))
    for (let i = 0; i < 2; i++) {
      const revoked = await app.request('/auth/device/revoke', send('POST', { deviceToken }))
      expect(revoked.status).toBe(200)
      expect(await revoked.json()).toEqual({ ok: true })
    }
    expect(kv.zsets.get('devices:u-1')?.size ?? 0).toBe(0)
    const refused = await deviceLogin(app, deviceToken)
    expect(refused.status).toBe(401)
    expect(await refused.json()).toEqual({ error: 'Fingerprint sign-in was turned off. Sign in with your password.' })
  })

  it('turns the key off after a password change, and after a deactivation', async () => {
    const app = authApp()
    const deviceToken = await addDevice(app, await login(app))
    user.passwordHash = 'hashed:new-secret'
    const refused = await deviceLogin(app, deviceToken)
    expect(refused.status).toBe(401)
    expect(((await refused.json()) as { error: string }).error).toBe('Fingerprint sign-in was turned off. Sign in with your password.')
    expect(kv.values.has(`device:${sha256(deviceToken)}`)).toBe(false)

    user.passwordHash = 'hashed:secret-1'
    const second = await addDevice(app, await login(app))
    user.sessionVersion = 1
    expect((await deviceLogin(app, second)).status).toBe(401)
    expect(kv.values.has(`device:${sha256(second)}`)).toBe(false)
  })

  it('refuses unknown and malformed keys with the same message', async () => {
    const app = authApp()
    for (const deviceToken of ['A'.repeat(43), 'not-a-key']) {
      const response = await deviceLogin(app, deviceToken)
      expect(response.status).toBe(401)
      expect(((await response.json()) as { error: string }).error).toContain('Fingerprint sign-in was turned off')
    }
  })

  it('keeps at most five keys per user, dropping the oldest', async () => {
    const app = authApp()
    const token = await login(app)
    let now = 1_800_000_000_000
    const clock = vi.spyOn(Date, 'now').mockImplementation(() => (now += 1000))
    const keys: string[] = []
    try {
      for (let i = 0; i < 6; i++) keys.push(await addDevice(app, token, `Phone ${i}`))
    } finally {
      clock.mockRestore()
    }
    expect(kv.zsets.get('devices:u-1')?.size).toBe(5)
    expect((await deviceLogin(app, keys[0]!)).status).toBe(401)
    expect((await deviceLogin(app, keys[5]!)).status).toBe(200)
  })
})

// ─────────────────────────────────────────────────────────────────────────
// Flight costs and flight profit
// ─────────────────────────────────────────────────────────────────────────

const FLIGHT_CODE = 'BG305-20261024-abc123'
const supplierA = { id: 'sup-1', code: 'SUP-004', name: 'Nila Store', phone: '01700000000', terms: 'instant', archivedAt: null }
const supplierB = { id: 'sup-2', code: 'SUP-009', name: 'Bismillah Telecom', phone: '01800000000', terms: 'monthly', archivedAt: null }

function shipmentFixture(over: Record<string, unknown> = {}): Any {
  const supplier = (over.supplier as typeof supplierA) ?? supplierA
  return {
    id: 'sh-1', code: 'SH-18', supplierId: supplier.id, supplier,
    flightId: null, flight: null, flyerId: null, flyer: null,
    bookedKg: 4, weighedKg: null, charge: 3800, chargeRate: 950, chargeCurrency: 'BDT', pricingRates: { BDT: 1, CNY: 17 }, pcsItems: [],
    customsTax: 0, afterSalesFee: 0, paidAmount: 0, freeOfCharge: false, paymentTerms: 'invoice', payStatus: 'unpaid', payMethod: null,
    status: 'received_bd_hub', createdAt: day(-20), handedOverAt: null, description: '—', categories: ['Mobile'], serials: [],
    exception: null, exceptionReason: '', deliveryMode: 'courier', lastMileRef: null, lastMileCourier: null, deliveryBookedAt: null,
    dispatchedAt: null, packedAt: null, packageCount: 0, photosCount: 0, hasVideo: false,
    cnFare: 0, bdFare: null, costSources: {}, trackToken: 'legacy-token',
    invoice: null, costs: [], receipts: [], expenses: [], logs: [], payments: [],
    ...over,
  }
}

const issuedInvoice = (total: number, over: Record<string, unknown> = {}) => ({
  id: 'inv-1', number: 'INV-2610-SH-18', shipmentId: 'sh-1', supplierId: 'sup-1', state: 'issued', pricingMode: 'automatic', needsReview: false,
  lines: [{ label: 'Shipment charges', amount: total }], discount: 0, total, note: '', issuedAt: day(-5), updatedAt: day(-5),
  sourceCurrency: 'BDT', sourceFxRate: 1, sourceAmount: total, pricingFingerprint: null,
  ...over,
})

const expenseRow = (over: Record<string, unknown>): Any => ({
  id: 'exp-x', flightId: 'fl-1', shipmentId: null, costId: null, costField: null, category: 'transport', reason: 'Transport', amount: 0,
  date: day(-2), createdAt: day(-2), reversedAt: null, reversalOfId: null,
  accountName: null, accountCurrency: null, accountAmount: null, fxRate: null, sourceCurrency: 'BDT', sourceFxRate: 1, sourceAmount: null,
  ...over,
})

describe('Flight costs', () => {
  const cash = { id: 'acc-1', name: 'Dhaka cash', kind: 'cash', currency: 'BDT', balance: 84250, createdAt: day(-100) }
  const flightRow = { id: 'fl-1', code: FLIGHT_CODE }
  const app = () => appFor('admin', '/flights', flightRoutes)

  beforeEach(() => {
    db.flight.findUnique.mockImplementation(async ({ where }: Any) => (where.code === FLIGHT_CODE ? flightRow : null))
    db.account.findMany.mockResolvedValue([cash])
    db.expense.create.mockImplementation(async ({ data }: Any) => expenseRow({ id: 'exp-new', createdAt: new Date(), ...data }))
  })

  it('records a paid flight cost against the account and a pay-later one as unpaid', async () => {
    const paid = await app().request(`/flights/${FLIGHT_CODE}/costs`, send('POST', { category: 'transport', label: 'Airport to Dhaka hub', amount: 900, accountName: 'Dhaka cash' }))
    expect(paid.status).toBe(201)
    expect(((await paid.json()) as Any).cost).toMatchObject({ category: 'transport', label: 'Airport to Dhaka hub', amount: 900, paid: true, accountName: 'Dhaka cash' })
    expect(db.account.update).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'acc-1' }, data: { balance: { decrement: expect.anything() } } }))
    expect(Number(db.account.update.mock.calls[0]![0].data.balance.decrement)).toBe(900)
    expect(db.expense.create.mock.calls[0]![0].data).toMatchObject({ flightId: 'fl-1', category: 'transport', amount: 900, accountName: 'Dhaka cash', accountAmount: 900 })
    expect(db.expense.create.mock.calls[0]![0].data).not.toHaveProperty('shipmentId')

    db.account.update.mockClear()
    const later = await app().request(`/flights/${FLIGHT_CODE}/costs`, send('POST', { category: 'others', label: 'Labour', amount: 600, payLater: true }))
    expect(later.status).toBe(201)
    expect(((await later.json()) as Any).cost).toMatchObject({ category: 'others', label: 'Labour', amount: 600, paid: false, accountName: null })
    expect(db.account.update).not.toHaveBeenCalled()
    expect(db.expense.create.mock.calls[1]![0].data).not.toHaveProperty('accountName')
  })

  it('needs exactly one of an account or pay later, a flight-cost category and a flight', async () => {
    for (const body of [
      { category: 'courier', amount: 100 },
      { category: 'courier', amount: 100, accountName: 'Dhaka cash', payLater: true },
      { category: 'ticket', amount: 100, payLater: true },
      { category: 'courier', amount: 0, payLater: true },
      { category: 'courier', amount: 100, payLater: true, label: 'x'.repeat(61) },
    ]) expect((await app().request(`/flights/${FLIGHT_CODE}/costs`, send('POST', body))).status).toBe(400)
    expect((await app().request('/flights/NOPE/costs', send('POST', { category: 'courier', amount: 100, payLater: true }))).status).toBe(404)
    expect(db.expense.create).not.toHaveBeenCalled()
    expect((await appFor('hub', '/flights', flightRoutes).request(`/flights/${FLIGHT_CODE}/costs`, send('POST', { category: 'courier', amount: 100, payLater: true }))).status).toBe(403)
  })

  it('removes a paid cost by reversing it: the money goes back and nothing is deleted', async () => {
    const original = expenseRow({ id: 'exp-1', amount: 900, accountName: 'Dhaka cash', accountCurrency: 'BDT', accountAmount: 900, fxRate: 1, sourceAmount: 900 })
    db.expense.findFirst.mockResolvedValue(original)
    const response = await app().request(`/flights/${FLIGHT_CODE}/costs/exp-1`, send('DELETE'))
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ ok: true })
    expect(db.expense.findFirst.mock.calls[0]![0].where).toMatchObject({ id: 'exp-1', flightId: 'fl-1', category: { not: 'ticket' }, reversalOfId: null })
    expect(db.account.update).toHaveBeenCalledWith({ where: { id: 'acc-1' }, data: { balance: { increment: 900 } } })
    expect(db.expense.create.mock.calls[0]![0].data).toMatchObject({ amount: -900, accountAmount: -900, accountName: 'Dhaka cash', reversalOfId: 'exp-1', flightId: 'fl-1', category: 'transport' })
    expect(db.expense.update).toHaveBeenCalledWith({ where: { id: 'exp-1' }, data: { reversedAt: expect.any(Date) } })
    expect(db.ledgerReversal.create.mock.calls[0]![0].data).toMatchObject({ kind: 'expense', recordId: 'exp-1', offsetId: 'exp-new' })
  })

  it('removes a pay-later cost without touching any account, and a second remove is a no-op', async () => {
    db.expense.findFirst.mockResolvedValueOnce(expenseRow({ id: 'exp-2', amount: 600, category: 'courier' }))
    expect((await app().request(`/flights/${FLIGHT_CODE}/costs/exp-2`, send('DELETE'))).status).toBe(200)
    expect(db.account.update).not.toHaveBeenCalled()
    expect(db.expense.create.mock.calls[0]![0].data).toMatchObject({ amount: -600, accountAmount: null, accountName: null, reversalOfId: 'exp-2' })

    db.expense.findFirst.mockResolvedValueOnce(expenseRow({ id: 'exp-2', amount: 600, reversedAt: new Date() }))
    expect((await app().request(`/flights/${FLIGHT_CODE}/costs/exp-2`, send('DELETE'))).status).toBe(200)
    expect(db.expense.create).toHaveBeenCalledTimes(1)
    db.expense.findFirst.mockResolvedValueOnce(null)
    expect((await app().request(`/flights/${FLIGHT_CODE}/costs/missing`, send('DELETE'))).status).toBe(404)
  })

  it('shows flight costs, the profit breakdown and late days on the flight', async () => {
    const flight = {
      id: 'fl-1', code: FLIGHT_CODE, date: new Date('2026-10-24'), depTime: '10:00', arrTime: '14:00', via: 'Direct', status: 'completed',
      fare: 6000, actualCost: 18000, agencyShare: 12000, flyerPaidAmount: 6000, spaceKg: 44, mobiles: 2, laptops: 1,
      sourceCurrency: 'BDT', sourceFxRate: 1, sourceAmount: 18000, legs: [], flyers: [{ contribution: 6000, paidAmount: 6000, flyer: { name: 'RAHMAN Arif', bdPhone: '017' } }],
      expenses: [
        expenseRow({ id: 'ticket', category: 'ticket', amount: 18000, accountName: 'Dhaka cash', accountAmount: 18000, date: day(-10) }),
        expenseRow({ id: 'transport', category: 'transport', reason: 'Airport to Dhaka hub', amount: 900, accountName: 'Dhaka cash', accountAmount: 900, date: day(-3) }),
        expenseRow({ id: 'packaging', category: 'packaging', reason: 'Boxes and tape', amount: 650, accountName: 'Dhaka cash', accountAmount: 650, date: day(-2) }),
        expenseRow({ id: 'courier', category: 'courier', reason: 'Courier', amount: 600, date: day(-1) }),
        expenseRow({ id: 'removed', category: 'customs', amount: 400, reversedAt: day(-1), date: day(-4) }),
        expenseRow({ id: 'removed-twin', category: 'customs', amount: -400, reversalOfId: 'removed', date: day(-1) }),
      ],
      shipments: [
        shipmentFixture({ flightId: 'fl-1', status: 'delivered', handedOverAt: day(-12), bookedKg: 4.5, weighedKg: 4, charge: 4800, invoice: issuedInvoice(5100), costs: [{ id: 'c1', name: 'Courier to customer', category: 'courier', amount: 300, voidedAt: null, createdAt: day(-3), sourceCurrency: 'BDT', sourceAmount: 300, sourceFxRate: 1 }] }),
        shipmentFixture({ id: 'sh-2', code: 'SH-14', flightId: 'fl-1', status: 'delivered', handedOverAt: day(-9), bookedKg: 34, charge: 33800, invoice: issuedInvoice(33800, { id: 'inv-2' }) }),
        shipmentFixture({ id: 'sh-3', code: 'SH-21', supplier: supplierB, flightId: 'fl-1', paymentTerms: 'monthly', status: 'delivered', bookedKg: 0, charge: 0, paidAmount: 500, invoice: issuedInvoice(500, { id: 'inv-3' }) }),
      ].map((s) => ({ ...s, flight: { code: FLIGHT_CODE, date: new Date('2026-10-24'), spaceKg: 44, agencyShare: 12000 } })),
    }
    db.flight.findUnique.mockResolvedValue(flight)
    const response = await app().request(`/flights/${FLIGHT_CODE}`)
    expect(response.status).toBe(200)
    const body = ((await response.json()) as Any).flight

    expect(body.flightCosts.map((c: Any) => c.id)).toEqual(['courier', 'packaging', 'transport'])
    expect(body.flightCosts[0]).toEqual({ id: 'courier', category: 'courier', label: 'Courier', amount: 600, date: expect.any(String), paid: false, accountName: null })
    expect(body.flightCosts[2]).toMatchObject({ label: 'Airport to Dhaka hub', paid: true, accountName: 'Dhaka cash' })
    expect(body.flightCostTotal).toBe(2150)
    // Costs on the bill (৳300) are left out: 4,800 + 33,800 + 500 charged.
    expect(body.profitBreakdown).toEqual({ shipmentCharges: 39100, flyerIncome: 6000, ticket: 18000, flightCosts: 2150, otherCosts: 0, profit: 24950 })
    expect(body.margin).toBe(24950)
    expect(body.bookings.map((b: Any) => [b.code, b.lateDays])).toEqual([['SH-18', 12], ['SH-14', null], ['SH-21', null]])
  })

  it('keeps the flight list profit on the same breakdown', async () => {
    db.flight.findMany.mockResolvedValue([{
      id: 'fl-1', code: FLIGHT_CODE, date: new Date('2026-10-24'), depTime: '—', arrTime: '—', via: 'Direct', status: 'upcoming',
      fare: 1000, actualCost: 5000, agencyShare: 4000, flyerPaidAmount: 0, spaceKg: 44, mobiles: 2, laptops: 1, sourceCurrency: 'BDT', sourceFxRate: 1, sourceAmount: 5000,
      legs: [], flyers: [], expenses: [{ category: 'ticket', amount: 5000 }, { category: 'packaging', amount: 250 }],
      shipments: [{ bookedKg: 5, weighedKg: null, charge: 6000, customsTax: 200, afterSalesFee: 0, cnFare: 0, bdFare: null, invoice: { total: 6500 }, expenses: [], costs: [{ category: 'courier', amount: 300, voidedAt: null }] }],
    }])
    const body = (await (await app().request('/flights')).json()) as Any
    expect(body.flights[0].profitBreakdown).toEqual({ shipmentCharges: 6000, flyerIncome: 1000, ticket: 5000, flightCosts: 250, otherCosts: 0, profit: 1750 })
    expect(body.flights[0].margin).toBe(1750)
    expect(body.flights[0].flightCostTotal).toBe(250)
  })
})

describe('Profit breakdowns', () => {
  it("gives each shipment a share of the flight costs by weight and leaves bill costs out", () => {
    const shipment = { charge: 4800, customsTax: 0, afterSalesFee: 0, bookedKg: 4.5, weighedKg: 4, invoice: { total: 5100 }, costs: [{ amount: 300, voidedAt: null }, { amount: 999, voidedAt: new Date() }] }
    expect(shipmentProfitBreakdown(shipment, { flightCostTotal: 2150, flightKg: 38 })).toEqual({ charge: 4800, flightCostShare: 226.32, billCosts: 300, otherCosts: 0, profit: 4573.68, shareKg: 4, flightKg: 38 })
    // Booked weight until weighed; nothing shared without a flight or weight.
    expect(shipmentProfitBreakdown({ ...shipment, weighedKg: null }, { flightCostTotal: 2150, flightKg: 38 }).shareKg).toBe(4.5)
    expect(shipmentProfitBreakdown(shipment, null)).toMatchObject({ flightCostShare: 0, profit: 4800, flightKg: 0 })
    expect(shipmentProfitBreakdown({ ...shipment, bookedKg: 0, weighedKg: null }, { flightCostTotal: 2150, flightKg: 38 }).flightCostShare).toBe(0)
  })

  it('treats a discount as lower charge and before an invoice uses the charge less credits', () => {
    const discounted = { charge: 4800, customsTax: 100, afterSalesFee: 200, bookedKg: 4, invoice: { total: 4900 }, costs: [{ amount: 300, voidedAt: null }] }
    expect(shipmentProfitBreakdown(discounted, null)).toMatchObject({ charge: 4500, billCosts: 400 })
    expect(shipmentProfitBreakdown({ ...discounted, invoice: null }, null)).toMatchObject({ charge: 4600 })
  })

  it('computes flight profit as charges + flyers − ticket − flight costs', () => {
    expect(flightProfitBreakdown({
      fare: 6000, actualCost: 18000,
      expenses: [{ category: 'ticket', amount: 18000 }, { category: 'transport', amount: 900 }, { category: 'customs', amount: 400 }, { category: 'customs', amount: -400 }],
      shipments: [{ charge: 4800, customsTax: 0, afterSalesFee: 0, bookedKg: 4, invoice: { total: 5100 }, costs: [{ amount: 300, voidedAt: null }] }],
    })).toEqual({ shipmentCharges: 4800, flyerIncome: 6000, ticket: 18000, flightCosts: 900, otherCosts: 0, profit: -8100 })
  })

  it('keeps older unbilled shipment costs as otherCosts on the shipment and the flight', () => {
    const shipment = {
      charge: 4800, customsTax: 0, afterSalesFee: 0, bookedKg: 4, invoice: { total: 4800 }, costs: [], cnFare: 200, bdFare: 150,
      expenses: [
        { amount: 100, category: 'courier', costId: null, costField: null, flightId: null }, // old extra: counts
        { amount: 50, category: 'transport', costId: null, costField: 'cnFare', flightId: null }, // pays the fare: already counted
        { amount: 300, category: 'courier', costId: 'c1', costField: null, flightId: null }, // a cost on the bill: pass-through
        { amount: 999, category: 'ticket', costId: null, costField: null, flightId: 'fl-1' }, // a ticket row: on the flight
        { amount: 40, category: 'packaging', costId: null, costField: null, flightId: null }, // removed ...
        { amount: -40, category: 'packaging', costId: null, costField: null, flightId: null }, // ... with its twin
      ],
    }
    expect(shipmentProfitBreakdown(shipment, { flightCostTotal: 380, flightKg: 8 })).toEqual({ charge: 4800, flightCostShare: 190, billCosts: 0, otherCosts: 450, profit: 4160, shareKg: 4, flightKg: 8 })
    expect(flightProfitBreakdown({
      fare: 1000, actualCost: 3000, expenses: [{ category: 'courier', amount: 380 }],
      shipments: [shipment, { ...shipment, cnFare: 0, bdFare: null, expenses: [] }],
    })).toEqual({ shipmentCharges: 9600, flyerIncome: 1000, ticket: 3000, flightCosts: 380, otherCosts: 450, profit: 6770 })
  })

  it("adds the shipment's breakdown to the admin detail only", async () => {
    const store = shipmentStore({ flightId: 'fl-1', flight: { id: 'fl-1', code: FLIGHT_CODE, date: new Date('2026-10-24'), spaceKg: 44, agencyShare: 12000 }, bookedKg: 4.5, weighedKg: 4, charge: 4800 })
    store.invoice = issuedInvoice(5100)
    store.costs.push({ id: 'c1', name: 'Courier to customer', category: 'courier', amount: 300, voidedAt: null, createdAt: day(-3), sourceCurrency: 'BDT', sourceAmount: 300, sourceFxRate: 1, expenses: [] })
    db.flight.findUnique.mockResolvedValue({
      expenses: [{ category: 'ticket', amount: 18000 }, { category: 'transport', amount: 900 }, { category: 'packaging', amount: 650 }, { category: 'courier', amount: 600 }],
      shipments: [{ bookedKg: 4.5, weighedKg: 4 }, { bookedKg: 34, weighedKg: null }],
    })
    const admin = ((await (await appFor('admin', '/shipments', shipmentRoutes).request('/shipments/SH-18')).json()) as Any).shipment
    expect(admin.profitBreakdown).toEqual({ charge: 4800, flightCostShare: 226.32, billCosts: 300, otherCosts: 0, profit: 4573.68, shareKg: 4, flightKg: 38 })
    const hub = ((await (await appFor('hub', '/shipments', shipmentRoutes).request('/shipments/SH-18')).json()) as Any).shipment
    expect(hub).not.toHaveProperty('profitBreakdown')
  })
})

// ─────────────────────────────────────────────────────────────────────────
// Automatic invoices
// ─────────────────────────────────────────────────────────────────────────

interface Store {
  shipment: Any
  invoice: Any
  costs: Any[]
  logs: { message: string; actor: string; at: Date }[]
  revisions: Any[]
  creditNotes: Any[]
}

/** One shipment held in memory, read the way findByCode and the billing helpers read it. */
function shipmentStore(over: Record<string, unknown> = {}): Store {
  const store: Store = { shipment: shipmentFixture(over), invoice: null, costs: [], logs: [], revisions: [], creditNotes: [] }
  const view = () => ({ ...store.shipment, invoice: store.invoice, costs: store.costs, logs: [...store.logs].reverse(), receipts: [], expenses: [], payments: [] })
  db.shipment.findUnique.mockImplementation(async ({ where }: Any) => (where.id === store.shipment.id || where.code === store.shipment.code ? view() : null))
  db.shipment.update.mockImplementation(async ({ data }: Any) => {
    Object.assign(store.shipment, data)
    return store.shipment
  })
  db.invoice.upsert.mockImplementation(async ({ create, update }: Any) => {
    store.invoice = store.invoice ? { ...store.invoice, ...update, updatedAt: new Date() } : { id: 'inv-1', note: '', issuedAt: new Date(), updatedAt: new Date(), ...create }
    return store.invoice
  })
  db.invoice.update.mockImplementation(async ({ data }: Any) => (store.invoice = { ...store.invoice, ...data }))
  db.invoiceRevision.count.mockImplementation(async () => store.revisions.length)
  db.invoiceRevision.create.mockImplementation(async ({ data }: Any) => store.revisions.push(data))
  db.creditNote.create.mockImplementation(async ({ data }: Any) => store.creditNotes.push(data))
  db.shipmentLog.create.mockImplementation(async ({ data }: Any) => store.logs.push({ ...data, at: new Date() }))
  return store
}

describe('Automatic invoices', () => {
  const admin = () => appFor('admin', '/shipments', shipmentRoutes)

  function bookingStore() {
    const store = shipmentStore()
    db.supplier.findUnique.mockResolvedValue(supplierA)
    db.shipment.findMany.mockResolvedValue([{ code: 'SH-100' }])
    db.shipment.create.mockImplementation(async ({ data }: Any) => {
      store.shipment = shipmentFixture({ ...data, id: 'sh-new', weighedKg: null, afterSalesFee: 0, customsTax: 0, paidAmount: 0 })
      return store.shipment
    })
    return store
  }
  const book = (body: Record<string, unknown>) => admin().request('/shipments', send('POST', { supplierCode: 'SUP-004', categories: ['Mobile'], ...body }))

  it('issues the bill when a shipment is booked', async () => {
    const store = bookingStore()
    const response = await book({ bookedKg: 4, chargeRate: 950, pcsItems: [{ category: 'Mobile', count: 2, rate: 500 }] })
    expect(response.status).toBe(201)
    expect(await response.json()).toEqual({ code: 'SH-101' })
    expect(store.invoice).toMatchObject({ state: 'issued', pricingMode: 'automatic', needsReview: false, total: 4800, number: expect.stringMatching(/^INV-\d{4}-SH-101$/) })
    expect(store.invoice.lines.map((l: Any) => l.amount)).toEqual([3800, 1000])
    expect(store.revisions).toHaveLength(1)
    expect(store.logs.some((l) => l.message.startsWith('Bill issued automatically'))).toBe(true)
  })

  it('issues a ৳0 bill for a free booking and keeps an unpriced one as a draft', async () => {
    const free = bookingStore()
    expect((await book({ bookedKg: 2, freeOfCharge: true })).status).toBe(201)
    expect(free.invoice).toMatchObject({ state: 'issued', total: 0, needsReview: false })
    expect(free.shipment).toMatchObject({ freeOfCharge: true, payStatus: 'paid' })

    vi.clearAllMocks()
    const unpriced = bookingStore()
    expect((await book({ bookedKg: 2 })).status).toBe(201)
    expect(unpriced.invoice).toMatchObject({ state: 'draft', total: 0, pricingMode: 'automatic' })

    expect((await book({ bookedKg: 2, chargeRate: 500, freeOfCharge: true })).status).toBe(400)
  })

  it('re-calculates an issued automatic bill when the charge changes and keeps it issued', async () => {
    const store = shipmentStore()
    store.invoice = issuedInvoice(3800, { lines: [{ label: 'Shipping · 4 kg × BDT 950.00', amount: 3800 }] })
    const up = await admin().request('/shipments/SH-18', send('PATCH', { chargeRate: 1000 }))
    expect(up.status).toBe(200)
    expect(store.invoice).toMatchObject({ state: 'issued', needsReview: false, total: 4000 })
    expect(store.revisions.at(-1)).toMatchObject({ reason: 'Shipment pricing changed', snapshot: expect.objectContaining({ total: 4000, state: 'issued' }) })
    expect(store.creditNotes).toHaveLength(0)

    const down = await admin().request('/shipments/SH-18', send('PATCH', { chargeRate: 900 }))
    expect(down.status).toBe(200)
    expect(store.invoice.total).toBe(3600)
    expect(store.creditNotes).toEqual([expect.objectContaining({ amount: 400, revisedTotal: 3600 })])
    expect(store.logs.filter((l) => l.message.startsWith('Bill updated automatically'))).toHaveLength(2)
  })

  it('moves an overpayment to customer credit when the bill falls below what was paid', async () => {
    const store = shipmentStore({ paidAmount: 3800, payStatus: 'paid' })
    store.invoice = issuedInvoice(3800, { lines: [{ label: 'Shipping · 4 kg × BDT 950.00', amount: 3800 }] })
    db.supplier.findUniqueOrThrow.mockResolvedValue({ ...supplierA, creditBalance: 0 })
    const credits: Any[] = []
    db.customerCredit.create.mockImplementation(async ({ data }: Any) => credits.push(data))
    expect((await admin().request('/shipments/SH-18', send('PATCH', { chargeRate: 900 }))).status).toBe(200)
    expect(credits).toEqual([expect.objectContaining({ amount: 200, kind: 'bill-reduction', shipmentCode: 'SH-18' })])
    expect(db.supplier.update).toHaveBeenCalledWith({ where: { id: 'sup-1' }, data: { creditBalance: { increment: 200 } } })
    expect(store.shipment).toMatchObject({ paidAmount: 3600, payStatus: 'paid' })
  })

  it('still flags a hand-edited invoice for review instead of rewriting it', async () => {
    const store = shipmentStore()
    store.invoice = issuedInvoice(3500, { pricingMode: 'manual', lines: [{ label: 'Agreed price', amount: 3500 }] })
    expect((await admin().request('/shipments/SH-18', send('PATCH', { chargeRate: 1000 }))).status).toBe(200)
    expect(db.invoice.upsert).not.toHaveBeenCalled()
    expect(store.invoice).toMatchObject({ pricingMode: 'manual', state: 'issued', needsReview: true, total: 3500 })
  })

  it('issues an older shipment the first time an admin opens it', async () => {
    const store = shipmentStore({ bookedKg: 2, chargeRate: 500, charge: 1000 })
    const hub = await appFor('hub', '/shipments', shipmentRoutes).request('/shipments/SH-18')
    expect(hub.status).toBe(200)
    expect(db.invoice.upsert).not.toHaveBeenCalled()

    const opened = await admin().request('/shipments/SH-18')
    expect(opened.status).toBe(200)
    const body = ((await opened.json()) as Any).shipment
    expect(body.invoice).toMatchObject({ state: 'issued', total: 1000, pricingMode: 'automatic' })
    expect(store.logs.map((l) => l.message)).toContain(`Bill issued automatically: ${store.invoice.number} — ৳1,000`)
    expect(store.logs.find((l) => l.message.startsWith('Bill issued automatically'))?.actor).toBe('System')

    await admin().request('/shipments/SH-18/invoice')
    expect(db.invoice.upsert).toHaveBeenCalledTimes(1)
  })

  it('issues an automatic draft from the invoice view but leaves a ৳0 one alone', async () => {
    const store = shipmentStore({ bookedKg: 2, chargeRate: 0, charge: 0 })
    store.invoice = issuedInvoice(0, { state: 'draft', lines: [{ label: 'Shipment charges', amount: 0 }] })
    const empty = await admin().request('/shipments/SH-18/invoice')
    expect(((await empty.json()) as Any).invoice.state).toBe('draft')
    expect(db.invoice.upsert).not.toHaveBeenCalled()

    store.shipment.charge = 1000
    store.shipment.chargeRate = 500
    const priced = await admin().request('/shipments/SH-18/invoice')
    expect(((await priced.json()) as Any).invoice).toMatchObject({ state: 'issued', total: 1000 })
  })

  it('lets an unpaid automatic shipment be deleted, never a hand-edited or paid one', async () => {
    const store = shipmentStore()
    store.invoice = issuedInvoice(3800)
    db.customerCredit.count.mockResolvedValue(0)
    db.creditNote.count.mockResolvedValue(0)
    expect((await admin().request('/shipments/SH-18', send('DELETE'))).status).toBe(200)
    expect(db.invoiceRevision.deleteMany).toHaveBeenCalledWith({ where: { invoiceId: 'inv-1' } })
    expect(db.invoice.delete).toHaveBeenCalledWith({ where: { id: 'inv-1' } })
    expect(db.shipment.delete).toHaveBeenCalledWith({ where: { id: 'sh-1' } })

    store.invoice = issuedInvoice(3800, { pricingMode: 'manual' })
    expect((await admin().request('/shipments/SH-18', send('DELETE'))).status).toBe(400)
    store.invoice = issuedInvoice(3800)
    store.shipment.paidAmount = 100
    expect((await admin().request('/shipments/SH-18', send('DELETE'))).status).toBe(400)
  })
})

// ─────────────────────────────────────────────────────────────────────────
// Late payments
// ─────────────────────────────────────────────────────────────────────────

describe('Late payments', () => {
  const late = (over: Record<string, unknown>) => shipmentFixture({ status: 'delivered', charge: 6300, ...over })

  it('is late 10 days after handover for after-delivery bills', () => {
    const today = new Date('2026-10-27')
    const ships = [
      late({ code: 'SH-9', handedOverAt: new Date('2026-10-18T15:00:00Z') }),
      late({ code: 'SH-12', handedOverAt: new Date('2026-10-15T09:00:00Z'), supplier: supplierB, supplierId: supplierB.id }),
      late({ code: 'SH-PAID', handedOverAt: new Date('2026-10-01'), paidAmount: 6300 }),
      late({ code: 'SH-FREE', handedOverAt: new Date('2026-10-01'), freeOfCharge: true }),
      late({ code: 'SH-ROAD', handedOverAt: null, status: 'out_for_delivery', createdAt: new Date('2026-09-01') }),
    ]
    expect(LATE_DAYS).toBe(10)
    expect(latePayments(ships, today)).toEqual({
      rows: [{ kind: 'after_delivery', customerCode: 'SUP-009', customerName: 'Bismillah Telecom', shipmentCode: 'SH-12', amount: 6300, days: 12, since: '2026-10-15' }],
      count: 1,
    })
  })

  it('is late 10 days after the month ends for monthly customers, one row per customer and month', () => {
    const monthly = (code: string, createdAt: string, over: Record<string, unknown> = {}) =>
      shipmentFixture({ code, supplier: supplierB, supplierId: supplierB.id, paymentTerms: 'monthly', createdAt: new Date(createdAt), invoice: issuedInvoice(1000), status: 'in_transit', ...over })
    const ships = [
      monthly('SH-A', '2026-09-03T10:00:00Z'),
      monthly('SH-B', '2026-09-20T10:00:00Z', { paidAmount: 400 }),
      monthly('SH-DRAFT', '2026-09-21T10:00:00Z', { invoice: issuedInvoice(1000, { state: 'draft' }) }),
      monthly('SH-OCT', '2026-10-02T10:00:00Z'),
    ]
    expect(latePayments(ships, new Date('2026-10-09')).count).toBe(0)
    expect(latePayments(ships, new Date('2026-10-10')).rows).toEqual([
      { kind: 'monthly', customerCode: 'SUP-009', customerName: 'Bismillah Telecom', month: '2026-09', monthLabel: 'September 2026', amount: 1600, days: 10 },
    ])
  })

  it('marks Get paid rows overdue after 10 days instead of 7', async () => {
    db.statementLink.findMany.mockResolvedValue([])
    db.shipment.findMany.mockImplementation(listing([
      shipmentFixture({ code: 'SH-9', status: 'delivered', handedOverAt: day(-9) }),
      shipmentFixture({ code: 'SH-12', status: 'delivered', handedOverAt: day(-12) }),
    ]))
    const body = (await (await appFor('admin', '/', dashboardRoutes).request('/collect')).json()) as Any
    expect(body.afterDelivery.handedOver.map((r: Any) => [r.code, r.days, r.overdue])).toEqual([['SH-12', 12, true], ['SH-9', 9, false]])
    expect(body.afterDelivery.overdueCount).toBe(1)
  })

  it('lists late customers on the overview with a count', async () => {
    const ships = [
      ...Array.from({ length: 11 }, (_, i) => shipmentFixture({ id: `sh-${i}`, code: `SH-${200 + i}`, status: 'delivered', handedOverAt: day(-11 - i), charge: 100 + i })),
      shipmentFixture({ id: 'sh-on-time', code: 'SH-300', status: 'delivered', handedOverAt: day(-3) }),
    ]
    db.shipment.findMany.mockImplementation(listing(ships))
    db.flight.findMany.mockResolvedValue([])
    db.todo.findMany.mockResolvedValue([])
    db.flyer.findMany.mockResolvedValue([])
    db.statementLink.findMany.mockResolvedValue([])
    db.account.findMany.mockResolvedValue([])
    db.expense.findMany.mockResolvedValue([])
    db.payment.findMany.mockResolvedValue([])
    db.customerRefund.findMany.mockResolvedValue([])
    db.fundTransfer.findMany.mockResolvedValue([])
    db.supplier.aggregate.mockResolvedValue({ _sum: { creditBalance: 0 } })
    const response = await appFor('admin', '/', dashboardRoutes).request('/overview')
    expect(response.status).toBe(200)
    const body = (await response.json()) as Any
    expect(body.latePaymentsCount).toBe(11)
    expect(body.latePayments).toHaveLength(10)
    expect(body.latePayments[0]).toMatchObject({ kind: 'after_delivery', shipmentCode: 'SH-210', days: 21, amount: 110, customerName: 'Nila Store' })
    expect(body.latePayments.map((r: Any) => r.days)).toEqual([21, 20, 19, 18, 17, 16, 15, 14, 13, 12])
  })
})

// ─────────────────────────────────────────────────────────────────────────
// Finance summary: flight costs counted once
// ─────────────────────────────────────────────────────────────────────────

describe('Flight costs in the finance summary', () => {
  it('counts flight costs once with their flight, keeps unpaid ones out of cash and in payables', async () => {
    db.account.findMany.mockResolvedValue([])
    db.payment.findMany.mockResolvedValue([])
    db.customerRefund.findMany.mockResolvedValue([])
    db.fundTransfer.findMany.mockResolvedValue([])
    db.supplier.aggregate.mockResolvedValue({ _sum: { creditBalance: 0 } })
    db.shipment.findMany.mockResolvedValue([])
    db.flight.findMany.mockResolvedValue([{ id: 'fl-1', date: new Date('2026-10-24'), actualCost: 18000, agencyShare: 12000, flyerPaidAmount: 6000 }])
    const posted = { accountName: 'Dhaka cash', accountCurrency: 'BDT', accountAmount: 1, fxRate: 1 }
    db.expense.findMany.mockResolvedValue([
      expenseRow({ id: 'ticket', category: 'ticket', amount: 18000, ...posted }),
      expenseRow({ id: 'paid', amount: 900, ...posted }),
      expenseRow({ id: 'unpaid', category: 'courier', amount: 600 }),
      expenseRow({ id: 'gone', category: 'customs', amount: 400, reversedAt: new Date() }),
      expenseRow({ id: 'gone-twin', category: 'customs', amount: -400, reversalOfId: 'gone' }),
      expenseRow({ id: 'gone-paid', amount: 300, reversedAt: new Date(), ...posted }),
      expenseRow({ id: 'gone-paid-twin', amount: -300, reversalOfId: 'gone-paid', ...posted }),
      expenseRow({ id: 'rent', flightId: null, category: 'others', amount: 2000, ...posted }),
    ].map((e) => ({ ...e, shipment: null, flight: e.flightId ? { code: FLIGHT_CODE } : null })))

    const summary = await financialSummary('all')
    // Cash out: ticket 18,000 + paid 900 + rent 2,000 (the removed paid cost nets to 0).
    expect(summary.expenses).toBe(20900)
    expect(summary.expenseRows.map((r) => r.amount).sort((a, b) => a - b)).toEqual([-300, 300, 900, 2000, 18000])
    expect(summary.results).toMatchObject({ tickets: 18000, flightCosts: 1500, businessExpenses: 2000, otherExpenses: 3500, costs: 21500 })
    expect(summary.costPayables).toBe(600)
  })

  it('counts older unbilled shipment costs exactly once', async () => {
    db.account.findMany.mockResolvedValue([])
    db.payment.findMany.mockResolvedValue([])
    db.customerRefund.findMany.mockResolvedValue([])
    db.fundTransfer.findMany.mockResolvedValue([])
    db.supplier.aggregate.mockResolvedValue({ _sum: { creditBalance: 0 } })
    db.flight.findMany.mockResolvedValue([])
    const costOnBill = { id: 'c1', name: 'Courier charge', category: 'courier', amount: 300, voidedAt: null, createdAt: day(-3), sourceCurrency: 'BDT', sourceAmount: 300, sourceFxRate: 1 }
    const posted = { accountName: 'Dhaka cash', accountCurrency: 'BDT', accountAmount: 1, fxRate: 1, flightId: null, shipmentId: 'sh-1' }
    const rows = [
      expenseRow({ id: 'old-extra', category: 'courier', amount: 100, ...posted }),
      expenseRow({ id: 'fare-payment', category: 'transport', amount: 50, costField: 'cnFare', ...posted }),
      expenseRow({ id: 'bill-cost-payment', category: 'courier', amount: 300, costId: 'c1', ...posted }),
      expenseRow({ id: 'removed', category: 'packaging', amount: 40, reversedAt: new Date(), ...posted }),
      expenseRow({ id: 'removed-twin', category: 'packaging', amount: -40, reversalOfId: 'removed', ...posted }),
    ]
    db.expense.findMany.mockResolvedValue(rows.map((e) => ({ ...e, shipment: { code: 'SH-18' }, flight: null })))
    db.shipment.findMany.mockResolvedValue([shipmentFixture({ cnFare: 200, bdFare: 150, charge: 4800, invoice: issuedInvoice(5100), costs: [costOnBill], expenses: rows })])
    const { results } = await financialSummary('all')
    // 200 + 150 + 100 older costs (what profit calls otherCosts) plus the 300 cost on the bill, once each.
    expect(results).toMatchObject({ cnTransport: 200, bdTransport: 150, shipmentCosts: 750, businessExpenses: 0, flightCosts: 0, billing: 5100, profit: 4350 })
  })
})

// ─────────────────────────────────────────────────────────────────────────
// Catch-up: older shipments get their automatic bill without being opened
// ─────────────────────────────────────────────────────────────────────────

describe('Automatic bill catch-up', () => {
  const month = new Date().toISOString().slice(0, 7)

  /** Answers the catch-up query for the in-memory shipment the way Postgres would; list reads get the shipment. */
  function pendingQuery(store: Store) {
    db.shipment.findMany.mockImplementation(async (args?: Any) => {
      const s = store.shipment
      if (!args?.where?.AND) return [await db.shipment.findUnique({ where: { id: s.id } })]
      const awaiting = !store.invoice || (store.invoice.pricingMode === 'automatic' && store.invoice.state === 'draft')
      const billable = Number(s.charge) > 0 || Number(s.customsTax) > 0 || s.freeOfCharge || store.costs.some((c) => !c.voidedAt)
      const inScope = !args.where.supplierId || args.where.supplierId === s.supplierId
      return awaiting && billable && inScope ? [{ id: s.id }] : []
    })
  }
  const quiet = () => [vi.spyOn(console, 'warn').mockImplementation(() => undefined), vi.spyOn(console, 'log').mockImplementation(() => undefined)]

  it('issues each waiting bill once with the usual log line, then finds nothing', async () => {
    const store = shipmentStore({ bookedKg: 2, chargeRate: 500, charge: 1000 })
    pendingQuery(store)
    expect(await issuePendingInvoices()).toBe(1)
    expect(db.shipment.findMany.mock.calls[0]![0]).toEqual({ where: PENDING_AUTOMATIC_BILL, select: { id: true }, orderBy: { createdAt: 'asc' } })
    expect(store.invoice).toMatchObject({ state: 'issued', pricingMode: 'automatic', needsReview: false, total: 1000 })
    expect(store.logs.filter((l) => l.message.startsWith('Bill issued automatically'))).toEqual([
      expect.objectContaining({ actor: 'System', message: `Bill issued automatically: ${store.invoice.number} — ৳1,000` }),
    ])
    expect(await issuePendingInvoices()).toBe(0)
    expect(db.invoice.upsert).toHaveBeenCalledTimes(1)
  })

  it('only looks at missing or automatic-draft bills that have something to bill', () => {
    const [which, billable] = PENDING_AUTOMATIC_BILL.AND
    expect(which!.OR).toEqual([{ invoice: { is: null } }, { invoice: { is: { pricingMode: 'automatic', state: 'draft' } } }])
    expect(billable!.OR).toEqual([{ charge: { gt: 0 } }, { customsTax: { gt: 0 } }, { freeOfCharge: true }, { costs: { some: { voidedAt: null } } }])
  })

  it('leaves an unpriced draft alone and keeps going past a shipment that fails', async () => {
    const unpriced = shipmentStore({ bookedKg: 2, chargeRate: 0, charge: 0 })
    pendingQuery(unpriced)
    expect(await issuePendingInvoices()).toBe(0)
    expect(db.invoice.upsert).not.toHaveBeenCalled()

    const [warn, log] = quiet()
    try {
      const store = shipmentStore({ bookedKg: 2, chargeRate: 500, charge: 1000 })
      db.shipment.findMany.mockResolvedValueOnce([{ id: 'missing' }, { id: store.shipment.id }])
      expect(await issuePendingInvoices()).toBe(1)
      expect(store.invoice.state).toBe('issued')
      expect(warn).toHaveBeenCalledWith(expect.stringContaining('could not issue the automatic bill for shipment missing'))
    } finally {
      warn!.mockRestore()
      log!.mockRestore()
    }
  })

  it('never throws, and the startup run returns at once and only logs', async () => {
    const [warn, log] = quiet()
    try {
      db.shipment.findMany.mockRejectedValueOnce(new Error('database restarting'))
      expect(await issuePendingInvoices()).toBe(0)
      expect(warn).toHaveBeenCalledWith(expect.stringContaining('catch-up skipped: database restarting'))

      pendingQuery(shipmentStore({ bookedKg: 2, chargeRate: 500, charge: 1000 }))
      const started = startInvoiceCatchUp()
      expect(started).toBeInstanceOf(Promise)
      await expect(started).resolves.toBeUndefined()
      expect(log).toHaveBeenCalledWith('[billing] automatic bill catch-up issued 1 bill(s)')
    } finally {
      warn!.mockRestore()
      log!.mockRestore()
    }
  })

  it('runs before Get paid counts this month\'s monthly bills', async () => {
    const store = shipmentStore({ supplier: supplierB, supplierId: supplierB.id, paymentTerms: 'monthly', createdAt: new Date(), bookedKg: 2, chargeRate: 500, charge: 1000 })
    pendingQuery(store)
    db.statementLink.findMany.mockResolvedValue([])
    const body = (await (await appFor('admin', '/', dashboardRoutes).request('/collect')).json()) as Any
    expect(body.monthly.customers).toEqual([expect.objectContaining({ code: 'SUP-009', billed: 1000, due: 1000, shipments: 1 })])
    expect(store.invoice.state).toBe('issued')
  })

  it('runs before the overview counts what customers owe', async () => {
    const store = shipmentStore({ bookedKg: 2, chargeRate: 500, charge: 1000 })
    pendingQuery(store)
    for (const read of [db.flight.findMany, db.todo.findMany, db.flyer.findMany, db.statementLink.findMany, db.account.findMany, db.expense.findMany, db.payment.findMany, db.customerRefund.findMany, db.fundTransfer.findMany]) read.mockResolvedValue([])
    db.supplier.aggregate.mockResolvedValue({ _sum: { creditBalance: 0 } })
    const body = (await (await appFor('admin', '/', dashboardRoutes).request('/overview')).json()) as Any
    expect(body.unpaid).toBe(1000)
    expect(store.invoice.state).toBe('issued')
  })

  it("runs for the customer before a monthly statement is made", async () => {
    const store = shipmentStore({ supplier: supplierB, supplierId: supplierB.id, paymentTerms: 'monthly', createdAt: new Date(`${month}-02T10:00:00Z`), bookedKg: 2, chargeRate: 500, charge: 1000 })
    pendingQuery(store)
    db.supplier.findUnique.mockResolvedValue(supplierB)
    const response = await appFor('admin', '/suppliers', statementAdminRoutes).request('/suppliers/SUP-009/statement-link', send('POST', { month }))
    expect(response.status).toBe(201)
    expect(db.shipment.findMany.mock.calls[0]![0].where).toMatchObject({ supplierId: 'sup-2', AND: PENDING_AUTOMATIC_BILL.AND })
    expect(store.invoice.state).toBe('issued')
    expect(db.statementLink.create.mock.calls[0]![0].data).toMatchObject({ supplierId: 'sup-2', month })
  })
})
