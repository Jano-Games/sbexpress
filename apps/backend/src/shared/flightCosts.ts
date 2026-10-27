/**
 * Flight costs — transport, courier, packaging, customs, labour and the like
 * for a whole flight. They are our cost only, never on a customer's bill.
 *
 * Stored as Expense rows carrying the flight's id with any category except
 * 'ticket' (ticket rows keep their own sync with the flight's ticket cost).
 * Paid now: the row has an account posting like every other expense.
 * Pay later: the row has no account posting yet — a payable, not cash out.
 * Removing one reverses it with a negative twin; posted money is never deleted.
 */

import type { Prisma } from '@prisma/client'

export const FLIGHT_COST_CATEGORIES = ['transport', 'courier', 'packaging', 'customs', 'others'] as const
export type FlightCostCategory = (typeof FLIGHT_COST_CATEGORIES)[number]

export const FLIGHT_COST_LABEL: Record<FlightCostCategory, string> = {
  transport: 'Transport',
  courier: 'Courier',
  packaging: 'Packaging',
  customs: 'Customs',
  others: 'Other cost',
}

type Money = Prisma.Decimal | number | null | undefined
const amountOf = (value: Money) => (value === null || value === undefined ? 0 : Number(value))
const round2 = (value: number) => Math.round((value + Number.EPSILON) * 100) / 100

export const isFlightCost = (e: { flightId?: string | null; category: string }) => Boolean(e.flightId) && e.category !== 'ticket'

/** A pay-later flight cost (or its reversal) has no account posting: it never counts as cash out. */
export const isUnpaidFlightCost = (e: { flightId?: string | null; category: string; accountAmount: Money }) =>
  isFlightCost(e) && (e.accountAmount === null || e.accountAmount === undefined)

/**
 * Net flight cost: every non-ticket expense on the flight. A removed cost and its
 * negative twin cancel out, so the total equals the sum of the listed costs.
 */
export function flightCostTotal(expenses: { category: string; amount: Money }[]): number {
  return round2(expenses.filter((e) => e.category !== 'ticket').reduce((sum, e) => sum + amountOf(e.amount), 0))
}

export interface FlightCostExpense {
  id: string
  category: string
  reason: string
  amount: Money
  date: Date
  createdAt: Date
  accountName: string | null
  accountAmount: Money
  reversedAt: Date | null
  reversalOfId: string | null
}

export function flightCostRow(e: FlightCostExpense) {
  return {
    id: e.id,
    category: e.category,
    label: e.reason,
    amount: amountOf(e.amount),
    date: e.date.toISOString().slice(0, 10),
    paid: e.accountAmount !== null && e.accountAmount !== undefined,
    accountName: e.accountAmount !== null && e.accountAmount !== undefined ? e.accountName : null,
  }
}

/** Live flight costs, newest first: no ticket rows, nothing removed, no reversal twins. */
export function flightCostRows(expenses: FlightCostExpense[]) {
  return expenses
    .filter((e) => e.category !== 'ticket' && !e.reversedAt && !e.reversalOfId)
    .sort((a, b) => b.date.getTime() - a.date.getTime() || b.createdAt.getTime() - a.createdAt.getTime())
    .map(flightCostRow)
}
