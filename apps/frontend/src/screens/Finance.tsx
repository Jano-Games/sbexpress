import { useState, type ReactNode } from "react";
import { Link } from "react-router-dom";
import { ArrowLeftRight, Plus } from "lucide-react";
import { api } from "@/api/client";
import type { FinanceData, InvoiceDoc } from "@/api/types";
import { useFetch } from "@/state/useFetch";
import {
  PageHeader,
  PageTabs,
  SummaryStrip,
  usePageSection,
} from "@/components/Workspace";
import {
  DetailGrid,
  FormActions,
  FormGrid,
  FormSection,
  Panel,
  SectionNotice,
} from "@/components/DesignSystem";
import { MoneyInput, useMoneyEntry } from "@/components/MoneyInput";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import { useToast } from "@/components/beui/toast";
import { ErrorBlock, LoadingBlock } from "@/components/ui";
import { Modal } from "@/components/Modal";
import { InvoiceModal } from "@/modals/InvoiceModal";
import { Reconciliation } from "@/components/Reconciliation";
import { FinanceLedger, accountMoney } from "@/components/FinanceLedger";
import { fmtBdt } from "@/lib/format";

type Action = "income" | "expense" | "transfer" | "account" | null;
const selectClass =
  "mt-2 block h-10 w-full rounded-md border border-border bg-card px-3 text-sm text-foreground";

function Choice({
  label,
  value,
  onChange,
  children,
  disabled = false,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  children: ReactNode;
  disabled?: boolean;
}) {
  return (
    <label className="block text-xs font-medium text-muted-foreground">
      {label}
      <select
        aria-label={label}
        className={selectClass}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        disabled={disabled}
      >
        {children}
      </select>
    </label>
  );
}

function MoneyLine({
  label,
  amount,
  strong = false,
}: {
  label: string;
  amount: number;
  strong?: boolean;
}) {
  return (
    <div
      className={`flex justify-between gap-4 py-3 text-sm ${strong ? "border-t border-border font-semibold" : ""}`}
    >
      <dt className={strong ? "" : "text-muted-foreground"}>{label}</dt>
      <dd className="whitespace-nowrap tabular-nums">{fmtBdt(amount)}</dd>
    </div>
  );
}

