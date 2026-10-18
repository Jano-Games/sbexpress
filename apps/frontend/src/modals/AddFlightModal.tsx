import {
  FormSection,
  FormGrid,
  FormActions,
  DetailGrid,
  SectionNotice,
} from "@/components/DesignSystem";
import {
  CurrencyFields,
  useMoneyEntry,
  nativeMoney,
} from "@/components/MoneyInput";
import { useFetch } from "@/state/useFetch";
import { fmtBdt } from "@/lib/format";
import { useEffect, useMemo, useRef, useState } from "react";
import { Search } from "lucide-react";
import { api } from "@/api/client";
import type {
  Flyer,
  FlightLeg,
  FlightLookup,
  FlightSummary,
} from "@/api/types";
import { Modal } from "@/components/Modal";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import { useToast } from "@/components/beui/toast";
import { fmtDayMonth } from "@/lib/format";
import { AddFlyerModal } from "./AddFlyerModal";

const EMPTY = {
  code: "",
  date: "",
  agencyShare: "",
  actualCost: "",
  spaceKg: "44",
  mobiles: "2",
  laptops: "1",
  status: "upcoming",
};

export function AddFlightModal({
  open,
  onClose,
  onDone,
  lockedFlyer,
  editing,
}: {
  open: boolean;
  onClose: () => void;
  /** Receives the (possibly renamed) flight code after an edit. */
  onDone: (code?: string) => void;
  /** Pre-selected flyer when opened from a flyer page; more can be added. */
  lockedFlyer?: string;
  /** When set, the modal edits this flight instead of adding a new one. */
  editing?: FlightSummary;
}) {
  const entry = useMoneyEntry(undefined, false, open);
  const { showToast } = useToast();
  const {
    data: funds,
    error: fundsError,
    loading: fundsLoading,
    reload: reloadFunds,
  } = useFetch<{
    rate: number;
    accounts: { name: string; currency: string; balance: number }[];
  }>(open ? "/finance?period=all" : null);
  const [accountName, setAccountName] = useState("");
  const [submitError, setSubmitError] = useState("");
  const submitLock = useRef(false);
  const flyerInput = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [flyers, setFlyers] = useState<Flyer[]>([]);
  const [selected, setSelected] = useState<string[]>([]);
  const [query, setQuery] = useState("");
  const [pickerOpen, setPickerOpen] = useState(false);
  const [registering, setRegistering] = useState(false);
  const [form, setForm] = useState(EMPTY);
  const [lookupBusy, setLookupBusy] = useState(false);
  const [lookupInfo, setLookupInfo] = useState<string | null>(null);
  /** Amber banner when a search replaced an existing itinerary. */
  const [lookupWarn, setLookupWarn] = useState(false);
  /** The last successful lookup, ready to be appended as a leg. */
  const [lookupLeg, setLookupLeg] = useState<FlightLeg | null>(null);
  /** A multi-code search result waiting for the Update button. */
  const [pendingLegs, setPendingLegs] = useState<FlightLeg[] | null>(null);
  const [legs, setLegs] = useState<FlightLeg[]>([]);
  const [manual, setManual] = useState(false);
  const emptySegment = {
    code: "",
    date: "",
    fromIata: "",
    fromCity: "",
    toIata: "",
    toCity: "",
    depTime: "",
    arrTime: "",
  };
  const [segment, setSegment] = useState(emptySegment);

  useEffect(() => {
    if (!open) return;
    entry.restore(editing?.sourceCurrency ?? "BDT", editing?.sourceFxRate ?? 1);
    setAccountName("");
    setSubmitError("");
    setQuery("");
    setLookupInfo(null);
    setManual(false);
    setSegment(emptySegment);
    setLookupWarn(false);
    setLookupLeg(null);
    setPendingLegs(null);
    setLegs(editing ? editing.legs : []);
    if (editing) {
      setForm({
        code: editing.code,
        date: editing.date,
        agencyShare: String(
          Math.round(
            (editing.agencyShare / (editing.sourceFxRate || 1)) * 100,
          ) / 100 || "",
        ),
        actualCost: String(
          editing.sourceAmount ??
            editing.actualCost / (editing.sourceFxRate || 1),
        ),
        spaceKg: String(editing.spaceKg),
        mobiles: String(editing.mobiles),
        laptops: String(editing.laptops),
        status: editing.status,
      });
      return;
    }
    setForm(EMPTY);
    setSelected(lockedFlyer ? [lockedFlyer] : []);
    api
      .get<{ flyers: Flyer[] }>("/flyers")
      .then((r) => setFlyers(r.flyers))
      .catch(() => undefined);
    // Refreshing the same record must not overwrite the open draft.
    // Reinitialize only when opened again or switched to a different record.
  }, [open, lockedFlyer, editing?.code]);

  const suggestions = useMemo(() => {
    const q = query.trim().toLowerCase();
    return flyers
      .filter(
        (f) =>
          !selected.includes(f.name) &&
          (!q || f.name.toLowerCase().includes(q)),
      )
      .slice(0, 8);
  }, [flyers, selected, query]);

  const showRegister =
    query.trim().length > 1 &&
    !flyers.some((f) => f.name.toLowerCase() === query.trim().toLowerCase());

  const legFromLookup = (
    fl: NonNullable<FlightLookup["flight"]>,
  ): FlightLeg => ({
    code: fl.code,
    source: "schedule",
    date: form.date || null,
    fromIata: fl.from.iata ?? "",
    fromCity: fl.from.city ?? "",
    toIata: fl.to.iata ?? "",
    toCity: fl.to.city ?? "",
    depTime: fl.depTime ?? "—",
    arrTime: fl.arrTime ?? "—",
  });

  const searchSchedule = async () => {
    // "MU5850+MU2035" or "MU5850, MU2035" searches both, in the typed order.
    const codes = form.code
      .split(/[+,]/)
      .map((s) => s.trim())
      .filter(Boolean);
    if (!codes.length || !form.date) {
      showToast({ title: "Enter flight no and date first", status: "error" });
      return;
    }
    setLookupBusy(true);
    setLookupInfo(null);
    setLookupWarn(false);
    setLookupLeg(null);
    setPendingLegs(null);
    try {
      if (codes.length > 1) {
        // Multi-code: look them up sequentially and show the itinerary as a
        // preview — the Update button commits it (replacing existing legs,
        // since a re-search usually means a new date).
        const found: FlightLeg[] = [];
        const notes: string[] = [];
        let sample = false;
        for (const code of codes) {
          try {
            const r = await api.get<FlightLookup>(
              `/flights/lookup?code=${encodeURIComponent(code)}&date=${form.date}`,
            );
            if (r.found && r.flight) {
              found.push(legFromLookup(r.flight));
              notes.push(`${r.flight.code} ✓`);
              sample ||= Boolean(r.sample);
            } else {
              notes.push(`${code} not found`);
            }
          } catch {
            notes.push(`${code} lookup failed`);
          }
        }
        if (found.length) setPendingLegs(found);
        setLookupWarn(Boolean(found.length && legs.length));
        setLookupInfo(
          `${notes.join(" · ")}${sample ? " · sample data (no API key set)" : ""}`,
        );
        return;
      }

      const r = await api.get<FlightLookup>(
        `/flights/lookup?code=${encodeURIComponent(codes[0]!)}&date=${form.date}`,
      );
      if (!r.found || !r.flight) {
        setLookupInfo("No flight found for that number on that date.");
        return;
      }
      const fl = r.flight;
      setLookupLeg(legFromLookup(fl));
      const route = `${fl.from.iata ?? "?"} ${fl.from.city ?? ""} → ${fl.to.iata ?? "?"} ${fl.to.city ?? ""}`;
      setLookupInfo(
        `${fl.airline ?? "Unknown airline"} · ${route}${fl.status ? ` · ${fl.status}` : ""}${r.sample ? " · sample data (no API key set)" : ""}`,
      );
    } catch (e) {
      showToast({
        title: e instanceof Error ? e.message : "Lookup failed",
        status: "error",
      });
    } finally {
      setLookupBusy(false);
    }
  };

  const addLeg = () => {
    if (!lookupLeg) return;
    setLegs((l) => [...l, lookupLeg]);
    setLookupLeg(null);
    setLookupInfo(null);
    setForm((f) => ({ ...f, code: "" }));
  };

  /** Endpoint chain for display: CTU → CAN → DAC. */
  const routeLabel = useMemo(() => {
    if (!legs.length) return null;
    const stops = [
      legs[0]!.fromIata || legs[0]!.fromCity || "?",
      ...legs.map((l) => l.toIata || l.toCity || "?"),
    ];
    return stops.join(" → ");
  }, [legs]);

  const pick = (name: string) => {
    setSelected((s) => [...s, name]);
    setQuery("");
    // Keep the list open — the input still has focus and more flyers may follow.
    setPickerOpen(true);
    flyerInput.current?.focus();
  };

  const actualCost = Number(form.actualCost || 0),
    agencyShare = Number(form.agencyShare || 0);
  const ticketMovement = entry.toBdt(actualCost) - (editing?.ticketPaid ?? 0);
  const payingAccount = funds?.accounts.find((a) => a.name === accountName);
  const accountMovement =
    payingAccount?.currency === "CNY"
      ? Math.round(
          (ticketMovement /
            (entry.currency === "CNY"
              ? entry.exchangeRate
              : funds?.rate || 1)) *
            100,
        ) / 100
      : ticketMovement;
  const paymentError =
    !Number.isFinite(actualCost) ||
    actualCost < 0 ||
    !Number.isFinite(agencyShare) ||
    agencyShare < 0
      ? "Enter valid, non-negative ticket amounts."
      : agencyShare > actualCost
        ? "Agency share cannot exceed the actual ticket cost."
        : ticketMovement === 0 || !accountName
          ? ""
          : fundsLoading
            ? "Loading accounts…"
            : fundsError
              ? "Could not load funds. Refresh accounts and try again."
              : !funds?.accounts.length
                ? "Add an account in Finance first, then refresh accounts here."
                : !payingAccount
                  ? "This account is no longer available. Choose another account or save without payment."
                  : ticketMovement > 0 &&
                      accountMovement > payingAccount.balance
                    ? `Insufficient balance in ${payingAccount.name}. Add funds or choose another account.`
                    : "";

  const submit = async () => {
    if (submitLock.current) return;
    setSubmitError("");
    if (paymentError) {
      setSubmitError(paymentError);
      return;
    }
    if (!editing && !legs.length) {
      setSubmitError(
        "Add a schedule result or manually enter an itinerary segment first.",
      );
      return;
    }
    if (!editing && !selected.length) {
      setSubmitError("Pick at least one flyer.");
      return;
    }
    submitLock.current = true;
    setBusy(true);
    try {
      const common = {
        ...entry.meta,
        // With legs the backend derives the real code; the field still needs a value.
        code: form.code.trim() || legs[0]?.code || editing?.code || "",
        date: form.date || new Date().toISOString().slice(0, 10),
        accountName:
          ticketMovement !== 0 && accountName ? accountName : undefined,
        agencyShare: parseFloat(form.agencyShare) || 0,
        actualCost: parseFloat(form.actualCost) || 0,
        spaceKg: Number.isNaN(parseInt(form.spaceKg))
          ? 44
          : parseInt(form.spaceKg),
        mobiles: Number.isNaN(parseInt(form.mobiles))
          ? 2
          : parseInt(form.mobiles),
        laptops: Number.isNaN(parseInt(form.laptops))
          ? 1
          : parseInt(form.laptops),
        legs: legs.length ? legs : undefined,
      };
      if (editing) {
        const r = await api.patch<{ code: string }>(
          `/flights/${editing.code}`,
          { ...common, status: form.status },
        );
        showToast({ title: "Flight updated", status: "success" });
        onDone(r.code);
      } else {
        await api.post("/flights", { ...common, flyerNames: selected });
        showToast({ title: "Flight added", status: "success" });
        onDone();
      }
      onClose();
      setForm(EMPTY);
      setSelected([]);
    } catch (e) {
      setSubmitError(
        e instanceof Error
          ? e.message
          : "Could not save the flight. Your entries are still here.",
      );
      void reloadFunds();
    } finally {
      submitLock.current = false;
      setBusy(false);
    }
  };

  return (
    <>
      <Modal
        open={open && !registering}
        onClose={() => {
          if (!submitLock.current) onClose();
        }}
        className="max-w-4xl"
      >
        <header className="mb-6">
          <h2 data-dialog-title className="text-xl font-semibold">
            {editing ? `Edit flight ${editing.code}` : "Add flight"}
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Set the itinerary, assign flyers, then record ticket costs and cargo
            capacity.
          </p>
        </header>
        <fieldset disabled={busy} className="space-y-7">
          <FormSection
            title="Itinerary"
            description="Search flight schedules, then add the confirmed segments to this itinerary."
          >
            <FormGrid>
              <Input
                label="Flight number"
                placeholder="e.g. CA945 or MU5850+MU2035"
                value={form.code}
                onChange={(value) =>
                  setForm((current) => ({ ...current, code: value }))
                }
              />
              <Input
                label="Departure date"
                type="date"
                value={form.date}
                onChange={(value) =>
                  setForm((current) => ({ ...current, date: value }))
                }
              />
            </FormGrid>
            <div className="mt-4">
              <Button
                variant="secondary"
                disabled={lookupBusy || busy}
                onClick={() => void searchSchedule()}
              >
                <Search className="size-4" />
                {lookupBusy ? "Searching…" : "Find schedule"}
              </Button>
            </div>
            <Button
              className="mt-3"
              variant="secondary"
              onClick={() => {
                setManual(!manual);
                setSegment({
                  ...emptySegment,
                  code: form.code.split(/[+,]/)[0] ?? "",
                  date: form.date,
                });
              }}
            >
              Enter segment manually
            </Button>
            {manual && (
              <section className="mt-4 space-y-4 rounded-md border border-border p-4">
                <h3 className="font-semibold">Manual itinerary segment</h3>
                <p className="text-xs text-muted-foreground">
                  Use the confirmed ticket. Times are local to each airport.
                  Manual segments stay labelled and are only replaced when you
                  choose Replace itinerary.
                </p>
                <FormGrid>
                  {(
                    [
                      ["code", "Segment flight number", "text"],
                      ["date", "Segment departure date", "date"],
                      ["fromIata", "Origin airport code", "text"],
                      ["fromCity", "Origin city", "text"],
                      ["toIata", "Destination airport code", "text"],
                      ["toCity", "Destination city", "text"],
                      ["depTime", "Departure time", "time"],
                      ["arrTime", "Arrival time", "time"],
                    ] as const
                  ).map(([key, label, type]) => (
                    <Input
                      key={key}
                      label={label}
                      type={type}
                      value={segment[key]}
                      onChange={(value) =>
                        setSegment((v) => ({
                          ...v,
                          [key]:
                            key === "code" || key.endsWith("Iata")
                              ? value.toUpperCase()
                              : value,
                        }))
                      }
                    />
                  ))}
                </FormGrid>
                <Button
                  disabled={
                    !segment.code.trim() ||
                    !segment.date ||
                    !/^[A-Z]{3}$/.test(segment.fromIata) ||
                    !/^[A-Z]{3}$/.test(segment.toIata) ||
                    segment.fromIata === segment.toIata ||
                    !segment.depTime ||
                    !segment.arrTime
                  }
                  onClick={() => {
                    setLegs((rows) => [
                      ...rows,
                      { ...segment, source: "manual" },
                    ]);
                    setForm((v) => ({ ...v, date: v.date || segment.date }));
                    setManual(false);
                    setLookupInfo(
                      "Manual segment added. Review the itinerary before saving.",
                    );
                  }}
                >
                  Add manual segment
                </Button>
              </section>
            )}
            {lookupInfo && (
              <div className="mt-4">
                <SectionNotice tone={lookupWarn ? "warning" : "neutral"}>
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <span>{lookupInfo}</span>
                    {lookupLeg && (
                      <Button variant="secondary" onClick={addLeg}>
                        Add segment
                      </Button>
                    )}
                  </div>
                </SectionNotice>
              </div>
            )}
            {pendingLegs && (
              <div className="mt-4 rounded-md border border-border p-4">
                <h3 className="text-sm font-semibold">
                  Found itinerary · {fmtDayMonth(form.date)}
                </h3>
                {lookupWarn && (
                  <p className="mt-2 text-sm text-warn">
                    Using this itinerary will replace the existing {legs.length}{" "}
                    segments.
                  </p>
                )}
                <ol className="mt-3 divide-y divide-border">
                  {pendingLegs.map((leg, index) => (
                    <li
                      key={`${leg.code}-${index}`}
                      className="flex flex-wrap gap-3 py-3 text-sm"
                    >
                      <span className="font-medium">
                        {leg.code}
                        {leg.source === "manual" ? " · Manually entered" : ""}
                      </span>
                      <span className="text-muted-foreground">
                        {leg.fromIata || leg.fromCity} {leg.depTime} →{" "}
                        {leg.toIata || leg.toCity} {leg.arrTime}
                      </span>
                    </li>
                  ))}
                </ol>
                <div className="mt-3 flex gap-2">
                  <Button
                    onClick={() => {
                      setLegs(pendingLegs);
                      setPendingLegs(null);
                      setLookupWarn(false);
                      setLookupInfo(
                        `Itinerary ${legs.length ? "updated" : "set"} — ${pendingLegs.length} segments`,
                      );
                      setForm((current) => ({ ...current, code: "" }));
                    }}
                  >
                    {legs.length ? "Replace itinerary" : "Use itinerary"}
                  </Button>
                  <Button
                    variant="secondary"
                    onClick={() => setPendingLegs(null)}
                  >
                    Discard result
                  </Button>
                </div>
              </div>
            )}
            {legs.length > 0 ? (
              <div className="mt-5">
                <div className="mb-3 flex flex-wrap justify-between gap-2">
                  <h3 className="text-sm font-semibold">Selected itinerary</h3>
                  <p className="text-sm text-muted-foreground">{routeLabel}</p>
                </div>
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-sm">
                    <thead className="border-b border-border text-xs text-muted-foreground">
                      <tr>
                        <th className="py-3 pr-3 font-medium">Flight</th>
                        <th className="py-3 pr-3 font-medium">Departure</th>
                        <th className="py-3 pr-3 font-medium">Arrival</th>
                        <th className="py-3 font-medium">
                          <span className="sr-only">Actions</span>
                        </th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-border">
                      {legs.map((leg, index) => (
                        <tr key={`${leg.code}-${index}`}>
                          <td className="py-3 pr-3">
                            <p className="font-medium">{leg.code}</p>
                            {leg.source === "manual" && (
                              <p className="text-xs text-muted-foreground">
                                Manually entered
                              </p>
                            )}
                            <p className="mt-1 text-xs text-muted-foreground">
                              {leg.date ? fmtDayMonth(leg.date) : "—"}
                            </p>
                          </td>
                          <td className="py-3 pr-3">
                            {leg.fromIata || leg.fromCity} · {leg.depTime}
                          </td>
                          <td className="py-3 pr-3">
                            {leg.toIata || leg.toCity} · {leg.arrTime}
                          </td>
                          <td className="py-3 text-right">
                            <button
                              type="button"
                              className="text-sm text-danger"
                              aria-label={`Remove segment ${leg.code}`}
                              onClick={() =>
                                setLegs((current) =>
                                  current.filter((_, i) => i !== index),
                                )
                              }
                            >
                              Remove
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <p className="mt-3 text-xs text-muted-foreground">
                  For connecting flights, search and add each segment in travel
                  order.
                </p>
              </div>
            ) : (
              <p className="mt-4 text-sm text-muted-foreground">
                No segments added. Search a flight and choose Add segment, or
                search multiple numbers separated by +.
              </p>
            )}
          </FormSection>
          {!editing && (
            <FormSection
              title="Flyers"
              description="Assign at least one person carrying cargo on this flight."
            >
              <div
                className="relative"
                onBlur={(event) => {
                  if (
                    !event.currentTarget.contains(
                      event.relatedTarget as Node | null,
                    )
                  )
                    setPickerOpen(false);
                }}
                onKeyDown={(event) => {
                  if (event.key === "Escape" && pickerOpen) {
                    event.preventDefault();
                    event.stopPropagation();
                    flyerInput.current?.focus();
                    setPickerOpen(false);
                  }
                }}
              >
                <Input
                  ref={flyerInput}
                  label="Find a flyer"
                  placeholder="Search by name"
                  value={query}
                  onChange={(value) => {
                    setQuery(value);
                    setPickerOpen(true);
                  }}
                  onFocus={() => setPickerOpen(true)}
                />
                {pickerOpen && (suggestions.length > 0 || showRegister) && (
                  <div className="absolute left-0 right-0 top-full z-20 mt-1 max-h-52 overflow-auto rounded-md border border-border bg-card py-1">
                    {suggestions.map((flyer) => (
                      <button
                        key={flyer.name}
                        type="button"
                        className="flex w-full items-center justify-between gap-3 px-3 py-2.5 text-left text-sm hover:bg-muted"
                        onMouseDown={(event) => event.preventDefault()}
                        onClick={() => pick(flyer.name)}
                      >
                        <span>{flyer.name}</span>
                        <span className="text-xs text-muted-foreground">
                          {flyer.bdPhone}
                        </span>
                      </button>
                    ))}
                    {showRegister && (
                      <button
                        type="button"
                        className="w-full border-t border-border px-3 py-2.5 text-left text-sm text-primary hover:bg-muted"
                        onMouseDown={(event) => event.preventDefault()}
                        onClick={() => setRegistering(true)}
                      >
                        Register “{query.trim()}”
                      </button>
                    )}
                  </div>
                )}
              </div>
              {selected.length > 0 && (
                <ul className="mt-3 divide-y divide-border">
                  {selected.map((name) => (
                    <li
                      key={name}
                      className="flex items-center justify-between gap-3 py-3 text-sm"
                    >
                      <span>{name}</span>
                      <button
                        type="button"
                        className="text-sm text-danger"
                        aria-label={`Remove ${name}`}
                        onClick={() =>
                          setSelected((current) =>
                            current.filter((value) => value !== name),
                          )
                        }
                      >
                        Remove
                      </button>
                    </li>
                  ))}
                </ul>
              )}
              <Button
                className="mt-3"
                variant="secondary"
                onClick={() => setRegistering(true)}
              >
                Register new flyer
              </Button>
            </FormSection>
          )}
          <FormSection
            title="Ticket costs"
            description="Enter the actual ticket cost and the agency share in the selected currency."
          >
            <CurrencyFields
              entry={{
                ...entry,
                setCurrency: (currency) => {
                  const rate = currency === "BDT" ? 1 : Number(entry.rateText);
                  if (!(rate > 0)) return;
                  setForm((current) => ({
                    ...current,
                    actualCost: String(
                      Math.round(
                        (entry.toBdt(Number(current.actualCost) || 0) / rate) *
                          100,
                      ) / 100,
                    ),
                    agencyShare: String(
                      Math.round(
                        (entry.toBdt(Number(current.agencyShare) || 0) / rate) *
                          100,
                      ) / 100,
                    ),
                  }));
                  entry.setCurrency(currency);
                },
              }}
              disabled={busy}
            />
            <div className="mt-4">
              <FormGrid>
                <Input
                  label={`Actual ticket cost (${entry.currency})`}
                  inputMode="decimal"
                  placeholder="0.00"
                  value={form.actualCost}
                  onChange={(value) =>
                    setForm((current) => ({ ...current, actualCost: value }))
                  }
                />
                <Input
                  label={`Agency share (${entry.currency})`}
                  inputMode="decimal"
                  placeholder="0.00"
                  value={form.agencyShare}
                  onChange={(value) =>
                    setForm((current) => ({ ...current, agencyShare: value }))
                  }
                />
              </FormGrid>
            </div>
            <div className="mt-5">
              <DetailGrid
                columns={2}
                items={[
                  {
                    label: "Flyer contribution",
                    value: nativeMoney(
                      Math.max(0, actualCost - agencyShare) || 0,
                      entry.currency,
                    ),
                  },
                  {
                    label: "Ticket total (BDT)",
                    value: fmtBdt(entry.toBdt(actualCost) || 0),
                  },
                ]}
              />
            </div>
          </FormSection>
          {ticketMovement !== 0 && (
            <FormSection
              title={ticketMovement < 0 ? "Ticket refund" : "Ticket payment"}
              description="Select an account to record the money movement now, or leave it outstanding."
            >
              <label className="block text-xs font-medium text-muted-foreground">
                {ticketMovement < 0 ? "Receive refund into" : "Pay from"}
                <select
                  className="mt-2 h-10 w-full rounded-md border border-border bg-card px-3 text-sm text-foreground"
                  disabled={busy || fundsLoading}
                  value={accountName}
                  onChange={(event) => {
                    setAccountName(event.target.value);
                    setSubmitError("");
                  }}
                >
                  <option value="">
                    {ticketMovement < 0 ? "Record refund later" : "Pay later"}
                  </option>
                  {funds?.accounts.map((account) => (
                    <option key={account.name} value={account.name}>
                      {account.name} · {account.currency}{" "}
                      {account.balance.toLocaleString("en-IN", {
                        maximumFractionDigits: 2,
                      })}{" "}
                      available
                    </option>
                  ))}
                </select>
              </label>
              <p className="mt-3 text-sm text-muted-foreground">
                {!accountName
                  ? ticketMovement < 0
                    ? `Refund of ${fmtBdt(-ticketMovement)} remains outstanding. No money moves now.`
                    : `${fmtBdt(ticketMovement)} remains unpaid. You can record payment later.`
                  : ticketMovement < 0
                    ? `Record ${fmtBdt(-ticketMovement)} only after the refund has arrived.`
                    : `${fmtBdt(ticketMovement)} will be deducted when you save. Flyer contributions are collected separately.`}
              </p>
              {payingAccount?.currency === "CNY" && (
                <p className="mt-2 text-sm text-muted-foreground">
                  Account movement:{" "}
                  {nativeMoney(Math.abs(accountMovement), "CNY")} at{" "}
                  {entry.currency === "CNY" ? entry.exchangeRate : funds?.rate}{" "}
                  BDT per CNY.
                </p>
              )}
              {fundsError && (
                <p className="mt-2 text-sm text-danger">
                  Accounts could not load. Refresh accounts, or save without
                  payment.
                </p>
              )}
              {!fundsLoading && !fundsError && !funds?.accounts.length && (
                <p className="mt-2 text-sm text-muted-foreground">
                  No accounts available. Add an account in Finance to pay now.
                </p>
              )}
              <div className="mt-4 flex flex-wrap items-center gap-4">
                <a
                  className="text-sm font-medium text-primary"
                  href="/finance"
                  target="_blank"
                  rel="noreferrer"
                >
                  Manage accounts ↗
                </a>
                <Button
                  variant="secondary"
                  disabled={busy || fundsLoading}
                  onClick={() => void reloadFunds()}
                >
                  Refresh accounts
                </Button>
              </div>
            </FormSection>
          )}
          <FormSection
            title="Capacity & status"
            description="Set the cargo allowance for this flight."
          >
            <div className="grid gap-4 sm:grid-cols-3">
              <Input
                label="Cargo space (kg)"
                type="number"
                min={0}
                value={form.spaceKg}
                onChange={(value) =>
                  setForm((current) => ({ ...current, spaceKg: value }))
                }
              />
              <Input
                label="Mobile allowance"
                type="number"
                min={0}
                value={form.mobiles}
                onChange={(value) =>
                  setForm((current) => ({ ...current, mobiles: value }))
                }
              />
              <Input
                label="Laptop allowance"
                type="number"
                min={0}
                value={form.laptops}
                onChange={(value) =>
                  setForm((current) => ({ ...current, laptops: value }))
                }
              />
            </div>
            {editing && (
              <label className="mt-4 block text-xs font-medium text-muted-foreground">
                Flight status
                <select
                  className="mt-2 h-10 w-full rounded-md border border-border bg-card px-3 text-sm text-foreground"
                  value={form.status}
                  onChange={(event) =>
                    setForm((current) => ({
                      ...current,
                      status: event.target.value,
                    }))
                  }
                >
                  <option value="upcoming">Upcoming</option>
                  <option value="departed">Departed</option>
                  <option value="completed">Completed</option>
                </select>
              </label>
            )}
          </FormSection>
          {(submitError || paymentError) && (
            <SectionNotice tone="danger">
              {submitError || paymentError}
            </SectionNotice>
          )}
          <FormActions>
            <Button variant="secondary" disabled={busy} onClick={onClose}>
              Cancel
            </Button>
            <Button
              disabled={busy || !!paymentError || !entry.valid}
              onClick={() => void submit()}
            >
              {busy ? "Saving…" : editing ? "Save changes" : "Add flight"}
            </Button>
          </FormActions>
        </fieldset>
      </Modal>
      <AddFlyerModal
        open={registering}
        onClose={() => setRegistering(false)}
        prefillName={query.trim() || undefined}
        onDone={(name) => {
          setFlyers((current) => [
            ...current.filter((flyer) => flyer.name !== name),
            { name, bdPhone: "—" } as Flyer,
          ]);
          setSelected((current) =>
            current.includes(name) ? current : [...current, name],
          );
          setQuery("");
        }}
      />
    </>
  );
}
