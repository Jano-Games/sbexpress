import { useEffect, useRef, useState } from "react";
import { FileUp, Trash2 } from "lucide-react";
import { api } from "@/api/client";
import type { Flyer } from "@/api/types";
import {
  DetailGrid,
  FormActions,
  FormSection,
  SectionNotice,
} from "@/components/DesignSystem";
import { Modal } from "@/components/Modal";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import { useToast } from "@/components/beui/toast";
import { fmtDate } from "@/lib/format";
import {
  DIRECTION_LABEL,
  LEG_FIELDS,
  draftProblem,
  draftsFrom,
  flightBody,
  flyerPrefill,
  routeOf,
  type Draft,
  type LegField,
  type TicketImport,
} from "@/lib/ticketDrafts";
import { AddFlyerModal } from "./AddFlyerModal";

function readAsBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result).replace(/^data:[^,]*,/, ""));
    reader.onerror = () => reject(new Error("Could not read the file"));
    reader.readAsDataURL(file);
  });
}

export function ImportTicketModal({
  open,
  onClose,
  onDone,
}: {
  open: boolean;
  onClose: () => void;
  /** Called after at least one flight was created. */
  onDone: () => void;
}) {
  const { showToast } = useToast();
  const fileInput = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [reading, setReading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [result, setResult] = useState<TicketImport | null>(null);
  const [drafts, setDrafts] = useState<Draft[]>([]);
  const [flyers, setFlyers] = useState<Flyer[]>([]);
  const [flyer, setFlyer] = useState("");
  const [registering, setRegistering] = useState(false);

  useEffect(() => {
    if (!open) return;
    setFile(null);
    setResult(null);
    setDrafts([]);
    setFlyer("");
    setError("");
    if (fileInput.current) fileInput.current.value = "";
    api
      .get<{ flyers: Flyer[] }>("/flyers")
      .then((r) => setFlyers(r.flyers.filter((f) => !f.archivedAt)))
      .catch(() => undefined);
  }, [open]);

  const read = async () => {
    if (!file) return;
    setReading(true);
    setError("");
    try {
      const parsed = await api.post<TicketImport>("/flights/ticket", {
        file: await readAsBase64(file),
      });
      setResult(parsed);
      setDrafts(draftsFrom(parsed));
      setFlyer(parsed.flyerMatches[0]?.name ?? "");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not read the ticket.");
    } finally {
      setReading(false);
    }
  };

  const update = (key: string, patch: Partial<Draft>) =>
    setDrafts((rows) => rows.map((row) => (row.key === key ? { ...row, ...patch, error: "" } : row)));

  const updateLeg = (draftKey: string, legKey: string, field: LegField, value: string) =>
    setDrafts((rows) =>
      rows.map((row) =>
        row.key !== draftKey
          ? row
          : {
              ...row,
              error: "",
              legs: row.legs.map((leg) =>
                leg.key !== legKey
                  ? leg
                  : {
                      ...leg,
                      [field]: field === "code" || field.endsWith("Iata") ? value.toUpperCase().trim() : value,
                    },
              ),
            },
      ),
    );

  const pending = drafts.filter((draft) => !draft.saved);
  const problems = pending.map(draftProblem);

  const saveAll = async () => {
    if (!flyer) {
      setError("Choose the flyer travelling on this ticket.");
      return;
    }
    const firstProblem = problems.find(Boolean);
    if (firstProblem) {
      setError(firstProblem);
      return;
    }
    setSaving(true);
    setError("");
    let created = 0;
    for (const draft of pending) {
      try {
        await api.post("/flights", flightBody(draft, flyer));
        created += 1;
        setDrafts((rows) => rows.map((row) => (row.key === draft.key ? { ...row, saved: true } : row)));
      } catch (e) {
        const message = e instanceof Error ? e.message : "Could not save this flight.";
        setDrafts((rows) => rows.map((row) => (row.key === draft.key ? { ...row, error: message } : row)));
      }
    }
    setSaving(false);
    if (created) {
      showToast({ title: `${created} flight${created === 1 ? "" : "s"} added`, status: "success" });
      onDone();
    }
    if (created === pending.length) onClose();
  };

  return (
    <>
      <Modal open={open && !registering} onClose={() => !saving && onClose()} className="max-w-4xl">
        <header className="mb-6">
          <h2 data-dialog-title className="text-xl font-semibold">
            Import from ticket
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Upload an e-ticket PDF. Each journey on it becomes a flight you can edit or remove before saving. The file
            is read once and not stored.
          </p>
        </header>
        <fieldset disabled={saving} className="space-y-7">
          <FormSection title="Ticket PDF" description="Text-based PDFs from the agency work best; scanned images cannot be read.">
            <div className="flex flex-wrap items-center gap-3">
              <input
                ref={fileInput}
                type="file"
                accept="application/pdf,.pdf"
                aria-label="Ticket PDF"
                className="text-sm"
                onChange={(event) => {
                  setFile(event.target.files?.[0] ?? null);
                  setError("");
                }}
              />
              <Button variant="secondary" disabled={!file || reading} onClick={() => void read()}>
                <FileUp className="size-4" />
                {reading ? "Reading…" : result ? "Read again" : "Read ticket"}
              </Button>
            </div>
          </FormSection>

          {result && (
            <>
              <FormSection title="Ticket" description="Shown for checking only; it is not saved with the flights.">
                <DetailGrid
                  columns={3}
                  items={[
                    { label: "Passenger", value: result.ticket.passenger },
                    { label: "Airline PNR", value: result.ticket.pnr },
                    { label: "Ticket number", value: result.ticket.ticketNumber },
                    { label: "Issued", value: result.ticket.issuedOn ? fmtDate(result.ticket.issuedOn) : null },
                    { label: "Agency", value: result.ticket.agency },
                    { label: "Journeys", value: result.journeys.length },
                  ]}
                />
              </FormSection>

              <FormSection title="Flyer" description="The person carrying cargo on these flights.">
                <label className="block text-xs font-medium text-muted-foreground">
                  Flyer
                  <select
                    className="mt-2 h-10 w-full rounded-md border border-border bg-card px-3 text-sm text-foreground"
                    value={flyer}
                    onChange={(event) => setFlyer(event.target.value)}
                  >
                    <option value="">Choose a flyer</option>
                    {flyers.map((f) => (
                      <option key={f.name} value={f.name}>
                        {f.name}
                        {result.flyerMatches.some((m) => m.name === f.name) ? " · matches ticket" : ""}
                      </option>
                    ))}
                  </select>
                </label>
                {!result.flyerMatches.length && (
                  <div className="mt-3">
                    <SectionNotice tone="warning">
                      No flyer matches {result.ticket.passenger ?? "this passenger"}. Choose one, or register the flyer.
                    </SectionNotice>
                  </div>
                )}
                <Button className="mt-3" variant="secondary" onClick={() => setRegistering(true)}>
                  Register new flyer
                </Button>
              </FormSection>

              {drafts.map((draft, index) => (
                <section
                  key={draft.key}
                  className="rounded-md border border-border p-4"
                  aria-label={`Flight ${index + 1}`}
                >
                  <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <h3 className="font-semibold">
                        Flight {index + 1} · {DIRECTION_LABEL[draft.direction]}
                      </h3>
                      <p className="mt-1 text-sm text-muted-foreground">
                        {routeOf(draft.legs)} · {draft.legs[0] ? fmtDate(draft.legs[0].date) : "—"}
                      </p>
                    </div>
                    {draft.saved ? (
                      <span className="text-sm font-medium text-success">Saved</span>
                    ) : (
                      <Button
                        variant="danger-outline"
                        size="sm"
                        aria-label={`Remove flight ${index + 1}`}
                        onClick={() => setDrafts((rows) => rows.filter((row) => row.key !== draft.key))}
                      >
                        <Trash2 className="size-4" />
                        Remove flight
                      </Button>
                    )}
                  </div>
                  <fieldset disabled={draft.saved} className="space-y-4">
                    {draft.legs.map((leg, legIndex) => (
                      <div key={leg.key} className="rounded-md bg-muted p-3">
                        <div className="mb-2 flex items-center justify-between gap-3">
                          <p className="text-sm font-medium">Segment {legIndex + 1}</p>
                          {draft.legs.length > 1 && (
                            <button
                              type="button"
                              className="text-sm text-danger"
                              aria-label={`Remove segment ${leg.code}`}
                              onClick={() =>
                                update(draft.key, { legs: draft.legs.filter((row) => row.key !== leg.key) })
                              }
                            >
                              Remove
                            </button>
                          )}
                        </div>
                        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                          {LEG_FIELDS.map(([field, label, type]) => (
                            <Input
                              key={field}
                              label={label}
                              type={type}
                              value={leg[field]}
                              onChange={(value) => updateLeg(draft.key, leg.key, field, value)}
                            />
                          ))}
                        </div>
                      </div>
                    ))}
                    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
                      <Input
                        label="Cargo space (kg)"
                        type="number"
                        min={0}
                        value={draft.spaceKg}
                        onChange={(value) => update(draft.key, { spaceKg: value })}
                      />
                      <Input
                        label="Mobiles"
                        type="number"
                        min={0}
                        value={draft.mobiles}
                        onChange={(value) => update(draft.key, { mobiles: value })}
                      />
                      <Input
                        label="Laptops"
                        type="number"
                        min={0}
                        value={draft.laptops}
                        onChange={(value) => update(draft.key, { laptops: value })}
                      />
                      <Input
                        label="Ticket cost (BDT)"
                        inputMode="decimal"
                        placeholder="0.00"
                        value={draft.actualCost}
                        onChange={(value) => update(draft.key, { actualCost: value })}
                      />
                      <Input
                        label="Agency share (BDT)"
                        inputMode="decimal"
                        placeholder="0.00"
                        value={draft.agencyShare}
                        onChange={(value) => update(draft.key, { agencyShare: value })}
                      />
                    </div>
                  </fieldset>
                  {draft.error && (
                    <div className="mt-3">
                      <SectionNotice tone="danger">{draft.error}</SectionNotice>
                    </div>
                  )}
                </section>
              ))}
              {drafts.length > 1 && (
                <p className="text-sm text-muted-foreground">
                  A return ticket is paid once: enter its cost on one flight and leave the other at zero. No money
                  moves here — record the ticket payment from the flight later.
                </p>
              )}
              {!drafts.length && (
                <SectionNotice tone="warning">All flights were removed. Read the ticket again to start over.</SectionNotice>
              )}
            </>
          )}

          {error && <SectionNotice tone="danger">{error}</SectionNotice>}
          <FormActions>
            <Button variant="secondary" disabled={saving} onClick={onClose}>
              {drafts.some((draft) => draft.saved) ? "Close" : "Cancel"}
            </Button>
            {result && (
              <Button disabled={saving || !pending.length} onClick={() => void saveAll()}>
                {saving
                  ? "Saving…"
                  : `Create ${pending.length} flight${pending.length === 1 ? "" : "s"}`}
              </Button>
            )}
          </FormActions>
        </fieldset>
      </Modal>
      <AddFlyerModal
        open={registering}
        onClose={() => setRegistering(false)}
        prefillName={flyerPrefill(result?.ticket.passenger ?? null)}
        onDone={(name) => {
          setFlyers((current) => [
            ...current.filter((f) => f.name !== name),
            { name, bdPhone: "—" } as Flyer,
          ]);
          setFlyer(name);
        }}
      />
    </>
  );
}