export function Finance() {
  const entry = useMoneyEntry();
  const { showToast } = useToast();
  const [tab, setTab] = usePageSection(
    "summary",
    ["summary", "ledger", "accounts", "statements", "reports"],
    "tab",
  );
  const [mode, setMode] = usePageSection(
    "month",
    ["month", "week", "all"],
    "period",
  );
  const [month, setMonth] = useState(new Date().toISOString().slice(0, 7));
  const [action, setAction] = useState<Action>(null);
  const [busy, setBusy] = useState(false);
  const [revision, setRevision] = useState(0);
  const [ledgerAccount, setLedgerAccount] = useState("");
  const [statement, setStatement] = useState<InvoiceDoc | null>(null);
  const [amount, setAmount] = useState("");
  const [account, setAccount] = useState("");
  const [note, setNote] = useState("");
  const [kind, setKind] = useState("income");
  const [category, setCategory] = useState("others");
  const [editingAccount, setEditingAccount] = useState<string | null>(null);
  const [deletingAccount, setDeletingAccount] = useState<string | null>(null);
  const [mobile, setMobile] = useState({ provider: "", number: "", label: "" });
  const mobileField = (field: keyof typeof mobile) => (value: string) =>
    setMobile((previous) => ({ ...previous, [field]: value }));
  const [accountKind, setAccountKind] = useState("fund");
  const [bank, setBank] = useState({
    bankName: "",
    accountNumber: "",
    accountName: "",
    branch: "",
    district: "",
  });
  const bankField = (field: keyof typeof bank) => (value: string) =>
    setBank((previous) => ({ ...previous, [field]: value }));
  const [name, setName] = useState("");
  const [currency, setCurrency] = useState("BDT");
  const [to, setTo] = useState("");
  const [received, setReceived] = useState("");
  const [transferReference, setTransferReference] = useState(() =>
    crypto.randomUUID(),
  );
  const period = mode === "month" ? month : mode;
  const { data, error, loading, reload } = useFetch<FinanceData>(
    `/finance?period=${period}`,
  );

  function open(next: Action) {
    setAction(next);
    entry.restore("BDT", 1);
    setEditingAccount(null);
    setMobile({ provider: "", number: "", label: "" });
    setAmount("");
    setAccount("");
    setNote("");
    setName("");
    setAccountKind("fund");
    setBank({
      bankName: "",
      accountNumber: "",
      accountName: "",
      branch: "",
      district: "",
    });
    setCurrency("BDT");
    setKind("income");
    setCategory("others");
    setTo("");
    setReceived("");
    setTransferReference(crypto.randomUUID());
  }

  function editAccount(item: FinanceData["accounts"][number]) {
    open("account");
    setEditingAccount(item.name);
    setName(item.name);
    setCurrency(item.currency);
    setAmount(String(item.balance));
    setAccountKind(item.kind);
    if (item.bank) setBank(item.bank);
    if (item.mobile) setMobile(item.mobile);
  }

  function ledger(accountName = "") {
    setLedgerAccount(accountName);
    setTab("ledger");
  }

  async function save() {
    if (!action || busy) return;
    setBusy(true);
    try {
      if (action === "account") {
        const details = {
          kind: accountKind,
          ...(accountKind === "bank" ? { bank } : {}),
          ...(["mobile", "wallet"].includes(accountKind) ? { mobile } : {}),
        };
        if (editingAccount)
          await api.patch(
            `/finance/accounts/${encodeURIComponent(editingAccount)}`,
            details,
          );
        else
          await api.post("/finance/accounts", {
            name: name.trim(),
            currency,
            balance: Number(amount || 0),
            ...details,
          });
      } else if (action === "income")
        await api.post("/finance/incomes", {
          ...entry.meta,
          amount: Number(amount),
          method: account,
          note: note.trim(),
          kind,
        });
      else if (action === "expense")
        await api.post("/finance/expenses", {
          ...entry.meta,
          amount: Number(amount),
          accountName: account,
          reason: note.trim(),
          category,
        });
      else
        await api.post("/finance/transfers", {
          from: account,
          to,
          amount: Number(amount),
          receivedAmount: received ? Number(received) : undefined,
          note: note.trim(),
          reference: transferReference,
        });
      setAction(null);
      setRevision((current) => current + 1);
      await reload();
      showToast({
        title:
          action === "transfer"
            ? "Funds transferred"
            : action === "account"
              ? editingAccount
                ? "Account updated"
                : "Account created"
              : "Entry recorded",
        status: "success",
      });
    } catch (error) {
      showToast({
        title: error instanceof Error ? error.message : "Could not save entry",
        status: "error",
      });
    } finally {
      setBusy(false);
    }
  }

  async function openStatement(code: string) {
    try {
      const response = await api.get<{ statement: InvoiceDoc }>(
        `/suppliers/${code}/statement?month=${month}`,
      );
      setStatement(response.statement);
    } catch (error) {
      showToast({
        title:
          error instanceof Error ? error.message : "Could not load statement",
        status: "error",
      });
    }
  }

  if (error) return <ErrorBlock message={error} />;
  if (!data) return <LoadingBlock />;
  const outgoing = data.expenses + data.refunded;
  const sourceAccount = data.accounts.find((item) => item.name === account);
  const targetAccount = data.accounts.find((item) => item.name === to);
  const crossCurrency = sourceAccount?.currency !== targetAccount?.currency;
  const formValid =
    action === "account"
      ? Boolean(name.trim()) &&
        Number.isFinite(Number(amount || 0)) &&
        (accountKind !== "bank" ||
          Boolean(
            bank.bankName.trim() &&
              bank.accountNumber.trim() &&
              bank.accountName.trim(),
          )) &&
        (!["mobile", "wallet"].includes(accountKind) ||
          Boolean(mobile.provider.trim() && mobile.number.trim()))
      : Number.isFinite(Number(amount)) &&
        Number(amount) > 0 &&
        Boolean(account && note.trim()) &&
        (action === "transfer"
          ? Boolean(
              to &&
                to !== account &&
                (!crossCurrency ||
                  (Number.isFinite(Number(received)) && Number(received) > 0)),
            )
          : entry.valid);
  const dialogTitle =
    action === "transfer"
      ? "Transfer funds"
      : action === "account"
        ? editingAccount
          ? "Edit account"
          : "Add account"
        : "Record transaction";

  return (
    <div className="space-y-6 pb-6">
      <PageHeader
        title="Finance"
        description="Manage accounts, record payments and review business performance."
        actions={
          <>
            <Button
              variant="secondary"
              disabled={data.accounts.length < 2}
              onClick={() => open("transfer")}
            >
              <ArrowLeftRight size={16} />
              Transfer funds
            </Button>
            <Button
              onClick={() => open(tab === "accounts" ? "account" : "income")}
            >
              <Plus size={16} />
              {tab === "accounts" ? "Add account" : "Record transaction"}
            </Button>
          </>
        }
      />
      <PageTabs
        value={tab}
        onChange={setTab}
        items={[
          { value: "summary", label: "Overview" },
          { value: "ledger", label: "Transactions" },
          { value: "accounts", label: "Accounts" },
          { value: "statements", label: "Statements" },
          { value: "reports", label: "Booking profitability" },
        ]}
      />
      {tab !== "accounts" && (
        <section
          aria-label="Reporting period"
          className="flex flex-wrap items-end justify-between gap-4 rounded-md border border-border bg-card p-4"
        >
          <div className="flex flex-wrap items-end gap-4">
            <div className="min-w-40">
              <Choice label="Reporting period" value={mode} onChange={setMode}>
                <option value="month">Monthly</option>
                <option value="week">This week</option>
                <option value="all">All time</option>
              </Choice>
            </div>
            {mode === "month" && (
              <Input
                label="Month"
                aria-label="Statement month"
                type="month"
                value={month}
                onChange={(value) => {
                  if (/^20\d{2}-(0[1-9]|1[0-2])$/.test(value)) setMonth(value);
                }}
              />
            )}
          </div>
          <p className="pb-2 text-xs text-muted-foreground">
            Combined reports use BDT. Account balances retain their original
            currency.
          </p>
        </section>
      )}
      {loading ? (
        <LoadingBlock label="Updating financial records…" />
      ) : (
        <>
          {tab === "summary" && (
            <>
              <SummaryStrip
                items={[
                  {
                    label: "Available funds",
                    value: fmtBdt(data.cash.worth),
                    description: "All accounts · current BDT equivalent",
                  },
                  {
                    label: "Customer receivables",
                    value: fmtBdt(data.receivables.total),
                    description: `${data.receivables.count} unpaid shipments · all time`,
                  },
                  {
                    label: "Unpaid operating costs",
                    value: fmtBdt(data.costPayables),
                    description: "Recorded costs still to settle · all time",
                  },
                  {
                    label:
                      data.results.profit >= 0
                        ? "Booked profit"
                        : "Booked loss",
                    value: fmtBdt(data.results.profit),
                    description: data.periodLabel,
                  },
                ]}
              />
              <div className="grid items-start gap-6 xl:grid-cols-2">
                <Panel
                  title="Cash movement"
                  description={data.periodLabel}
                  actions={
                    <Button variant="secondary" onClick={() => ledger()}>
                      View transactions
                    </Button>
                  }
                >
                  <dl>
                    <MoneyLine label="Money received" amount={data.received} />
                    <MoneyLine label="Money paid out" amount={outgoing} />
                    <MoneyLine
                      label="Net cash movement"
                      amount={data.net}
                      strong
                    />
                  </dl>
                  <p className="mt-4 text-xs leading-relaxed text-muted-foreground">
                    Includes customer receipts, owner capital and refunds.
                    Transfers between your accounts do not change total cash
                    flow.
                  </p>
                </Panel>
                <Panel
                  title="Outstanding balances"
                  description="Amounts to collect or settle across the business today."
                >
                  <dl>
                    <MoneyLine
                      label="Customer invoices to collect"
                      amount={data.receivables.total}
                    />
                    <MoneyLine
                      label="Flyer contributions to collect"
                      amount={data.flyerReceivables}
                    />
                    <MoneyLine
                      label="Operating costs to pay"
                      amount={data.costPayables}
                    />
                    <MoneyLine
                      label="Flight tickets to pay"
                      amount={data.ticketPayables}
                    />
                    {data.ticketRefundReceivables > 0 && (
                      <MoneyLine
                        label="Ticket refunds to collect"
                        amount={data.ticketRefundReceivables}
                      />
                    )}
                    <MoneyLine
                      label="Customer credit held"
                      amount={data.customerCreditLiability}
                    />
                  </dl>
                  <div className="mt-4 flex flex-wrap gap-4 border-t border-border pt-4 text-sm">
                    <Link
                      to="/suppliers"
                      className="font-medium text-primary underline"
                    >
                      Customer accounts
                    </Link>
                    <Link
                      to="/flights"
                      className="font-medium text-primary underline"
                    >
                      Flight settlements
                    </Link>
                  </div>
                </Panel>
              </div>
              <Panel
                title="Account balances"
                description="Current balances in the account's original currency."
                actions={
                  <Button
                    variant="secondary"
                    onClick={() => setTab("accounts")}
                  >
                    Manage accounts
                  </Button>
                }
              >
                {data.accounts.length ? (
                  <div className="overflow-x-auto">
                    <table className="w-full min-w-[520px] text-left text-sm">
                      <thead>
                        <tr className="border-y border-border bg-background text-xs text-muted-foreground">
                          <th className="p-3 font-medium">Account</th>
                          <th className="p-3 font-medium">Type</th>
                          <th className="p-3 font-medium">Currency</th>
                          <th className="p-3 text-right font-medium">
                            Balance
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        {data.accounts.slice(0, 5).map((item) => (
                          <tr
                            key={item.name}
                            className="border-b border-border"
                          >
                            <td className="p-3">
                              <button
                                type="button"
                                className="font-medium text-primary underline"
                                onClick={() => ledger(item.name)}
                              >
                                {item.name}
                              </button>
                            </td>
                            <td className="p-3 capitalize text-muted-foreground">
                              {item.kind}
                            </td>
                            <td className="p-3">{item.currency}</td>
                            <td className="whitespace-nowrap p-3 text-right tabular-nums">
                              {accountMoney(item.balance, item.currency)}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <p className="py-4 text-sm text-muted-foreground">
                    Add an account to start tracking your funds.
                  </p>
                )}
                <div className="mt-4 flex flex-wrap justify-between gap-3 text-xs text-muted-foreground">
                  <span>
                    {data.accounts.length > 5
                      ? `Showing 5 of ${data.accounts.length} accounts`
                      : `${data.accounts.length} accounts`}
                  </span>
                  <span>
                    Owner capital received this period:{" "}
                    <strong className="font-medium text-foreground">
                      {fmtBdt(data.capitalReceived)}
                    </strong>
                  </span>
                </div>
              </Panel>
              <FinanceLedger
                key={`recent-${period}-${revision}`}
                period={period}
                accounts={data.accounts}
                compact
                onViewAll={() => ledger()}
              />
            </>
          )}
          {tab === "ledger" && (
            <FinanceLedger
              key={`${period}-${revision}-${ledgerAccount}`}
              period={period}
              accounts={data.accounts}
              initialAccount={ledgerAccount}
            />
          )}
          {tab === "accounts" && (
            <>
              <Panel
                title="Accounts and funds"
                description={`${data.accounts.length} accounts · Balances are shown in each account's currency.`}
              >
                {data.accounts.length ? (
                  <div className="overflow-x-auto">
                    <table className="w-full min-w-[820px] text-left text-sm">
                      <thead>
                        <tr className="border-y border-border bg-background text-xs text-muted-foreground">
                          <th className="p-3 font-medium">Account</th>
                          <th className="p-3 font-medium">Type</th>
                          <th className="p-3 font-medium">Currency</th>
                          <th className="p-3 text-right font-medium">
                            Current balance
                          </th>
                          <th className="p-3 text-right font-medium">
                            Actions
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        {data.accounts.map((item) => (
                          <tr
                            key={item.name}
                            className="border-b border-border"
                          >
                            <td className="p-3 font-medium">{item.name}</td>
                            <td className="p-3 capitalize text-muted-foreground">
                              {item.kind}
                            </td>
                            <td className="p-3">{item.currency}</td>
                            <td className="whitespace-nowrap p-3 text-right tabular-nums">
                              {accountMoney(item.balance, item.currency)}
                            </td>
                            <td className="p-3">
                              <div className="flex justify-end gap-2">
                                <Button
                                  variant="secondary"
                                  size="sm"
                                  onClick={() => ledger(item.name)}
                                >
                                  Transactions
                                </Button>
                                <Button
                                  variant="secondary"
                                  size="sm"
                                  onClick={() => editAccount(item)}
                                >
                                  Edit
                                </Button>
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  onClick={() => setDeletingAccount(item.name)}
                                >
                                  Delete
                                </Button>
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <div className="space-y-4 py-6">
                    <p className="text-sm text-muted-foreground">
                      No accounts yet. Add a cash drawer, bank account or
                      wallet.
                    </p>
                    <Button onClick={() => open("account")}>
                      Add your first account
                    </Button>
                  </div>
                )}
              </Panel>
              <Reconciliation key={revision} />
            </>
          )}
          {tab === "statements" && (
            <Panel
              title="Customer statements"
              description={
                mode === "month"
                  ? `Monthly billing · ${data.periodLabel} · All amounts in BDT.`
                  : "Select a monthly period to review a billing cycle."
              }
            >
              {mode !== "month" ? (
                <Button variant="secondary" onClick={() => setMode("month")}>
                  Choose monthly period
                </Button>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[640px] text-left text-sm">
                    <thead>
                      <tr className="border-y border-border bg-background text-xs text-muted-foreground">
                        <th className="p-3 font-medium">Customer</th>
                        <th className="p-3 text-right font-medium">Billed</th>
                        <th className="p-3 text-right font-medium">Paid</th>
                        <th className="p-3 text-right font-medium">
                          Outstanding
                        </th>
                        <th className="p-3 text-right font-medium">
                          Statement
                        </th>
                      </tr>
                    </thead>
                    <tbody>
                      {data.statements.map((item) => (
                        <tr key={item.code} className="border-b border-border">
                          <td className="p-3">
                            <Link
                              to={`/suppliers/${item.code}`}
                              className="font-medium text-primary underline"
                            >
                              {item.name}
                            </Link>
                            <p className="mt-1 text-xs text-muted-foreground">
                              {item.code} · {item.shipmentCount} shipments
                            </p>
                          </td>
                          <td className="whitespace-nowrap p-3 text-right tabular-nums">
                            {fmtBdt(item.billed)}
                          </td>
                          <td className="whitespace-nowrap p-3 text-right tabular-nums">
                            {fmtBdt(item.paid)}
                          </td>
                          <td className="whitespace-nowrap p-3 text-right font-medium tabular-nums">
                            {fmtBdt(item.balance)}
                          </td>
                          <td className="p-3 text-right">
                            <Button
                              variant="secondary"
                              size="sm"
                              onClick={() => void openStatement(item.code)}
                            >
                              View statement
                            </Button>
                          </td>
                        </tr>
                      ))}
                      {!data.statements.length && (
                        <tr>
                          <td
                            colSpan={5}
                            className="p-8 text-center text-muted-foreground"
                          >
                            No monthly customer statements for this period.
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              )}
            </Panel>
          )}
          {tab === "reports" && (
            <>
              <SummaryStrip
                items={[
                  {
                    label: "Revenue · BDT",
                    value: fmtBdt(data.results.earned),
                    description: data.periodLabel,
                  },
                  {
                    label: "Costs · BDT",
                    value: fmtBdt(data.results.costs),
                    description: data.periodLabel,
                  },
                  {
                    label:
                      data.results.profit >= 0
                        ? "Booking profit · BDT"
                        : "Booking loss · BDT",
                    value: fmtBdt(data.results.profit),
                    description: "Revenue less costs · owner capital excluded",
                  },
                ]}
              />
              <Panel
                title="Booking profitability"
                description="Current shipment estimates / issued charges and their costs follow the shipment booking month, including later revisions. Business income and overheads follow transaction dates. Cash flow uses payment dates; this is not a closed-period accounting statement."
              >
                <div className="grid gap-6 md:grid-cols-2">
                  <div>
                    <FormSection title="Revenue">
                      <dl>
                        <MoneyLine
                          label="Shipment billing"
                          amount={data.results.billing}
                        />
                        <MoneyLine
                          label="Flyer contributions"
                          amount={data.results.fares}
                        />
                        <MoneyLine
                          label="Other business income"
                          amount={data.results.otherIncome}
                        />
                        <MoneyLine
                          label="Total revenue"
                          amount={data.results.earned}
                          strong
                        />
                      </dl>
                    </FormSection>
                  </div>
                  <div>
                    <FormSection title="Costs">
                      <dl>
                        <MoneyLine
                          label="Air tickets"
                          amount={data.results.tickets}
                        />
                        <MoneyLine
                          label="Shipment costs"
                          amount={data.results.shipmentCosts}
                        />
                        <MoneyLine
                          label="Business expenses"
                          amount={data.results.businessExpenses}
                        />
                        <MoneyLine
                          label="Total costs"
                          amount={data.results.costs}
                          strong
                        />
                      </dl>
                    </FormSection>
                  </div>
                </div>
                <div className="mt-6 border-t border-border pt-5">
                  <DetailGrid
                    items={[
                      {
                        label:
                          data.results.profit >= 0 ? "Net profit" : "Net loss",
                        value: (
                          <span className="text-xl font-semibold tabular-nums">
                            {fmtBdt(data.results.profit)}
                          </span>
                        ),
                      },
                      {
                        label: "Profit margin",
                        value:
                          data.results.marginPct !== null
                            ? `${data.results.marginPct}%`
                            : "Not available",
                      },
                    ]}
                  />
                </div>
                <p className="mt-5 text-xs leading-relaxed text-muted-foreground">
                  Billing and costs are recognized separately from cash
                  collection. Salary, rent and other recorded business expenses
                  are included. Owner capital is excluded from profit.
                </p>
              </Panel>
            </>
          )}
        </>
      )}
      <ConfirmDialog
        open={deletingAccount !== null}
        onClose={() => setDeletingAccount(null)}
        title={`Delete ${deletingAccount ?? "account"}?`}
        body="Deletes this unused, zero-balance account and its linked payment method. Accounts with balances or transaction history cannot be deleted."
        onConfirm={async () => {
          if (!deletingAccount) return;
          try {
            await api.delete(
              `/finance/accounts/${encodeURIComponent(deletingAccount)}`,
            );
            setRevision((current) => current + 1);
            await reload();
            showToast({ title: "Account deleted", status: "success" });
          } catch (error) {
            showToast({
              title:
                error instanceof Error
                  ? error.message
                  : "Could not delete account",
              status: "error",
            });
          }
        }}
      />
      <Modal
        open={action !== null}
        onClose={() => {
          if (!busy) setAction(null);
        }}
        className="max-w-2xl"
      >
        <header className="mb-6">
          <h2 data-dialog-title className="text-xl font-semibold">
            {dialogTitle}
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            {action === "transfer"
              ? "Move existing funds between your accounts."
              : action === "account"
                ? editingAccount
                  ? "Update account details. Name, currency and balance are preserved."
                  : "Set up a fund and its opening balance."
                : action === "expense"
                  ? "Record a business expense paid from an account."
                  : "Record an actual movement of money."}
          </p>
        </header>
        {(action === "income" || action === "expense") && (
          <div className="mb-6">
            <PageTabs
              value={action}
              onChange={(value) => {
                if (!busy) setAction(value as "income" | "expense");
              }}
              items={[
                { value: "income", label: "Money in" },
                { value: "expense", label: "Money out" },
              ]}
            />
          </div>
        )}
        <form
          onSubmit={(event) => {
            event.preventDefault();
            if (formValid) void save();
          }}
          className="space-y-6"
        >
          <fieldset disabled={busy} className="space-y-6">
            {action === "account" ? (
              <>
                <FormSection title="Account details">
                  <FormGrid>
                    <Input
                      label="Account name"
                      disabled={Boolean(editingAccount)}
                      value={name}
                      onChange={setName}
                      placeholder="e.g. Dhaka bank account"
                    />
                    <Choice
                      label="Account type"
                      value={accountKind}
                      onChange={setAccountKind}
                    >
                      <option value="fund">Fund / reserve</option>
                      <option value="cash">Cash</option>
                      <option value="bank">Bank account</option>
                      <option value="mobile">Mobile money</option>
                      <option value="wallet">Wallet</option>
                    </Choice>
                    <Choice
                      label="Currency"
                      value={currency}
                      onChange={setCurrency}
                      disabled={Boolean(editingAccount)}
                    >
                      <option value="BDT">BDT · Taka</option>
                      <option value="CNY">CNY · Yuan</option>
                    </Choice>
                    <Input
                      label={`${editingAccount ? "Current balance (read only)" : "Opening balance"} · ${currency}`}
                      disabled={Boolean(editingAccount)}
                      inputMode="decimal"
                      value={amount}
                      onChange={setAmount}
                      placeholder="0.00"
                    />
                  </FormGrid>
                </FormSection>
                {accountKind === "bank" && (
                  <FormSection
                    title="Bank account information"
                    description="This account also appears in Settings → Payment methods and uses the same fund balance."
                  >
                    <FormGrid>
                      <Input
                        label="Bank name"
                        value={bank.bankName}
                        onChange={bankField("bankName")}
                      />
                      <Input
                        label="Bank account number"
                        value={bank.accountNumber}
                        onChange={bankField("accountNumber")}
                      />
                      <Input
                        label="Account holder name"
                        value={bank.accountName}
                        onChange={bankField("accountName")}
                      />
                      <Input
                        label="Branch (optional)"
                        value={bank.branch}
                        onChange={bankField("branch")}
                      />
                      <Input
                        label="District (optional)"
                        value={bank.district}
                        onChange={bankField("district")}
                      />
                    </FormGrid>
                  </FormSection>
                )}
                {["mobile", "wallet"].includes(accountKind) && (
                  <FormSection
                    title="Payment account information"
                    description="This account also appears in Settings → Payment methods and uses the same fund balance."
                  >
                    <FormGrid>
                      <Input
                        label="Provider"
                        value={mobile.provider}
                        onChange={mobileField("provider")}
                        placeholder="bKash, Nagad or Alipay"
                      />
                      <Input
                        label="Mobile / wallet number"
                        value={mobile.number}
                        onChange={mobileField("number")}
                      />
                      <Input
                        label="Account label (optional)"
                        value={mobile.label}
                        onChange={mobileField("label")}
                      />
                    </FormGrid>
                  </FormSection>
                )}
              </>
            ) : (
              <>
                {action === "income" && (
                  <Choice label="Entry type" value={kind} onChange={setKind}>
                    <option value="income">Business income</option>
                    <option value="capital">Owner capital</option>
                  </Choice>
                )}
                <FormGrid columns={action === "transfer" ? 2 : 1}>
                  <Choice
                    label={
                      action === "transfer"
                        ? "From account"
                        : action === "income"
                          ? "Receiving account"
                          : "Pay from account"
                    }
                    value={account}
                    onChange={(value) => {
                      setAccount(value);
                      setReceived("");
                      setTransferReference(crypto.randomUUID());
                    }}
                  >
                    <option value="">Select an account</option>
                    {data.accounts.map((item) => (
                      <option key={item.name} value={item.name}>
                        {item.name} · {item.currency}
                      </option>
                    ))}
                  </Choice>
                  {action === "transfer" && (
                    <Choice
                      label="To account"
                      value={to}
                      onChange={(value) => {
                        setTo(value);
                        setReceived("");
                        setTransferReference(crypto.randomUUID());
                      }}
                    >
                      <option value="">Select a destination</option>
                      {data.accounts
                        .filter((item) => item.name !== account)
                        .map((item) => (
                          <option key={item.name} value={item.name}>
                            {item.name} · {item.currency}
                          </option>
                        ))}
                    </Choice>
                  )}
                </FormGrid>
                {action === "expense" && (
                  <div className="space-y-4">
                    <Choice
                      label="Expense category"
                      value={category}
                      onChange={setCategory}
                    >
                      {[
                        "salary",
                        "transport",
                        "packaging",
                        "courier",
                        "customs",
                        "others",
                      ].map((item) => (
                        <option value={item} key={item}>
                          {item.charAt(0).toUpperCase() + item.slice(1)}
                        </option>
                      ))}
                    </Choice>
                    <SectionNotice>
                      This records a business expense. For customer-billed
                      costs, use{" "}
                      <Link className="text-primary underline" to="/shipments">
                        Shipment → Costs → Add cost
                      </Link>
                      . Record ticket payments on the{" "}
                      <Link className="text-primary underline" to="/flights">
                        flight record
                      </Link>
                      .
                    </SectionNotice>
                  </div>
                )}
                {action === "transfer" ? (
                  <FormSection
                    title="Transfer amounts"
                    description={
                      account && to && crossCurrency
                        ? "Enter the actual amounts leaving and arriving in each account."
                        : "The same amount will be received when both accounts use the same currency."
                    }
                  >
                    <FormGrid>
                      <Input
                        label={`Amount to send · ${sourceAccount?.currency ?? "source currency"}`}
                        inputMode="decimal"
                        value={amount}
                        onChange={(value) => {
                          setAmount(value);
                          setTransferReference(crypto.randomUUID());
                        }}
                        placeholder="0.00"
                      />
                      {account && to && crossCurrency && (
                        <Input
                          label={`Amount received · ${targetAccount?.currency}`}
                          inputMode="decimal"
                          value={received}
                          onChange={(value) => {
                            setReceived(value);
                            setTransferReference(crypto.randomUUID());
                          }}
                          placeholder="0.00"
                        />
                      )}
                    </FormGrid>
                  </FormSection>
                ) : (
                  <MoneyInput
                    entry={entry}
                    label={
                      action === "income" ? "Amount received" : "Amount paid"
                    }
                    value={amount}
                    onChange={setAmount}
                  />
                )}
                <Input
                  label={action === "expense" ? "Reason" : "Note"}
                  value={note}
                  onChange={(value) => {
                    setNote(value);
                    setTransferReference(crypto.randomUUID());
                  }}
                  placeholder="Describe this transaction"
                />
                {action === "income" && (
                  <SectionNotice>
                    {kind === "capital"
                      ? "Owner capital increases available funds and is excluded from profit."
                      : "Record customer and flyer payments on their own record pages to settle the correct bills."}
                  </SectionNotice>
                )}
              </>
            )}
          </fieldset>
          <FormActions>
            <Button
              variant="secondary"
              disabled={busy}
              onClick={() => setAction(null)}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={busy || !formValid}>
              {busy
                ? "Saving…"
                : action === "transfer"
                  ? "Transfer funds"
                  : action === "account"
                    ? editingAccount
                      ? "Save account"
                      : "Create account"
                    : "Save entry"}
            </Button>
          </FormActions>
        </form>
      </Modal>
      <InvoiceModal
        open={statement !== null}
        onClose={() => setStatement(null)}
        doc={statement}
      />
    </div>
  );
}
