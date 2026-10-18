import { Link, useNavigate } from "react-router-dom";
import {
  ArrowRight,
  Package,
  ClipboardCheck,
  ListTodo,
  Plus,
} from "lucide-react";
import { useFetch } from "@/state/useFetch";
import type { AdminOverview } from "@/api/types";
import {
  PageHeader,
  SummaryStrip,
  RecordList,
  EmptyState,
} from "@/components/Workspace";
import { Panel, DetailGrid } from "@/components/DesignSystem";
import { Button } from "@/components/beui/button";
import { StatusChip, ErrorBlock, LoadingBlock, Chip } from "@/components/ui";
import {
  fmtBdt,
  fmtDate,
  PAY_CHIP,
  PAY_LABEL,
  displayFlightCode,
} from "@/lib/format";

export function Overview() {
  const navigate = useNavigate();
  const { data, error } = useFetch<AdminOverview>("/dashboard/overview");
  if (error) return <ErrorBlock message={error} />;
  if (!data) return <LoadingBlock label="Loading dashboard…" />;
  const active = data.activeShipments;
  const stageCount = (statuses: string[]) =>
    statuses.reduce(
      (total, status) => total + (data.stageCounts?.[status] ?? 0),
      0,
    );
  const recent = [...active]
    .sort((a, b) => b.date.localeCompare(a.date))
    .slice(0, 8);
  const stages = [
    { label: "Booked", key: "booked", statuses: ["pending"] },
    {
      label: "China hub",
      key: "china",
      statuses: ["received_cn_hub", "ready_for_shipment"],
    },
    {
      label: "In transit",
      key: "transit",
      statuses: ["in_transit", "customs_cleared"],
    },
    {
      label: "Dhaka & delivery",
      key: "delivery",
      statuses: ["received_bd_hub", "ready_for_last_mile", "out_for_delivery"],
    },
    {
      label: "Delivered",
      key: "delivered",
      statuses: ["delivered"],
    },
  ];
  const next = data.nextFlight;
  return (
    <div className="space-y-6">
      <PageHeader
        title="Dashboard"
        description="A clear view of today's operations and the work to do next."
        actions={
          <Button onClick={() => navigate("/shipments/new")}>
            <Plus size={16} />
            New shipment
          </Button>
        }
      />
      <SummaryStrip
        items={[
          {
            label: "Active shipments",
            value: data.activeShipmentCount,
            description: "Currently in progress",
          },
          {
            label: "Customer balance due",
            value: fmtBdt(data.unpaid),
            description: "All outstanding shipments",
          },
          {
            label: "Receipts to review",
            value: data.reviewCount,
            description: "Awaiting your confirmation",
          },
          {
            label: "Available funds",
            value: fmtBdt(data.cash.worth),
            description: "All accounts · BDT equivalent",
          },
        ]}
      />
      <div className="dashboard-grid">
        <div className="min-w-0 space-y-6">
          <section aria-labelledby="active-shipments-heading">
            <div className="mb-4 flex items-center justify-between gap-4">
              <h2
                id="active-shipments-heading"
                className="text-lg font-semibold"
              >
                Active shipments
              </h2>
              <Link to="/shipments?view=active" className="text-action">
                View all
              </Link>
            </div>
            <RecordList
              rows={recent}
              recordKey={(row) => row.code}
              href={(row) => "/shipments/" + row.code}
              searchText={(row) =>
                [
                  row.code,
                  row.supplierName,
                  row.supplierCode,
                  row.description,
                ].join(" ")
              }
              placeholder="Search recent shipments…"
              emptyTitle="No active shipments"
              emptyDescription="Create a shipment to start planning your next delivery."
              columns={[
                {
                  label: "Shipment",
                  render: (row) => (
                    <div>
                      {row.code}
                      <p className="mt-1 text-xs font-normal text-muted-foreground">
                        {row.supplierName || row.supplierCode}
                      </p>
                    </div>
                  ),
                },
                {
                  label: "Status",
                  render: (row) => (
                    <StatusChip
                      index={row.statusIndex}
                      label={row.statusLabel}
                    />
                  ),
                },
                {
                  label: "Payment",
                  render: (row) => (
                    <Chip colors={PAY_CHIP[row.payStatus] ?? PAY_CHIP.unpaid!}>
                      {PAY_LABEL[row.payStatus]}
                    </Chip>
                  ),
                },
                {
                  label: "Bill · BDT",
                  align: "right",
                  render: (row) => fmtBdt(row.billAmount),
                },
              ]}
            />
          </section>
          <Panel
            title="Financial activity"
            description={data.weekLabel + " · All totals in BDT"}
            actions={
              <Link to="/finance" className="text-action">
                Open finance
              </Link>
            }
          >
            <DetailGrid
              columns={3}
              items={[
                {
                  label: "Received this week",
                  value: (
                    <strong className="text-lg font-semibold">
                      {fmtBdt(data.received)}
                    </strong>
                  ),
                },
                {
                  label: "Paid out this week",
                  value: (
                    <strong className="text-lg font-semibold">
                      {fmtBdt(data.expenses + data.refunded)}
                    </strong>
                  ),
                },
                {
                  label: "Costs still to pay",
                  value: (
                    <strong className="text-lg font-semibold">
                      {fmtBdt(data.payables)}
                    </strong>
                  ),
                },
              ]}
            />
            <p className="mt-6 border-t border-border pt-4 text-xs text-muted-foreground">
              Current conversion rate: 1 CNY = {data.rate} BDT. Recorded
              transactions retain their saved rates.
            </p>
          </Panel>
        </div>
        <aside className="min-w-0 space-y-6">
          <Panel title="Work to do">
            <div className="action-list">
              {[
                {
                  to: "/review",
                  icon: ClipboardCheck,
                  title: "Verify payments",
                  description: "Review submitted receipts",
                  count: data.reviewCount,
                },
                {
                  to: "/shipments?view=booked",
                  icon: Package,
                  title: "Receive cargo",
                  description: "Awaiting China hub intake",
                  count: stageCount(["pending"]),
                },
                {
                  to: "/shipments?stage=5",
                  icon: Package,
                  title: "Weigh and pack",
                  description: "Cargo at the Dhaka hub",
                  count: stageCount(["received_bd_hub"]),
                },
                {
                  to: "/todos",
                  icon: ListTodo,
                  title: "Follow up on tasks",
                  description: "Open operational tasks",
                  count: data.openTodoCount,
                },
              ].map((item) => (
                <Link to={item.to} key={item.title}>
                  <item.icon size={18} />
                  <div>
                    <strong>{item.title}</strong>
                    <p>{item.description}</p>
                  </div>
                  <b>{item.count}</b>
                </Link>
              ))}
            </div>
          </Panel>
          <Panel title="Next departure">
            {next ? (
              <div className="space-y-5">
                <Link
                  to={"/flights/" + next.code}
                  className="text-lg font-semibold text-primary"
                >
                  {displayFlightCode(next.code)}
                </Link>
                <DetailGrid
                  items={[
                    { label: "Departure date", value: fmtDate(next.date) },
                    {
                      label: "Booked capacity",
                      value: next.bookedKg + " / " + next.spaceKg + " kg",
                    },
                  ]}
                />
                <Link
                  className="flex items-center justify-between border-t border-border pt-4 text-sm text-primary"
                  to={"/flights/" + next.code}
                >
                  Manage flight
                  <ArrowRight size={16} />
                </Link>
              </div>
            ) : (
              <EmptyState
                title="No upcoming departure"
                description="Add a flight to plan the next shipment."
                action={
                  <Link to="/flights" className="text-action">
                    Open flights
                  </Link>
                }
              />
            )}
          </Panel>
        </aside>
      </div>
      <section className="dashboard-queue">
        <header>
          <h2>Shipment status</h2>
          <span className="text-sm text-muted-foreground">
            Select a stage to open its records
          </span>
        </header>
        <nav aria-label="Shipment status filters">
          {stages.map((stage) => (
            <Link key={stage.key} to={"/shipments?view=" + stage.key}>
              <span>{stage.label}</span>
              <strong>{stageCount(stage.statuses)}</strong>
            </Link>
          ))}
        </nav>
      </section>
    </div>
  );
}
