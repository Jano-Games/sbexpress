/**
 * A flight's own rates for new orders, the effective rates (flight first,
 * settings default after) and the orders that follow a rate change. Admin
 * only: none of this is ever part of a hub response.
 */

import type { Prisma } from '@prisma/client'
import { prisma } from '../core/db'
import { writeShipmentLog } from './actor'
import type { PcsItem } from './compute'
import { num } from './serialize'
import type { AppSettings } from './settings'
import { refreshShipmentInvoice } from './shipmentBilling'
import { repriceShipment, type PricingChange } from './shipmentPricing'

type Currency = 'BDT' | 'CNY'

/** The rate columns stored on a flight; null means the default from settings. */
export interface FlightRateColumns {
  kgRate: Prisma.Decimal | number | null
  kgRateCurrency: Currency | null
  pcsRates: Prisma.JsonValue | null
}

/** Category → piece price (BDT), keeping only non-negative numbers. */
export function parsePcsRates(value: unknown): Record<string, number> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>).filter(([, v]) => typeof v === 'number' && Number.isFinite(v) && v >= 0),
  ) as Record<string, number>
}

const hasOwnRates = (f: FlightRateColumns): boolean => f.kgRate !== null && f.kgRate !== undefined

/** The admin flight summary fields for a flight's own rates. */
export function flightRateFields(f: FlightRateColumns) {
  const own = hasOwnRates(f)
  return {
    ownRates: own,
    kgRate: own ? num(f.kgRate) : null,
    kgRateCurrency: own ? (f.kgRateCurrency ?? 'BDT') : null,
    pcsRates: own ? parsePcsRates(f.pcsRates) ?? {} : null,
  }
}

export interface EffectiveRates {
  kgRate: number
  kgCurrency: Currency
  /** Piece price for a category in BDT, or undefined when none is set. */
  piece: (category: string) => number | undefined
}

/** Case-insensitive category lookup. */
function priceFor(rates: Record<string, number> | null | undefined, category: string): number | undefined {
  if (!rates) return undefined
  const wanted = category.trim().toLowerCase()
  const key = Object.keys(rates).find((k) => k.trim().toLowerCase() === wanted)
  return key === undefined ? undefined : rates[key]
}

/** The flight's own rates when it has them, otherwise the defaults from settings. */
export function effectiveRates(
  f: FlightRateColumns,
  settings: Pick<AppSettings, 'kgRate' | 'kgRateCurrency' | 'pcsRates'>,
): EffectiveRates {
  const own = hasOwnRates(f)
  const flightPieces = own ? parsePcsRates(f.pcsRates) : null
  return {
    kgRate: own ? num(f.kgRate) : num(settings.kgRate),
    kgCurrency: own ? (f.kgRateCurrency ?? 'BDT') : (settings.kgRateCurrency ?? 'BDT'),
    piece: (category) => priceFor(flightPieces, category) ?? priceFor(settings.pcsRates, category),
  }
}

/** What decides whether an order follows a rate change. */
export interface FollowerSource {
  paidAmount: Prisma.Decimal | number
  payments?: unknown[]
  invoice?: { pricingMode: string } | null
  chargeRate: Prisma.Decimal | number
  chargeCurrency: Currency
  pcsItems: Prisma.JsonValue
}

const pcsOf = (s: Pick<FollowerSource, 'pcsItems'>): PcsItem[] =>
  Array.isArray(s.pcsItems) ? (s.pcsItems as unknown as PcsItem[]).filter((i) => i && typeof i === 'object') : []

const onKgRate = (s: FollowerSource, rates: EffectiveRates): boolean =>
  rates.kgRate > 0 && s.chargeCurrency === rates.kgCurrency && num(s.chargeRate) === rates.kgRate

const onPiecePrice = (item: PcsItem, rates: EffectiveRates): boolean => {
  if ((item.currency ?? 'BDT') !== 'BDT') return false
  const price = rates.piece(item.category)
  return price !== undefined && item.rate === price
}

/**
 * An order follows its flight's rates when nothing is paid on it, its invoice
 * is not hand-edited and its kg part or a device item is on the given rates.
 */
export function followsRates(s: FollowerSource, rates: EffectiveRates): boolean {
  if (num(s.paidAmount) !== 0 || (s.payments?.length ?? 0) > 0 || s.invoice?.pricingMode === 'manual') return false
  return onKgRate(s, rates) || pcsOf(s).some((item) => onPiecePrice(item, rates))
}

/**
 * The parts of a follower that sit on the old rates, moved to the new ones.
 * A part whose new rate is not set (kg rate 0, no piece price) stays as it is.
 */
export function movedToRates(s: FollowerSource, from: EffectiveRates, to: EffectiveRates): PricingChange {
  const change: PricingChange = {}
  if (onKgRate(s, from) && to.kgRate > 0 && (to.kgRate !== from.kgRate || to.kgCurrency !== from.kgCurrency)) {
    change.chargeRate = to.kgRate
    change.chargeCurrency = to.kgCurrency
  }
  let piecesMoved = false
  const items = pcsOf(s).map((item) => {
    if (!onPiecePrice(item, from)) return item
    const price = to.piece(item.category)
    if (price === undefined || price === item.rate) return item
    piecesMoved = true
    return { ...item, rate: price }
  })
  if (piecesMoved) change.pcsItems = items
  return change
}

/** "BG305" from "BG305-20261024-ab12cd"; older codes are used as they are. */
export const flightNumber = (code: string): string => /^(.+)-\d{8}-[0-9a-f]{6}$/.exec(code)?.[1] ?? code

const money = (currency: Currency, amount: number) => `${currency === 'CNY' ? '¥' : '৳'}${amount}`

/**
 * Reprices every order on the flight that is still on the old rates, the
 * same way an edited order is repriced. Returns how many orders changed.
 */
export async function applyRatesToOrders(
  flight: { id: string; code: string },
  from: EffectiveRates,
  to: EffectiveRates,
  settings: Pick<AppSettings, 'rate' | 'exchangeRates'>,
): Promise<number> {
  const shipments = await prisma.shipment.findMany({
    where: { flightId: flight.id },
    include: { invoice: { select: { pricingMode: true } }, payments: { select: { id: true } } },
    orderBy: { code: 'asc' },
  })
  let updated = 0
  for (const shipment of shipments) {
    if (!followsRates(shipment, from)) continue
    const change = movedToRates(shipment, from, to)
    const data: Prisma.ShipmentUncheckedUpdateInput = {}
    const changed: string[] = []
    if (!(await repriceShipment(shipment, change, data, changed, settings))) continue
    const parts: string[] = []
    if (change.chargeRate !== undefined) parts.push(`${money(change.chargeCurrency ?? 'BDT', change.chargeRate)}/kg`)
    const before = pcsOf(shipment)
    const pieces = new Map<string, number>()
    change.pcsItems?.forEach((item, i) => {
      if (item.rate !== before[i]?.rate) pieces.set(item.category, item.rate)
    })
    for (const [category, price] of pieces) parts.push(`${category} ${money('BDT', price)} each`)
    const charge = data.charge !== undefined ? ` (charge ${money('BDT', num(data.charge as Prisma.Decimal))})` : ''
    await prisma.shipment.update({ where: { id: shipment.id }, data })
    await writeShipmentLog(shipment.id, `Rates from flight ${flightNumber(flight.code)}: ${parts.join(', ')}${charge}`, 'Admin')
    // The automatic bill follows the new charge; a hand-edited one never gets here.
    await refreshShipmentInvoice(shipment.id, 'Shipment pricing changed')
    updated++
  }
  return updated
}
