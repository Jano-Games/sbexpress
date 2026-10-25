import {
  Panel,
  FormGrid,
  FormActions,
  SectionNotice,
  DetailGrid,
} from "@/components/DesignSystem";
import { MoneyInput, useMoneyEntry } from "@/components/MoneyInput";
import { displayFlightCode } from "@/lib/format";
import { PageHeader, PageTabs, usePageSection } from "@/components/Workspace";
import { FlyerSettlement } from "@/components/FlyerSettlement";
import { useEffect, useMemo, useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { api } from "@/api/client";
import { useFetch } from "@/state/useFetch";
import type { FlightDetail as Detail, FlightLookup, Flyer } from "@/api/types";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import { useToast } from "@/components/beui/toast";
import {
  BillFigure,
  Chip,
  ErrorBlock,
  LoadingBlock,
  ProgressBar,
  StatusChip,
} from "@/components/ui";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { NewShipmentModal } from "@/modals/NewShipmentModal";
import { AddFlyerModal } from "@/modals/AddFlyerModal";
import { AddFlightModal } from "@/modals/AddFlightModal";
import {
  FLIGHT_CHIP,
  fmtBdt,
  fmtDate,
  fmtKg,
  supplierLabel,
} from "@/lib/format";

type LiveInfo = { status: string; sample?: boolean };

function LiveBadge({ info }: { info?: LiveInfo }) {
  const available = info && !/unknown|not found/i.test(info.status);
  return (
    <span className="text-xs text-muted-foreground">
      {available ? info.status : "Unavailable"}
      {available && info.sample ? " (sample)" : ""}
    </span>
  );
}

const liveKey = (code: string, date: string | null | undefined) =>
  `${code}|${date ?? ""}`;

// Match the backend schedule lookup: airline designator followed by 1–4 digits.
const flightNumberPattern = /^(?:[A-Z]{2}|[A-Z]\d|\d[A-Z]|[A-Z]{3})\d{1,4}$/;
const lookupFlightNumber = (bookingCode: string) => {
  const number = displayFlightCode(bookingCode)
    .toUpperCase()
    .replace(/\s+/g, "");
  return flightNumberPattern.test(number) ? number : null;
};

export function FlightDetail() {
  const paymentEntry = useMoneyEntry();
  const { code = "" } = useParams();
  const navigate = useNavigate();
  const { showToast } = useToast();
  const { data, error, loading, reload } = useFetch<{ flight: Detail }>(
    `/flights/${code}`,
  );
  const { data: flyersData, reload: reloadFlyers } = useFetch<{
    flyers: Flyer[];
  }>("/flyers");

  const [section, setSection] = usePageSection("operations", [
    "operations",
    "cargo",
    "flyers",
    "money",
  ]);
  const mutationLock = useRef(false);
  const [assignmentBusy, setAssignmentBusy] = useState(false);
  const [query, setQuery] = useState("");
  const [flyerAmount, setFlyerAmount] = useState("");
  const [payingFlyer, setPayingFlyer] = useState("");
  const [flyerMethod, setFlyerMethod] = useState("");
  const [payBusy, setPayBusy] = useState(false);
  const { data: accountData } = useFetch<{ accounts: { name: string }[] }>(
    "/finance?period=all",
  );
  const [addingShipment, setAddingShipment] = useState(false);
  const [registering, setRegistering] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [live, setLive] = useState<Record<string, LiveInfo>>({});

  // Live schedule status per segment from the provider (cached server-side).
  useEffect(() => {
    if (!data) return;
    const f = data.flight;
    const targets = f.legs.length
      ? f.legs.map((l) => ({ code: l.code, date: l.date ?? f.date }))
      : f.code.includes("+")
        ? []
        : [{ code: f.code, date: f.date }];
    const seen = new Set<string>();
    let active = true;
    for (const t of targets) {
      const flightNumber = lookupFlightNumber(t.code);
      if (!flightNumber || !/^\d{4}-\d{2}-\d{2}$/.test(t.date ?? "")) continue;
      const key = liveKey(t.code, t.date);
      if (seen.has(key)) continue;
      seen.add(key);
      api
        .get<FlightLookup>(
          `/flights/lookup?code=${encodeURIComponent(flightNumber)}&date=${t.date}`,
        )
        .then((r) => {
          if (!active) return;
          setLive((s) => ({
            ...s,
            [key]: {
              status: r.found ? (r.flight?.status ?? "Unknown") : "Not found",
              sample: r.sample,
            },
          }));
        })
        .catch(() => undefined);
    }
    return () => {
      active = false;
    };
  }, [data]);

  const suggestions = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q || !data || !flyersData) return [];
    const current = new Set(data.flight.flyers);
    return flyersData.flyers
      .filter((f) => !current.has(f.name) && f.name.toLowerCase().includes(q))
      .slice(0, 5);
  }, [query, data, flyersData]);

  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  const f = data.flight;
  const pct = (f.bookedKg / f.spaceKg) * 100;
  const showRegisterNew = query.trim().length > 1 && suggestions.length === 0;

  const changeFlyer = async (name: string, remove = false) => {
    if (mutationLock.current) return;
    mutationLock.current = true;
    setAssignmentBusy(true);
    try {
      if (remove)
        await api.delete(
          `/flights/${f.code}/flyers/${encodeURIComponent(name)}`,
        );
      else await api.post(`/flights/${f.code}/flyers`, { name });
      setQuery("");
      await reload();
      showToast({
        title: `${name} ${remove ? "removed from" : "added to"} ${f.code}`,
        status: "success",
      });
    } catch (error) {
      showToast({
        title: error instanceof Error ? error.message : "Failed",
        status: "error",
      });
    } finally {
      mutationLock.current = false;
      setAssignmentBusy(false);
    }
  };

  return (
    <div className="space-y-5">
      <Link
        to="/flights"
        className="inline-block text-sm text-muted-foreground hover:text-primary"
      >
        ← Flights
      </Link>
      <PageHeader
        title={displayFlightCode(f.code)}
        description={`${fmtDate(f.date)} · ${f.via}`}
        actions={
          <div className="flex flex-wrap gap-2">
            <Button variant="secondary" onClick={() => setEditOpen(true)}>
              Edit flight
            </Button>
            <Button
              variant="danger-outline"
              onClick={() => setDeleteOpen(true)}
            >
              Delete
            </Button>
            <Button onClick={() => setAddingShipment(true)}>
              Add shipment
            </Button>
          </div>
        }
      />
      {f.scheduleNeedsConfirmation && <SectionNotice tone="warning">The scheduled departure date has passed. Confirm the actual flight status in Edit flight; viewing this record does not mark it completed.</SectionNotice>}
      <Panel
        title="Flight overview"
        actions={
          <Chip colors={FLIGHT_CHIP[f.status] ?? FLIGHT_CHIP.completed!}>
            {f.statusLabel}
          </Chip>
        }
      >
        <DetailGrid
          columns={3}
          items={[
            { label: "Departure date", value: fmtDate(f.date) },
            { label: "Route", value: f.via || "Not specified" },
            { label: "Assigned flyers", value: f.flyers.length },
            {
              label: "Cargo booked",
              value: `${f.bookedKg} kg / ${f.spaceKg} kg`,
            },
            { label: "Remaining capacity", value: `${f.leftKg} kg` },
            { label: "Shipments", value: f.shipmentCount },
          ]}
        />
      </Panel>
      <PageTabs
        value={section}
        onChange={setSection}
        items={[
          { value: "operations", label: "Itinerary" },
          { value: "cargo", label: `Cargo (${f.shipmentCount})` },
          { value: "flyers", label: `Flyers (${f.flyers.length})` },
          { value: "money", label: "Costs & payments" },
        ]}
      />
      {section === "operations" && (
        <div className="space-y-5">
          <Panel
            title="Flight itinerary"
            description="Scheduled departure and arrival times for each segment."
          >
            {f.legs.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm">
                  <thead className="border-b border-border text-xs text-muted-foreground">
                    <tr>
                      <th className="py-3 pr-4 font-medium">Flight</th>
                      <th className="py-3 pr-4 font-medium">Date</th>
                      <th className="py-3 pr-4 font-medium">Departure</th>
                      <th className="py-3 pr-4 font-medium">Arrival</th>
                      <th className="py-3 font-medium">Live status</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {f.legs.map((leg, index) => (
                      <tr key={`${leg.code}-${index}`}>
                        <td className="py-4 pr-4 font-medium">{leg.code}{leg.source === "manual" ? " · Manual" : leg.source === "ticket" ? " · From ticket" : ""}</td>
                        <td className="py-4 pr-4 whitespace-nowrap">
                          {fmtDate(leg.date ?? f.date)}
                        </td>
                        <td className="py-4 pr-4">
                          <p>
                            {leg.depTime} · {leg.fromIata}
                          </p>
                          <p className="mt-1 text-xs text-muted-foreground">
                            {leg.fromCity}
                          </p>
                        </td>
                        <td className="py-4 pr-4">
                          <p>
                            {leg.arrTime} · {leg.toIata}
                          </p>
                          <p className="mt-1 text-xs text-muted-foreground">
                            {leg.toCity}
                          </p>
                        </td>
                        <td className="py-4">
                          <LiveBadge
                            info={live[liveKey(leg.code, leg.date ?? f.date)]}
                          />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <DetailGrid
                columns={3}
                items={[
                  { label: "Departure time", value: f.depTime },
                  { label: "Arrival time", value: f.arrTime },
                  {
                    label: "Live status",
                    value: <LiveBadge info={live[liveKey(f.code, f.date)]} />,
                  },
                ]}
              />
            )}
          </Panel>
          <Panel
            title="Cargo allowance"
            description="Weight capacity and additional device allowances."
          >
            <div className="mb-4 flex flex-wrap justify-between gap-3 text-sm">
              <span>
                {f.bookedKg} kg booked of {f.spaceKg} kg
              </span>
              <span
                className={
                  f.leftKg < 0 ? "text-danger" : "text-muted-foreground"
                }
              >
                {f.leftKg} kg available
              </span>
            </div>
            <ProgressBar pct={pct} danger={pct > 100} height={6} />
            <div className="mt-5">
              <DetailGrid
                columns={2}
                items={[
                  { label: "Mobile allowance", value: f.mobiles },
                  { label: "Laptop allowance", value: f.laptops },
                ]}
              />
            </div>
          </Panel>
        </div>
      )}
      {section === "cargo" && (
        <Panel
          title="Shipment manifest"
          actions={
            <Button variant="secondary" onClick={() => setAddingShipment(true)}>
              Add shipment
            </Button>
          }
        >
          {f.bookings.length ? (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-border text-xs text-muted-foreground">
                  <tr>
                    <th className="py-3 pr-4 font-medium">Shipment</th>
                    <th className="py-3 pr-4 font-medium">Customer / cargo</th>
                    <th className="py-3 pr-4 font-medium">Weight</th>
                    <th className="py-3 pr-4 font-medium">Status</th>
                    <th className="py-3 text-right font-medium">Bill (BDT)</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {f.bookings.map((booking) => (
                    <tr key={booking.code}>
                      <td className="py-4 pr-4">
                        <Link
                          className="font-medium text-primary"
                          to={`/shipments/${booking.code}`}
                        >
                          {booking.code}
                        </Link>
                      </td>
                      <td className="py-4 pr-4">
                        <p>
                          {supplierLabel(
                            booking.supplierCode,
                            booking.supplierName,
                          )}
                        </p>
                        <p className="mt-1 text-xs text-muted-foreground">
                          {booking.description}
                        </p>
                      </td>
                      <td className="py-4 pr-4 whitespace-nowrap">
                        {fmtKg(booking.bookedKg)}
                      </td>
                      <td className="py-4 pr-4">
                        <StatusChip
                          index={booking.statusIndex}
                          label={booking.statusLabel}
                        />
                      </td>
                      <td className="py-4 text-right">
                        <BillFigure
                          bill={booking.billAmount}
                          discount={booking.discountAmount}
                        />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p className="py-4 text-sm text-muted-foreground">
              No shipments assigned. Add a shipment to start this manifest.
            </p>
          )}
        </Panel>
      )}
      {section === "flyers" && (
        <div className="space-y-5">
          <Panel
            title="Assign a flyer"
            description="Find an existing flyer or register a new person."
            actions={
              <Button
                variant="secondary"
                disabled={assignmentBusy}
                onClick={() => setRegistering(true)}
              >
                Register flyer
              </Button>
            }
          >
            <Input
              label="Search flyers"
              placeholder="Search by name"
              value={query}
              onChange={setQuery}
              disabled={assignmentBusy}
            />
            {suggestions.length > 0 && (
              <ul className="mt-3 divide-y divide-border rounded-md border border-border">
                {suggestions.map((flyer) => (
                  <li
                    key={flyer.name}
                    className="flex flex-wrap items-center justify-between gap-3 p-3"
                  >
                    <div>
                      <p className="text-sm font-medium">{flyer.name}</p>
                      <p className="text-xs text-muted-foreground">
                        {flyer.bdPhone}
                      </p>
                    </div>
                    <Button
                      variant="secondary"
                      disabled={assignmentBusy}
                      onClick={() => void changeFlyer(flyer.name)}
                    >
                      Assign
                    </Button>
                  </li>
                ))}
              </ul>
            )}
            {showRegisterNew && (
              <p className="mt-3 text-sm text-muted-foreground">
                No unassigned flyer matches this name. Register a new flyer to
                continue.
              </p>
            )}
          </Panel>
          <Panel title="Assigned flyers">
            {f.flyerDetails.length ? (
              <div className="divide-y divide-border">
                {f.flyerDetails.map((flyer) => (
                  <div
                    key={flyer.name}
                    className="flex flex-wrap items-center justify-between gap-4 py-4 first:pt-0 last:pb-0"
                  >
                    <div>
                      <Link
                        className="text-sm font-medium text-primary"
                        to={`/flyers/${encodeURIComponent(flyer.name)}`}
                      >
                        {flyer.name}
                      </Link>
                      <p className="mt-1 text-sm text-muted-foreground">
                        {flyer.bdPhone}
                      </p>
                    </div>
                    <Button
                      variant="secondary"
                      disabled={assignmentBusy}
                      onClick={() => void changeFlyer(flyer.name, true)}
                    >
                      Remove assignment
                    </Button>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-muted-foreground">
                No flyers assigned to this flight.
              </p>
            )}
          </Panel>
        </div>
      )}
      {section === "money" && (
        <div className="space-y-5">
          <Panel
            title="Ticket payment"
            description="Ticket costs and reporting totals are shown in BDT."
            actions={
              f.ticketDue > 0 || f.ticketRefundDue > 0 ? (
                <Button onClick={() => setEditOpen(true)}>
                  {f.ticketDue > 0 ? "Pay ticket" : "Record refund"}
                </Button>
              ) : undefined
            }
          >
            <DetailGrid
              columns={3}
              items={[
                { label: "Ticket cost", value: fmtBdt(f.actualCost) },
                { label: "Paid", value: fmtBdt(f.ticketPaid) },
                { label: "Outstanding", value: fmtBdt(f.ticketDue) },
                { label: "Agency share", value: fmtBdt(f.agencyShare) },
                { label: "Flyer contribution", value: fmtBdt(f.fare) },
                {
                  label: "Refund to collect",
                  value: fmtBdt(f.ticketRefundDue),
                },
              ]}
            />
          </Panel>
          <Panel
            title="Flyer payments"
            description="Record money only after it arrives in the receiving account."
          >
            <DetailGrid
              columns={2}
              items={[
                {
                  label: "Received from flyers",
                  value: fmtBdt(f.flyerPaidAmount),
                },
                {
                  label: "Outstanding contribution",
                  value: fmtBdt(f.flyerDue),
                },
              ]}
            />
            {f.flyerDue > 0 && (
              <fieldset
                disabled={payBusy}
                className="mt-6 space-y-4 border-t border-border pt-5"
              >
                <FormGrid>
                  <label className="text-xs font-medium text-muted-foreground">
                    Paying flyer
                    <select
                      className="mt-2 h-10 w-full rounded-md border border-border bg-card px-3 text-sm text-foreground"
                      value={payingFlyer}
                      onChange={(e) => setPayingFlyer(e.target.value)}
                    >
                      <option value="">Select flyer</option>
                      {f.settlements.map((flyer) => (
                        <option key={flyer.name}>{flyer.name}</option>
                      ))}
                    </select>
                  </label>
                  <label className="text-xs font-medium text-muted-foreground">
                    Receiving account
                    <select
                      className="mt-2 h-10 w-full rounded-md border border-border bg-card px-3 text-sm text-foreground"
                      value={flyerMethod}
                      onChange={(e) => setFlyerMethod(e.target.value)}
                    >
                      <option value="">Select account</option>
                      {(accountData?.accounts ?? []).map((account) => (
                        <option key={account.name}>{account.name}</option>
                      ))}
                    </select>
                  </label>
                </FormGrid>
                <MoneyInput
                  entry={paymentEntry}
                  label="Amount received"
                  value={flyerAmount}
                  onChange={setFlyerAmount}
                />
                <FormActions>
                  <Button
                    disabled={
                      payBusy ||
                      !paymentEntry.valid ||
                      !flyerMethod ||
                      !payingFlyer
                    }
                    onClick={() =>
                      void (async () => {
                        if (mutationLock.current) return;
                        mutationLock.current = true;
                        setPayBusy(true);
                        try {
                          await api.post(`/flights/${code}/payments`, {
                            ...paymentEntry.meta,
                            amount: Number(flyerAmount),
                            method: flyerMethod,
                            flyerName: payingFlyer || undefined,
                          });
                          setFlyerAmount("");
                          await reload();
                          showToast({
                            title: "Flyer payment recorded",
                            status: "success",
                          });
                        } catch (error) {
                          showToast({
                            title:
                              error instanceof Error ? error.message : "Failed",
                            status: "error",
                          });
                        } finally {
                          mutationLock.current = false;
                          setPayBusy(false);
                        }
                      })()
                    }
                  >
                    {payBusy ? "Saving…" : "Record flyer payment"}
                  </Button>
                </FormActions>
              </fieldset>
            )}
          </Panel>
          <Panel title="Contribution allocation">
            <FlyerSettlement
              key={JSON.stringify(f.settlements)}
              code={code}
              rows={f.settlements}
              legacy={f.unallocatedFlyerPaid}
              onSaved={reload}
            />
          </Panel>
          <Panel
            title="Flight profitability"
            description="Income and operating costs in BDT."
          >
            <dl className="divide-y divide-border text-sm">
              {[
                ["Shipment charges", f.revenue],
                ["Flyer contribution", f.fare],
                ["Ticket cost", -f.actualCost],
                [
                  "Shipment costs",
                  -(
                    f.shipmentCosts.cnTransport +
                    f.shipmentCosts.courier +
                    f.shipmentCosts.customs +
                    f.shipmentCosts.other
                  ),
                ],
              ].map(([label, amount]) => (
                <div key={label} className="flex justify-between gap-4 py-3">
                  <dt className="text-muted-foreground">{label}</dt>
                  <dd className="shrink-0 font-medium">
                    {fmtBdt(Number(amount))}
                  </dd>
                </div>
              ))}
            </dl>
            <div className="mt-4 flex justify-between gap-4 border-t border-border pt-5 text-base font-semibold">
              <span>
                {f.margin >= 0 ? "Estimated profit" : "Estimated loss"}
              </span>
              <span className={f.margin >= 0 ? "text-success" : "text-danger"}>
                {fmtBdt(f.margin)}
              </span>
            </div>
          </Panel>
        </div>
      )}

      <NewShipmentModal
        open={addingShipment}
        onClose={() => setAddingShipment(false)}
        onDone={() => void reload()}
        lockedFlight={{ code: f.code, date: f.date }}
      />
      <AddFlyerModal
        open={registering}
        onClose={() => setRegistering(false)}
        prefillName={query.trim()}
        assignFlightCode={f.code}
        onDone={() => {
          setQuery("");
          void reload();
          void reloadFlyers();
        }}
      />
      <AddFlightModal
        open={editOpen}
        onClose={() => setEditOpen(false)}
        editing={f}
        onDone={(newCode) => {
          if (newCode && newCode !== f.code)
            navigate(`/flights/${newCode}`, { replace: true });
          else void reload();
        }}
      />
      <ConfirmDialog
        open={deleteOpen}
        onClose={() => setDeleteOpen(false)}
        title={`Delete flight ${f.code}?`}
        body={
          f.shipmentCount > 0
            ? `${f.code} still has ${f.shipmentCount} booking(s) — deleting will be refused until they are moved or deleted.`
            : "The flight and its flyer assignments are removed permanently."
        }
        onConfirm={async () => {
          try {
            await api.delete(`/flights/${f.code}`);
            showToast({ title: `${f.code} deleted`, status: "success" });
            navigate("/flights");
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
