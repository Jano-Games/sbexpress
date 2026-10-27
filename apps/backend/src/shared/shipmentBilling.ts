import { createHash } from 'node:crypto'
import type { Prisma } from '@prisma/client'
import { sourceAt, sourceFields } from './money'
import { atomicMutation, prisma } from '../core/db'
import { badRequest, notFound } from '../core/errors'
import { num } from './serialize'
import { snapshotInvoice, releaseExcessPaid } from './customerCredit'
import { writeShipmentLog } from './actor'
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
const cents = (n: number) => Math.round(n * 100) / 100
/** Compare stored and calculated lines without depending on JSON key order. */
const lineKey = (lines: unknown) =>
  JSON.stringify(
    (Array.isArray(lines) ? (lines as BillLine[]) : []).map((l) => [
      l.label,
      Number(l.amount),
      l.costId ?? null,
    ]),
  )
/** What a re-calculated automatic invoice would total (charge lines + customs tax + costs on the bill − credit). */
const calculatedTotal = (
  lines: BillLine[],
  s: { invoice: { discount: unknown } | null; afterSalesFee: unknown },
) =>
  cents(
    lines.reduce((n, l) => n + l.amount, 0) -
      Number(s.invoice?.discount ?? s.afterSalesFee ?? 0),
  )

/** Automatic invoices are issued once there is a charge (or the shipment is confirmed free). */
export const awaitsAutomaticIssue = (
  invoice: { pricingMode: string; state: string } | null | undefined,
) => !invoice || (invoice.pricingMode === 'automatic' && invoice.state === 'draft')

/**
 * The invoice follows the shipment. An automatic invoice is re-calculated from
 * the charge lines, customs tax and costs on the bill and is issued as soon as
 * there is something to bill (a ৳0 bill only when the shipment is free); once
 * issued it stays issued, with a revision snapshot, a credit note when the
 * total falls and any overpayment moved to customer credit. A hand-edited
 * (manual) invoice is never rewritten: it is flagged for the admin to review.
 */
export async function refreshShipmentInvoice(
  shipmentId: string,
  reason: string,
  create = true,
) {
  const { shipment: s, lines } = await calculatedInvoice(shipmentId)
  const current = s.invoice
  if (current?.pricingMode === 'manual') {
    if (current.needsReview) return current
    return prisma.invoice.update({
      where: { id: current.id },
      data: { needsReview: true },
    })
  }
  if (!current && !create) return null
  const discount = num(current?.discount ?? s.afterSalesFee),
    total = calculatedTotal(lines, s)
  if (total < 0)
    throw badRequest(
      'Charges would fall below the existing credit; review the invoice first',
    )
  const free = total === 0 && s.freeOfCharge
  const wasIssued = current?.state === 'issued'
  const state = total > 0 || free || wasIssued ? 'issued' : 'draft'
  // An issued bill that falls to ৳0 is confirmed as free by the admin, never assumed.
  const needsReview = state === 'issued' && total === 0 && !free
  if (
    current &&
    current.state === state &&
    current.needsReview === needsReview &&
    current.supplierId === s.supplierId &&
    num(current.total) === total &&
    num(current.discount) === discount &&
    lineKey(current.lines) === lineKey(lines)
  )
    return current

  const rate = Number((s.pricingRates as Record<string, number>)?.CNY ?? 1),
    source = {
      sourceCurrency: s.chargeCurrency,
      sourceFxRate: s.chargeCurrency === 'CNY' ? rate : 1,
    }
  const issuing = state === 'issued' && !wasIssued
  if (wasIssued && total < num(current!.total)) {
    const reduction = cents(num(current!.total) - total)
    await prisma.creditNote.create({
      data: {
        ...sourceFields(reduction),
        shipmentId: s.id,
        amount: reduction,
        reason,
        previousTotal: current!.total,
        revisedTotal: total,
      },
    })
  }
  const invoice = await prisma.invoice.upsert({
    where: { shipmentId },
    create: {
      shipmentId,
      supplierId: s.supplierId,
      number: `INV-${new Date().toISOString().slice(2, 7).replace('-', '')}-${s.code}`,
      state,
      needsReview,
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
      state,
      needsReview,
      supplierId: s.supplierId,
      pricingFingerprint: pricingFingerprint(s),
      ...(issuing ? { issuedAt: new Date() } : {}),
      ...sourceAt(total, current ?? source),
    },
  })
  const released = await releaseExcessPaid(s, total, reason)
  await snapshotInvoice(invoice, reason)
  const paid = cents(num(s.paidAmount) - released)
  await prisma.shipment.update({
    where: { id: s.id },
    data: {
      freeOfCharge: free,
      payStatus:
        state === 'issued' && !needsReview && (total > 0 || free) && paid >= total
          ? 'paid'
          : paid > 0
            ? 'partial'
            : 'unpaid',
    },
  })
  const amount = `৳${total.toLocaleString('en-IN')}`
  if (issuing)
    await writeShipmentLog(
      s.id,
      `Bill issued automatically: ${invoice.number} — ${amount}`,
    )
  else if (wasIssued)
    await writeShipmentLog(
      s.id,
      `Bill updated automatically (${reason}) — ${amount}${needsReview ? '; confirm it is free of charge' : ''}`,
    )
  return invoice
}
export async function addShipmentBillCharge(
  shipmentId: string,
  _category: string,
  _amount: number,
  _publicLabel?: string,
) {
  return refreshShipmentInvoice(shipmentId, 'Shipment costs updated')
}
/**
 * Issues a missing or automatic-draft invoice once it has a non-zero total (or
 * the shipment is free). Manual and already issued invoices are left alone.
 */
