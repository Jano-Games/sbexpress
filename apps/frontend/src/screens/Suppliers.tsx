import { useState } from "react";
import { Plus } from "lucide-react";
import { useFetch } from "@/state/useFetch";
import type { SupplierSummary } from "@/api/types";
import { Button } from "@/components/beui/button";
import { ErrorBlock, LoadingBlock } from "@/components/ui";
import {
  PageHeader,
  PageTabs,
  RecordList,
  SummaryStrip,
  usePageSection,
} from "@/components/Workspace";
import { AddSupplierModal } from "@/modals/AddSupplierModal";
import { fmtBdt, fmtKg } from "@/lib/format";

export function Suppliers() {
  const { data, error, loading, reload } = useFetch<{
    suppliers: SupplierSummary[];
  }>("/suppliers");
  const [adding, setAdding] = useState(false);
  const [view, setView] = usePageSection(
    "all",
    ["all", "instant", "monthly", "due"],
    "view",
  );
  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  const suppliers = data.suppliers;
  const outstanding = suppliers.filter((s) => s.balance > 0);

  return (
    <div>
      <PageHeader
        title="Customers"
        description="Customer records, shipping activity and billing accounts."
        actions={
          <Button onClick={() => setAdding(true)}>
            <Plus size={16} /> Add customer
          </Button>
        }
      />
      <SummaryStrip
        items={[
          { label: "Total customers", value: suppliers.length },
          {
            label: "Monthly accounts",
            value: suppliers.filter((s) => s.terms === "monthly").length,
          },
          { label: "Accounts with a balance", value: outstanding.length },
          {
            label: "Outstanding · BDT",
            value: fmtBdt(suppliers.reduce((sum, s) => sum + s.balance, 0)),
          },
        ]}
      />
      <RecordList
        views={
          <PageTabs
            value={view}
            onChange={setView}
            items={[
              { value: "all", label: "All customers" },
              { value: "due", label: "Balance due" },
              { value: "monthly", label: "Monthly billing" },
              { value: "instant", label: "Instant billing" },
            ]}
          />
        }
        rows={suppliers.filter(
          (s) =>
            view === "all" ||
            (view === "due" ? s.balance > 0 : s.terms === view),
        )}
        recordKey={(s) => s.code}
        href={(s) => `/suppliers/${encodeURIComponent(s.code)}`}
        searchText={(s) => `${s.code} ${s.name} ${s.phone} ${s.address}`}
        placeholder="Search name, customer code or phone"
        emptyTitle={
          suppliers.length ? "No customers in this view" : "No customers added"
        }
        emptyDescription={
          suppliers.length
            ? "Choose another billing filter to see your customers."
            : "Add a customer to create shipments and track their account."
        }
        columns={[
          {
            label: "Customer",
            render: (s) => (
              <div>
                {s.name}
                <p className="mt-1 text-xs font-normal text-muted-foreground">
                  {s.code}
                </p>
              </div>
            ),
          },
          { label: "Phone", render: (s) => s.phone },
          {
            label: "Billing",
            render: (s) => (s.terms === "monthly" ? "Monthly" : "Instant"),
          },
          { label: "Shipments", align: "right", render: (s) => s.orderCount },
          {
            label: "Weight shipped",
            align: "right",
            render: (s) => fmtKg(s.shippedKg),
            mobile: false,
          },
          {
            label: "Balance due · BDT",
            align: "right",
            render: (s) => (
              <span
                className={
                  s.balance > 0
                    ? "font-semibold text-danger"
                    : "text-muted-foreground"
                }
              >
                {fmtBdt(s.balance)}
              </span>
            ),
          },
        ]}
      />
      <AddSupplierModal
        open={adding}
        onClose={() => setAdding(false)}
        onDone={() => void reload()}
      />
    </div>
  );
}
