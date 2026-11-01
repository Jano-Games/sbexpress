import { Prisma } from '@prisma/client'
import { computeCharge, pcsTotal, type PcsItem } from './compute'
import { num } from './serialize'
import { getSettings, type AppSettings } from './settings'

/** The stored values a shipment's charge is worked out from. */
export interface PricedShipment {
  bookedKg: Prisma.Decimal | number
  weighedKg: Prisma.Decimal | number | null
  charge: Prisma.Decimal | number
  chargeRate: Prisma.Decimal | number
  chargeCurrency: 'BDT' | 'CNY'
  pcsItems: Prisma.JsonValue
  pricingRates: Prisma.JsonValue
}

/** New pricing inputs; anything left out keeps the shipment's current value. */
export interface PricingChange {
  chargeRate?: number
  chargeCurrency?: 'BDT' | 'CNY'
  bookedKg?: number
  pcsItems?: PcsItem[]
}

/** Serial column stays a flat copy of the per-unit serials for display/search. */
export const flattenSerials = (items: { units?: { serial: string }[] }[]): string[] =>
  items.flatMap((i) => (i.units ?? []).map((u) => u.serial.trim()).filter(Boolean))

/**
 * Rate, currency, weight or device pieces moving means the total charge moves
 * with them. Works the new charge out with the shipment's locked fx rate
 * (today's rate when it has none yet), puts the new pricing into `data` and
 * describes it in `changed`. A new booked weight is only read here: the caller
 * stores and describes it. Returns true when anything that prices the
 * shipment moved; the caller then saves `data` and refreshes the invoice.
 */
export async function repriceShipment(
  shipment: PricedShipment,
  change: PricingChange,
  data: Prisma.ShipmentUncheckedUpdateInput,
  changed: string[],
  settings?: Pick<AppSettings, 'rate' | 'exchangeRates'>,
): Promise<boolean> {
  const existingPcs = (shipment.pcsItems as unknown as PcsItem[]) ?? []
  const rateChanged = change.chargeRate !== undefined && change.chargeRate !== num(shipment.chargeRate)
  const currencyChanged = change.chargeCurrency !== undefined && change.chargeCurrency !== shipment.chargeCurrency
  const pcsChanged = change.pcsItems !== undefined && JSON.stringify(change.pcsItems) !== JSON.stringify(existingPcs)
  const kgChanged = change.bookedKg !== undefined && change.bookedKg !== num(shipment.bookedKg)
  if (!(rateChanged || currencyChanged || pcsChanged || kgChanged)) return false

  const { rate: todayRate, exchangeRates } = settings ?? (await getSettings())
  const rate = change.chargeRate ?? num(shipment.chargeRate)
  const currency = change.chargeCurrency ?? shipment.chargeCurrency
  const kg = shipment.weighedKg !== null ? num(shipment.weighedKg) : change.bookedKg ?? num(shipment.bookedKg)
  const pcs = change.pcsItems ?? existingPcs
  const pricing = shipment.pricingRates as Record<string, number>
  const lockedRate = pricing.CNY || todayRate
  if (!pricing.CNY) data.pricingRates = exchangeRates
  const total = Math.round((computeCharge(rate, kg, currency, lockedRate) + pcsTotal(pcs, lockedRate)) * 100) / 100
  data.chargeRate = new Prisma.Decimal(rate)
  data.chargeCurrency = currency
  if (pcsChanged) {
    data.pcsItems = change.pcsItems as unknown as Prisma.InputJsonValue
    data.serials = flattenSerials(change.pcsItems ?? [])
    changed.push(
      `devices ${pcs.map((i) => `${i.count}× ${i.category} @${i.currency === 'CNY' ? '¥' : '৳'}${i.rate}`).join(', ') || 'none'}`,
    )
  }
  if (total !== num(shipment.charge)) {
    data.charge = new Prisma.Decimal(total)
    changed.push(`charge ৳${total} (${currency === 'CNY' ? '¥' : '৳'}${rate}/kg)`)
  } else if (rateChanged || currencyChanged) {
    changed.push(`rate ${currency === 'CNY' ? '¥' : '৳'}${rate}/kg`)
  }
  return true
}
