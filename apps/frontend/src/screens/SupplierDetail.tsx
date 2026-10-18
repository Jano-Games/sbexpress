import { SupplierActivity } from "@/components/SupplierActivity";
import { useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { api } from "@/api/client";
import { useFetch } from "@/state/useFetch";
import type { InvoiceDoc, SupplierDetail as Detail } from "@/api/types";
import { Button } from "@/components/beui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/beui/select";
import { useToast } from "@/components/beui/toast";
import {
  BillFigure,
  Chip,
  ErrorBlock,
  Field,
  LoadingBlock,
  StatusChip,
} from "@/components/ui";
import { MoneyInput, useMoneyEntry } from "@/components/MoneyInput";
import {
  PageHeader,
  PageTabs,
  RecordList,
  SummaryStrip,
  usePageSection,
  EmptyState,
} from "@/components/Workspace";
import {
  DetailGrid,
  FormActions,
  FormGrid,
  Panel,
  SectionNotice,
} from "@/components/DesignSystem";
import { StatementLinks } from "@/components/StatementLinks";
import { CustomerCredit } from "@/components/CustomerCredit";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { InvoiceModal } from "@/modals/InvoiceModal";
import { AddSupplierModal } from "@/modals/AddSupplierModal";
import {
  PAY_CHIP,
  PAY_LABEL,
  deltaLabel,
  fmtBdt,
  fmtDate,
  fmtKg,
  fmtLogAt,
} from "@/lib/format";

export function SupplierDetail() {
  const entry = useMoneyEntry();
  const { code = "" } = useParams();
  const navigate = useNavigate();
  const { showToast } = useToast();
  const { data: paymentAccounts } = useFetch<{
    accounts: { name: string; currency?: string }[];
  }>("/finance?period=all");
  const { data, error, loading, reload } = useFetch<{ supplier: Detail }>(
    `/suppliers/${encodeURIComponent(code)}`,
  );
  const [rawSection, setSection] = usePageSection("profile", [
    "profile",
    "overview",
    "shipments",
    "payments",
    "credit",
    "statements",
  ]);
  const section = rawSection === "overview" ? "profile" : rawSection;
  const [statement, setStatement] = useState<InvoiceDoc | null>(null);
  const [statementOpen, setStatementOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [payAmt, setPayAmt] = useState("");
  const [payMethod, setPayMethod] = useState("");
  const [payBusy, setPayBusy] = useState(false);

  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  const s = data.supplier;
  const monthLabel = new Date().toLocaleDateString("en-GB", { month: "long" });

  async function recordPayment(amount: number, baseCurrency = false) {
    if (payBusy) return;
    if (
      !Number.isFinite(amount) ||
      amount <= 0 ||
      (!baseCurrency && !entry.valid)
    ) {
      showToast({
        title: "Enter a valid payment amount and exchange rate",
        status: "error",
      });
      return;
    }
    if (!payMethod) {
      showToast({
        title: "Select the account that received this payment",
        status: "error",
      });
      return;
    }
    setPayBusy(true);
    try {
      const result = await api.post<{
        allocations: { code: string; amount: number }[];
      }>(`/suppliers/${encodeURIComponent(code)}/payments`, {
        ...(baseCurrency
          ? { money: { currency: "BDT", exchangeRate: 1 } }
          : entry.meta),
        amount,
        method: payMethod,
      });
      showToast({
        title: `${fmtBdt(baseCurrency ? amount : entry.toBdt(amount))} recorded`,
        description: result.allocations
          .map((a) => `${a.code} ${fmtBdt(a.amount)}`)
          .join(" · "),
        status: "success",
      });
      setPayAmt("");
      await reload();
    } catch (e) {
      showToast({
        title: e instanceof Error ? e.message : "Payment could not be recorded",
        status: "error",
      });
    } finally {
      setPayBusy(false);
    }
  }

  async function openStatement() {
    try {
      const result = await api.get<{ statement: InvoiceDoc }>(
        `/suppliers/${encodeURIComponent(s.code)}/statement?month=${new Date().toISOString().slice(0, 7)}`,
      );
      setStatement(result.statement);
      setStatementOpen(true);
    } catch (e) {
      showToast({
        title: e instanceof Error ? e.message : "Statement could not be loaded",
        status: "error",
      });
    }
  }

  return (
    <div>
      <Link to="/suppliers" className="mb-4 inline-block text-sm text-primary">
        ← Customers
      </Link>
      <PageHeader
        title={s.name}
        description={`${s.code} · ${s.terms === "monthly" ? "Monthly" : "Instant"} billing account`}
        actions={
          <>
            <Button variant="secondary" onClick={() => setEditOpen(true)}>
              Edit customer
            </Button>
            <Button onClick={() => setSection("payments")}>
              Record payment
            </Button>
          </>
        }
      />
      <SummaryStrip
        items={[
          { label: "Balance due · BDT", value: fmtBdt(s.balance) },
          { label: "Total billed · BDT", value: fmtBdt(s.billed) },
          { label: "Payments received · BDT", value: fmtBdt(s.paid) },
          { label: "Shipments", value: s.orderCount },
        ]}
      />
      <PageTabs
        value={section}
        onChange={setSection}
        items={[
          { value: "profile", label: "Profile" },
          { value: "shipments", label: "Shipments" },
          { value: "payments", label: "Payments & invoices" },
          { value: "credit", label: "Credit & refunds" },
          { value: "statements", label: "Statements" },
        ]}
      />

      {section === "profile" && (
        <div className="space-y-5">
          <Panel
            title="Customer information"
            description="Contact and delivery details used for this account."
          >
            <DetailGrid
              items={[
                { label: "Customer name", value: s.name },
                { label: "Account code", value: s.code },
                { label: "Phone", value: s.phone },
                {
                  label: "Billing terms",
                  value:
                    s.terms === "monthly"
                      ? "Monthly billing"
                      : "Instant billing",
                },
                { label: "Delivery address", value: s.address },
              ]}
            />
          </Panel>
          <Panel title="Shipping and billing summary">
            <DetailGrid
              columns={3}
              items={[
                { label: "Total shipments", value: s.orderCount },
                { label: "Delivered shipments", value: s.deliveredCount },
                { label: "Weight shipped", value: fmtKg(s.shippedKg) },
                { label: "Total billed", value: fmtBdt(s.billed) },
                { label: "Discounts given", value: fmtBdt(s.discountTotal) },
                { label: "Outstanding balance", value: fmtBdt(s.balance) },
              ]}
            />
          </Panel>
          <Panel
            title="Account management"
            description="A customer with linked shipments or financial activity may not be eligible for deletion."
            actions={
              <Button
                variant="danger-outline"
                onClick={() => setDeleteOpen(true)}
              >
                Delete customer
              </Button>
            }
          >
            <p className="text-sm text-muted-foreground">
              Review this customer’s shipments and billing records before
              removing the account.
            </p>
          </Panel>
        </div>
      )}

      {section === "shipments" && (
        <RecordList
          rows={s.orders}
          recordKey={(r) => r.code}
          href={(r) => `/shipments/${encodeURIComponent(r.code)}`}
          searchText={(r) =>
            `${r.code} ${r.categories.join(" ")} ${r.description} ${r.statusLabel}`
          }
          placeholder="Search shipment code, description or status"
          emptyTitle="No shipments for this customer"
          emptyDescription="Shipments assigned to this customer will be listed here."
          columns={[
            { label: "Shipment", render: (r) => r.code },
            {
              label: "Contents",
              render: (r) => (
                <div>
                  {r.description}
                  <p className="mt-1 text-xs text-muted-foreground">
                    {r.categories.join(", ")}
                  </p>
                </div>
              ),
            },
            {
              label: "Weight",
              render: (r) => (
                <div>
                  {r.effectiveKg > 0 ? fmtKg(r.effectiveKg) : "By item"}
                  {r.weightDelta !== null && (
                    <p className="mt-1 text-xs text-muted-foreground">
                      {deltaLabel(r.weightDelta)}
                    </p>
                  )}
                </div>
              ),
            },
            {
              label: "Shipment status",
              render: (r) => (
                <StatusChip index={r.statusIndex} label={r.statusLabel} />
              ),
            },
            {
              label: "Payment",
              render: (r) => (
                <Chip colors={PAY_CHIP[r.payStatus] ?? PAY_CHIP.unpaid!}>
                  {PAY_LABEL[r.payStatus]}
                </Chip>
              ),
            },
            {
              label: "Bill · BDT",
              align: "right",
              render: (r) => (
                <BillFigure bill={r.billAmount} discount={r.discountAmount} />
              ),
            },
          ]}
        />
      )}

      {section === "payments" && (
        <div className="space-y-5">
          <Panel
            title="Record a payment"
            description="Payments settle the oldest reviewed, issued invoices first. Money for draft or pending invoices is kept as customer credit."
          >
            <form
              onSubmit={(e) => {
                e.preventDefault();
                void recordPayment(Number(payAmt));
              }}
            >
              <FormGrid>
                <MoneyInput
                  entry={entry}
                  label="Amount received"
                  value={payAmt}
                  onChange={setPayAmt}
                  disabled={payBusy}
                />
                <Field label="Receiving account">
                  <Select
                    value={payMethod}
                    onValueChange={setPayMethod}
                    disabled={payBusy}
                  >
                    <SelectTrigger aria-label="Receiving account">
                      <SelectValue placeholder="Select account" />
                    </SelectTrigger>
                    <SelectContent>
                      {(paymentAccounts?.accounts ?? []).map((account) => (
                        <SelectItem key={account.name} value={account.name}>
                          {account.name}
                          {account.currency ? ` · ${account.currency}` : ""}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
              </FormGrid>
              {!paymentAccounts?.accounts.length && (
                <div className="mt-4">
                  <SectionNotice>
                    Add a receiving account in Finance before recording a
                    payment.
                  </SectionNotice>
                </div>
              )}
              <FormActions>
                <Button
                  variant="secondary"
                  disabled={payBusy || s.balance <= 0 || !payMethod}
                  onClick={() => void recordPayment(s.balance, true)}
                >
                  Settle full balance · {fmtBdt(s.balance)}
                </Button>
                <Button
                  type="submit"
                  disabled={
                    payBusy || !payMethod || !entry.valid || Number(payAmt) <= 0
                  }
                >
                  {payBusy ? "Recording…" : "Record payment"}
                </Button>
              </FormActions>
            </form>
          </Panel>
          {s.pricingPending > 0 && (
            <SectionNotice tone="warning">
              {s.pricingPending} shipment(s) await pricing review or invoice
              issue. Their estimates are excluded from the payable balance;
              payments for them remain customer credit until applied.
            </SectionNotice>
          )}
          <SupplierActivity code={code} onChanged={reload} />
          <Panel
            title="Invoices"
            description={`${s.invoices.length} saved invoice${s.invoices.length === 1 ? "" : "s"} for this customer.`}
          >
            {s.invoices.length ? (
              <div className="data-table">
                <table>
                  <thead>
                    <tr>
                      <th>Invoice</th>
                      <th>Shipment</th>
                      <th>Issued</th>
                      <th className="text-right">Discount · BDT</th>
                      <th className="text-right">Total · BDT</th>
                    </tr>
                  </thead>
                  <tbody>
                    {s.invoices.map((invoice) => (
                      <tr key={invoice.number}>
                        <td>
                          <Link
                            className="text-primary"
                            to={`/shipments/${encodeURIComponent(invoice.shipmentCode)}?section=billing`}
                          >
                            {invoice.number}
                          </Link>
                        </td>
                        <td>{invoice.shipmentCode}</td>
                        <td>{fmtDate(invoice.issuedAt)}</td>
                        <td className="text-right tabular-nums">
                          {fmtBdt(invoice.discount)}
                        </td>
                        <td className="text-right tabular-nums">
                          {fmtBdt(invoice.total)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <EmptyState
                title="No invoices finalized"
                description="Finalize a shipment’s invoice to add it to this account."
              />
            )}
          </Panel>
        </div>
      )}

      {section === "credit" && (
        <CustomerCredit
          key={JSON.stringify(s)}
          code={code}
          onChanged={reload}
        />
      )}
      {section === "statements" && (
        <div className="space-y-5">
          {s.terms === "monthly" && (
            <Panel
              title="Current month"
              description={`View the ${monthLabel} account statement.`}
              actions={
                <Button
                  variant="secondary"
                  onClick={() => void openStatement()}
                >
                  View {monthLabel} statement
                </Button>
              }
            >
              <p className="text-sm text-muted-foreground">
                Review this month’s charges and payments before sharing a
                statement.
              </p>
            </Panel>
          )}
          <StatementLinks code={code} onChanged={reload} />
        </div>
      )}

      <InvoiceModal
        open={statementOpen}
        onClose={() => setStatementOpen(false)}
        doc={statement}
      />
      <AddSupplierModal
        open={editOpen}
        onClose={() => setEditOpen(false)}
        editing={s}
        onDone={(newCode) => {
          if (newCode && newCode !== s.code)
            navigate(`/suppliers/${encodeURIComponent(newCode)}`, {
              replace: true,
            });
          else void reload();
        }}
      />
      <ConfirmDialog
        open={deleteOpen}
        onClose={() => setDeleteOpen(false)}
        title={`Delete customer ${s.code}?`}
        body={
          s.orderCount > 0
            ? `${s.name} still has ${s.orderCount} shipment(s) — deleting will be refused until they are removed or reassigned.`
            : `${s.name} is removed permanently.`
        }
        onConfirm={async () => {
          try {
            await api.delete(`/suppliers/${encodeURIComponent(s.code)}`);
            showToast({ title: `${s.code} deleted`, status: "success" });
            navigate("/suppliers");
          } catch (e) {
            showToast({
              title: e instanceof Error ? e.message : "Failed",
              status: "error",
            });
          }
        }}
      />
    </div>
  );
}
