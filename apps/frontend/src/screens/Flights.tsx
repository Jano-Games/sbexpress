import { useState } from "react";
import { FileUp, Plus } from "lucide-react";
import {
  PageHeader,
  PageTabs,
  RecordList,
  SummaryStrip,
  usePageSection,
} from "@/components/Workspace";
import { useFetch } from "@/state/useFetch";
import type { FlightSummary } from "@/api/types";
import { Button } from "@/components/beui/button";
import {
  Chip,
  ErrorBlock,
  FlightCode,
  LoadingBlock,
  ProgressBar,
} from "@/components/ui";
import { AddFlightModal } from "@/modals/AddFlightModal";
import { ImportTicketModal } from "@/modals/ImportTicketModal";
import { FLIGHT_CHIP, fmtBdt, fmtDate } from "@/lib/format";

export function Flights() {
  const { data, error, loading, reload } = useFetch<{
    flights: FlightSummary[];
  }>("/flights");
  const [adding, setAdding] = useState(false);
  const [importing, setImporting] = useState(false);
  const [view, setView] = usePageSection(
    "all",
    ["all", "upcoming", "departed", "completed"],
    "view",
  );

  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  const upcoming = data.flights.filter(
    (flight) => flight.status === "upcoming",
  );

  return (
    <div className="space-y-5">
      <PageHeader
        title="Flights"
        description="Manage flight schedules, cargo capacity and flyer payments."
        actions={
          <div className="flex flex-wrap gap-2">
            <Button variant="secondary" onClick={() => setImporting(true)}>
              <FileUp size={16} />
              Import ticket
            </Button>
            <Button onClick={() => setAdding(true)}>
              <Plus size={16} />
              Add flight
            </Button>
          </div>
        }
      />
      <SummaryStrip
        items={[
          { label: "All flights", value: data.flights.length },
          { label: "Upcoming", value: upcoming.length },
          {
            label: "Upcoming available capacity",
            value: `${upcoming.reduce((total, flight) => total + Math.max(0, flight.leftKg), 0)} kg`,
          },
          {
            label: "Shipments assigned",
            value: data.flights.reduce(
              (total, flight) => total + flight.shipmentCount,
              0,
            ),
          },
        ]}
      />
      <RecordList
        views={
          <PageTabs
            value={view}
            onChange={setView}
            items={[
              { value: "all", label: "All flights" },
              { value: "upcoming", label: "Upcoming" },
              { value: "departed", label: "Departed" },
              { value: "completed", label: "Completed" },
            ]}
          />
        }
        rows={data.flights.filter(
          (flight) => view === "all" || flight.status === view,
        )}
        recordKey={(flight) => flight.code}
        href={(flight) => `/flights/${encodeURIComponent(flight.code)}`}
        searchText={(flight) =>
          `${flight.code} ${flight.date} ${flight.via} ${flight.flyers.join(" ")} ${flight.statusLabel}`
        }
        placeholder="Search flight, route, flyer or date"
        emptyTitle="No flights in this view"
        emptyDescription="Choose another status, or add a flight to start planning cargo."
        columns={[
          {
            label: "Flight / route",
            render: (flight) => (
              <div>
                <FlightCode code={flight.code} />
                <p className="mt-1 text-xs font-normal text-muted-foreground">
                  {flight.via || "Route not specified"}
                </p>
              </div>
            ),
          },
          {
            label: "Departure",
            render: (flight) => (
              <div>
                {fmtDate(flight.date)}
                <p className="mt-1 text-xs text-muted-foreground">
                  {flight.depTime}
                </p>
              </div>
            ),
          },
          {
            label: "Flyers",
            render: (flight) => flight.flyers.join(", ") || "Unassigned",
          },
          {
            label: "Cargo capacity",
            render: (flight) => (
              <div className="min-w-32">
                <p>
                  {flight.bookedKg} / {flight.spaceKg} kg
                </p>
                <ProgressBar
                  className="my-2"
                  height={4}
                  pct={
                    flight.spaceKg > 0
                      ? (flight.bookedKg / flight.spaceKg) * 100
                      : 0
                  }
                  danger={flight.bookedKg > flight.spaceKg}
                />
                <p className="text-xs text-muted-foreground">
                  {flight.leftKg} kg available
                </p>
              </div>
            ),
          },
          {
            label: "Status",
            render: (flight) => (
              <Chip
                colors={FLIGHT_CHIP[flight.status] ?? FLIGHT_CHIP.completed!}
              >
                {flight.statusLabel}
              </Chip>
            ),
          },
          {
            label: "Flyer due (BDT)",
            align: "right",
            render: (flight) => fmtBdt(flight.flyerDue),
          },
          {
            label: "Shipments",
            align: "right",
            render: (flight) => flight.shipmentCount,
            mobile: false,
          },
        ]}
      />
      <AddFlightModal
        open={adding}
        onClose={() => setAdding(false)}
        onDone={() => void reload()}
      />
      <ImportTicketModal
        open={importing}
        onClose={() => setImporting(false)}
        onDone={() => void reload()}
      />
    </div>
  );
}
