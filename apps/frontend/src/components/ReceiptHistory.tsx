import type { ReceiptHistoryItem } from "@/api/types";
import { Panel } from "./DesignSystem";
import { ReceiptScreenshot } from "./ReceiptScreenshot";
import { nativeMoney } from "./MoneyInput";
import { fmtBdt, fmtLogAt } from "@/lib/format";
export function ReceiptHistory({
  items,
  publicView = false,
}: {
  items: ReceiptHistoryItem[];
  publicView?: boolean;
}) {
  if (!items.length) return null;
  const rows = (
    <div className="divide-y divide-border">
      {items.map((r) => (
        <article key={r.reference ?? r.id ?? `${r.txnRef}:${r.date}`} className="py-4">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <strong className="text-sm">{r.txnRef}</strong>
              <p className="text-xs text-muted-foreground">
                {fmtLogAt(r.date)} · {r.method}
              </p>
            </div>
            <div className="text-right">
              <strong className="text-sm">
                {nativeMoney(
                  r.sourceAmount ?? r.amount,
                  r.sourceCurrency ?? "BDT",
                )}
              </strong>
              {r.sourceCurrency === "CNY" && (
                <p className="text-xs text-muted-foreground">
                  {fmtBdt(r.amount)} · 1 CNY = {r.sourceFxRate} BDT
                </p>
              )}
              <p className="text-xs font-medium">
                {r.reversedAmount > 0
                  ? "Credit reversed"
                  : r.status === "pending"
                    ? "Awaiting verification"
                    : r.status === "approved"
                      ? "Verified"
                      : "Not verified"}
              </p>
            </div>
          </div>
          {r.reason && (
            <p className="mt-3 rounded-md border border-border p-3 text-sm">
              {r.reason}
              {r.status === "rejected"
                ? " Correct your proof or contact support. Do not send another payment just because a receipt was rejected."
                : ""}
            </p>
          )}
          {!publicView && (
            <div className="mt-3 flex flex-wrap items-center justify-between gap-3">
              <ReceiptScreenshot screenshot={r.screenshot} compact />
              {r.reviewedBy && (
                <span className="text-xs text-muted-foreground">
                  Reviewed by {r.reviewedBy}
                  {r.reviewedAt ? ` · ${fmtLogAt(r.reviewedAt)}` : ""}
                </span>
              )}
            </div>
          )}
        </article>
      ))}
    </div>
  );
  return publicView ? (
    <details className="mt-4 rounded-md border border-border bg-card p-4">
      <summary className="cursor-pointer text-sm font-semibold">
        Payment submissions ({items.length})
      </summary>
      {rows}
    </details>
  ) : (
    <Panel
      title="Receipt submissions"
      description="Every submitted transfer and screenshot is retained, including earlier partial payments and review decisions."
    >
      {rows}
    </Panel>
  );
}
