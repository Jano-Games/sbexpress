import { Link } from "react-router-dom";
import { PageHeader, RecordList, SummaryStrip } from "@/components/Workspace";
import { Panel } from "@/components/DesignSystem";
import { useFetch } from "@/state/useFetch";
import type { HubOverview as HubData } from "@/api/types";
import { ErrorBlock, LoadingBlock, StatusChip } from "@/components/ui";
import { deltaLabel, fmtKg } from "@/lib/format";

export function HubOverview() {
  const { data, error } = useFetch<HubData>("/dashboard/hub");
  if (error) return <ErrorBlock message={error} />;
  if (!data) return <LoadingBlock />;

  return (
    <div className="space-y-5">
      <PageHeader
        title="Dhaka hub"
        description="Receive, weigh and pack shipments before arranging delivery."
        actions={
          <Link
            className="text-sm font-medium text-primary"
            to="/shipments?view=delivery"
          >
            View delivery shipments →
          </Link>
        }
      />
      <SummaryStrip
        items={[
          {
            label: "At the hub",
            value: data.atHubCount,
            description: "Shipments awaiting handling",
          },
          {
            label: "Incoming cargo",
            value: fmtKg(data.incoming.kg),
            description: `${data.incoming.count} shipments in transit`,
          },
          {
            label: "Open tasks",
            value: data.openTodoCount,
            description: "Operational follow-ups",
          },
        ]}
      />
      <Panel
        title="Processing sequence"
        description="Open a shipment below to complete its next handling step."
      >
        <ol className="grid gap-5 text-sm sm:grid-cols-3">
          <li>
            <h3 className="font-semibold">1. Receive & weigh</h3>
            <p className="mt-1 text-muted-foreground">
              Confirm the cargo has arrived and record its measured weight.
            </p>
          </li>
          <li>
            <h3 className="font-semibold">2. Confirm packing</h3>
            <p className="mt-1 text-muted-foreground">
              Check the contents and save the final package count.
            </p>
          </li>
          <li>
            <h3 className="font-semibold">3. Arrange delivery</h3>
            <p className="mt-1 text-muted-foreground">
              Enter the courier or pickup reference before dispatch.
            </p>
          </li>
        </ol>
      </Panel>
      <section aria-labelledby="hub-processing-title">
        <header className="mb-4">
          <h2 id="hub-processing-title" className="text-xl font-semibold">
            Ready for processing
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Shipments received at the Dhaka hub and awaiting handling.
          </p>
        </header>
        <RecordList
          rows={data.toProcess}
          recordKey={(shipment) => shipment.code}
          href={(shipment) =>
            `/shipments/${encodeURIComponent(shipment.code)}?section=handling`
          }
          searchText={(shipment) =>
            `${shipment.code} ${shipment.supplierCode} ${shipment.description}`
          }
          placeholder="Search shipment, customer code or cargo"
          emptyTitle="No shipments waiting"
          emptyDescription="New shipments appear here when they reach the Dhaka hub."
          columns={[
            { label: "Shipment", render: (shipment) => shipment.code },
            { label: "Customer", render: (shipment) => shipment.supplierCode },
            { label: "Contents", render: (shipment) => shipment.description },
            {
              label: "Weight",
              render: (shipment) => (
                <div>
                  {fmtKg(shipment.effectiveKg)}
                  {shipment.weightDelta !== null && (
                    <p className="mt-1 text-xs text-danger">
                      {deltaLabel(shipment.weightDelta)} difference
                    </p>
                  )}
                </div>
              ),
            },
            {
              label: "Status",
              render: (shipment) => (
                <StatusChip
                  index={shipment.statusIndex}
                  label={shipment.statusLabel}
                />
              ),
            },
          ]}
        />
      </section>
    </div>
  );
}
