import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono, type Context, type Next } from 'hono'
import type { AppEnv, Role } from '../src/modules/auth'

const db = vi.hoisted(() => ({
  shipment: { findMany: vi.fn() },
  statementLink: { findMany: vi.fn() },
}))
vi.mock('../src/core/db', () => ({ prisma: db }))
vi.mock('../src/shared/financialSummary', () => ({ financialSummary: vi.fn() }))
vi.mock('../src/core/redis', () => ({ cacheGetJson: vi.fn(), cacheSetJson: vi.fn() }))
vi.mock('../src/modules/flights', () => ({ autoCompletePastFlights: vi.fn() }))
vi.mock('../src/shared/hubTodos', () => ({ syncHubTodos: vi.fn() }))
// The bill catch-up has its own tests in round7.test.ts.
vi.mock('../src/shared/shipmentBilling', () => ({ issuePendingInvoices: vi.fn(async () => 0) }))
vi.mock('../src/modules/auth', () => ({ requireRole: (...roles: Role[]) => async (c: Context<AppEnv>, next: Next) => {
  if (!roles.includes(c.get('user').role)) return c.json({ error: 'Forbidden' }, 403)
  await next()
} }))
const { dashboardRoutes } = await import('../src/modules/dashboard')
const { usualCosts } = await import('../src/shared/shipmentCosts')

function appFor(role: Role) {
  const app = new Hono<AppEnv>()
  app.use('*', async (c, next) => {
    c.set('user', { id: 'unit-test', name: 'Unit test', email: 'unit@example.invalid', role, roleLabel: role })
    await next()
  })
  return app.route('/', dashboardRoutes)
}

const day = (offset: number) => new Date(Date.now() + offset * 86_400_000)
const month = new Date().toISOString().slice(0, 7)
const supplier = (code: string, name: string) => ({ id: `id-${code}`, code, name, phone: '01700000000' })

function shipment(code: string, over: Record<string, unknown>) {
  const owner = (over.supplier as ReturnType<typeof supplier>) ?? supplier('C-1', 'Nila Store')
  return {
    id: `id-${code}`, code, supplierId: owner.id, supplier: owner,
    paymentTerms: 'invoice', freeOfCharge: false, status: 'delivered', handedOverAt: day(-1), createdAt: day(-3),
    charge: 1000, customsTax: 0, afterSalesFee: 0, paidAmount: 0, invoice: null,
    cnFare: 0, bdFare: 0, costSources: {}, expenses: [], costs: [], receipts: [],
    ...over,
  }
}

beforeEach(() => {
  vi.clearAllMocks()
  db.statementLink.findMany.mockResolvedValue([])
})

describe('Get paid list', () => {
  it('lists handed-over after-delivery bills oldest first and keeps monthly bills apart', async () => {
    const issued = { state: 'issued', needsReview: false, total: 5000 }
    db.shipment.findMany.mockResolvedValue([
      shipment('SH-21', { charge: 11250, handedOverAt: day(-1) }),
      shipment('SH-14', { charge: 6300, handedOverAt: day(-12), supplier: supplier('C-22', 'Bismillah Telecom') }),
      shipment('SH-30', { charge: 800, paidAmount: 800 }),
      shipment('SH-51', { charge: 10050, status: 'out_for_delivery', handedOverAt: null }),
      shipment('SH-60', { charge: 900, status: 'received_bd_hub', handedOverAt: null }),
      shipment('SH-18', { paymentTerms: 'monthly', invoice: issued, paidAmount: 1000, createdAt: new Date(`${month}-02T10:00:00Z`) }),
      shipment('SH-70', { paymentTerms: 'monthly', invoice: { ...issued, state: 'draft' } }),
    ])
    db.statementLink.findMany.mockResolvedValue([{ supplierId: 'id-C-1', createdAt: day(-2), expiresAt: day(5) }])

    const response = await appFor('admin').request('/collect')
    expect(response.status).toBe(200)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const body = (await response.json()) as any

    expect(body.afterDelivery.handedOver.map((row: { code: string }) => row.code)).toEqual(['SH-14', 'SH-21'])
    expect(body.afterDelivery.handedOver[0]).toMatchObject({ supplierName: 'Bismillah Telecom', amount: 6300, days: 12, overdue: true })
    expect(body.afterDelivery.handedOver[1]).toMatchObject({ amount: 11250, days: 1, overdue: false })
    expect(body.afterDelivery.due).toBe(17550)
    expect(body.afterDelivery.overdueCount).toBe(1)
    expect(body.afterDelivery.comingSoon).toEqual([
      expect.objectContaining({ code: 'SH-51', amount: 10050, status: 'out_for_delivery' }),
    ])

    expect(body.monthly.month).toBe(month)
    expect(body.monthly.customers).toEqual([
      expect.objectContaining({ code: 'C-1', billed: 5000, paid: 1000, due: 4000, shipments: 1, linkActive: true }),
    ])
    expect(body.monthly.due).toBe(4000)
  })

  it('is admin only', async () => {
    const response = await appFor('hub').request('/collect')
    expect(response.status).toBe(403)
    expect(db.shipment.findMany).not.toHaveBeenCalled()
  })
})

describe('Usual shipment costs', () => {
  it('reports each of the four usual costs, counting legacy fields and skipping voided costs', () => {
    const costs = usualCosts({
      cnFare: 120 as never,
      bdFare: 0 as never,
      customsTax: 400 as never,
      costSources: {},
      expenses: [],
      costs: [
        { id: 'c1', name: 'Box', category: 'packaging', amount: 150, createdAt: day(0), voidedAt: null, sourceCurrency: 'BDT', sourceAmount: null, sourceFxRate: 1 },
        { id: 'c2', name: 'Courier', category: 'courier', amount: 300, createdAt: day(0), voidedAt: day(0), sourceCurrency: 'BDT', sourceAmount: null, sourceFxRate: 1 },
      ] as never,
    })
    expect(costs).toEqual([
      { category: 'packaging', amount: 150 },
      { category: 'courier', amount: 0 },
      { category: 'customs', amount: 400 },
      { category: 'transport', amount: 120 },
    ])
  })
})
