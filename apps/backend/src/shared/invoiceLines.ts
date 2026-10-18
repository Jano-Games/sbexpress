import type { Prisma } from '@prisma/client'

type Decimal = Prisma.Decimal | number
export type BillLine = { label: string; amount: number; costId?: string }
type ShipmentCharges = {
  charge: Decimal; customsTax: Decimal; afterSalesFee: Decimal;
  bookedKg?: Decimal; weighedKg?: Decimal | null; chargeRate?: Decimal; chargeCurrency?: string;
  pricingRates?: unknown; pcsItems?: unknown;
}
const cents = (n:number) => Math.round((n + Number.EPSILON) * 100) / 100
const native = (amount:number, currency:string) => `${currency} ${amount.toLocaleString('en-IN', {minimumFractionDigits:2,maximumFractionDigits:2})}`
/** Expand only a calculation that exactly reconciles with the stored charge. Legacy/manual amounts stay intact. */
export function shipmentChargeLines(s: ShipmentCharges): BillLine[] {
  const fallback = [{label:'Shipment charges', amount:Number(s.charge)}]
  const rates = s.pricingRates as Record<string,number> | undefined
  const fx = (currency:string) => currency === 'CNY' ? rates?.CNY ?? 0 : 1
  const currency = s.chargeCurrency ?? 'BDT', kg = Number(s.weighedKg ?? s.bookedKg ?? 0), unitRate = Number(s.chargeRate ?? 0)
  const lines: BillLine[] = []
  if (kg > 0 && unitRate > 0) {
    if (!fx(currency)) return fallback
    lines.push({label:`Shipping · ${kg} kg × ${native(unitRate,currency)}`, amount:cents(kg * unitRate * fx(currency))})
  }
  if (Array.isArray(s.pcsItems)) for (const item of s.pcsItems) {
    if (!item || typeof item !== 'object') return fallback
    const count = Number(item.count), rate = Number(item.rate), unitCurrency = item.currency === 'CNY' ? 'CNY' : 'BDT'
    if (!Number.isFinite(count) || !Number.isFinite(rate) || count < 0 || rate < 0 || !fx(unitCurrency)) return fallback
    if (count) lines.push({label:`${String(item.category).slice(0,70)} · ${count} ${count === 1 ? 'pc' : 'pcs'} × ${native(rate,unitCurrency)}`, amount:cents(count * rate * fx(unitCurrency))})
  }
  if (!lines.length || Math.abs(cents(lines.reduce((sum,line)=>sum+line.amount,0)) - Number(s.charge)) > 0.011) return fallback
  const adjustment = cents(Number(s.charge) - lines.reduce((sum,line)=>sum+line.amount,0))
  lines[lines.length-1]!.amount = cents(lines[lines.length-1]!.amount + adjustment)
  return lines
}
export function draftBillLines(s: ShipmentCharges): BillLine[] {
  return [...shipmentChargeLines(s),
    ...(Number(s.customsTax) ? [{label:'Customs tax', amount:Number(s.customsTax)}] : []),
    ...(Number(s.afterSalesFee) ? [{label:'After-sales credit', amount:-Number(s.afterSalesFee)}] : [])]
}
export function invoiceBillLines(s: ShipmentCharges & {invoice?: {lines:unknown} | null}): BillLine[] {
  if (!s.invoice) return draftBillLines(s)
  const lines = s.invoice.lines as BillLine[]
  let expanded = false
  return lines.flatMap(line => {
    const automatic = /^(Shipment charges|Shipment charge(?: — .*)?|\[TEST\] Shipping)$/.test(line.label)
    if (!expanded && automatic && Math.abs(line.amount - Number(s.charge)) < 0.005) {
      expanded = true; return shipmentChargeLines(s)
    }
    return [line]
  })
}
