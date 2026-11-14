/**
 * Hub sorting and admin approval (round 12). After the hub receives a flight,
 * it sorts each customer's orders: measured weight, what arrived and goods
 * photos per order; packages, packing photos, delivery partner, optional
 * courier ID and a note per customer. The orders then wait for an admin, who
 * approves them (courier: In delivery; Hub pickup: ready for pickup) or sends
 * them back with a note. No new statuses: sorted orders are Ready for last
 * mile until approved. See docs/hub-sorting.md.
 *
 * The hub sees customer codes, never names, phones or money.
 */

import { Prisma, type ShipmentStatus, type UserRole } from '@prisma/client'
import { prisma } from '../core/db'
import { badRequest } from '../core/errors'
import { computeCharge, pcsTotal, weightDelta, type PcsItem } from './compute'
import { effectiveBill, num, numOrNull } from './serialize'
import { refreshShipmentInvoice } from './shipmentBilling'
import { writeShipmentLog } from './actor'
import { STATUS_LABEL, statusIndex } from './status'
import type { AppSettings } from './settings'

export type SortState =
  | 'not_received'
  | 'to_sort'
  | 'sent_back'
  | 'waiting_admin'
  | 'in_delivery'
  | 'ready_pickup'
  | 'delivered'
  | 'problem'

export interface SortStateSource {
  status: ShipmentStatus
  exception: string | null
  sortedAt: Date | null
  approvedAt: Date | null
  sentBackAt: Date | null
  deliveryMode: string
  lastMileCourier: string | null
  packedAt: Date | null
}

/** Where one order is in the hub's sorting and the admin's approval. */
export function orderSortState(s: SortStateSource): SortState {
  if (s.status === 'delivered') return 'delivered'
  if (s.exception) return 'problem'
  if (s.status === 'out_for_delivery') return 'in_delivery'
  if (s.status === 'ready_for_last_mile') {
    const pickup = s.deliveryMode === 'pickup'
    if (s.sortedAt) return s.approvedAt ? (pickup ? 'ready_pickup' : 'in_delivery') : 'waiting_admin'
    // Booked the older way, before sorting: the admin approves what the hub booked.
    return s.packedAt && s.lastMileCourier ? 'waiting_admin' : 'to_sort'
  }
  if (s.status === 'received_bd_hub') return s.sentBackAt ? 'sent_back' : 'to_sort'
  return 'not_received'
}

/** The state a customer is shown in: the most urgent of its orders. */
const GROUP_ORDER: SortState[] = ['sent_back', 'to_sort', 'waiting_admin', 'problem', 'ready_pickup', 'in_delivery', 'delivered', 'not_received']

export function groupState(states: SortState[]): SortState {
  const received = states.filter((s) => s !== 'not_received')
  const pool = received.length ? received : states
  return GROUP_ORDER.find((s) => pool.includes(s)) ?? 'not_received'
}

export const SORT_INCLUDE = {
  supplier: true,
  flight: true,
  receipts: true,
  expenses: true,
  costs: true,
  invoice: true,
  flyer: { select: { name: true } },
} as const

export type SortShipment = Prisma.ShipmentGetPayload<{ include: typeof SORT_INCLUDE }>

export interface SortMedia {
  shipmentId: string
  reference: string
  purpose: string
  deviceKey: string | null
}

const round1 = (n: number) => Math.round(n * 10) / 10
const round2 = (n: number) => Math.round(n * 100) / 100

/** The bill the order had at its booked weight, before the hub measured it. */
export function bookedBill(s: SortShipment, settings: Pick<AppSettings, 'rate'>): number {
  const pricing = (s.pricingRates ?? {}) as Record<string, number>
  const lockedRate = pricing.CNY || settings.rate
  return round2(
    computeCharge(num(s.chargeRate), num(s.bookedKg), s.chargeCurrency, lockedRate) +
      pcsTotal(s.pcsItems as unknown as PcsItem[], lockedRate) +
      num(s.customsTax) -
      num(s.afterSalesFee),
  )
}

function deviceLabel(m: SortMedia, items: unknown): string {
  if (m.purpose === 'device_category') return m.deviceKey ?? 'Device'
  const [item, unit] = (m.deviceKey ?? '').split(':').map(Number)
  const row = Array.isArray(items) ? (items[item ?? -1] as { category?: string; count?: number } | undefined) : undefined
  if (!row?.category) return 'Device'
  return Number(row.count ?? 0) > 1 ? `${row.category} ${(unit ?? 0) + 1}` : row.category
}

