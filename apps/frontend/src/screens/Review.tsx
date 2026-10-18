import { Input } from "@/components/beui/input";
import { useRef, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import {
  ArrowUpRight,
  Check,
  Copy,
  Image as ImageIcon,
  ReceiptText,
  X,
} from "lucide-react";
import { api } from "@/api/client";
import type { ReviewItem, ReceiptScreenshotMeta } from "@/api/types";
import { useFetch } from "@/state/useFetch";
import { PageHeader, EmptyState, SummaryStrip } from "@/components/Workspace";
import { Panel } from "@/components/DesignSystem";
import { ReceiptScreenshot } from "@/components/ReceiptScreenshot";
import { nativeMoney } from "@/components/MoneyInput";
import { Button } from "@/components/beui/button";
import { useToast } from "@/components/beui/toast";
import { ErrorBlock, LoadingBlock } from "@/components/ui";
import { fmtBdt, fmtDayMonth, fmtLogAt } from "@/lib/format";

type StatementReview = {
  sourceCurrency: string;
  sourceAmount: number;
  sourceFxRate: number;
  reference: string;
  supplierCode: string;
  supplierName: string;
  month: string;
  amount: number;
  method: string;
  txnRef: string;
  date: string;
  screenshot: ReceiptScreenshotMeta | null;
};

export function Review() {
  const [params] = useSearchParams();
  const [selected, setSelected] = useState(params.get("receipt") ?? "");
  const [busy, setBusy] = useState(false);
  const [rejecting, setRejecting] = useState(false);
  const [reason, setReason] = useState("");
  const locked = useRef(false);
  const detail = useRef<HTMLElement>(null);
  const { showToast } = useToast();
  const { data, error, loading, reload } = useFetch<{
    queue: ReviewItem[];
    statements: StatementReview[];
  }>("/review");
  const rows = data
    ? [
        ...data.queue.map((item) => ({
          ...item,
          key: `shipment:${item.code}`,
          kind: "Shipment",
          record: item.code,
          target: `/shipments/${encodeURIComponent(item.code)}?section=billing`,
          actionPath: `/shipments/${encodeURIComponent(item.code)}/receipt`,
          targetLabel: "Open shipment billing",
        })),
        ...data.statements.map((item) => ({
          ...item,
          key: `statement:${item.reference}`,
          kind: "Monthly statement",
          record: item.month,
          target: `/suppliers/${encodeURIComponent(item.supplierCode)}?section=statements`,
          actionPath: `/suppliers/${encodeURIComponent(item.supplierCode)}/statement-receipts/${item.reference}`,
          targetLabel: "Open customer statement",
        })),
      ]
    : [];
  const current = rows.find((item) => item.key === selected) ?? rows[0];

  async function act(action: "approve" | "reject") {
    if (
      locked.current ||
      !current ||
      (action === "reject" && reason.trim().length < 3)
    )
      return;
    locked.current = true;
    setBusy(true);
    try {
      await api.post(
        `${current.actionPath}/${action}`,
        action === "reject" ? { reason: reason.trim() } : undefined,
      );
      setRejecting(false);
      setReason("");
      showToast({
        title:
          action === "approve"
            ? `Payment verified — ${current.record}`
            : `Receipt rejected — ${current.record}`,
        status: action === "approve" ? "success" : "neutral",
      });
      await reload();
    } catch (error) {
      showToast({
        title:
          error instanceof Error ? error.message : "Could not review payment",
        status: "error",
      });
    } finally {
      locked.current = false;
      setBusy(false);
    }
  }
  async function copyReference() {
    try {
      await navigator.clipboard.writeText(current?.txnRef ?? "");
      showToast({ title: "Transaction reference copied", status: "success" });
    } catch {
      showToast({
        title: "Select and copy the transaction reference",
        status: "error",
      });
    }
  }
  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  return (
    <div className="space-y-6">
      <PageHeader
        title="Payment review"
        description="Review customer screenshots and match each transfer before recording the payment."
      />
      <SummaryStrip
        items={[
          {
            label: "Pending receipts",
            value: rows.length,
            description: "Awaiting account verification",
          },
          {
            label: "Shipment payments",
            value: data.queue.length,
            description: "Individual shipment receipts",
          },
          {
            label: "Statement payments",
            value: data.statements.length,
            description: "Monthly balance receipts",
          },
        ]}
      />
      <Panel
        title="Receipts awaiting verification"
        description="Select a receipt to see its screenshot and payment details."
      >
        {!rows.length ? (
          <EmptyState
            title="No receipts awaiting review"
            description="New customer payment receipts will appear here."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[850px] text-left text-sm">
              <thead>
                <tr className="border-y border-border bg-background text-xs text-muted-foreground">
                  <th scope="col" className="p-3 font-medium">
                    Reference
                  </th>
                  <th scope="col" className="p-3 font-medium">
                    Customer
                  </th>
                  <th scope="col" className="p-3 font-medium">
                    Payment account
                  </th>
                  <th scope="col" className="p-3 font-medium">
                    Screenshot
                  </th>
                  <th scope="col" className="p-3 text-right font-medium">
                    Submitted amount
                  </th>
                  <th scope="col" className="p-3 text-right font-medium">
                    Review
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.map((item) => (
                  <tr
                    key={item.key}
                    className={`border-b border-border align-top ${current?.key === item.key ? "bg-primary-soft" : ""}`}
                  >
                    <td className="p-3">
                      <p className="font-medium">{item.record}</p>
                      <p className="mt-1 text-xs text-muted-foreground">
                        {item.kind} · {fmtDayMonth(item.date)}
                      </p>
                    </td>
                    <td className="p-3">
                      {item.supplierName || item.supplierCode}
                    </td>
                    <td className="p-3">{item.method}</td>
                    <td className="p-3">
                      <span className="receipt-attachment-label">
                        <ImageIcon size={15} aria-hidden="true" />
                        {item.screenshot ? "Attached" : "Not attached"}
                      </span>
                    </td>
                    <td className="whitespace-nowrap p-3 text-right tabular-nums">
                      <p>
                        {nativeMoney(
                          item.sourceAmount ?? item.amount,
                          item.sourceCurrency ?? "BDT",
                        )}
                      </p>
                      {item.sourceCurrency === "CNY" && (
                        <p className="mt-1 text-xs text-muted-foreground">
                          {fmtBdt(item.amount)}
                        </p>
                      )}
                    </td>
                    <td className="p-3 text-right">
                      <Button
                        variant="secondary"
                        size="sm"
                        aria-pressed={current?.key === item.key}
                        disabled={busy}
                        onClick={() => {
                          setSelected(item.key);
                          setRejecting(false);
                          setReason("");
                          requestAnimationFrame(() =>
                            detail.current?.scrollIntoView({ block: "start" }),
                          );
                        }}
                      >
                        {current?.key === item.key
                          ? "Selected"
                          : "Review receipt"}
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Panel>
      {current && (
        <section
          ref={detail}
          className="receipt-review"
          aria-labelledby="receipt-review-heading"
        >
          <header className="receipt-review-header">
            <div className="receipt-review-title">
              <span className="receipt-review-icon">
                <ReceiptText size={22} />
              </span>
              <div>
                <p>Receipt review · {current.kind}</p>
                <h2 id="receipt-review-heading">{current.record}</h2>
                <span>{current.supplierName || current.supplierCode}</span>
              </div>
            </div>
            <div className="receipt-review-header-actions">
              <span className="receipt-pending-status">
                Awaiting verification
              </span>
              <Link to={current.target}>
                {current.targetLabel}
                <ArrowUpRight size={15} />
              </Link>
            </div>
          </header>
          <div className="receipt-review-body">
            <ReceiptScreenshot
              key={current.key}
              screenshot={current.screenshot}
            />
            <section
              className="receipt-payment-details"
              aria-label="Submitted payment details"
            >
              <div className="receipt-submitted-amount">
                <span>Submitted amount</span>
                <strong>
                  {nativeMoney(
                    current.sourceAmount ?? current.amount,
                    current.sourceCurrency ?? "BDT",
                  )}
                </strong>
                <p>
                  Amount to credit <b>{fmtBdt(current.amount)}</b>
                </p>
                {current.sourceCurrency === "CNY" && (
                  <small>Saved rate: 1 CNY = {current.sourceFxRate} BDT</small>
                )}
              </div>
              <dl className="receipt-payment-fields">
                <div>
                  <dt>Receiving account</dt>
                  <dd>{current.method}</dd>
                </div>
                <div>
                  <dt>Transaction reference</dt>
                  <dd className="receipt-reference">
                    <span>{current.txnRef || "No reference supplied"}</span>
                    {current.txnRef && (
                      <Button
                        size="icon"
                        variant="ghost"
                        aria-label="Copy transaction reference"
                        onClick={() => void copyReference()}
                      >
                        <Copy size={15} />
                      </Button>
                    )}
                  </dd>
                </div>
                <div>
                  <dt>Submitted on</dt>
                  <dd>{fmtLogAt(current.date)}</dd>
                </div>
                <div>
                  <dt>
                    {current.kind === "Shipment"
                      ? "Shipment"
                      : "Statement month"}
                  </dt>
                  <dd>{current.record}</dd>
                </div>
              </dl>
            </section>
          </div>
          <footer className="receipt-review-footer">
            <p>
              Match the amount and reference with your receiving account before
              approving this payment.
            </p>
            <div>
              {rejecting && (
                <div className="w-full space-y-2">
                  <Input
                    label="Reason shown to customer"
                    value={reason}
                    onChange={setReason}
                    disabled={busy}
                    placeholder="Explain what could not be verified and how to correct it"
                  />
                  <p className="text-xs text-muted-foreground">
                    The customer keeps their submission history. Ask for
                    corrected proof or contact, not another transfer.
                  </p>
                </div>
              )}
              <Button
                variant="secondary"
                disabled={busy || (rejecting && reason.trim().length < 3)}
                onClick={() => {
                  if (rejecting) void act("reject");
                  else setRejecting(true);
                }}
              >
                <X size={16} />
                {rejecting ? "Confirm rejection" : "Reject receipt"}
              </Button>
              <Button disabled={busy} onClick={() => void act("approve")}>
                <Check size={16} />
                {busy ? "Saving…" : "Approve verified payment"}
              </Button>
            </div>
          </footer>
        </section>
      )}
    </div>
  );
}