export async function ensureShipmentInvoice(
  shipmentId: string,
  reason = 'Bill issued automatically',
) {
  const { shipment: s, lines } = await calculatedInvoice(shipmentId)
  if (!awaitsAutomaticIssue(s.invoice)) return s.invoice
  const total = calculatedTotal(lines, s)
  if (total < 0 || (total === 0 && !s.freeOfCharge)) return s.invoice
  return refreshShipmentInvoice(shipmentId, reason)
}

/**
 * Shipments whose automatic bill is missing or still a draft but which have
 * something to bill (a charge, customs tax, a live cost on the bill) or are free.
 * Unpriced drafts stay out, so once everything is issued this finds nothing.
 */
export const PENDING_AUTOMATIC_BILL = {
  AND: [
    {
      OR: [
        { invoice: { is: null } },
        { invoice: { is: { pricingMode: 'automatic', state: 'draft' } } },
      ],
    },
    {
      OR: [
        { charge: { gt: 0 } },
        { customsTax: { gt: 0 } },
        { freeOfCharge: true },
        { costs: { some: { voidedAt: null } } },
      ],
    },
  ],
} satisfies Prisma.ShipmentWhereInput

/**
 * Catch-up for older shipments: issues every missing or automatic-draft bill
 * with a non-zero total (a free shipment's ৳0 bill too) through the same helper
 * and log line as opening the shipment. Each shipment gets its own transaction
 * unless the caller already holds one. Idempotent; never throws. Returns how
 * many bills it issued.
 */
export async function issuePendingInvoices(
  scope: { supplierId?: string } = {},
): Promise<number> {
  let pending: { id: string }[]
  try {
    pending = await prisma.shipment.findMany({
      where: {
        ...PENDING_AUTOMATIC_BILL,
        ...(scope.supplierId ? { supplierId: scope.supplierId } : {}),
      },
      select: { id: true },
      orderBy: { createdAt: 'asc' },
    })
  } catch (error) {
    console.warn(
      `[billing] automatic bill catch-up skipped: ${error instanceof Error ? error.message : String(error)}`,
    )
    return 0
  }
  let issued = 0
  for (const { id } of pending) {
    try {
      const invoice = await atomicMutation(() => ensureShipmentInvoice(id))
      if (invoice?.state === 'issued') issued++
    } catch (error) {
      console.warn(
        `[billing] could not issue the automatic bill for shipment ${id}: ${error instanceof Error ? error.message : String(error)}`,
      )
    }
  }
  return issued
}

/** Server start: runs the catch-up in the background; it never blocks or fails the boot. */
export function startInvoiceCatchUp(): Promise<void> {
  return issuePendingInvoices().then(
    (count) => console.log(`[billing] automatic bill catch-up issued ${count} bill(s)`),
    (error: unknown) =>
      console.warn(
        `[billing] automatic bill catch-up failed: ${error instanceof Error ? error.message : String(error)}`,
      ),
  )
}
