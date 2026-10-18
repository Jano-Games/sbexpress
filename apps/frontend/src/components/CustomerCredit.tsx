import { nativeMoney } from "./MoneyInput";
import { useState } from "react";
import { api } from "@/api/client";
import { useFetch } from "@/state/useFetch";
import { MoneyInput, useMoneyEntry } from "@/components/MoneyInput";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/beui/select";
import { ErrorBlock, Field, LoadingBlock } from "@/components/ui";
import {
  DetailGrid,
  FormActions,
  FormGrid,
  Panel,
  SectionNotice,
} from "@/components/DesignSystem";
import { EmptyState, PageTabs } from "@/components/Workspace";
import { fmtBdt, fmtDate } from "@/lib/format";

type CreditEntry = {
  sourceCurrency: string;
  sourceAmount: number;
  sourceFxRate: number;
  reference: string;
  amount: number;
  kind: string;
  reason: string;
  shipmentCode: string | null;
  at: string;
};

export function CustomerCredit({
  code,
  onChanged,
}: {
  code: string;
  onChanged: () => void;
}) {
  const entry = useMoneyEntry();
  const { data, reload, error, loading } = useFetch<{
    balance: number;
    entries: CreditEntry[];
  }>(`/suppliers/${encodeURIComponent(code)}/credits`);
  const { data: accounts } = useFetch<{
    accounts: { name: string; currency?: string }[];
  }>("/finance?period=all");
  const [action, setAction] = useState("apply");
  const [amount, setAmount] = useState("");
  const [account, setAccount] = useState("");
  const [reason, setReason] = useState("");
  const [shipment, setShipment] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [saved, setSaved] = useState("");

  async function submit() {
    if (busy) return;
    if (
      !Number.isFinite(Number(amount)) ||
      Number(amount) <= 0 ||
      !entry.valid
    ) {
      setMessage("Enter a valid amount and exchange rate.");
      return;
    }
    if (action === "apply" && !shipment.trim()) {
      setMessage("Enter the shipment code to receive this credit.");
      return;
    }
    if (action === "refund" && (!account || !reason.trim())) {
      setMessage("Select the paying account and enter a refund reason.");
      return;
    }
    setBusy(true);
    setMessage("");
    setSaved("");
    try {
      const path = action === "apply" ? "apply-credit" : "refunds";
      const body =
        action === "apply"
          ? {
              ...entry.meta,
              amount: Number(amount),
              shipmentCode: shipment.trim(),
            }
          : {
              ...entry.meta,
              amount: Number(amount),
              accountName: account,
              reason: reason.trim(),
            };
      await api.post(`/suppliers/${encodeURIComponent(code)}/${path}`, body);
      setAmount("");
      setSaved(
        action === "apply"
          ? "Credit applied to the shipment."
          : "Refund recorded.",
      );
      await reload();
      onChanged();
    } catch (e) {
      setMessage(
        e instanceof Error
          ? e.message
          : "The credit action could not be completed.",
      );
    } finally {
      setBusy(false);
    }
  }

  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;

  return (
    <div className="space-y-5">
      <Panel
        title="Available customer credit"
        description="Overpayments remain available for a future bill or a refund."
      >
        <DetailGrid
          items={[
            { label: "Credit balance · BDT", value: fmtBdt(data.balance) },
            { label: "Customer account", value: code },
          ]}
        />
      </Panel>
      <Panel title="Use customer credit">
        <PageTabs
          value={action}
          onChange={(value) => {
            setAction(value);
            setMessage("");
            setSaved("");
          }}
          items={[
            { value: "apply", label: "Apply to shipment" },
            { value: "refund", label: "Record refund" },
          ]}
        />
        <form
          onSubmit={(event) => {
            event.preventDefault();
            void submit();
          }}
          className="space-y-4"
        >
          <p className="text-sm text-muted-foreground">
            {action === "apply"
              ? "Apply existing credit to an outstanding shipment bill."
              : "Record money already returned to the customer. For a paid shipment, issue a credit note before recording its refund."}
          </p>
          <FormGrid>
            <MoneyInput
              entry={entry}
              label={action === "apply" ? "Credit amount" : "Refund amount"}
              value={amount}
              onChange={setAmount}
              disabled={busy}
            />
            {action === "apply" ? (
              <Input
                label="Shipment code"
                placeholder="e.g. SH-201"
                required
                value={shipment}
                onChange={setShipment}
                disabled={busy}
              />
            ) : (
              <div className="space-y-4">
                <Field label="Refund paying account">
                  <Select
                    value={account}
                    onValueChange={setAccount}
                    disabled={busy}
                  >
                    <SelectTrigger aria-label="Refund paying account">
                      <SelectValue placeholder="Select account" />
                    </SelectTrigger>
                    <SelectContent>
                      {accounts?.accounts.map((item) => (
                        <SelectItem key={item.name} value={item.name}>
                          {item.name}
                          {item.currency ? ` · ${item.currency}` : ""}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
                <Input
                  label="Refund reason"
                  required
                  value={reason}
                  onChange={setReason}
                  disabled={busy}
                />
              </div>
            )}
          </FormGrid>
          {message && (
            <div role="alert">
              <SectionNotice tone="danger">{message}</SectionNotice>
            </div>
          )}
          {saved && (
            <div role="status">
              <SectionNotice tone="success">{saved}</SectionNotice>
            </div>
          )}
          <FormActions>
            <Button
              type="submit"
              disabled={
                busy || data.balance <= 0 || !entry.valid || Number(amount) <= 0
              }
            >
              {busy
                ? "Saving…"
                : action === "apply"
                  ? "Apply credit"
                  : "Record refund paid"}
            </Button>
          </FormActions>
        </form>
      </Panel>
      <Panel
        title="Credit history"
        description="Original amounts retain their saved exchange rates. The customer credit balance is reported in BDT."
      >
        {data.entries.length ? (
          <div className="data-table">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Reference</th>
                  <th>Type</th>
                  <th>Shipment</th>
                  <th>Reason</th>
                  <th className="text-right">Amount · BDT</th>
                </tr>
              </thead>
              <tbody>
                {data.entries.map((item) => (
                  <tr key={item.reference}>
                    <td>{fmtDate(item.at)}</td>
                    <td>{item.reference}</td>
                    <td>{item.kind.replaceAll("_", " ")}</td>
                    <td>{item.shipmentCode ?? "—"}</td>
                    <td>{item.reason || "—"}</td>
                    <td className="text-right tabular-nums">
                      {fmtBdt(item.amount)}
                      {item.sourceCurrency === "CNY" && (
                        <p className="mt-1 text-xs text-muted-foreground">
                          {nativeMoney(item.sourceAmount, "CNY")} · 1 CNY ={" "}
                          {item.sourceFxRate} BDT
                        </p>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            title="No credit history"
            description="Overpayments, credit allocations and refunds will appear here."
          />
        )}
      </Panel>
    </div>
  );
}

type InvoiceRevision = {
  version: number;
  reason: string;
  at: string;
  snapshot: {
    total: number;
    discount: number;
    note: string;
    lines: { label: string; amount: number }[];
  };
};
type CreditNote = {
  number: string;
  amount: number;
  reason: string;
  previousTotal: number;
  revisedTotal: number;
  at: string;
};

export function InvoiceHistory({ code }: { code: string }) {
  const { data, error, loading } = useFetch<{
    revisions: InvoiceRevision[];
    creditNotes: CreditNote[];
  }>(`/shipments/${encodeURIComponent(code)}/invoice-history`);
  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  return (
    <div className="space-y-5">
      <Panel
        title="Credit notes"
        description="Changes to finalized billing totals, reported in BDT."
      >
        {data.creditNotes.length ? (
          <div className="data-table">
            <table>
              <thead>
                <tr>
                  <th>Credit note</th>
                  <th>Date</th>
                  <th>Reason</th>
                  <th className="text-right">Credit</th>
                  <th className="text-right">Previous total</th>
                  <th className="text-right">Revised total</th>
                </tr>
              </thead>
              <tbody>
                {data.creditNotes.map((note) => (
                  <tr key={note.number}>
                    <td>{note.number}</td>
                    <td>{fmtDate(note.at)}</td>
                    <td>{note.reason}</td>
                    <td className="text-right tabular-nums">
                      {fmtBdt(note.amount)}
                    </td>
                    <td className="text-right tabular-nums">
                      {fmtBdt(note.previousTotal)}
                    </td>
                    <td className="text-right tabular-nums">
                      {fmtBdt(note.revisedTotal)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            title="No credit notes"
            description="Issued credit notes will appear here."
          />
        )}
      </Panel>
      <Panel
        title="Invoice revisions"
        description="Expand a revision to review the saved invoice lines."
      >
        {data.revisions.length ? (
          <div className="divide-y divide-border">
            {data.revisions.map((revision) => (
              <details key={revision.version} className="py-4 text-sm">
                <summary className="cursor-pointer">
                  <span className="font-medium">
                    Revision {revision.version}
                  </span>{" "}
                  · {fmtDate(revision.at)} · {fmtBdt(revision.snapshot.total)}
                  <span className="ml-2 text-muted-foreground">
                    {revision.reason}
                  </span>
                </summary>
                <div className="mt-4 data-table">
                  <table>
                    <thead>
                      <tr>
                        <th>Line item</th>
                        <th className="text-right">Amount · BDT</th>
                      </tr>
                    </thead>
                    <tbody>
                      {revision.snapshot.lines.map((line, index) => (
                        <tr key={index}>
                          <td>{line.label}</td>
                          <td className="text-right tabular-nums">
                            {fmtBdt(line.amount)}
                          </td>
                        </tr>
                      ))}
                      <tr>
                        <td>Discount</td>
                        <td className="text-right tabular-nums">
                          {fmtBdt(revision.snapshot.discount)}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                {revision.snapshot.note && (
                  <p className="mt-3 text-muted-foreground">
                    {revision.snapshot.note}
                  </p>
                )}
              </details>
            ))}
          </div>
        ) : (
          <EmptyState
            title="No invoice revisions"
            description="Saved invoice revisions will appear here."
          />
        )}
      </Panel>
    </div>
  );
}
