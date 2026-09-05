/**
 * Role-aware serializers. Redaction happens here, not in the client: the hub
 * role gets supplier short codes only, and cost/profit lines are admin-only.
 */

import type { Prisma } from '@prisma/client'
import type { Role } from '../modules/auth'
import { STATUS_LABEL, statusIndex } from './status'
import { billAmount, effectiveKg, fareShare, weightDelta } from './compute'

/** Prisma Decimal (or null) to plain number for JSON. */
export const num = (value: Prisma.Decimal | number | null | undefined): number =>
  value === null || value === undefined ? 0 : Number(value)

export const numOrNull = (value: Prisma.Decimal | null | undefined): number | null =>
  value === null || value === undefined ? null : Number(value)

export const isoDate = (d: Date): string => d.toISOString().slice(0, 10)

export type ShipmentWithRelations = Prisma.ShipmentGetPayload<{
  include: { supplier: true; flight: true; receipt: true; expenses: true }
}>

/**
 * What the customer actually owes: the finalized invoice total when one
 * exists (it may carry a discount or adjustments), else the computed bill.
 */
export function effectiveBill(s: {
  charge: Prisma.Decimal
  customsTax: Prisma.Decimal
  afterSalesFee: Prisma.Decimal
  invoice?: { total: Prisma.Decimal } | null
}): number {
  if (s.invoice) return num(s.invoice.total)
  return billAmount({ charge: num(s.charge), customsTax: num(s.customsTax), afterSalesFee: num(s.afterSalesFee) })
}

/** Recorded operating costs plus additional expense lines, excluding settlements. */
export function shipmentOperatingCosts(s: {
  cnFare: Prisma.Decimal | number; bdFare: Prisma.Decimal | number | null; customsTax: Prisma.Decimal | number
  expenses: { costField: string | null; category: string; amount: Prisma.Decimal | number }[]
}) {
  const costs = { cnTransport: num(s.cnFare), courier: num(s.bdFare), customs: num(s.customsTax), other: 0 }
  for (const expense of s.expenses) {
    if (expense.costField) continue
    if (expense.category === 'courier') costs.courier += num(expense.amount)
    else costs.other += num(expense.amount)
  }
  return { ...costs, total: costs.cnTransport + costs.courier + costs.customs + costs.other }
}

export interface ShipmentRowDto {
  code: string
  supplierCode: string
  /** Null for the hub role — short codes only. */
  supplierName: string | null
  flightCode: string | null
  flightDate: string | null
  bookedKg: number
  weighedKg: number | null
  effectiveKg: number
  weightDelta: number | null
  description: string
  categories: string[]
  charge: number
  billAmount: number
  /** Invoice discount baked into billAmount; 0 when no discount was given. */
  discountAmount: number
  paidAmount: number
  /** What's still outstanding after partial payments. */
  dueAmount: number
  status: string
  statusIndex: number
  statusLabel: string
  payStatus: string
  payMethod: string | null
  receiptStatus: string | null
  date: string
}

export function shipmentRow(s: ShipmentWithRelations, role: Role, threshold: number): ShipmentRowDto {
  return {
    code: s.code,
    supplierCode: s.supplier.code,
    supplierName: role === 'hub' ? null : s.supplier.name,
    flightCode: s.flight?.code ?? null,
    flightDate: s.flight ? isoDate(s.flight.date) : null,
    bookedKg: num(s.bookedKg),
    weighedKg: numOrNull(s.weighedKg),
    effectiveKg: effectiveKg(num(s.bookedKg), numOrNull(s.weighedKg)),
    weightDelta: weightDelta(num(s.bookedKg), numOrNull(s.weighedKg), threshold),
    description: s.description,
    categories: s.categories,
    charge: num(s.charge),
    billAmount: effectiveBill(s as Parameters<typeof effectiveBill>[0]),
    discountAmount: num((s as { invoice?: { discount: Prisma.Decimal } | null }).invoice?.discount ?? null),
    paidAmount: num(s.paidAmount),
    dueAmount: Math.max(
      0,
      Math.round((effectiveBill(s as Parameters<typeof effectiveBill>[0]) - num(s.paidAmount)) * 100) / 100,
    ),
    status: s.status,
    statusIndex: statusIndex(s.status),
    statusLabel: STATUS_LABEL[s.status],
    payStatus: num(s.paidAmount) >= effectiveBill(s) ? 'paid' : num(s.paidAmount) > 0 ? 'partial' : s.supplier.terms === 'monthly' ? 'monthly' : s.payStatus === 'cod' ? 'cod' : 'unpaid',
    payMethod: s.payMethod,
    receiptStatus: s.receipt?.status ?? null,
    date: isoDate(s.createdAt),
  }
}

