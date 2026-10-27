/**
 * Round 7 profit rules, shared by the flight, the shipment and the dashboard.
 *
 * - Costs on a customer's bill (ShipmentCost lines, and the legacy customs tax
 *   line) are pass-through: the customer pays back what we paid, so they never
 *   change profit.
 * - A shipment's own charge is what its bill asks for without those lines.
 * - Flight profit = shipment charges + what the flyers paid us − ticket − flight costs.
 * - Each shipment takes a share of the flight costs by weight (weighed kg when
 *   known, else booked kg). Ticket and flyer money stay on the flight.
 * - Older unbilled costs recorded on a shipment (China/Dhaka transport fares and
 *   old expenses that are not costs on the bill) are `otherCosts`: our cost,
 *   so they still come off profit.
 */

import type { Prisma } from '@prisma/client'
import { flightCostTotal } from './flightCosts'

type Money = Prisma.Decimal | number | null | undefined
const amountOf = (value: Money) => (value === null || value === undefined ? 0 : Number(value))
const round2 = (value: number) => Math.round((value + Number.EPSILON) * 100) / 100
const round1 = (value: number) => Math.round((value + Number.EPSILON) * 10) / 10

export interface ProfitShipment {
  charge: Money
  customsTax: Money
  afterSalesFee: Money
  bookedKg: Money
  weighedKg?: Money
  invoice?: { total: Money } | null
  costs?: { amount: Money; voidedAt: Date | null }[]
  cnFare?: Money
  bdFare?: Money
  expenses?: { amount: Money; category: string; costId?: string | null; costField?: string | null; flightId?: string | null }[]
}

/**
 * Older unbilled costs on one shipment: the China and Dhaka transport fares plus
 * old expenses linked to it that are not a cost on the bill (costId), not a
 * payment of a recorded fare (costField) and not a ticket row. A removed expense
 * and its negative twin cancel out. The finance results count the same set once
 * (cnTransport, bdTransport and the legacy part of shipmentCosts).
 */
export function shipmentOtherCosts(s: ProfitShipment): number {
  const legacy = (s.expenses ?? [])
    .filter((e) => !e.costId && !e.costField && !(e.category === 'ticket' && e.flightId))
    .reduce((sum, e) => sum + amountOf(e.amount), 0)
  return round2(amountOf(s.cnFare) + amountOf(s.bdFare) + legacy)
}

/** Costs on the bill: non-voided shipment costs plus a legacy customs tax line. */
export function billCostTotal(s: ProfitShipment): number {
  const costs = (s.costs ?? []).filter((c) => !c.voidedAt).reduce((sum, c) => sum + amountOf(c.amount), 0)
  return round2(costs + amountOf(s.customsTax))
}

/**
 * The shipment's own charge: the bill without its pass-through cost lines.
 * With an invoice that is its total (discounts and credits included); before
 * one exists, the weight and device charge less any after-sales credit.
 */
export function shipmentOwnCharge(s: ProfitShipment): number {
  if (s.invoice) return round2(amountOf(s.invoice.total) - billCostTotal(s))
  return round2(amountOf(s.charge) - amountOf(s.afterSalesFee))
}

/** Weight used for the flight-cost share: weighed when known, else booked. */
export const shareKg = (s: { bookedKg: Money; weighedKg?: Money }): number =>
  round1(s.weighedKg !== null && s.weighedKg !== undefined ? amountOf(s.weighedKg) : amountOf(s.bookedKg))

export const flightKg = (shipments: { bookedKg: Money; weighedKg?: Money }[]): number =>
  round1(shipments.reduce((sum, s) => sum + shareKg(s), 0))

export interface FlightProfitBreakdown {
  shipmentCharges: number
  flyerIncome: number
  ticket: number
  flightCosts: number
  otherCosts: number
  profit: number
}

export function flightProfitBreakdown(f: {
  fare: Money
  actualCost: Money
  expenses: { category: string; amount: Money }[]
  shipments: ProfitShipment[]
}): FlightProfitBreakdown {
  const shipmentCharges = round2(f.shipments.reduce((sum, s) => sum + shipmentOwnCharge(s), 0))
  const flyerIncome = round2(amountOf(f.fare))
  const ticket = round2(amountOf(f.actualCost))
  const flightCosts = flightCostTotal(f.expenses)
  const otherCosts = round2(f.shipments.reduce((sum, s) => sum + shipmentOtherCosts(s), 0))
  return {
    shipmentCharges,
    flyerIncome,
    ticket,
    flightCosts,
    otherCosts,
    profit: round2(shipmentCharges + flyerIncome - ticket - flightCosts - otherCosts),
  }
}

/** What one shipment's profit needs to know about its flight. */
export interface FlightCostBasis {
  flightCostTotal: number
  flightKg: number
}

export function flightCostBasis(f: { expenses: { category: string; amount: Money }[]; shipments: { bookedKg: Money; weighedKg?: Money }[] }): FlightCostBasis {
  return { flightCostTotal: flightCostTotal(f.expenses), flightKg: flightKg(f.shipments) }
}

export function shipmentProfitBreakdown(s: ProfitShipment, flight: FlightCostBasis | null) {
  const charge = shipmentOwnCharge(s)
  const kg = shareKg(s)
  const totalKg = flight ? flight.flightKg : 0
  const flightCostShare = flight && kg > 0 && totalKg > 0 ? round2((flight.flightCostTotal * kg) / totalKg) : 0
  const otherCosts = shipmentOtherCosts(s)
  return {
    charge,
    flightCostShare,
    billCosts: billCostTotal(s),
    otherCosts,
    profit: round2(charge - flightCostShare - otherCosts),
    shareKg: kg,
    flightKg: totalKg,
  }
}
