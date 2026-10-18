import type { Receipt } from '@prisma/client'
export function latestReceipt<T extends { uploadedAt: Date }>(
  rows: T[],
): T | null {
  return rows.reduce<T | null>(
    (latest, row) =>
      !latest || row.uploadedAt > latest.uploadedAt ? row : latest,
    null,
  )
}
export function receiptSummary(
  r: Receipt & {
    screenshot?: unknown
    payments?: { amount: unknown; reversedAt?: Date | null }[]
  },
) {
  return {
    id: r.id,
    reference: r.reference,
    method: r.method,
    amount: Number(r.amount),
    sourceCurrency: r.sourceCurrency,
    sourceAmount: Number(r.sourceAmount ?? r.amount),
    sourceFxRate: Number(r.sourceFxRate),
    status: r.status,
    txnRef: r.txnRef,
    date: r.uploadedAt.toISOString(),
    reviewedAt: r.reviewedAt?.toISOString() ?? null,
    reviewedBy: r.reviewedByName,
    reason: r.reviewReason,
    screenshot: r.screenshot ?? null,
    reversedAmount: (r.payments ?? [])
      .filter((p) => p.reversedAt)
      .reduce((sum, p) => sum + Number(p.amount), 0),
  }
}

/** An explicit public allowlist prevents internal keys, staff details and proof metadata leaking. */
export function publicReceiptSummary(r: {
  reference: string
  method: string
  amount: unknown
  sourceCurrency: string
  sourceAmount: unknown
  sourceFxRate: unknown
  status: string
  txnRef: string
  uploadedAt?: Date
  createdAt?: Date
  reviewedAt: Date | null
  reviewReason: string
  payments?: { amount: unknown; reversedAt?: Date | null }[]
}) {
  return {
    reference: r.reference,
    method: r.method,
    amount: Number(r.amount),
    sourceCurrency: r.sourceCurrency,
    sourceAmount: Number(r.sourceAmount ?? r.amount),
    sourceFxRate: Number(r.sourceFxRate),
    status: r.status,
    txnRef: r.txnRef,
    date: (r.uploadedAt ?? r.createdAt)!.toISOString(),
    reviewedAt: r.reviewedAt?.toISOString() ?? null,
    reason: r.reviewReason,
    reversedAmount: (r.payments ?? [])
      .filter((p) => p.reversedAt)
      .reduce((sum, p) => sum + Number(p.amount), 0),
  }
}
