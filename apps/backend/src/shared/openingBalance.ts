import { Prisma, type Currency } from '@prisma/client'
import { badRequest } from '../core/errors'
import { roundMoney, toBdt } from './money'

/**
 * An opening balance is typed in the new account's currency.
 * Zero creates the fund and posts nothing. A positive amount becomes a
 * capital payment: the ledger stores the BDT equivalent at the saved rate,
 * and the account receives exactly the typed currency amount.
 */
export function openingCapital(
  amount: number,
  currency: Currency,
  rate: number | undefined,
): { opening: number; amountBdt: number; rate: number } | null {
  if (!Number.isFinite(amount) || amount < 0) throw badRequest('Opening balance cannot be negative')
  if (amount > 9999999999) throw badRequest('Amount exceeds the supported limit')
  if (new Prisma.Decimal(amount).decimalPlaces() > 2) throw badRequest('Money amounts may have at most two decimal places')
  const opening = roundMoney(amount)
  if (opening === 0) return null
  if (currency === 'BDT') return { opening, amountBdt: opening, rate: 1 }
  if (!rate || rate <= 0) throw badRequest(`Set the ${currency} exchange rate in Settings first`)
  return { opening, amountBdt: toBdt(opening, rate), rate }
}
