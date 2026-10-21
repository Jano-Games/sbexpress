import { describe, expect, it, vi } from 'vitest'

vi.mock('../src/core/db', () => ({ prisma: {} }))

import { openingCapital } from '../src/shared/openingBalance'

describe('opening capital', () => {
  it('posts nothing for a zero balance, including a new CNY fund before a rate is needed', () => {
    expect(openingCapital(0, 'BDT', undefined)).toBeNull()
    expect(openingCapital(0, 'CNY', undefined)).toBeNull()
  })

  it('keeps a BDT opening in BDT', () => {
    expect(openingCapital(2500, 'BDT', undefined)).toEqual({ opening: 2500, amountBdt: 2500, rate: 1 })
  })

  it('converts a CNY opening with the saved rate and does not treat it as income', () => {
    expect(openingCapital(100, 'CNY', 17.5)).toEqual({ opening: 100, amountBdt: 1750, rate: 17.5 })
  })

  it('refuses a negative balance, extra decimals, or a CNY fund with no rate', () => {
    expect(() => openingCapital(-1, 'BDT', 1)).toThrow(/negative/)
    expect(() => openingCapital(10.555, 'BDT', 1)).toThrow(/two decimal places/)
    expect(() => openingCapital(100, 'CNY', undefined)).toThrow(/exchange rate/)
  })
})
