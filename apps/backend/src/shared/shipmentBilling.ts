import { createHash } from 'node:crypto'
import { sourceAt } from './money'
import { prisma } from '../core/db'
import { badRequest, notFound } from '../core/errors'
import { num } from './serialize'
import { snapshotInvoice, releaseExcessPaid } from './customerCredit'
import { shipmentChargeLines, type BillLine } from './invoiceLines'
export { draftBillLines } from './invoiceLines'
const include = { invoice: true, costs: true } as const
export function pricingFingerprint(s: {
  charge: unknown
  customsTax: unknown
  bookedKg: unknown
  weighedKg: unknown
  chargeRate: unknown
  chargeCurrency: string
  pcsItems: unknown
}) {
  return createHash('sha256')
    .update(
      JSON.stringify([
        String(s.charge),
        String(s.customsTax),
        String(s.bookedKg),
        String(s.weighedKg),
        String(s.chargeRate),
        s.chargeCurrency,
        s.pcsItems,
      ]),
    )
    .digest('hex')
}
export async function calculatedInvoice(shipmentId: string) {
  const s = await prisma.shipment.findUnique({
    where: { id: shipmentId },
    include,
  })
  if (!s) throw notFound('Shipment not found')
  const lines: BillLine[] = [
    ...shipmentChargeLines(s),
    ...(num(s.customsTax)
      ? [{ label: 'Customs tax', amount: num(s.customsTax) }]
      : []),
    ...s.costs
      .filter((c) => !c.voidedAt)
      .map((c) => ({ label: c.name, amount: num(c.amount), costId: c.id })),
  ]
  return { shipment: s, lines }
}
export async function invoiceSuggestion(shipmentId: string) {
  const { shipment: s, lines } = await calculatedInvoice(shipmentId)
  if (!s.invoice || s.invoice.pricingMode === 'automatic') return lines
  const existing = (s.invoice.lines as BillLine[]).filter(
    (l) => !l.costId || !s.costs.find((c) => c.id === l.costId)?.voidedAt,
  )
  return [
    ...existing,
    ...s.costs
      .filter(
        (c) =>
          !c.voidedAt &&
          !c.id.startsWith('cost_') &&
          !existing.some((l) => l.costId === c.id),
      )
      .map((c) => ({ label: c.name, amount: num(c.amount), costId: c.id })),
  ]
}
/** Costs are accrued separately. They update a draft or request review of an issued agreement. */
export async function refreshShipmentInvoice(
  shipmentId: string,
  reason: string,
  createDraft = false,
) {
  const { shipment: s, lines } = await calculatedInvoice(shipmentId)
  if (s.invoice?.state === 'issued' || s.invoice?.pricingMode === 'manual') {
    await prisma.invoice.update({
      where: { id: s.invoice.id },
      data: { needsReview: true },
    })
    return s.invoice
  }
  if (!s.invoice && !createDraft) return null
  const discount = num(s.invoice?.discount ?? s.afterSalesFee),
    total =
      Math.round((lines.reduce((n, l) => n + l.amount, 0) - discount) * 100) /
      100
  if (total < 0)
    throw badRequest(
      'Charges would fall below the existing credit; review the invoice first',
    )
  const rate = Number((s.pricingRates as Record<string, number>)?.CNY ?? 1),
    source = {
      sourceCurrency: s.chargeCurrency,
      sourceFxRate: s.chargeCurrency === 'CNY' ? rate : 1,
    }
  const invoice = await prisma.invoice.upsert({
    where: { shipmentId },
    create: {
      shipmentId,
      supplierId: s.supplierId,
      number: `INV-${new Date().toISOString().slice(2, 7).replace('-', '')}-${s.code}`,
      state: 'draft',
      pricingMode: 'automatic',
      pricingFingerprint: pricingFingerprint(s),
      lines,
      discount,
      total,
      ...sourceAt(total, source),
    },
    update: {
      lines,
      discount,
      total,
      state: 'draft',
      needsReview: false,
      pricingFingerprint: pricingFingerprint(s),
      ...sourceAt(total, s.invoice ?? source),
    },
  })
  await releaseExcessPaid(s, total, reason)
  await snapshotInvoice(invoice, reason)
  return invoice
}
export async function addShipmentBillCharge(
  shipmentId: string,
  _category: string,
  _amount: number,
  _publicLabel?: string,
) {
  return refreshShipmentInvoice(shipmentId, 'Shipment costs updated', true)
}
/** Sharing may show a draft estimate, but never implicitly issues it or enables payments. */
export async function ensureShipmentInvoice(shipmentId: string) {
  const s = await prisma.shipment.findUnique({
    where: { id: shipmentId },
    include: { invoice: true },
  })
  if (!s) throw notFound('Shipment not found')
  return (
    s.invoice ??
    refreshShipmentInvoice(shipmentId, 'Draft prepared for customer link', true)
  )
}
