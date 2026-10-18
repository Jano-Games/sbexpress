import { ReceiptHistory } from "./ReceiptHistory";
import type { ReceiptHistoryItem } from "@/api/types";
import {
  SavedCustomerLinks,
  type SavedCustomerLink,
} from "@/components/SavedCustomerLinks";
import {
  ReceiptScreenshotInput,
  useReceiptScreenshot,
} from "@/components/ReceiptScreenshotInput";
import { ReceiptScreenshot } from "@/components/ReceiptScreenshot";
import type { ReceiptScreenshotMeta } from "@/api/types";
import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { api } from "@/api/client";
import { useFetch } from "@/state/useFetch";
import { ErrorBlock, LoadingBlock } from "@/components/ui";
import { MoneyInput, useMoneyEntry } from "@/components/MoneyInput";
import { optionalScreenshotReference } from "@/lib/uploadFile";
import {
  DetailGrid,
  FormActions,
  FormGrid,
  FormSection,
  Panel,
  SectionNotice,
} from "@/components/DesignSystem";
import { Input } from "@/components/beui/input";
import { Button } from "@/components/beui/button";
import { fmtBdt } from "@/lib/format";

type StatementReceipt = {
  screenshot: ReceiptScreenshotMeta | null;
  reference: string;
  amount: number;
  method: string;
  txnRef: string;
  status: string;
  month: string;
};