/** One customer's orders on one flight, as the hub or the admin sees them. */
export function sortGroups(
  shipments: SortShipment[],
  media: SortMedia[],
  role: UserRole,
  settings: Pick<AppSettings, 'rate' | 'threshold'>,
) {
  const bySupplier = new Map<string, SortShipment[]>()
  for (const s of shipments) {
    const list = bySupplier.get(s.supplier.code) ?? []
    list.push(s)
    bySupplier.set(s.supplier.code, list)
  }
  const mediaOf = (id: string, purposes: string[]) => media.filter((m) => m.shipmentId === id && purposes.includes(m.purpose))
  const admin = role === 'admin'
  return [...bySupplier.entries()].map(([customerCode, list]) => {
    list.sort((a, b) => a.code.localeCompare(b.code))
    const states = list.map(orderSortState)
    const state = groupState(states)
    const lead = list.find((s) => s.sortedAt) ?? list.find((s) => s.sentBackAt) ?? list[0]!
    const sentBack = list.find((s) => s.sentBackAt)
    const orders = list.map((s, i) => {
      const booked = num(s.bookedKg)
      const measured = numOrNull(s.weighedKg)
      return {
        code: s.code,
        state: states[i]!,
        status: s.status,
        statusLabel: s.exception ? s.exception.replaceAll('_', ' ') : STATUS_LABEL[s.status],
        exception: s.exception,
        description: s.description,
        categories: s.categories,
        bookedKg: booked,
        weighedKg: measured,
        /** Measured minus booked, when over the warning threshold either way. */
        weightDelta: weightDelta(booked, measured, settings.threshold),
        arrivedNote: s.arrivedNote,
        flyerName: s.flyer?.name ?? null,
        goodsPhotos: mediaOf(s.id, ['goods']).map((m) => m.reference),
        devicePhotos: mediaOf(s.id, ['device_photo', 'device_category']).map((m) => ({ reference: m.reference, label: deviceLabel(m, s.pcsItems) })),
        ...(admin
          ? {
              bill: round2(effectiveBill(s as Parameters<typeof effectiveBill>[0])),
              bookedBill: bookedBill(s, settings),
            }
          : {}),
      }
    })
    const active = list.filter((s, i) => states[i] !== 'not_received' && states[i] !== 'problem')
    const bookedKg = round1(active.reduce((t, s) => t + num(s.bookedKg), 0))
    const measuredKg = round1(active.reduce((t, s) => t + (numOrNull(s.weighedKg) ?? num(s.bookedKg)), 0))
    const money = admin
      ? (() => {
          const bill = round2(active.reduce((t, s) => t + effectiveBill(s as Parameters<typeof effectiveBill>[0]), 0))
          const paid = round2(active.reduce((t, s) => t + num(s.paidAmount), 0))
          return { bill, paid, due: Math.max(0, round2(bill - paid)), bookedBill: round2(active.reduce((t, s) => t + bookedBill(s, settings), 0)) }
        })()
      : null
    return {
      customerCode,
      ...(admin ? { customerName: lead.supplier.name, customerPhone: lead.supplier.phone, customerAddress: lead.supplier.address } : {}),
      state,
      orders,
      orderCount: list.length,
      bookedKg,
      measuredKg,
      /** True when an order weighs more or less than booked by the warning threshold: the admin should look. */
      needsLook: orders.some((o) => o.weightDelta !== null),
      packages: lead.packageCount,
      partner: lead.lastMileCourier,
      courierRef: lead.lastMileRef,
      hubNote: lead.hubNote,
      /** Each with the order it was uploaded to, which its download link needs. */
      packingPhotos: list.flatMap((s) => mediaOf(s.id, ['packing']).map((m) => ({ reference: m.reference, order: s.code }))),
      sortedAt: lead.sortedAt?.toISOString() ?? null,
      sortedBy: lead.sortedBy,
      approvedAt: lead.approvedAt?.toISOString() ?? null,
      approvedBy: lead.approvedBy,
      sentBackNote: sentBack?.sentBackNote ?? '',
      sentBackAt: sentBack?.sentBackAt?.toISOString() ?? null,
      sentBackBy: sentBack?.sentBackBy ?? null,
      ...(money ? { money } : {}),
    }
  })
}

export type SortGroup = ReturnType<typeof sortGroups>[number]

export async function loadSortMedia(ids: string[]): Promise<SortMedia[]> {
  if (!ids.length) return []
  return prisma.shipmentMedia.findMany({
    where: { shipmentId: { in: ids }, status: 'ready', purpose: { in: ['goods', 'packing', 'device_photo', 'device_category'] } },
    select: { shipmentId: true, reference: true, purpose: true, deviceKey: true },
    orderBy: { createdAt: 'asc' },
  })
}

/**
 * Records the measured weight and prices the order again, as the Weigh step
 * did: the locked fx rate, the per-kg part at the new weight plus the pieces.
 */
export async function applyMeasuredWeight(
  s: Pick<SortShipment, 'id' | 'pricingRates' | 'chargeRate' | 'chargeCurrency' | 'pcsItems' | 'invoice' | 'customsTax' | 'afterSalesFee' | 'paidAmount' | 'bookedKg'>,
  kg: number,
  settings: Pick<AppSettings, 'rate' | 'threshold'>,
  actor: string,
): Promise<void> {
  const pricing = (s.pricingRates ?? {}) as Record<string, number>
  const lockedRate = pricing.CNY || settings.rate
  const charge = round2(computeCharge(num(s.chargeRate), kg, s.chargeCurrency, lockedRate) + pcsTotal(s.pcsItems as unknown as PcsItem[], lockedRate))
  if (!s.invoice && charge + num(s.customsTax) - num(s.afterSalesFee) < num(s.paidAmount)) {
    throw badRequest('New bill is below receipts; adjust the invoice before reweighing')
  }
  await prisma.shipment.update({
    where: { id: s.id },
    data: { pricingRates: { BDT: 1, CNY: lockedRate }, weighedKg: new Prisma.Decimal(kg), charge },
  })
  await refreshShipmentInvoice(s.id, 'Measured weight updated')
  const delta = weightDelta(num(s.bookedKg), kg, settings.threshold)
  await writeShipmentLog(s.id, `Weighed ${kg} kg${delta !== null ? ' — DISCREPANCY' : ''}`, actor)
}

/** Orders the hub may sort now: received, not sorted yet or sent back, without a problem. */
export const sortable = (s: SortStateSource) => ['to_sort', 'sent_back'].includes(orderSortState(s))

/** True for orders past customs at the hub (received or later). */
export const atHub = (status: ShipmentStatus) => statusIndex(status) >= statusIndex('received_bd_hub')
