import { Link } from "react-router-dom";
import { useFetch } from "@/state/useFetch";
import { ErrorBlock, LoadingBlock } from "@/components/ui";
import { FormSection, Panel, SectionNotice } from "@/components/DesignSystem";
import { accountMoney } from "@/components/FinanceLedger";

type ReconciliationData = {
  accounts: {
    name: string;
    currency: string;
    balance: number;
    recordedNetMovement: number;
    impliedOpeningBalance: number;
  }[];
  missingPostings: { kind: string; reference: string; amount: number }[];
  shipmentDifferences: {
    code: string;
    allocatedPaid: number;
    ledgerPaid: number;
    difference: number;
  }[];
  note: string;
};

export function Reconciliation() {
  const { data, error, loading } = useFetch<ReconciliationData>(
    "/finance/reconciliation",
  );
  return (
    <Panel
      title="Historical reconciliation"
      description="Compare account balances and shipment payments with recorded ledger movements."
    >
      {error ? (
        <ErrorBlock message={error} />
      ) : loading || !data ? (
        <LoadingBlock />
      ) : (
        <div className="space-y-6">
          <SectionNotice
            tone={
              data.missingPostings.length || data.shipmentDifferences.length
                ? "warning"
                : "neutral"
            }
          >
            {data.missingPostings.length} entries are missing account snapshots.{" "}
            {data.shipmentDifferences.length} shipments have payment
            differences.{data.note && <p className="mt-2">{data.note}</p>}
          </SectionNotice>
          <FormSection
            title="Account balances"
            description="Each amount is shown in the account's currency."
          >
            <div className="overflow-x-auto">
              <table className="w-full min-w-[640px] text-left text-sm">
                <thead>
                  <tr className="border-y border-border bg-background text-xs text-muted-foreground">
                    <th className="p-3 font-medium">Account</th>
                    <th className="p-3 text-right font-medium">
                      Current balance
                    </th>
                    <th className="p-3 text-right font-medium">
                      Recorded movement
                    </th>
                    <th className="p-3 text-right font-medium">
                      Implied opening balance
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {data.accounts.map((account) => (
                    <tr key={account.name} className="border-b border-border">
                      <td className="p-3 font-medium">{account.name}</td>
                      <td className="whitespace-nowrap p-3 text-right tabular-nums">
                        {accountMoney(account.balance, account.currency)}
                      </td>
                      <td className="whitespace-nowrap p-3 text-right tabular-nums">
                        {accountMoney(
                          account.recordedNetMovement,
                          account.currency,
                        )}
                      </td>
                      <td className="whitespace-nowrap p-3 text-right tabular-nums">
                        {accountMoney(
                          account.impliedOpeningBalance,
                          account.currency,
                        )}
                      </td>
                    </tr>
                  ))}
                  {!data.accounts.length && (
                    <tr>
                      <td
                        className="p-6 text-center text-muted-foreground"
                        colSpan={4}
                      >
                        No accounts available.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </FormSection>
          <FormSection
            title="Shipment payment differences"
            description="All comparison amounts are in BDT."
          >
            {data.shipmentDifferences.length ? (
              <div className="overflow-x-auto">
                <table className="w-full min-w-[560px] text-left text-sm">
                  <thead>
                    <tr className="border-y border-border bg-background text-xs text-muted-foreground">
                      <th className="p-3 font-medium">Shipment</th>
                      <th className="p-3 text-right font-medium">
                        Allocated payments
                      </th>
                      <th className="p-3 text-right font-medium">
                        Ledger payments
                      </th>
                      <th className="p-3 text-right font-medium">Difference</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.shipmentDifferences.map((shipment) => (
                      <tr
                        key={shipment.code}
                        className="border-b border-border"
                      >
                        <td className="p-3">
                          <Link
                            className="font-medium text-primary underline"
                            to={`/shipments/${shipment.code}`}
                          >
                            {shipment.code}
                          </Link>
                        </td>
                        <td className="whitespace-nowrap p-3 text-right tabular-nums">
                          {accountMoney(shipment.allocatedPaid, "BDT")}
                        </td>
                        <td className="whitespace-nowrap p-3 text-right tabular-nums">
                          {accountMoney(shipment.ledgerPaid, "BDT")}
                        </td>
                        <td className="whitespace-nowrap p-3 text-right tabular-nums">
                          {accountMoney(shipment.difference, "BDT")}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p className="text-sm text-muted-foreground">
                No shipment payment differences found.
              </p>
            )}
          </FormSection>
          <FormSection
            title="Missing account snapshots"
            description="These historical entries do not include a complete account posting snapshot."
          >
            {data.missingPostings.length ? (
              <div className="overflow-x-auto">
                <table className="w-full min-w-[460px] text-left text-sm">
                  <thead>
                    <tr className="border-y border-border bg-background text-xs text-muted-foreground">
                      <th className="p-3 font-medium">Type</th>
                      <th className="p-3 font-medium">Reference</th>
                      <th className="p-3 text-right font-medium">
                        Amount · BDT
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.missingPostings.map((posting, index) => (
                      <tr
                        key={`${posting.reference}-${index}`}
                        className="border-b border-border"
                      >
                        <td className="p-3">{posting.kind}</td>
                        <td className="break-words p-3">
                          {posting.reference || "—"}
                        </td>
                        <td className="whitespace-nowrap p-3 text-right tabular-nums">
                          {accountMoney(posting.amount, "BDT")}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p className="text-sm text-muted-foreground">
                Every recorded entry has an account snapshot.
              </p>
            )}
          </FormSection>
        </div>
      )}
    </Panel>
  );
}
