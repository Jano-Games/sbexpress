import { useState } from "react";
import { Link } from "react-router-dom";
import { useFetch } from "@/state/useFetch";
import { Panel } from "./DesignSystem";
import { Button } from "./beui/button";
import { ErrorBlock, LoadingBlock } from "./ui";
import { ReverseEntry } from "./ReverseEntry";
import { nativeMoney } from "./MoneyInput";
import { fmtBdt, fmtLogAt } from "@/lib/format";
type Entry = {
  id: string;
  label: string;
  kind: string;
  amount: number;
  sourceCurrency: string;
  sourceAmount: number;
  sourceFxRate: number;
  at: string;
  reference: string;
  shipmentCode: string | null;
  accountName: string | null;
  reason: string;
  canReverse: boolean;
  reversalKind: string;
};
export function SupplierActivity({
  code,
  onChanged,
}: {
  code: string;
  onChanged: () => unknown;
}) {
  const [page, setPage] = useState(1);
  const { data, error, loading, reload } = useFetch<{
    entries: Entry[];
    page: number;
    limit: number;
    total: number;
  }>(`/suppliers/${encodeURIComponent(code)}/activity?page=${page}`);
  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  return (
    <Panel
      title="Account activity"
      description="Payments, advances, applied credit and refunds. Original currency and saved BDT equivalents stay together."
    >
      <div className="data-table">
        <table>
          <thead>
            <tr>
              <th>Activity / reference</th>
              <th>Original amount</th>
              <th>BDT equivalent</th>
              <th>Shipment / account</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {data.entries.map((e) => (
              <tr key={e.id}>
                <td>
                  <strong>{e.label}</strong>
                  <div className="text-xs text-muted-foreground">
                    {fmtLogAt(e.at)}
                  </div>
                  <div className="max-w-xs break-words text-xs">
                    {e.reference}
                  </div>
                  {e.reason && (
                    <div className="max-w-xs text-xs text-muted-foreground">
                      {e.reason}
                    </div>
                  )}
                </td>
                <td className="whitespace-nowrap">
                  {nativeMoney(
                    Math.sign(e.amount) * Math.abs(e.sourceAmount),
                    e.sourceCurrency,
                  )}
                  {e.sourceCurrency === "CNY" && (
                    <div className="text-xs text-muted-foreground">
                      1 CNY = {e.sourceFxRate} BDT
                    </div>
                  )}
                </td>
                <td className="whitespace-nowrap">{fmtBdt(e.amount)}</td>
                <td>
                  {e.shipmentCode && (
                    <Link
                      className="text-primary"
                      to={`/shipments/${encodeURIComponent(e.shipmentCode)}?section=billing`}
                    >
                      {e.shipmentCode}
                    </Link>
                  )}
                  <div className="text-xs text-muted-foreground">
                    {e.accountName ?? "Credit balance"}
                  </div>
                </td>
                <td>
                  {e.canReverse && (
                    <ReverseEntry
                      kind={e.reversalKind}
                      id={e.id}
                      onChanged={async () => {
                        await reload();
                        await onChanged();
                      }}
                    />
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {!data.entries.length && (
        <p className="py-5 text-sm text-muted-foreground">
          No account activity yet.
        </p>
      )}
      <div className="mt-4 flex items-center justify-between gap-3 text-sm">
        <span>
          {data.total} entries · Page {page}
        </span>
        <div className="flex gap-2">
          <Button
            variant="secondary"
            disabled={page === 1}
            onClick={() => setPage((n) => n - 1)}
          >
            Previous
          </Button>
          <Button
            variant="secondary"
            disabled={page * data.limit >= data.total}
            onClick={() => setPage((n) => n + 1)}
          >
            Next
          </Button>
        </div>
      </div>
    </Panel>
  );
}
