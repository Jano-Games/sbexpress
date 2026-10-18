import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { FinancialSummarySnapshot } from '../src/shared/financialSummary'

const db = vi.hoisted(() => ({
  setting: { findMany: vi.fn() },
  account: { findMany: vi.fn() },
  expense: { findMany: vi.fn() },
  payment: { findMany: vi.fn() },
  supplier: { findMany: vi.fn(), aggregate: vi.fn() },
  shipment: { findMany: vi.fn() },
  flight: { findMany: vi.fn() },
  customerRefund: { findMany: vi.fn() },
  fundTransfer: { findMany: vi.fn() },
}))
vi.mock('../src/core/db', () => ({ prisma: db }))
const { financialSummary } = await import('../src/shared/financialSummary')

const settings = { rate: 17, exchangeRates: { BDT: 1, CNY: 17 }, threshold: 1, investBdt: 20, investCny: 2, pcsRates: {} }
const suppliers = [{ id: 'supplier-a', code: 'SUP-A', name: 'Acme' }, { id: 'supplier-empty', code: 'SUP-EMPTY', name: 'No shipments' }]
const fixtureShipments = [
  { id: 'shipment-a', supplierId: 'supplier-a', createdAt: new Date('2026-09-03T12:00:00Z'), charge: 999, customsTax: 20, afterSalesFee: 0, invoice: { total: 100, state:"issued",needsReview:false }, paidAmount: 30, cnFare: 10, bdFare: 5, expenses: [] },
  { id: 'shipment-b', supplierId: 'supplier-a', createdAt: new Date('2026-09-04T12:00:00Z'), charge: 50, customsTax: 10, afterSalesFee: 5, invoice: null, paidAmount: 20, cnFare: 0, bdFare: 0, expenses: [] },
  { id: 'shipment-c', supplierId: 'supplier-a', createdAt: new Date('2026-09-05T12:00:00Z'), charge: 33.335, customsTax: 0, afterSalesFee: 0, invoice: null, paidAmount: 10.001, cnFare: 0, bdFare: 0, expenses: [] },
  { id: 'shipment-paid', supplierId: 'supplier-a', createdAt: new Date('2026-09-06T12:00:00Z'), charge: 25, customsTax: 0, afterSalesFee: 0, invoice: null, paidAmount: 30, cnFare: 0, bdFare: 0, expenses: [] },
  { id: 'shipment-old', supplierId: 'supplier-a', createdAt: new Date('2026-08-03T12:00:00Z'), charge: 40, customsTax: 0, afterSalesFee: 0, invoice: null, paidAmount: 0, cnFare: 0, bdFare: 0, expenses: [] },
  { id: 'shipment-other', supplierId: 'supplier-other', createdAt: new Date('2026-09-03T12:00:00Z'), charge: 90, customsTax: 0, afterSalesFee: 0, invoice: null, paidAmount: 0, cnFare: 0, bdFare: 0, expenses: [] },
]
const fixtureFlights = [{ id: 'flight-a', date: new Date('2026-09-04T12:00:00Z'), actualCost: 100, agencyShare: 40, flyerPaidAmount: 30 }]
const shipments = fixtureShipments as unknown as Awaited<NonNullable<FinancialSummarySnapshot['shipments']>>
const flights = fixtureFlights as unknown as Awaited<NonNullable<FinancialSummarySnapshot['flights']>>

beforeEach(() => {
  vi.clearAllMocks()
  db.setting.findMany.mockResolvedValue(Object.entries({ rate: 17, threshold: 1, investBdt: 20, investCny: 2, pcsRates: '{}' }).map(([key, value]) => ({ key, value: String(value) })))
  db.account.findMany.mockResolvedValue([{ name: 'BDT account', kind: 'cash', currency: 'BDT', balance: 100, paymentMethod: null }, { name: 'CNY account', kind: 'wallet', currency: 'CNY', balance: 5, paymentMethod: null }])
  db.expense.findMany.mockResolvedValue([])
  db.payment.findMany.mockResolvedValue([])
  db.supplier.findMany.mockResolvedValue(suppliers)
  db.supplier.aggregate.mockResolvedValue({ _sum: { creditBalance: 12 } })
  db.shipment.findMany.mockResolvedValue(shipments)
  db.flight.findMany.mockResolvedValue(flights)
  db.customerRefund.findMany.mockResolvedValue([])
  db.fundTransfer.findMany.mockResolvedValue([])
})

describe('Fresh financial summary query reuse', () => {
  it('returns identical financial values with a caller-provided response snapshot', async () => {
    const direct = await financialSummary('2026-09')
    vi.clearAllMocks()
    const reused = await financialSummary('2026-09', { settings: Promise.resolve(settings), shipments: Promise.resolve(shipments), flights: Promise.resolve(flights) })
    expect(reused).toEqual(direct)
    expect(db.setting.findMany).not.toHaveBeenCalled()
    expect(db.shipment.findMany).not.toHaveBeenCalled()
    expect(db.flight.findMany).not.toHaveBeenCalled()
    expect(reused.cash).toEqual({ bdt: 100, cny: 5, worth: 185 })
  })

  it('includes only reviewed issued invoices in payable statements without per-supplier reads', async () => {
    const result = await financialSummary('2026-09')
    // Finalized invoice overrides the 999 booking charge. Older and other-supplier
    // shipments are excluded; a surplus payment never creates a negative balance.
    const legacyBalance = 70
    expect(result.statements).toEqual([
      { code: 'SUP-A', name: 'Acme', billed: 100, paid: 30, balance: legacyBalance, shipmentCount: 1 },
      { code: 'SUP-EMPTY', name: 'No shipments', billed: 0, paid: 0, balance: 0, shipmentCount: 0 },
    ])
    expect(db.supplier.findMany).toHaveBeenCalledTimes(1)
    expect(db.shipment.findMany).toHaveBeenCalledTimes(1)
  })

  it('starts independent balance, refund and transfer reads before slower account reads finish', async () => {
    let finishAccounts!: (accounts: []) => void
    db.account.findMany.mockImplementationOnce(() => new Promise(resolve => { finishAccounts = resolve }))
    const pending = financialSummary('all')
    expect(db.customerRefund.findMany).toHaveBeenCalledTimes(1)
    expect(db.supplier.aggregate).toHaveBeenCalledTimes(1)
    expect(db.fundTransfer.findMany).toHaveBeenCalledTimes(1)
    expect(db.supplier.findMany).not.toHaveBeenCalled()
    finishAccounts([])
    await pending
  })

  it('reads current balances for every response instead of caching financial totals', async () => {
    const first = await financialSummary('all')
    db.account.findMany.mockResolvedValueOnce([{ name: 'BDT account', kind: 'cash', currency: 'BDT', balance: 250, paymentMethod: null }])
    const second = await financialSummary('all')
    expect(first.cash.bdt).toBe(100)
    expect(second.cash.bdt).toBe(250)
    expect(db.account.findMany).toHaveBeenCalledTimes(2)
  })
})