export function StatementLinks({
  code,
  onChanged,
}: {
  code: string;
  onChanged: () => void;
}) {
  const [month, setMonth] = useState(new Date().toISOString().slice(0, 7));
  const [days, setDays] = useState("7");
  const [message, setMessage] = useState("");
  const [failed, setFailed] = useState(false);
  const [busy, setBusy] = useState(false);
  const { data, error, loading, reload } = useFetch<{
    receipts: StatementReceipt[];
  }>(`/suppliers/${code}/statement-receipts`);

  const history = useFetch<{
    links: SavedCustomerLink[];
    balance: { billed: number; paid: number; due: number };
  }>(`/suppliers/${code}/statement-links?month=${month}`);

  async function act(work: () => Promise<unknown>, refreshParent = true) {
    if (busy) return;
    setBusy(true);
    setMessage("");
    setFailed(false);
    try {
      await work();
      await Promise.all([reload(), history.reload()]);
      if (refreshParent) onChanged();
    } catch (error) {
      setFailed(true);
      setMessage(
        error instanceof Error
          ? error.message
          : "Could not complete the request",
      );
    } finally {
      setBusy(false);
    }
  }

  async function create() {
    await api.post(`/suppliers/${code}/statement-link`, {
      month,
      days: Number(days),
    });
    setMessage("Statement link saved.");
  }

  return (
    <div className="space-y-6">
      <Panel
        title="Share a monthly statement"
        description="Create a customer link to view a monthly balance and submit a payment."
      >
        <form
          className="space-y-5"
          onSubmit={(event) => {
            event.preventDefault();
            void act(create, false);
          }}
        >
          <FormGrid>
            <Input
              label="Statement month"
              type="month"
              value={month}
              onChange={setMonth}
              required
              disabled={busy}
            />
            <Input
              label="Link expiry · days"
              type="number"
              min={1}
              max={90}
              step={1}
              value={days}
              onChange={setDays}
              required
              disabled={busy}
            />
          </FormGrid>
          {history.data && (
            <div className="share-invoice-balance">
              <div>
                <span>Monthly billed</span>
                <strong>{fmtBdt(history.data.balance.billed)}</strong>
              </div>
              <div>
                <span>Paid</span>
                <strong>{fmtBdt(history.data.balance.paid)}</strong>
              </div>
              <div>
                <span>Amount due</span>
                <strong>{fmtBdt(history.data.balance.due)}</strong>
              </div>
            </div>
          )}
          <p className="text-xs text-muted-foreground">
            The link uses the full remaining balance of this month's shipment
            invoices.
          </p>
          <FormActions>
            <Button
              variant="secondary"
              disabled={busy}
              onClick={() =>
                void act(async () => {
                  await api.delete(`/suppliers/${code}/statement-link`);
                  setMessage("Statement links revoked.");
                }, false)
              }
            >
              Revoke all statement links
            </Button>
            <Button
              type="submit"
              disabled={busy || history.loading || Boolean(history.error)}
            >
              {busy ? "Please wait…" : "Generate statement link"}
            </Button>
          </FormActions>
        </form>
        <div className="mt-5">
          {history.error ? (
            <div className="space-y-3">
              <ErrorBlock message={history.error} />
              <Button variant="secondary" onClick={() => void history.reload()}>
                Try again
              </Button>
            </div>
          ) : history.loading ? (
            <LoadingBlock />
          ) : (
            <SavedCustomerLinks links={history.data?.links ?? []} />
          )}
        </div>
        {message && (
          <div className="mt-4" role="status">
            <SectionNotice tone={failed ? "danger" : "success"}>
              {message}
            </SectionNotice>
          </div>
        )}
      </Panel>
      <Panel
        title="Statement payment receipts"
        description="Verify each transfer before approving it. Approved amounts are allocated to the customer's outstanding shipments."
      >
        {error ? (
          <ErrorBlock message={error} />
        ) : loading ? (
          <LoadingBlock />
        ) : !data?.receipts.length ? (
          <p className="py-4 text-sm text-muted-foreground">
            No statement receipts have been submitted.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[680px] text-left text-sm">
              <thead>
                <tr className="border-y border-border bg-background text-xs text-muted-foreground">
                  <th className="p-3 font-medium">Month / reference</th>
                  <th className="p-3 font-medium">Payment account</th>
                  <th className="p-3 text-right font-medium">Amount · BDT</th>
                  <th className="p-3 font-medium">Screenshot</th>
                  <th className="p-3 font-medium">Status</th>
                  <th className="p-3 text-right font-medium">Review</th>
                </tr>
              </thead>
              <tbody>
                {data.receipts.map((receipt) => (
                  <tr
                    key={receipt.reference}
                    className="border-b border-border align-top"
                  >
                    <td className="p-3">
                      <p className="font-medium">{receipt.month}</p>
                      <p className="mt-1 break-all text-xs text-muted-foreground">
                        {receipt.txnRef}
                      </p>
                    </td>
                    <td className="p-3">{receipt.method}</td>
                    <td className="whitespace-nowrap p-3 text-right tabular-nums">
                      {fmtBdt(receipt.amount)}
                    </td>
                    <td className="p-3">
                      <ReceiptScreenshot
                        key={receipt.reference}
                        screenshot={receipt.screenshot}
                        compact
                      />
                    </td>
                    <td className="p-3 capitalize">{receipt.status}</td>
                    <td className="p-3">
                      {receipt.status === "pending" ? (
                        <div className="flex justify-end gap-2">
                          <Button
                            disabled={busy}
                            variant="secondary"
                            size="sm"
                            onClick={() =>
                              void act(() =>
                                api.post(
                                  `/suppliers/${code}/statement-receipts/${receipt.reference}/reject`,
                                ),
                              )
                            }
                          >
                            Reject
                          </Button>
                          <Button
                            disabled={busy}
                            size="sm"
                            onClick={() =>
                              void act(() =>
                                api.post(
                                  `/suppliers/${code}/statement-receipts/${receipt.reference}/approve`,
                                ),
                              )
                            }
                          >
                            Approve verified payment
                          </Button>
                        </div>
                      ) : (
                        <p className="text-right text-xs text-muted-foreground">
                          Reviewed
                        </p>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Panel>
    </div>
  );
}

type PublicStatementData = {
  statement: {
    receiptHistory: ReceiptHistoryItem[]; pricingPending: number;
    exchangeRates: Record<string, number>;
    supplier: string;
    month: string;
    expiresAt: string;
    due: number;
    paid: number;
    requested: number;
    pending: boolean;
    rows: { code: string; billed: number; paid: number; due: number }[];
    payMethods: {
      currency: "BDT" | "CNY";
      id: string;
      name: string;
      label: string;
      number: string;
      accountNumber: string;
      accountName: string;
      bankName: string;
      branch: string;
      note: string;
    }[];
  };
};

export function PublicStatement() {
  const { token = "" } = useParams();
  const { data, error, loading, reload } = useFetch<PublicStatementData>(
    `/statements/${token}`,
  );
  const entry = useMoneyEntry(data?.statement.exchangeRates, true);
  const screenshot = useReceiptScreenshot(`/statements/${token}`);
  const [method, setMethod] = useState("");
  const [amount, setAmount] = useState("");
  const [txnRef, setTxnRef] = useState("");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const selected = data?.statement.payMethods.find(
    (item) => item.id === method,
  );
  useEffect(() => {
    entry.setCurrency(selected?.currency ?? "BDT");
    setAmount("");
  }, [method, selected?.currency]);

  async function submit() {
    if (busy || !selected) return;
    setBusy(true);
    setMessage("");
    try {
      const imageReference = await optionalScreenshotReference({
        hasFile: Boolean(screenshot.file),
        upload: () => screenshot.upload(),
        confirmWithoutScreenshot: () =>
          window.confirm(
            "The screenshot could not be uploaded. Submit this payment without a screenshot?",
          ),
      });
      await api.post(`/statements/${token}/receipt`, {
        imageReference,
        ...entry.meta,
        methodId: method,
        amount: Number(amount),
        txnRef: txnRef.trim(),
      });
      screenshot.clear();
      await reload();
    } catch (error) {
      setMessage(
        error instanceof Error ? error.message : "Could not submit payment",
      );
    } finally {
      setBusy(false);
    }
  }

  const statement = data?.statement;
  return (
    <div className="min-h-screen bg-background">
      <header className="border-b border-border bg-card">
        <div className="mx-auto max-w-6xl px-4 py-5 sm:px-6">
          <p className="text-base font-semibold">Sichuan Bangla Express</p>
          <p className="mt-1 text-xs text-muted-foreground">
            Customer statements and payments
          </p>
        </div>
      </header>
      <main className="mx-auto max-w-6xl space-y-6 px-4 py-6 sm:px-6 sm:py-8">
        {error ? (
          <Panel
            title="Statement unavailable"
            description="Contact your shipping agency for a new statement link."
          >
            <ErrorBlock message={error} />
          </Panel>
        ) : loading || !statement ? (
          <LoadingBlock />
        ) : (
          <>
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div>
                <h1 className="text-2xl font-semibold">Monthly statement</h1>
                <p className="mt-2 text-sm text-muted-foreground">
                  {statement.supplier} · {statement.month}
                </p>
              </div>
              <p className="text-xs text-muted-foreground">
                Link expires {new Date(statement.expiresAt).toLocaleString()}
              </p>
            </div>
            <div className="grid items-start gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(280px,1fr)]">
              <Panel
                title="Shipment balances"
                description="Billed, paid and outstanding amounts are shown in BDT."
              >
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[440px] text-left text-sm">
                    <thead>
                      <tr className="border-y border-border bg-background text-xs text-muted-foreground">
                        <th className="p-3 font-medium">Shipment</th>
                        <th className="p-3 text-right font-medium">Billed</th>
                        <th className="p-3 text-right font-medium">Paid</th>
                        <th className="p-3 text-right font-medium">Due</th>
                      </tr>
                    </thead>
                    <tbody>
                      {statement.rows.map((row) => (
                        <tr key={row.code} className="border-b border-border">
                          <td className="p-3 font-medium">{row.code}</td>
                          <td className="whitespace-nowrap p-3 text-right tabular-nums">
                            {fmtBdt(row.billed)}
                          </td>
                          <td className="whitespace-nowrap p-3 text-right tabular-nums">
                            {fmtBdt(row.paid)}
                          </td>
                          <td className="whitespace-nowrap p-3 text-right tabular-nums">
                            {fmtBdt(row.due)}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </Panel>
              <Panel title="Payment summary">
                <dl className="space-y-4 text-sm">
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Verified payments</dt>
                    <dd className="tabular-nums">{fmtBdt(statement.paid)}</dd>
                  </div>
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">
                      Outstanding balance
                    </dt>
                    <dd className="tabular-nums">{fmtBdt(statement.due)}</dd>
                  </div>
                  <div className="flex justify-between gap-4 border-t border-border pt-4 font-semibold">
                    <dt>Requested now</dt>
                    <dd className="tabular-nums">
                      {fmtBdt(statement.requested)}
                    </dd>
                  </div>
                </dl>
              </Panel>
            </div>
            <ReceiptHistory publicView items={statement.receiptHistory ?? []} />
            {statement.pricingPending > 0 && <SectionNotice tone="warning">{statement.pricingPending} shipment(s) are awaiting reviewed invoices and are excluded from the amount payable below.</SectionNotice>}
            {statement.pending ? (
              <SectionNotice tone="warning">
                Your payment receipt is awaiting staff verification. Approved
                payments will be reflected in this statement.
              </SectionNotice>
            ) : statement.requested <= 0 ? (
              <SectionNotice tone="success">
                There is no outstanding amount on the reviewed invoices in this statement.
              </SectionNotice>
            ) : (
              <Panel
                title="Submit a payment"
                description="Send the requested payment, then provide its amount and transaction reference for staff verification."
              >
                {!statement.payMethods.length ? (
                  <SectionNotice>
                    Payment account details are not available. Contact your
                    shipping agency for help.
                  </SectionNotice>
                ) : (
                  <form
                    className="grid gap-6 lg:grid-cols-2"
                    onSubmit={(event) => {
                      event.preventDefault();
                      void submit();
                    }}
                  >
                    <div className="space-y-5">
                      <label className="block text-xs font-medium text-muted-foreground">
                        Payment account
                        <select
                          aria-label="Payment account"
                          className="mt-2 block h-10 w-full rounded-md border border-border bg-card px-3 text-sm text-foreground"
                          value={method}
                          onChange={(event) => setMethod(event.target.value)}
                          disabled={busy}
                          required
                        >
                          <option value="">Select a payment account</option>
                          {statement.payMethods.map((item) => (
                            <option value={item.id} key={item.id}>
                              {item.name}
                              {item.label ? ` · ${item.label}` : ""} ·{" "}
                              {item.currency}
                            </option>
                          ))}
                        </select>
                      </label>
                      {selected && (
                        <>
                          <DetailGrid
                            items={[
                              {
                                label: "Account number",
                                value:
                                  selected.number || selected.accountNumber,
                              },
                              ...(selected.accountName
                                ? [
                                    {
                                      label: "Account name",
                                      value: selected.accountName,
                                    },
                                  ]
                                : []),
                              ...(selected.bankName
                                ? [{ label: "Bank", value: selected.bankName }]
                                : []),
                              ...(selected.branch
                                ? [{ label: "Branch", value: selected.branch }]
                                : []),
                              { label: "Currency", value: selected.currency },
                            ]}
                          />
                          {selected.note && (
                            <p className="whitespace-pre-wrap text-sm text-muted-foreground">
                              {selected.note}
                            </p>
                          )}
                        </>
                      )}
                    </div>
                    <div className="space-y-4 border-t border-border pt-5 lg:border-l lg:border-t-0 lg:pl-6 lg:pt-0">
                      <FormGrid columns={1}>
                        <MoneyInput
                          entry={entry}
                          label="Amount actually sent"
                          value={amount}
                          onChange={setAmount}
                          disabled={busy || !selected}
                        />
                        <Input
                          label="Transaction reference"
                          value={txnRef}
                          onChange={setTxnRef}
                          minLength={3}
                          maxLength={100}
                          required
                          disabled={busy || !selected}
                        />
                      </FormGrid>
                      <ReceiptScreenshotInput
                        entry={screenshot}
                        disabled={busy || !selected}
                      />
                      <FormActions>
                        <Button
                          type="submit"
                          disabled={
                            busy ||
                            screenshot.preparing ||
                            !selected ||
                            !entry.valid ||
                            !Number.isFinite(Number(amount)) ||
                            Number(amount) <= 0 ||
                            txnRef.trim().length < 3
                          }
                        >
                          {busy
                            ? "Submitting…"
                            : "Submit payment for verification"}
                        </Button>
                      </FormActions>
                      {message && (
                        <SectionNotice tone="danger">{message}</SectionNotice>
                      )}
                    </div>
                  </form>
                )}
              </Panel>
            )}
          </>
        )}
      </main>
      <footer className="mx-auto max-w-6xl border-t border-border px-4 py-6 text-xs text-muted-foreground sm:px-6">
        Sichuan Bangla Express · Bashundhara R/A, Dhaka
      </footer>
    </div>
  );
}
