import { ReverseEntry } from "./ReverseEntry";
import { useRef, useState } from "react";
import { Plus, ReceiptText } from "lucide-react";
import { Link } from "react-router-dom";
import { api } from "@/api/client";
import type { ShipmentCostItem, ShipmentDetail } from "@/api/types";
import { useFetch } from "@/state/useFetch";
import { Panel, FormActions, DetailGrid, SectionNotice } from "./DesignSystem";
import { SummaryStrip, EmptyState } from "./Workspace";
import { Modal } from "./Modal";
import {
  MoneyInput,
  useMoneyEntry,
  nativeMoney,
  type Currency,
} from "./MoneyInput";
import { Button } from "./beui/button";
import { Input } from "./beui/input";
import { useToast } from "./beui/toast";
import { fmtBdt, fmtDate } from "@/lib/format";

const categories = {
  others: "Other",
  courier: "Courier",
  transport: "Transport",
  packaging: "Packaging",
  customs: "Customs",
};
export function ShipmentCosts({
  shipment,
  onSaved,
}: {
  shipment: ShipmentDetail;
  onSaved: () => Promise<unknown>;
}) {
  const [mode, setMode] = useState<"add" | "pay" | "details" | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [category, setCategory] = useState("others");
  const [amount, setAmount] = useState("");
  const [account, setAccount] = useState("");
  const [busy, setBusy] = useState(false);
  const [timing, setTiming] = useState("later");
  const [voidReason, setVoidReason] = useState("");
  const lock = useRef(false);
  const entry = useMoneyEntry(
    undefined,
    false,
    mode === "add" || mode === "pay",
  );
  const accounts = useFetch<{
    accounts: { name: string; currency: Currency; balance: number }[];
  }>(mode === "add" || mode === "pay" ? "/finance/accounts" : null);
  const { showToast } = useToast();
  const costs = shipment.costs;
  if (!costs) return null;
  const items = costs.items;
  const selected = items.find((item) => item.id === selectedId);
  const paid = items.reduce((sum, item) => sum + item.paidAmount, 0);
  const remaining = items.reduce((sum, item) => sum + item.dueAmount, 0);
  const paying = mode === "pay";
  const value = Number(amount);
  const bdt = entry.toBdt(value);
  const overpayment =
    paying &&
    selected &&
    Number.isFinite(value) &&
    bdt > selected.dueAmount + 0.005;
  const valid =
    ((!paying && timing === "later") ||
      (Boolean(account) &&
        accounts.data?.accounts.some((item) => item.name === account) &&
        !accounts.error)) &&
    entry.valid &&
    Number.isFinite(value) &&
    value > 0 &&
    !overpayment &&
    (paying
      ? Boolean(selected && !selected.voidedAt && selected.dueAmount > 0)
      : Boolean(name.trim()));
  function open(next: "add" | "pay" | "details", item?: ShipmentCostItem) {
    setMode(next);
    setTiming("later");
    setVoidReason("");
    setSelectedId(item?.id ?? null);
    setName("");
    setCategory("others");
    setAccount("");
    entry.restore("BDT", 1);
    setAmount(next === "pay" && item ? String(item.dueAmount) : "");
  }
  async function save() {
    if (!valid || lock.current) return;
    lock.current = true;
    setBusy(true);
    try {
      await api.post(
        `/shipments/${encodeURIComponent(shipment.code)}/expenses`,
        {
          ...entry.meta,
          amount: value,
          accountName: paying || timing === "now" ? account : undefined,
          paymentTiming: paying ? "now" : timing,
          ...(paying && selected
            ? {
                category: selected.category,
                ...(selected.costField
                  ? { costField: selected.costField }
                  : { costId: selected.id }),
                reason: `Payment for ${selected.name}`,
              }
            : { category, reason: name.trim(), label: name.trim() }),
        },
      );
      setMode(null);
      await onSaved();
      showToast({
        title: paying
          ? "Cost payment recorded"
          : "Cost recorded; invoice pricing updated for review",
        status: "success",
      });
    } catch (error) {
      showToast({
        title: error instanceof Error ? error.message : "Could not save cost",
        status: "error",
      });
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }
  async function voidCost() {
    if (!selected || busy) return;
    setBusy(true);
    try {
      await api.post(
        `/shipments/${encodeURIComponent(shipment.code)}/costs/${selected.id}/void`,
        { reason: voidReason },
      );
      setMode(null);
      await onSaved();
      showToast({
        title: "Cost cancelled; review invoice pricing",
        status: "success",
      });
    } catch (e) {
      showToast({
        title: e instanceof Error ? e.message : "Could not cancel cost",
        status: "error",
      });
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="space-y-5">
      <SummaryStrip
        items={[
          {
            label: "Shipment costs",
            value: fmtBdt(costs.total),
            description: `${items.length} recorded ${items.length === 1 ? "cost" : "costs"}`,
          },
          {
            label: "Paid",
            value: fmtBdt(paid),
            description: "Payments against these costs",
          },
          {
            label: "Remaining to pay",
            value: fmtBdt(remaining),
            description:
              remaining > 0
                ? "Use Pay on the corresponding cost"
                : "No outstanding cost payments",
          },
        ]}
      />
      <Panel
        title="Shipment costs"
        description="Courier, packaging, customs and any other shipment cost — all in one place."
        actions={
          <Button onClick={() => open("add")}>
            <Plus size={16} />
            Add cost
          </Button>
        }
      >
        {!items.length ? (
          <EmptyState
            title="No costs added"
            description="Use Add cost for any expense on this shipment."
          />
        ) : (
          <div className="shipment-cost-scroll">
            <table className="shipment-cost-table">
              <caption className="sr-only">Shipment costs and payments</caption>
              <thead>
                <tr>
                  <th scope="col">Cost</th>
                  <th scope="col">Amount</th>
                  <th scope="col">Paid · BDT</th>
                  <th scope="col">Remaining · BDT</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {items.map((item) => (
                  <tr key={item.id}>
                    <td>
                      <strong>{item.name}</strong>
                      <span>
                        {item.recordedAt
                          ? fmtDate(item.recordedAt)
                          : "Earlier recorded cost"}
                      </span>
                    </td>
                    <td>
                      <strong>
                        {nativeMoney(item.sourceAmount, item.sourceCurrency)}
                      </strong>
                      {item.sourceCurrency !== "BDT" && (
                        <span>{fmtBdt(item.amount)}</span>
                      )}
                    </td>
                    <td>{fmtBdt(item.paidAmount)}</td>
                    <td>
                      <span
                        className={
                          item.dueAmount > 0 ? "cost-unpaid" : "cost-paid"
                        }
                      >
                        {item.voidedAt
                          ? "Cancelled"
                          : item.dueAmount > 0
                            ? fmtBdt(item.dueAmount)
                            : "Paid"}
                      </span>
                    </td>
                    <td>
                      <div className="flex justify-end gap-2">
                        <Button
                          variant="secondary"
                          size="sm"
                          onClick={() => open("details", item)}
                          aria-label={`Details for ${item.name}`}
                        >
                          Details
                        </Button>
                        {item.dueAmount > 0 && (
                          <Button
                            size="sm"
                            onClick={() => open("pay", item)}
                            aria-label={`Pay ${item.name}`}
                          >
                            Pay
                          </Button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Panel>
      {items.length > 0 && (
        <p className="billing-table-hint">
          Swipe the cost table to view payments and actions.
        </p>
      )}
      <Panel
        title="Shipment profitability"
        description="All totals are in BDT."
      >
        <DetailGrid
          columns={3}
          items={[
            { label: "Customer bill", value: fmtBdt(shipment.billAmount) },
            { label: "Shipment costs", value: fmtBdt(costs.total) },
            {
              label: "Estimated ticket allocation",
              value: shipment.flightCode
                ? fmtBdt(costs.fareShare)
                : "Flight not assigned",
            },
          ]}
        />
        <div className="shipment-profit-total">
          <span>
            {costs.profit >= 0 ? "Estimated profit" : "Estimated loss"}
          </span>
          <div>
            <strong
              className={costs.profit >= 0 ? "text-success" : "text-danger"}
            >
              {fmtBdt(costs.profit)}
            </strong>
            {costs.profitPct !== null && <span>{costs.profitPct}% margin</span>}
          </div>
        </div>
        {shipment.flightCode && (
          <p className="mt-3 text-xs text-muted-foreground">
            Ticket allocation uses {shipment.bookedKg} kg of{" "}
            {shipment.flightSpaceKg ?? "—"} kg. Manage ticket payments on the{" "}
            <Link
              className="text-primary"
              to={`/flights/${encodeURIComponent(shipment.flightCode)}?section=money`}
            >
              flight record
            </Link>
            .
          </p>
        )}
      </Panel>
      <Modal
        open={mode !== null}
        onClose={() => {
          if (!busy) setMode(null);
        }}
      >
        <header className="mb-6">
          <h2 data-dialog-title className="text-xl font-semibold">
            {mode === "details"
              ? "Cost details"
              : paying
                ? "Pay cost"
                : "Add cost"}
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            {shipment.code}
            {selected ? ` · ${selected.name}` : ""}
          </p>
        </header>
        {mode === "details" && selected ? (
          <div className="space-y-5">
            <DetailGrid
              items={[
                {
                  label: "Cost amount",
                  value: nativeMoney(
                    selected.sourceAmount,
                    selected.sourceCurrency,
                  ),
                },
                { label: "BDT total", value: fmtBdt(selected.amount) },
                { label: "Paid", value: fmtBdt(selected.paidAmount) },
                { label: "Remaining", value: fmtBdt(selected.dueAmount) },
                ...(selected.sourceCurrency === "CNY"
                  ? [
                      {
                        label: "Saved exchange rate",
                        value: `1 CNY = ${selected.sourceFxRate} BDT`,
                      },
                    ]
                  : []),
              ]}
            />
            <section>
              <h3 className="mb-3 text-sm font-semibold">Payments</h3>
              {selected.payments.length ? (
                <ul className="cost-payment-list">
                  {selected.payments.map((payment) => (
                    <li key={payment.id}>
                      <div>
                        <strong>
                          {payment.accountName ?? "Earlier payment"}
                        </strong>
                        <span>
                          {fmtDate(payment.at)}
                          {payment.reversedAt
                            ? " · Reversed"
                            : payment.reversalOfId
                              ? " · Reversal"
                              : ""}
                        </span>
                        {payment.accountCurrency &&
                          payment.accountAmount !== null &&
                          payment.accountCurrency !==
                            payment.sourceCurrency && (
                            <span>
                              Account debit:{" "}
                              {nativeMoney(
                                payment.accountAmount,
                                payment.accountCurrency,
                              )}
                            </span>
                          )}
                      </div>
                      <div>
                        <strong>
                          {nativeMoney(
                            payment.sourceAmount,
                            payment.sourceCurrency,
                          )}
                        </strong>
                        {payment.sourceCurrency !== "BDT" && (
                          <span>{fmtBdt(payment.amount)}</span>
                        )}
                        {payment.canReverse && (
                          <ReverseEntry
                            kind="expense"
                            id={payment.id}
                            onChanged={onSaved}
                          />
                        )}
                      </div>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="text-sm text-muted-foreground">
                  No payments recorded.
                </p>
              )}
            </section>
            {!selected.costField &&
              !selected.voidedAt &&
              selected.paidAmount <= 0 && (
                <section className="space-y-3 border-t pt-4">
                  <h3 className="font-semibold">Cancel incorrect cost</h3>
                  <p className="text-sm text-muted-foreground">
                    Keeps the original record. Any issued invoice must then be
                    reviewed.
                  </p>
                  <Input
                    label="Reason for cancelling cost"
                    value={voidReason}
                    onChange={setVoidReason}
                  />
                  <Button
                    variant="secondary"
                    disabled={busy || voidReason.trim().length < 3}
                    onClick={() => void voidCost()}
                  >
                    Cancel cost
                  </Button>
                </section>
              )}
            <FormActions>
              <Button variant="secondary" onClick={() => setMode(null)}>
                Close
              </Button>
              {selected.dueAmount > 0 && (
                <Button onClick={() => open("pay", selected)}>
                  Pay remaining cost
                </Button>
              )}
            </FormActions>
          </div>
        ) : (
          <form
            onSubmit={(event) => {
              event.preventDefault();
              void save();
            }}
          >
            <fieldset disabled={busy} className="space-y-5">
              {paying ? (
                <SectionNotice>
                  Remaining: <strong>{fmtBdt(selected?.dueAmount ?? 0)}</strong>
                  . This payment settles the recorded cost; the customer invoice
                  stays unchanged.
                </SectionNotice>
              ) : (
                <>
                  <Input
                    label="Cost name"
                    placeholder="e.g. Dhaka courier"
                    value={name}
                    onChange={setName}
                    maxLength={120}
                    required
                    aria-describedby="cost-name-help"
                  />
                  <p
                    id="cost-name-help"
                    className="!mt-2 text-xs text-muted-foreground"
                  >
                    This name appears in the customer invoice breakdown.
                  </p>
                </>
              )}
              <MoneyInput
                entry={entry}
                label={paying ? "Amount paid" : "Cost amount"}
                value={amount}
                onChange={setAmount}
              />
              {overpayment && (
                <SectionNotice tone="danger">
                  The payment exceeds the remaining cost.
                </SectionNotice>
              )}
              {!paying && (
                <label className="block text-sm">
                  Payment timing
                  <select
                    aria-label="Payment timing"
                    className="form-control mt-2"
                    value={timing}
                    onChange={(e) => setTiming(e.target.value)}
                  >
                    <option value="later">
                      Pay later · record an unpaid cost
                    </option>
                    <option value="now">
                      Paid now · deduct from an account
                    </option>
                  </select>
                </label>
              )}
              {(paying || timing === "now") && (
                <>
                  <label className="block text-xs font-medium text-muted-foreground">
                    Pay from account
                    <select
                      className="form-control mt-2"
                      aria-label="Pay from account"
                      value={account}
                      required
                      onChange={(event) => setAccount(event.target.value)}
                    >
                      <option value="">
                        {accounts.loading
                          ? "Loading accounts…"
                          : "Select an account"}
                      </option>
                      {(accounts.data?.accounts ?? []).map((item) => (
                        <option key={item.name} value={item.name}>
                          {item.name} · {item.currency}
                        </option>
                      ))}
                    </select>
                  </label>
                  {accounts.error && (
                    <SectionNotice tone="danger">
                      {accounts.error}
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={() => void accounts.reload()}
                      >
                        Retry accounts
                      </Button>
                    </SectionNotice>
                  )}
                  {accounts.data?.accounts.length === 0 && (
                    <p className="text-sm text-muted-foreground">
                      Add a paying account in{" "}
                      <Link className="text-primary" to="/finance?tab=accounts">
                        Finance
                      </Link>{" "}
                      first.
                    </p>
                  )}
                </>
              )}
              {!paying && (
                <>
                  <details className="cost-category">
                    <summary>Category (optional)</summary>
                    <label>
                      Category
                      <select
                        className="form-control mt-2"
                        aria-label="Cost category"
                        value={category}
                        onChange={(event) => setCategory(event.target.value)}
                      >
                        {Object.entries(categories).map(([key, label]) => (
                          <option key={key} value={key}>
                            {label}
                          </option>
                        ))}
                      </select>
                    </label>
                  </details>
                  <SectionNotice>
                    <ReceiptText size={16} className="mb-2" />
                    {timing === "now"
                      ? "The selected account will be debited. "
                      : "No account will be debited. Pay this cost later, in full or in parts. "}
                    This cost is included in draft pricing. An issued invoice
                    requires an explicit revision.
                  </SectionNotice>
                </>
              )}
            </fieldset>
            <FormActions>
              <Button
                variant="secondary"
                disabled={busy}
                onClick={() => setMode(null)}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={busy || !valid}>
                {busy ? "Saving…" : paying ? "Record payment" : "Add cost"}
              </Button>
            </FormActions>
          </form>
        )}
      </Modal>
    </div>
  );
}
