import { latestReceipt, receiptSummary } from './receiptHistory'
/**
 * Role-aware serializers. Redaction happens here, not in the client: the hub
 * role gets supplier short codes only, and cost/profit lines are admin-only.
 */

import { shipmentCostItems, type ShipmentCostItem } from './shipmentCosts'
import type { Prisma } from '@prisma/client'
import type { Role } from '../modules/auth'
import { STATUS_LABEL, statusIndex } from './status'
import { billAmount, effectiveKg, fareShare, weightDelta } from './compute'

/** Prisma Decimal (or null) to plain number for JSON. */
export const num = (value: Prisma.Decimal | number | null | undefined): number =>
  value === null || value === undefined ? 0 : Number(value)

type StoredMoney = {sourceCurrency?:string;sourceAmount?:Prisma.Decimal|null;sourceFxRate?:Prisma.Decimal}
export const sourceDto=(row:StoredMoney,base:number)=>({sourceCurrency:row.sourceCurrency??'BDT',sourceAmount:row.sourceAmount===null||row.sourceAmount===undefined?base:Number(row.sourceAmount),sourceFxRate:Number(row.sourceFxRate??1)})
export const numOrNull = (value: Prisma.Decimal | null | undefined): number | null =>
  value === null || value === undefined ? null : Number(value)

export const isoDate = (d: Date): string => d.toISOString().slice(0, 10)

export type ShipmentWithRelations = Prisma.ShipmentGetPayload<{
  include: { supplier: true; flight: true; receipts: true; expenses: true; costs: true }
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
  costs?: {category:string;amount:Prisma.Decimal|number;voidedAt:Date|null}[]
  expenses: { costId?:string|null; costField: string | null; category: string; amount: Prisma.Decimal | number }[]
}) {
  const costs = { cnTransport: num(s.cnFare), courier: num(s.bdFare), customs: num(s.customsTax), other: 0 }
  for (const expense of s.expenses) {
    if (expense.costField || expense.costId) continue
    if (expense.category === 'courier') costs.courier += num(expense.amount)
    else costs.other += num(expense.amount)
  }
  for(const cost of s.costs??[]) {if(cost.voidedAt)continue;if(cost.category==='courier')costs.courier+=num(cost.amount);else costs.other+=num(cost.amount)}
  return { ...costs, total: costs.cnTransport + costs.courier + costs.customs + costs.other }
}

export function shipmentRow(s: ShipmentWithRelations, role: Role, threshold: number) {
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
    statusLabel: s.exception ? s.exception.replaceAll('_',' ') : s.deliveryMode==='pickup' && s.status==='ready_for_last_mile' && s.lastMileRef ? 'Ready for collection' : STATUS_LABEL[s.status],
    exception:s.exception,exceptionReason:s.exceptionReason,paymentTerms:s.paymentTerms,freeOfCharge:s.freeOfCharge,
    payStatus: paymentStatus(s),
    payMethod: s.payMethod,
    receiptStatus: latestReceipt(s.receipts)?.status ?? null,
    date: isoDate(s.createdAt),
  }
}

export function shipmentDetail(
  s: ShipmentWithRelations & {
    receipts: (ShipmentWithRelations['receipts'][number] & { screenshot?: {reference:string;name:string;contentType:string;size:number} | null; payments?: {amount:unknown;reversedAt:Date|null}[] })[]
    flyer?: { name: string } | null
    logs: { actor: string; message: string; at: Date }[]
    invoice?: ({ state:string;needsReview:boolean;pricingMode:string; number: string; total: Prisma.Decimal; discount: Prisma.Decimal; issuedAt: Date; updatedAt: Date } & StoredMoney) | null
    payments?: ({ id:string;reference:string;reversedAt:Date|null;reversalOfId:string|null; method: string; amount: Prisma.Decimal; createdAt: Date } & StoredMoney)[]
  },
  role: Role,
  threshold: number,
) {
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
    pricingRates: s.pricingRates as Record<string,number>,
    costSources: role === 'admin' ? s.costSources as Record<string,{sourceCurrency:string;sourceFxRate:number;sourceAmount:number}> : {},
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
    lastMile: s.lastMileCourier ? { courier: s.lastMileCourier, ref: s.lastMileRef ?? '',mode:s.deliveryMode,bookedAt:s.deliveryBookedAt?.toISOString()??null,dispatchedAt:s.dispatchedAt?.toISOString()??null,handedOverAt:s.handedOverAt?.toISOString()??null } : null,
    trackToken: null,
    log: (role === 'hub' ? s.logs.filter(l => /^(Status|Weighed|Packed|Last mile|Delivery|Exception|Shipment resumed|Checkpoint)/.test(l.message)) : s.logs).map((l) => ({ actor: l.actor, message: l.message, at: l.at.toISOString() })),
    flightSpaceKg: s.flight?.spaceKg ?? null,
    costs:
      role === 'admin'
        ? {
            items: shipmentCostItems(s),
            total: Math.round(shipmentOperatingCosts(s).total * 100) / 100,
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
    receipt: role==='admin' && latestReceipt(s.receipts) ? receiptSummary(latestReceipt(s.receipts)!) : null,
    receiptHistory: role==='admin' ? [...s.receipts].sort((a,b)=>b.uploadedAt.getTime()-a.uploadedAt.getTime()).map(receiptSummary) : [],
    invoice:
      role === 'admin' && s.invoice
        ? {
            ...sourceDto(s.invoice,num(s.invoice.total)),
            state:s.invoice.state,needsReview:s.invoice.needsReview,pricingMode:s.invoice.pricingMode,
            number: s.invoice.number,
            total: num(s.invoice.total),
            discount: num(s.invoice.discount),
            issuedAt: isoDate(s.invoice.issuedAt),
            updatedAt: isoDate(s.invoice.updatedAt),
          }
        : null,
    payments:
      role !== 'hub'
        ? (s.payments ?? []).map((p) => ({ id:p.id,reference:p.reference,canReverse:!p.reversedAt&&!p.reversalOfId&&num(p.amount)>0,reversedAt:p.reversedAt?.toISOString()??null,reversalOfId:p.reversalOfId,...sourceDto(p,num(p.amount)), method: p.method, amount: num(p.amount), at: p.createdAt.toISOString() }))
        : [],
  }
}

export function paymentStatus(s:{paidAmount:unknown;charge:Prisma.Decimal;customsTax:Prisma.Decimal;afterSalesFee:Prisma.Decimal;freeOfCharge?:boolean;invoice?:{total:Prisma.Decimal;state?:string}|null}) {
  const total=effectiveBill(s),paid=Number(s.paidAmount)
  if((total>0 || s.freeOfCharge) && s.invoice?.state!=='draft' && paid>=total)return 'paid' as const
  return paid>0?'partial' as const:'unpaid' as const
}
