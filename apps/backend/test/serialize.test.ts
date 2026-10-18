import { describe, expect, it } from 'vitest'
import { shipmentDetail, shipmentRow } from '../src/shared/serialize'

const MONEY_KEYS = [
  'charge',
  'billAmount',
  'discountAmount',
  'paidAmount',
  'dueAmount',
  'payStatus',
  'payMethod',
  'pricingRates',
  'chargeRate',
  'chargeCurrency',
  'rate',
  'currency',
  'costSources',
  'profit',
  'cnFare',
  'collectAmount',
  'paymentTerms',
  'freeOfCharge',
  'receiptStatus',
] as const

function keysOf(value: unknown, found = new Set<string>()): Set<string> {
  if (Array.isArray(value)) {
    for (const item of value) keysOf(item, found)
    return found
  }
  if (value && typeof value === 'object') {
    for (const [key, child] of Object.entries(value)) {
      found.add(key)
      keysOf(child, found)
    }
  }
  return found
}

function assertOmitted(payload: unknown) {
  const json = JSON.stringify(payload)
  const keys = keysOf(payload)
  for (const key of MONEY_KEYS) {
    expect(keys.has(key), key).toBe(false)
    expect(json.includes(`"${key}":`), key).toBe(false)
  }
  expect(json).not.toContain('Secret Supplier')
  expect(json).not.toContain('Payment recorded')
}

const now = new Date('2026-10-02T00:00:00.000Z')

const shipment = {
  code: 'SH-9',
  supplier: { code: 'SUP-1', name: 'Secret Supplier' },
  flight: { code: 'CA945', date: new Date('2026-10-01T00:00:00.000Z'), spaceKg: 44, agencyShare: 1000 },
  bookedKg: 2,
  weighedKg: 2.1,
  description: 'phones',
  categories: ['Mobile'],
  status: 'received_bd_hub',
  exception: null,
  exceptionReason: '',
  paymentTerms: 'invoice',
  freeOfCharge: false,
  deliveryMode: 'courier',
  lastMileRef: null,
  receipts: [],
  createdAt: now,
  charge: 1500,
  customsTax: 50,
  afterSalesFee: 10,
  paidAmount: 200,
  payMethod: 'bkash',
  payStatus: 'partial',
  invoice: {
    total: 1400,
    discount: 100,
    state: 'issued',
    needsReview: false,
    pricingMode: 'manual',
    number: 'INV-1',
    issuedAt: now,
    updatedAt: now,
    sourceCurrency: 'BDT',
    sourceAmount: 1400,
    sourceFxRate: 1,
  },
  cnFare: 20,
  bdFare: 30,
  pricingRates: { mobile: 9 },
  costSources: { cn: { sourceCurrency: 'CNY', sourceFxRate: 16, sourceAmount: 1 } },
  chargeRate: 700,
  chargeCurrency: 'BDT',
  pcsItems: [{
    category: 'Mobile',
    count: 1,
    rate: 400,
    currency: 'BDT',
    units: [{ model: 'Pixel', serial: 'IMEI1', serialPhotoRef: '11111111-1111-4111-8111-111111111111' }],
  }],
  expenses: [],
  costs: [],
  payments: [],
  flyer: { name: 'Flyer A' },
  packedAt: null,
  packageCount: 1,
  serials: ['IMEI1'],
  photosCount: 1,
  hasVideo: false,
  lastMileCourier: null,
  deliveryBookedAt: null,
  dispatchedAt: null,
  handedOverAt: null,
  logs: [
    { actor: 'Hub', message: 'Device IMEI photo attached', at: now },
    { actor: 'Admin', message: 'Payment recorded 200', at: now },
  ],
} as unknown as Parameters<typeof shipmentDetail>[0]

describe('shipment role DTOs', () => {
  it('omits money keys from the hub list row', () => {
    const row = shipmentRow(shipment, 'hub', 0.5)
    assertOmitted(row)
    expect(row).toMatchObject({
      code: 'SH-9',
      supplierCode: 'SUP-1',
      supplierName: null,
      bookedKg: 2,
      weighedKg: 2.1,
      status: 'received_bd_hub',
    })
    expect('charge' in row).toBe(false)
    expect('paymentTerms' in row).toBe(false)
    expect('freeOfCharge' in row).toBe(false)
    expect('receiptStatus' in row).toBe(false)
  })

  it('keeps billing fields on the admin list row', () => {
    const row = shipmentRow(shipment, 'admin', 0.5)
    expect(row).toMatchObject({
      supplierName: 'Secret Supplier',
      charge: 1500,
      billAmount: 1400,
      discountAmount: 100,
      paidAmount: 200,
      dueAmount: 1200,
      payMethod: 'bkash',
      payStatus: 'partial',
      paymentTerms: 'invoice',
      freeOfCharge: false,
      receiptStatus: null,
    })
    const listed = JSON.stringify(row)
    for (const key of ['paymentTerms', 'freeOfCharge', 'receiptStatus'] as const) {
      expect(listed.includes(`"${key}":`), key).toBe(true)
    }
  })

  it('omits money, rates and piece prices from hub shipment detail', () => {
    const detail = shipmentDetail(shipment, 'hub', 0.5)
    assertOmitted(detail)
    expect(detail.pcsItems).toEqual([{
      category: 'Mobile',
      count: 1,
      units: [{ model: 'Pixel', serial: 'IMEI1', serialPhotoRef: '11111111-1111-4111-8111-111111111111' }],
    }])
    expect(detail.log.map((entry) => entry.message)).toEqual(['Device IMEI photo attached'])
    expect(detail.costs).toBeNull()
    expect(detail.invoice).toBeNull()
    expect(detail.payments).toEqual([])
    expect(detail.serials).toEqual(['IMEI1'])
  })

  it('returns rates, piece prices and billing on admin shipment detail', () => {
    const detail = shipmentDetail(shipment, 'admin', 0.5)
    if (!('pricingRates' in detail) || !detail.costs) throw new Error('admin detail dropped billing')
    const json = JSON.stringify(detail)
    for (const key of ['charge', 'billAmount', 'paidAmount', 'dueAmount', 'payStatus', 'payMethod', 'pricingRates', 'chargeRate', 'chargeCurrency', 'paymentTerms', 'freeOfCharge', 'receiptStatus'] as const) {
      expect(json.includes(`"${key}":`), key).toBe(true)
    }
    expect(detail.pcsItems[0]).toMatchObject({ rate: 400, currency: 'BDT' })
    expect(detail.pricingRates).toEqual({ mobile: 9 })
    expect(detail.chargeRate).toBe(700)
    expect(detail.chargeCurrency).toBe('BDT')
    expect(detail.costs.profit).toEqual(expect.any(Number))
  })
})
