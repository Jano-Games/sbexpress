/**
 * When is a customer late?
 * - Pays after delivery: 10 days after the parcel was handed over.
 * - Pays monthly: 10 days after the month of the booking ends.
 * Days are whole UTC calendar days, like the rest of the collect sheet.
 */

import type { Prisma } from '@prisma/client'
import { effectiveBill, isoDate, num } from './serialize'

export const LATE_DAYS = 10
const DAY_MS = 86_400_000
const round2 = (value: number) => Math.round(value * 100) / 100

const dayOf = (d: Date) => new Date(d.toISOString().slice(0, 10))
export const utcToday = (now = new Date()) => dayOf(now)
/** Whole days from `from` (its calendar day) to `today`, never negative. */
export const daysSince = (from: Date, today: Date) => Math.max(0, Math.floor((today.getTime() - dayOf(from).getTime()) / DAY_MS))
/** Last calendar day of a YYYY-MM month (UTC midnight). */
export const monthEnd = (month: string) => new Date(Date.UTC(Number(month.slice(0, 4)), Number(month.slice(5, 7)), 0))
export const isLate = (days: number) => days >= LATE_DAYS
export const monthLabel = (month: string) =>
  new Date(`${month}-01T00:00:00Z`).toLocaleDateString('en-GB', { month: 'long', year: 'numeric', timeZone: 'UTC' })

export interface LateShipment {
  code: string
  supplierId: string
  supplier: { code: string; name: string }
  paymentTerms: string
  freeOfCharge: boolean
  status: string
  handedOverAt: Date | null
  createdAt: Date
  paidAmount: Prisma.Decimal | number
  charge: Prisma.Decimal
  customsTax: Prisma.Decimal
  afterSalesFee: Prisma.Decimal
  invoice?: { total: Prisma.Decimal; state: string; needsReview: boolean } | null
}

export const amountDue = (s: LateShipment) => Math.max(0, round2(effectiveBill(s) - num(s.paidAmount as Prisma.Decimal)))

/** After-delivery bills still owed on a handed-over parcel: days since handover, else null. */
export function afterDeliveryDays(s: LateShipment, today: Date): number | null {
  if (s.paymentTerms === 'monthly' || s.freeOfCharge || s.status !== 'delivered' || amountDue(s) <= 0) return null
  return daysSince(s.handedOverAt ?? s.createdAt, today)
}

/** Monthly bills count once issued and reviewed, in the month they were booked. */
const monthlyMonth = (s: LateShipment): string | null =>
  s.paymentTerms === 'monthly' && s.invoice?.state === 'issued' && !s.invoice.needsReview && amountDue(s) > 0 ? s.createdAt.toISOString().slice(0, 7) : null

/** How many days this shipment's unpaid bill is late, or null when it is not late. */
export function shipmentLateDays(s: LateShipment, today = utcToday()): number | null {
  const after = afterDeliveryDays(s, today)
  if (after !== null) return isLate(after) ? after : null
  const month = monthlyMonth(s)
  if (!month) return null
  const days = daysSince(monthEnd(month), today)
  return isLate(days) ? days : null
}

export type LatePayment =
  | { kind: 'after_delivery'; customerCode: string; customerName: string; shipmentCode: string; amount: number; days: number; since: string }
  | { kind: 'monthly'; customerCode: string; customerName: string; month: string; monthLabel: string; amount: number; days: number }

/** Everyone late with something still unpaid, most overdue first. */
export function latePayments(ships: LateShipment[], today = utcToday(), limit = 10): { rows: LatePayment[]; count: number } {
  const rows: LatePayment[] = []
  const monthly = new Map<string, Extract<LatePayment, { kind: 'monthly' }>>()
  for (const s of ships) {
    const after = afterDeliveryDays(s, today)
    if (after !== null) {
      if (isLate(after)) {
        rows.push({ kind: 'after_delivery', customerCode: s.supplier.code, customerName: s.supplier.name, shipmentCode: s.code, amount: amountDue(s), days: after, since: isoDate(s.handedOverAt ?? s.createdAt) })
      }
      continue
    }
    const month = monthlyMonth(s)
    if (!month) continue
    const days = daysSince(monthEnd(month), today)
    if (!isLate(days)) continue
    const key = `${s.supplierId}:${month}`
    const row = monthly.get(key) ?? { kind: 'monthly' as const, customerCode: s.supplier.code, customerName: s.supplier.name, month, monthLabel: monthLabel(month), amount: 0, days }
    row.amount = round2(row.amount + amountDue(s))
    monthly.set(key, row)
  }
  const all = [...rows, ...monthly.values()].sort(
    (a, b) => b.days - a.days || b.amount - a.amount || a.customerName.localeCompare(b.customerName),
  )
  return { rows: all.slice(0, limit), count: all.length }
}
