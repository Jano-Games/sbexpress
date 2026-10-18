import { ReverseEntry } from "./ReverseEntry";
import { Fragment, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { ChevronLeft, ChevronRight, Download } from "lucide-react";
import { useFetch } from "@/state/useFetch";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import { ErrorBlock } from "@/components/ui";
import { DetailGrid, Panel } from "@/components/DesignSystem";
import { EmptyState } from "@/components/Workspace";

export const ledgerLabels: Record<string, string> = {
  customer: "Customer payment",
  flyer: "Flyer payment",
  income: "Business income",
  capital: "Owner capital",
  "customer-credit": "Customer advance",
  expense: "Expense",
  refund: "Refund",
  transfer: "Transfer",
};
export const accountMoney = (amount: number, currency: string) =>
  `${currency} ${amount.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
type Entry = {
  recordId: string;
  reversalKind: string;
  canReverse: boolean;
  reversedAt: string | null;
  reversalOfId: string | null;
  sourceCurrency?: string;
  sourceAmount?: number;
  sourceFxRate?: number;
  baseAmount?: number;
  key: string;
  at: string;
  type: string;
  description: string;
  reference: string;
  account: string | null;
  currency: string;
  amount: number;
  shipmentCode?: string;
  flightCode?: string;
  supplierCode?: string;
};
type Ledger = {
  entries: Entry[];
  total: number;
  page: number;
  limit: number;
  totals: { currency: string; moneyIn: number; moneyOut: number }[];
};

export function FinanceLedger({
  period,
  accounts,
  initialAccount = "",
  compact = false,
  onViewAll,
}: {
  period: string;
  accounts: { name: string; currency: string }[];
  initialAccount?: string;
  compact?: boolean;
  onViewAll?: () => void;
}) {
  const [account, setAccount] = useState(initialAccount);
  const [type, setType] = useState("all");
  const [search, setSearch] = useState("");
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [expanded, setExpanded] = useState<string | null>(null);
  useEffect(() => {
    const timer = setTimeout(() => {
      setQuery(search);
      setPage(1);
    }, 250);
    return () => clearTimeout(timer);
  }, [search]);
  useEffect(() => {
    setPage(1);
    setExpanded(null);
  }, [period, initialAccount]);
  const params = new URLSearchParams({
    period,
    account,
    type,
    search: query,
    page: String(page),
    limit: compact ? "5" : "25",
  });
  const { data, error, loading, reload } = useFetch<Ledger>(
    `/finance/ledger?${params}`,
  );
  const pages = Math.max(1, Math.ceil((data?.total ?? 0) / 25));

  function exportPage() {
    if (!data) return;
    const cell = (value: unknown) => {
      let text = String(value ?? "");
      if (/^[=+@\-\t\r]/.test(text)) text = "'" + text;
      return '"' + text.replaceAll('"', '""') + '"';
    };
    const rows = [
      [
        "Date",
        "Type",
        "Description",
        "Account",
        "Currency",
        "Money in",
        "Money out",
        "Reference",
        "Original currency",
        "Original amount",
        "BDT exchange rate",
        "BDT booked",
      ],
      ...data.entries.map((entry) => [
        entry.at,
        ledgerLabels[entry.type] ?? entry.type,
        entry.description,
        entry.account ?? "Unassigned",
        entry.currency,
        entry.amount > 0 ? entry.amount : 0,
        entry.amount < 0 ? -entry.amount : 0,
        entry.reference,
        entry.sourceCurrency,
        entry.sourceAmount,
        entry.sourceFxRate,
        entry.baseAmount,
      ]),
    ];
    const url = URL.createObjectURL(
      new Blob(
        ["\ufeff" + rows.map((row) => row.map(cell).join(",")).join("\r\n")],
        { type: "text/csv;charset=utf-8" },
      ),
    );
    const link = document.createElement("a");
    link.href = url;
    link.download = `ledger-${period}-page-${page}.csv`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  return (
    <Panel
      title={compact ? "Recent transactions" : "Transaction ledger"}
      description={
        compact
          ? "Latest money movements in the selected period."
          : "Receipts, expenses, refunds and account transfers. Amounts retain the currency of each account."
      }
      actions={
        compact ? (
          <Button variant="secondary" onClick={onViewAll}>
            View full ledger
          </Button>
        ) : (
          <Button
            variant="secondary"
            disabled={!data?.entries.length || loading}
            onClick={exportPage}
          >
            <Download size={16} /> Export this page
          </Button>
        )
      }
    >
      {!compact && (
        <div className="mb-5 grid items-end gap-4 md:grid-cols-3">
          <Input
            label="Search transactions"
            value={search}
            onChange={setSearch}
            placeholder="Reference, shipment or note"
          />
          <label className="block text-xs font-medium text-muted-foreground">
            Account
            <select
              aria-label="Ledger account"
              className="mt-2 block h-10 w-full rounded-md border border-border bg-card px-3 text-sm text-foreground"
              value={account}
              onChange={(event) => {
                setAccount(event.target.value);
                setPage(1);
              }}
            >
              <option value="">All accounts</option>
              {accounts.map((item) => (
                <option value={item.name} key={item.name}>
                  {item.name} · {item.currency}
                </option>
              ))}
              <option value="__unassigned">Unassigned legacy entries</option>
            </select>
          </label>
          <label className="block text-xs font-medium text-muted-foreground">
            Transaction type
            <select
              aria-label="Transaction type"
              className="mt-2 block h-10 w-full rounded-md border border-border bg-card px-3 text-sm text-foreground"
              value={type}
              onChange={(event) => {
                setType(event.target.value);
                setPage(1);
              }}
            >
              <option value="all">All types</option>
              {Object.entries(ledgerLabels).map(([key, label]) => (
                <option key={key} value={key}>
                  {label}
                </option>
              ))}
            </select>
          </label>
        </div>
      )}
      {error ? (
        <ErrorBlock message={error} />
      ) : (
        <>
          <div className="relative overflow-x-auto" aria-busy={loading}>
            <table className="w-full text-left text-sm">
              <thead>
                <tr className="border-y border-border bg-background text-xs text-muted-foreground">
                  <th
                    scope="col"
                    className="hidden px-3 py-3 font-medium sm:table-cell"
                  >
                    Date
                  </th>
                  <th scope="col" className="px-3 py-3 font-medium">
                    Transaction
                  </th>
                  <th
                    scope="col"
                    className="hidden px-3 py-3 font-medium sm:table-cell"
                  >
                    Account
                  </th>
                  <th
                    scope="col"
                    className="hidden px-3 py-3 text-right font-medium sm:table-cell"
                  >
                    Money in
                  </th>
                  <th
                    scope="col"
                    className="hidden px-3 py-3 text-right font-medium sm:table-cell"
                  >
                    Money out
                  </th>
                  <th scope="col" className="px-3 py-3">
                    <span className="sr-only">Details</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td
                      colSpan={6}
                      className="p-8 text-center text-muted-foreground"
                    >
                      Loading transactions…
                    </td>
                  </tr>
                ) : !data?.entries.length ? (
                  <tr>
                    <td colSpan={6}>
                      <EmptyState
                        title="No transactions found"
                        description={
                          search || account || type !== "all"
                            ? "Try a different search or filter."
                            : "Money movements appear here when they are recorded."
                        }
                      />
                    </td>
                  </tr>
                ) : (
                  data.entries.map((entry) => (
                    <Fragment key={entry.key}>
                      <tr className="border-b border-border align-top">
                        <td className="hidden whitespace-nowrap px-3 py-4 text-muted-foreground sm:table-cell">
                          {new Date(entry.at).toLocaleDateString("en-GB", {
                            day: "2-digit",
                            month: "short",
                            year: "numeric",
                            timeZone: "UTC",
                          })}
                        </td>
                        <td className="max-w-xs px-3 py-4">
                          <p className="font-medium">
                            {ledgerLabels[entry.type] ?? entry.type}
                          </p>
                          <p className="mt-1 break-words text-xs text-muted-foreground">
                            {entry.description}
                            {entry.reversedAt
                              ? " · Reversed"
                              : entry.reversalOfId
                                ? " · Reversal"
                                : ""}
                          </p>
                          <div className="mt-3 space-y-1 sm:hidden">
                            <p className="font-semibold tabular-nums">
                              {entry.amount >= 0 ? "+" : "−"}
                              {accountMoney(
                                Math.abs(entry.amount),
                                entry.currency,
                              )}
                            </p>
                            <p className="text-xs text-muted-foreground">
                              {entry.account ?? "Unassigned"} ·{" "}
                              {new Date(entry.at).toLocaleDateString("en-GB")}
                            </p>
                            {entry.sourceCurrency &&
                              entry.sourceCurrency !== entry.currency && (
                                <p className="text-xs">
                                  Original:{" "}
                                  {accountMoney(
                                    entry.sourceAmount ?? 0,
                                    entry.sourceCurrency,
                                  )}
                                </p>
                              )}
                          </div>
                        </td>
                        <td className="hidden px-3 py-4 sm:table-cell">
                          <p>{entry.account ?? "Unassigned"}</p>
                          <p className="mt-1 text-xs text-muted-foreground">
                            {entry.currency}
                            {!entry.account && " · legacy record"}
                          </p>
                        </td>
                        <td className="hidden whitespace-nowrap px-3 py-4 text-right tabular-nums sm:table-cell">
                          {entry.amount > 0
                            ? accountMoney(entry.amount, entry.currency)
                            : "—"}
                        </td>
                        <td className="hidden whitespace-nowrap px-3 py-4 text-right tabular-nums sm:table-cell">
                          {entry.amount < 0
                            ? accountMoney(-entry.amount, entry.currency)
                            : "—"}
                        </td>
                        <td className="px-3 py-3 text-right">
                          <Button
                            size="sm"
                            variant="ghost"
                            aria-expanded={expanded === entry.key}
                            onClick={() =>
                              setExpanded(
                                expanded === entry.key ? null : entry.key,
                              )
                            }
                          >
                            {expanded === entry.key ? "Hide" : "Details"}
                          </Button>
                        </td>
                      </tr>
                      {expanded === entry.key && (
                        <tr className="border-b border-border">
                          <td colSpan={6} className="p-4">
                            <DetailGrid
                              columns={3}
                              items={[
                                {
                                  label: "Reference",
                                  value: entry.reference || "—",
                                },
                                ...(entry.sourceCurrency
                                  ? [
                                      {
                                        label: "Original amount",
                                        value: accountMoney(
                                          entry.sourceAmount ?? 0,
                                          entry.sourceCurrency,
                                        ),
                                      },
                                      {
                                        label: "BDT exchange rate",
                                        value: entry.sourceFxRate ?? "—",
                                      },
                                    ]
                                  : []),
                                ...(entry.baseAmount !== undefined
                                  ? [
                                      {
                                        label: "Booked amount",
                                        value: accountMoney(
                                          entry.baseAmount,
                                          "BDT",
                                        ),
                                      },
                                    ]
                                  : []),
                              ]}
                            />
                            <div className="mt-4 flex flex-wrap gap-4 text-sm">
                              {entry.canReverse && (
                                <ReverseEntry
                                  kind={entry.reversalKind}
                                  id={entry.recordId}
                                  onChanged={reload}
                                />
                              )}
                              {entry.shipmentCode && (
                                <Link
                                  className="font-medium text-primary underline"
                                  to={`/shipments/${entry.shipmentCode}`}
                                >
                                  Shipment {entry.shipmentCode}
                                </Link>
                              )}
                              {entry.flightCode && (
                                <Link
                                  className="font-medium text-primary underline"
                                  to={`/flights/${entry.flightCode}`}
                                >
                                  Flight {entry.flightCode}
                                </Link>
                              )}
                              {entry.supplierCode && (
                                <Link
                                  className="font-medium text-primary underline"
                                  to={`/suppliers/${entry.supplierCode}`}
                                >
                                  Customer {entry.supplierCode}
                                </Link>
                              )}
                            </div>
                          </td>
                        </tr>
                      )}
                    </Fragment>
                  ))
                )}
              </tbody>
            </table>
          </div>
          {!compact && (
            <>
              <div className="space-y-2 border-b border-border py-4 text-xs text-muted-foreground">
                {data?.totals
                  .filter((total) => total.moneyIn || total.moneyOut)
                  .map((total) => (
                    <div
                      key={total.currency}
                      className="flex flex-wrap justify-between gap-2"
                    >
                      <span>{total.currency} totals for these filters</span>
                      <span className="tabular-nums text-foreground">
                        In: {accountMoney(total.moneyIn, total.currency)} · Out:{" "}
                        {accountMoney(total.moneyOut, total.currency)}
                      </span>
                    </div>
                  ))}
                <p>
                  Transfers appear on both accounts. Totals are separate for
                  each currency.
                </p>
              </div>
              <div className="flex flex-wrap items-center justify-between gap-3 pt-4 text-xs text-muted-foreground">
                <span>
                  {data?.total
                    ? `${(page - 1) * 25 + 1}–${Math.min(page * 25, data.total)} of ${data.total} transactions`
                    : "0 transactions"}
                </span>
                <div className="flex items-center gap-3">
                  <Button
                    variant="secondary"
                    size="icon"
                    aria-label="Previous ledger page"
                    disabled={page <= 1 || loading}
                    onClick={() => setPage((current) => current - 1)}
                  >
                    <ChevronLeft size={16} />
                  </Button>
                  <span>
                    Page {page} of {pages}
                  </span>
                  <Button
                    variant="secondary"
                    size="icon"
                    aria-label="Next ledger page"
                    disabled={!data || page * 25 >= data.total || loading}
                    onClick={() => setPage((current) => current + 1)}
                  >
                    <ChevronRight size={16} />
                  </Button>
                </div>
              </div>
            </>
          )}
        </>
      )}
    </Panel>
  );
}
