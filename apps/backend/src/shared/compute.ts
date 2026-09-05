/**
 * Pure business math shared across modules — plain numbers in, plain numbers
 * out, so the rules stay unit-testable without a database.
 */

export interface FlightEconomics {
  actualCost: number
  spaceKg: number
}

export interface ShipmentMoney {
  bookedKg: number
  charge: number
  cnFare: number
  bdFare: number | null
  customsTax: number
  afterSalesFee: number
}

/**
 * Estimated allocation of the agency-funded ticket share by booked weight.
 * Unassigned/zero-weight cargo has no invented flat cost; the full ticket
 * expense remains in the overall finance result.
 */
export function fareShare(shipment: Pick<ShipmentMoney, 'bookedKg' | 'charge'>, flight: FlightEconomics | null): number {
  if (shipment.bookedKg > 0 && flight && flight.spaceKg > 0) {
    return (flight.actualCost * shipment.bookedKg) / flight.spaceKg
  }
  return 0
}

/** Net profit on one shipment after every cost line. */
export function profit(shipment: ShipmentMoney, flight: FlightEconomics | null, extraExpenses: number): number {
  return (
    shipment.charge -
    fareShare(shipment, flight) -
    shipment.cnFare -
    (shipment.bdFare ?? 0) -
    shipment.customsTax -
    shipment.afterSalesFee -
    extraExpenses
  )
}

/** What the customer owes for one shipment. */
export function billAmount(shipment: Pick<ShipmentMoney, 'charge' | 'customsTax' | 'afterSalesFee'>): number {
  return shipment.charge + shipment.customsTax - shipment.afterSalesFee
}

/**
 * BD-hub weighed weight vs CN booked weight. Returns the signed delta in kg
 * when it meets the alert threshold, null otherwise.
 */
export function weightDelta(bookedKg: number, weighedKg: number | null, threshold: number): number | null {
  if (weighedKg === null) return null
  const delta = Math.round((weighedKg - bookedKg) * 10) / 10
  return Math.abs(delta) >= threshold ? delta : null
}

/** Effective weight for totals: weighed once known, booked before that. */
export function effectiveKg(bookedKg: number, weighedKg: number | null): number {
  return weighedKg ?? bookedKg
}

export const round1 = (n: number): number => Math.round(n * 10) / 10

/** The weight part of a charge: per-kg rate × booked kg, CNY at the fx rate. */
export function computeCharge(
  ratePerKg: number,
  bookedKg: number,
  currency: 'BDT' | 'CNY',
  fxRate: number,
): number {
  const fx = currency === 'CNY' ? fxRate : 1
  return Math.round(ratePerKg * bookedKg * fx * 100) / 100
}

export interface PcsItem {
  category: string
  count: number
  /** Per-piece rate in the item's currency. */
  rate: number
  currency?: 'BDT' | 'CNY'
  /** One entry per piece: model + serial/IMEI. */
  units?: { model: string; serial: string }[]
}

/** The device part of a charge in BDT: per-piece rates, CNY at the fx rate. */
export const pcsTotal = (items: PcsItem[], fxRate: number): number =>
  Math.round(items.reduce((a, i) => a + i.count * i.rate * (i.currency === 'CNY' ? fxRate : 1), 0) * 100) / 100
