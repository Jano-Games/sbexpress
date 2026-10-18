import { useEffect, useMemo } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Plus } from "lucide-react";
import {
  PageHeader,
  PageTabs,
  RecordList,
  SummaryStrip,
} from "@/components/Workspace";
import { useFetch } from "@/state/useFetch";
import { useAuth } from "@/state/auth";
import type { ShipmentRow } from "@/api/types";
import { Button } from "@/components/beui/button";
import {
  BillFigure,
  Chip,
  ErrorBlock,
  LoadingBlock,
  StatusChip,
  PIPELINE_LABELS,
} from "@/components/ui";
import {
  PAY_CHIP,
  PAY_LABEL,
  deltaLabel,
  fmtKg,
  fmtDate,
  fmtBdt,
} from "@/lib/format";

const views = [
  { value: "all", label: "All shipments" },
  { value: "active", label: "Active" },
  { value: "booked", label: "Booked" },
  { value: "china", label: "China hub" },
  { value: "transit", label: "In transit" },
  { value: "delivery", label: "Dhaka & delivery" },
  { value: "delivered", label: "Delivered" },
];

export function Shipments() {
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { data, error, loading } = useFetch<{ shipments: ShipmentRow[] }>(
    "/shipments",
  );
  const rawView = params.get("view") ?? "all";
  const view = views.some((item) => item.value === rawView) ? rawView : "all";
  const stage = params.get("stage") ?? "all";
  const supplier = params.get("supplier") ?? "all";
  const from = params.get("from") ?? "";
  const to = params.get("to") ?? "";
  const isAdmin = user?.role === "admin";

  function filter(key: string, value: string) {
    setParams((previous) => {
      const next = new URLSearchParams(previous);
      if (!value || value === "all") next.delete(key);
      else next.set(key, value);
      if (key === "view") next.delete("stage");
      return next;
    });
  }

  useEffect(() => {
    if (params.get("new") === "1")
      navigate("/shipments/new", { replace: true });
  }, [params, navigate]);

  const rows = useMemo(
    () =>
      (data?.shipments ?? []).filter((shipment) => {
        const index = shipment.statusIndex;
        if (view === "active" && index === 8) return false;
        if (view === "booked" && index !== 0) return false;
        if (view === "china" && (index < 1 || index > 2)) return false;
        if (view === "transit" && (index < 3 || index > 4)) return false;
        if (view === "delivery" && (index < 5 || index > 7)) return false;
        if (view === "delivered" && index !== 8) return false;
        return (
          (stage === "all" || index === Number(stage)) &&
          (supplier === "all" || shipment.supplierCode === supplier) &&
          (!from || shipment.date >= from) &&
          (!to || shipment.date <= to)
        );
      }),
    [data, view, stage, supplier, from, to],
  );

  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  const suppliers = [
    ...new Map(
      data.shipments.map((shipment) => [
        shipment.supplierCode,
        shipment.supplierName,
      ]),
    ).entries(),
  ];
  const hasFilters =
    stage !== "all" || supplier !== "all" || Boolean(from || to);

  return (
    <div className="space-y-5">
      <PageHeader
        title="Shipments"
        description="Book cargo and manage each shipment through delivery."
        actions={
          isAdmin ? (
            <Button onClick={() => navigate("/shipments/new")}>
              <Plus size={16} />
              New shipment
            </Button>
          ) : undefined
        }
      />
      <SummaryStrip
        items={[
          { label: "All shipments", value: data.shipments.length },
          {
            label: "Active",
            value: data.shipments.filter((shipment) => shipment.statusIndex < 8)
              .length,
          },
          {
            label: "Awaiting dispatch",
            value: data.shipments.filter(
              (shipment) => shipment.statusIndex <= 2,
            ).length,
          },
          {
            label: "Delivered",
            value: data.shipments.filter(
              (shipment) => shipment.statusIndex === 8,
            ).length,
          },
        ]}
      />
      <RecordList
        rows={rows}
        recordKey={(shipment) => shipment.code}
        href={(shipment) => `/shipments/${encodeURIComponent(shipment.code)}`}
        searchText={(shipment) =>
          `${shipment.code} ${shipment.supplierCode} ${shipment.supplierName ?? ""} ${shipment.description} ${shipment.categories.join(" ")} ${shipment.flightCode ?? ""}`
        }
        placeholder="Search shipment, customer, cargo or flight"
        emptyTitle="No shipments found"
        emptyDescription="Adjust the filters or create a new shipment."
        views={
          <PageTabs
            value={view}
            onChange={(value) => filter("view", value)}
            items={views}
          />
        }
        filters={
          <>
            <label className="text-xs font-medium text-muted-foreground">
              Status
              <select
                className="filter-control mt-1 block"
                value={stage}
                onChange={(event) => filter("stage", event.target.value)}
              >
                <option value="all">All statuses</option>
                {PIPELINE_LABELS.map((label, index) => (
                  <option value={String(index)} key={label}>
                    {label}
                  </option>
                ))}
              </select>
            </label>
            {isAdmin && (
              <label className="text-xs font-medium text-muted-foreground">
                Customer
                <select
                  className="filter-control mt-1 block"
                  value={supplier}
                  onChange={(event) => filter("supplier", event.target.value)}
                >
                  <option value="all">All customers</option>
                  {suppliers.map(([code, name]) => (
                    <option value={code} key={code}>
                      {name || code}
                    </option>
                  ))}
                </select>
              </label>
            )}
            <label className="text-xs font-medium text-muted-foreground">
              Booked from
              <input
                className="filter-control mt-1 block"
                type="date"
                value={from}
                onChange={(event) => filter("from", event.target.value)}
              />
            </label>
            <label className="text-xs font-medium text-muted-foreground">
              Booked to
              <input
                className="filter-control mt-1 block"
                type="date"
                min={from || undefined}
                value={to}
                onChange={(event) => filter("to", event.target.value)}
              />
            </label>
            {hasFilters && (
              <Button
                variant="secondary"
                onClick={() => setParams(view === "all" ? {} : { view })}
              >
                Clear filters
              </Button>
            )}
          </>
        }
        columns={[
          {
            label: "Shipment / booked",
            render: (shipment) => (
              <div>
                <span>{shipment.code}</span>
                <p className="mt-1 text-xs font-normal text-muted-foreground">
                  {fmtDate(shipment.date)}
                </p>
              </div>
            ),
          },
          {
            label: "Customer / cargo",
            render: (shipment) => (
              <div>
                <p className="font-medium">
                  {shipment.supplierName || shipment.supplierCode}
                </p>
                <p className="mt-1 text-xs text-muted-foreground">
                  {shipment.description ||
                    shipment.categories.join(", ") ||
                    "—"}
                </p>
              </div>
            ),
          },
          {
            label: "Flight",
            render: (shipment) => shipment.flightCode || "Unassigned",
            mobile: false,
          },
          {
            label: "Weight",
            render: (shipment) => (
              <div className="whitespace-nowrap">
                {shipment.effectiveKg > 0
                  ? fmtKg(shipment.effectiveKg)
                  : "Devices"}
                {shipment.weightDelta !== null && (
                  <p className="mt-1 text-xs text-danger">
                    {deltaLabel(shipment.weightDelta)}
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
          ...(isAdmin
            ? [
                {
                  label: "Payment",
                  render: (shipment: ShipmentRow) => (
                    <Chip
                      colors={PAY_CHIP[shipment.payStatus] ?? PAY_CHIP.unpaid!}
                    >
                      {PAY_LABEL[shipment.payStatus]}
                    </Chip>
                  ),
                },
                {
                  label: "Bill / due (BDT)",
                  align: "right" as const,
                  render: (shipment: ShipmentRow) => (
                    <div>
                      <BillFigure
                        bill={shipment.billAmount}
                        discount={shipment.discountAmount}
                      />
                      {shipment.dueAmount > 0 && (
                        <p className="mt-1 text-xs text-muted-foreground">
                          {fmtBdt(shipment.dueAmount)} due
                        </p>
                      )}
                    </div>
                  ),
                },
              ]
            : []),
        ]}
      />
    </div>
  );
}
