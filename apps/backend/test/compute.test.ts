import { describe, expect, it } from 'vitest'
import { billAmount, computeCharge, effectiveKg, fareShare, pcsTotal, profit, weightDelta } from '../src/shared/compute'

const CZ3059 = { actualCost: 39800, spaceKg: 44 }

describe('fareShare', () => {
  it('splits the ticket cost by booked weight', () => {
    expect(fareShare({ bookedKg: 11.2, charge: 8060 }, CZ3059)).toBeCloseTo((39800 * 11.2) / 44)
  })

  it('does not invent a ticket allocation for zero-weight devices', () => {
    expect(fareShare({ bookedKg: 0, charge: 6800 }, CZ3059)).toBe(0)
  })

  it('is free for unbilled zero-kg shipments', () => {
    expect(fareShare({ bookedKg: 0, charge: 0 }, CZ3059)).toBe(0)
  })
})

describe('profit', () => {
  it('subtracts every cost line from the charge', () => {
    // SH-103 from the demo dataset.
    const money = { bookedKg: 11.2, charge: 8060, cnFare: 410, bdFare: 260, customsTax: 0, afterSalesFee: 0 }
    const expected = 8060 - (39800 * 11.2) / 44 - 410 - 260
    expect(profit(money, CZ3059, 0)).toBeCloseTo(expected)
  })

  it('counts shipment-linked expenses', () => {
    const money = { bookedKg: 0, charge: 1000, cnFare: 0, bdFare: null, customsTax: 0, afterSalesFee: 0 }
    expect(profit(money, null, 250)).toBe(1000 - 250)
  })
})

describe('billAmount', () => {
  it('adds customs tax and subtracts after-sales credit', () => {
    // SH-108: ৳9,800 + 0 tax − ৳500 damage credit.
    expect(billAmount({ charge: 9800, customsTax: 0, afterSalesFee: 500 })).toBe(9300)
  })
})

describe('weightDelta', () => {
  it('flags a delta at or above the threshold', () => {
    expect(weightDelta(11.2, 12.4, 1)).toBeCloseTo(1.2)
    expect(weightDelta(12.4, 11.2, 1)).toBeCloseTo(-1.2)
  })

  it('ignores deltas below the threshold and unweighed shipments', () => {
    expect(weightDelta(18, 18.3, 1)).toBeNull()
    expect(weightDelta(18, null, 1)).toBeNull()
  })
})

describe('computeCharge', () => {
  it('multiplies the per-kg rate by booked weight', () => {
    // 22.4 kg at ৳700/kg.
    expect(computeCharge(700, 22.4, 'BDT', 17.05)).toBe(15680)
  })

  it('is zero without booked weight — devices are charged per piece instead', () => {
    expect(computeCharge(700, 0, 'BDT', 17.05)).toBe(0)
  })

  it('converts CNY rates at the fx rate', () => {
    expect(computeCharge(40, 10, 'CNY', 17.05)).toBe(6820)
  })
})

describe('pcsTotal', () => {
  it('sums count × rate across device categories', () => {
    expect(
      pcsTotal(
        [
          { category: 'Mobile', count: 2, rate: 500 },
          { category: 'Laptop', count: 1, rate: 1500 },
        ],
        17.05,
      ),
    ).toBe(2500)
  })

  it('converts CNY rates at the fx rate', () => {
    expect(pcsTotal([{ category: 'Mobile', count: 2, rate: 100, currency: 'CNY' }], 17.05)).toBe(3410)
  })

  it('is zero with no items', () => {
    expect(pcsTotal([], 17.05)).toBe(0)
  })
})

describe('effectiveKg', () => {
  it('prefers the weighed value once known', () => {
    expect(effectiveKg(11.2, 12.4)).toBe(12.4)
    expect(effectiveKg(11.2, null)).toBe(11.2)
  })
})