export interface ShipmentDetailDto extends ShipmentRowDto {
  chargeRate: number
  chargeCurrency: string
  pcsItems: {
    category: string
    count: number
    rate: number
    currency: 'BDT' | 'CNY'
    units: { model: string; serial: string }[]
  }[]
  flyerName: string | null
  packedAt: string | null
  packageCount: number
  serials: string[]
  photosCount: number
  hasVideo: boolean
  lastMile: { courier: string; ref: string } | null
  trackToken: string | null
  log: { actor: string; message: string; at: string }[]
  flightSpaceKg: number | null
  /** Admin-only money block; null for everyone else. */
  costs: {
    fareShare: number
    unpaidCosts: {cnFare:number;bdFare:number;customsTax:number}
    cnFare: number
    bdFare: number | null
    customsTax: number
    afterSalesFee: number
    extraLines: { category: string; reason: string; amount: number }[]
    profit: number
    profitPct: number | null
  } | null
  receipt: { method: string; amount: number; status: string; txnRef: string; date: string } | null
  /** Saved invoice summary — admin only. */
  invoice: { number: string; total: number; discount: number; issuedAt: string; updatedAt: string } | null
  /** Money received against this shipment, oldest first. Hidden from hub. */
  payments: { method: string; amount: number; at: string }[]
}

export function shipmentDetail(
  s: ShipmentWithRelations & {
    flyer?: { name: string } | null
    logs: { actor: string; message: string; at: Date }[]
    invoice?: { number: string; total: Prisma.Decimal; discount: Prisma.Decimal; issuedAt: Date; updatedAt: Date } | null
    payments?: { method: string; amount: Prisma.Decimal; createdAt: Date }[]
  },
  role: Role,
  threshold: number,
): ShipmentDetailDto {
  const flightEcon = s.flight ? { actualCost: num(s.flight.agencyShare), spaceKg: s.flight.spaceKg } : null
  const money = {
    bookedKg: num(s.bookedKg),
    charge: num(s.charge),
    cnFare: num(s.cnFare),
    bdFare: numOrNull(s.bdFare),
    customsTax: num(s.customsTax),
    afterSalesFee: num(s.afterSalesFee),
  }
  const extras = s.expenses.filter(e=>!e.costField).map((e) => ({ category: e.category, reason: e.reason, amount: num(e.amount) }))
  const net = effectiveBill(s) - fareShare(money, flightEcon) - shipmentOperatingCosts(s).total

  return {
    ...shipmentRow(s, role, threshold),
    chargeRate: num(s.chargeRate),
    chargeCurrency: s.chargeCurrency,
    pcsItems: (
      (s.pcsItems as
        | { category: string; count: number; rate: number; currency?: 'BDT' | 'CNY'; units?: { model: string; serial: string }[] }[]
        | null) ?? []
    ).map((i) => ({ ...i, currency: i.currency ?? 'BDT', units: i.units ?? [] })),
    flyerName:s.flyer?.name ?? null,
    packedAt:s.packedAt?.toISOString() ?? null,
    packageCount:s.packageCount,
    serials: s.serials,
    photosCount: s.photosCount,
    hasVideo: s.hasVideo,
    lastMile: s.lastMileCourier ? { courier: s.lastMileCourier, ref: s.lastMileRef ?? '' } : null,
    trackToken: null,
    log: (role === 'hub' ? s.logs.filter(l => l.actor === 'Hub' || l.message.startsWith('Status →')) : s.logs).map((l) => ({ actor: l.actor, message: l.message, at: l.at.toISOString() })),
    flightSpaceKg: s.flight?.spaceKg ?? null,
    costs:
      role === 'admin'
        ? {
            unpaidCosts: {
              cnFare:Math.max(0,num(s.cnFare)-s.expenses.filter(e=>e.costField === 'cnFare').reduce((a,e)=>a+num(e.amount),0)),
              bdFare:Math.max(0,num(s.bdFare)-s.expenses.filter(e=>e.costField === 'bdFare').reduce((a,e)=>a+num(e.amount),0)),
              customsTax:Math.max(0,num(s.customsTax)-s.expenses.filter(e=>e.costField === 'customsTax').reduce((a,e)=>a+num(e.amount),0)),
            },
            fareShare: Math.round(fareShare(money, flightEcon) * 100) / 100,
            cnFare: money.cnFare,
            bdFare: money.bdFare,
            customsTax: money.customsTax,
            afterSalesFee: money.afterSalesFee,
            extraLines: extras,
            profit: Math.round(net * 100) / 100,
            profitPct: effectiveBill(s) > 0 ? Math.round((net / effectiveBill(s)) * 100) : null,
          }
        : null,
    receipt:
      s.receipt && role !== 'hub'
        ? {
            method: s.receipt.method,
            amount: num(s.receipt.amount),
            status: s.receipt.status,
            txnRef: s.receipt.txnRef,
            date: isoDate(s.receipt.uploadedAt),
          }
        : null,
    invoice:
      role === 'admin' && s.invoice
        ? {
            number: s.invoice.number,
            total: num(s.invoice.total),
            discount: num(s.invoice.discount),
            issuedAt: isoDate(s.invoice.issuedAt),
            updatedAt: isoDate(s.invoice.updatedAt),
          }
        : null,
    payments:
      role !== 'hub'
        ? (s.payments ?? []).map((p) => ({ method: p.method, amount: num(p.amount), at: p.createdAt.toISOString() }))
        : [],
  }
}
