import { useEffect, useState } from "react";
import { api } from "@/api/client";
import type { ShipmentDetail, FlightSummary } from "@/api/types";
import { useFetch } from "@/state/useFetch";
import { Panel, FormGrid, FormActions, SectionNotice } from "./DesignSystem";
import { Modal } from "./Modal";
import { Button } from "./beui/button";
import { Input } from "./beui/input";
const selectClass =
  "mt-2 h-10 w-full rounded-md border border-border bg-card px-3 text-sm";
const stages = [
  "pending",
  "received_cn_hub",
  "ready_for_shipment",
  "in_transit",
  "customs_cleared",
  "received_bd_hub",
  "ready_for_last_mile",
  "out_for_delivery",
  "delivered",
];
export function ShipmentOperations({
  shipment: s,
  admin,
  onChanged,
}: {
  shipment: ShipmentDetail;
  admin: boolean;
  onChanged: () => unknown;
}) {
  const [open, setOpen] = useState(false),
    [action, setAction] = useState("on_hold"),
    [reason, setReason] = useState(""),
    [stage, setStage] = useState(""),
    [flight, setFlight] = useState(""),
    [flyer, setFlyer] = useState(""),
    [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  const flights = useFetch<{ flights: FlightSummary[] }>(
    open && action === "assignment" ? "/flights" : null,
  );
  const picked = flights.data?.flights.find((f) => f.code === flight);
  const actions = [
    ...(s.exception ? [["resume", "Resume shipment"]] : []),
    ["on_hold", "Place on hold"],
    ["delivery_failed", "Record failed delivery"],
    ...(admin
      ? [
          ["cancelled", "Cancel shipment"],
          ["returned", "Record return"],
          ["lost", "Record loss"],
          ["stage", "Correct earlier checkpoint"],
          ["assignment", "Correct flight assignment"],
        ]
      : []),
  ];
  async function save() {
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      const path =
        action === "stage"
          ? "correct-stage"
          : action === "assignment"
            ? "assignment-correction"
            : "exception";
      await api.post(
        `/shipments/${encodeURIComponent(s.code)}/${path}`,
        action === "stage"
          ? { status: stage, reason }
          : action === "assignment"
            ? { flightCode: flight, flyerName: flyer, reason }
            : { type: action, reason },
      );
      setOpen(false);
      setReason("");
      await onChanged();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not update shipment");
    } finally {
      setBusy(false);
    }
  }
  return (
    <>
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-md border border-border bg-card p-4">
        <div>
          <strong className="text-sm">
            {s.exception
              ? `Shipment ${s.exception.replaceAll("_", " ")}`
              : "Exceptions & corrections"}
          </strong>
          <p className="mt-1 text-sm text-muted-foreground">
            {s.exception
              ? s.exceptionReason
              : "Hold, resolve a delivery problem, or correct a recorded checkpoint."}
          </p>
        </div>
        <Button
          variant="secondary"
          onClick={() => {
            setAction(s.exception ? "resume" : "on_hold");
            setError("");
            setOpen(true);
          }}
        >
          {s.exception ? "Resolve exception" : "Manage shipment"}
        </Button>
      </div>
      <Modal
        open={open}
        onClose={() => {
          if (!busy) setOpen(false);
        }}
      >
        <h2 data-dialog-title className="text-xl font-semibold">
          Manage shipment · {s.code}
        </h2>
        <form
          className="mt-5 space-y-4"
          onSubmit={(e) => {
            e.preventDefault();
            void save();
          }}
        >
          <label className="block text-sm">
            Action
            <select
              aria-label="Shipment action"
              className={selectClass}
              value={action}
              onChange={(e) => {
                setAction(e.target.value);
                setError("");
              }}
            >
              {actions.map(([v, l]) => (
                <option key={v} value={v}>
                  {l}
                </option>
              ))}
            </select>
          </label>
          {action === "stage" && (
            <label className="block text-sm">
              Earlier checkpoint
              <select
                aria-label="Earlier checkpoint"
                className={selectClass}
                value={stage}
                onChange={(e) => setStage(e.target.value)}
              >
                <option value="">Select checkpoint</option>
                {stages.slice(0, s.statusIndex).map((x) => (
                  <option key={x} value={x}>
                    {x.replaceAll("_", " ")}
                  </option>
                ))}
              </select>
            </label>
          )}
          {action === "assignment" && (
            <>
              <label className="block text-sm">
                Correct flight
                <select
                  aria-label="Correct flight"
                  className={selectClass}
                  value={flight}
                  onChange={(e) => {
                    setFlight(e.target.value);
                    setFlyer("");
                  }}
                >
                  <option value="">Choose flight</option>
                  {flights.data?.flights.map((f) => (
                    <option key={f.code} value={f.code}>
                      {f.code} · {f.date}
                    </option>
                  ))}
                </select>
              </label>
              <label className="block text-sm">
                Carrying flyer
                <select
                  aria-label="Correct carrying flyer"
                  className={selectClass}
                  value={flyer}
                  onChange={(e) => setFlyer(e.target.value)}
                >
                  <option value="">Choose flyer</option>
                  {picked?.flyers.map((n) => (
                    <option key={n}>{n}</option>
                  ))}
                </select>
              </label>
              {flights.error && (
                <SectionNotice tone="danger">{flights.error}</SectionNotice>
              )}
            </>
          )}
          <Input
            label={
              ["stage", "assignment", "resume"].includes(action)
                ? "Reason for correction / resolution"
                : "Reason shown to the customer"
            }
            value={reason}
            onChange={setReason}
            required
          />
          <SectionNotice>
            History is retained. Cancelling or returning a shipment does not
            automatically change its invoice or refund money. Review Billing
            separately.
          </SectionNotice>
          {error && (
            <div role="alert">
              <SectionNotice tone="danger">{error}</SectionNotice>
            </div>
          )}
          <FormActions>
            <Button
              variant="secondary"
              disabled={busy}
              onClick={() => setOpen(false)}
            >
              Close
            </Button>
            <Button
              type="submit"
              disabled={
                busy ||
                reason.trim().length < 3 ||
                (action === "stage" && !stage) ||
                (action === "assignment" && (!flight || !flyer))
              }
            >
              {busy ? "Saving…" : "Save update"}
            </Button>
          </FormActions>
        </form>
      </Modal>
    </>
  );
}
export function DeliveryBooking({
  shipment: s,
  onChanged,
}: {
  shipment: ShipmentDetail;
  onChanged: () => unknown;
}) {
  const [mode, setMode] = useState<"courier" | "pickup">("courier"),
    [courier, setCourier] = useState("Pathao"),
    [ref, setRef] = useState(""),
    [reason, setReason] = useState(""),
    [confirmation, setConfirmation] = useState(""),
    [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  useEffect(() => {
    setMode(s.lastMile?.mode ?? "courier");
    setCourier(s.lastMile?.courier ?? "Pathao");
    setRef(s.lastMile?.ref ?? "");
    setReason("");
  }, [s.code, s.lastMile?.ref, s.lastMile?.mode]);
  const blocked =
    !!s.exception || ![6, 7].includes(s.statusIndex) || !s.packedAt;
  async function act(action: string, body: unknown) {
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      await api.post(
        `/shipments/${encodeURIComponent(s.code)}/${action}`,
        body,
      );
      await onChanged();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not update delivery");
    } finally {
      setBusy(false);
    }
  }
  return (
    <Panel
      title="3. Delivery or hub collection"
      description="Save the booking first. Confirm dispatch or handover only when it actually happens."
    >
      <fieldset disabled={busy || blocked} className="space-y-4">
        <FormGrid>
          <label className="block text-sm">
            Delivery type
            <select
              aria-label="Delivery type"
              className={selectClass}
              value={mode}
              onChange={(e) => setMode(e.target.value as typeof mode)}
              disabled={s.statusIndex === 7}
            >
              <option value="courier">Courier delivery</option>
              <option value="pickup">Hub collection</option>
            </select>
          </label>
          {mode === "courier" && (
            <div>
              <Input
                label="Courier service"
                value={courier}
                onChange={setCourier}
                list="courier-options"
              />
              <datalist id="courier-options">
                <option value="Pathao" />
                <option value="Steadfast" />
                <option value="Sundarban" />
                <option value="SA Paribahan" />
              </datalist>
            </div>
          )}
          <Input
            label="Booking / pickup reference"
            value={ref}
            onChange={setRef}
            required
          />
        </FormGrid>
        {s.lastMile && (
          <Input
            label="Reason for changing the booking"
            value={reason}
            onChange={setReason}
          />
        )}
        <FormActions>
          <Button
            disabled={
              !ref.trim() ||
              (mode === "courier" && !courier.trim()) ||
              (!!s.lastMile && reason.trim().length < 3)
            }
            onClick={() =>
              void act("last-mile", {
                courier: mode === "pickup" ? "Hub pickup" : courier,
                ref,
                mode,
                ...(s.lastMile ? { reason } : {}),
              })
            }
          >
            {s.lastMile ? "Save booking correction" : "Save delivery booking"}
          </Button>
        </FormActions>
      </fieldset>
      {s.lastMile && (
        <div className="mt-5 space-y-4 border-t border-border pt-5">
          <p className="text-sm">
            Current booking:{" "}
            <strong>
              {s.lastMile.courier} · {s.lastMile.ref}
            </strong>
          </p>
          {s.statusIndex === 6 && s.lastMile.mode === "courier" && (
            <Button
              disabled={busy || blocked}
              onClick={() => void act("dispatch", {})}
            >
              Confirm courier dispatch
            </Button>
          )}
          {(s.statusIndex === 7 ||
            (s.statusIndex === 6 && s.lastMile.mode === "pickup")) && (
            <div className="space-y-3">
              <Input
                label={
                  s.lastMile.mode === "pickup"
                    ? "Collected by / handover confirmation"
                    : "Recipient / delivery confirmation"
                }
                value={confirmation}
                onChange={setConfirmation}
                disabled={busy || blocked}
              />
              <Button
                disabled={busy || blocked || confirmation.trim().length < 3}
                onClick={() => void act("handover", { confirmation })}
              >
                {s.lastMile.mode === "pickup"
                  ? "Confirm collection"
                  : "Confirm delivered"}
              </Button>
            </div>
          )}
        </div>
      )}
      {s.statusIndex === 8 && (
        <p className="mt-4 text-sm">
          Delivery / collection has been confirmed.
        </p>
      )}
      {error && (
        <div role="alert" className="mt-4">
          <SectionNotice tone="danger">{error}</SectionNotice>
        </div>
      )}
    </Panel>
  );
}
