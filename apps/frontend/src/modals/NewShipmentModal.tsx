import {
  Panel,
  FormSection,
  FormGrid,
  FormActions,
  DetailGrid,
  SectionNotice,
} from "@/components/DesignSystem";
import { AddSupplierModal } from "./AddSupplierModal";
import { useEffect, useMemo, useState, useRef, type ReactNode } from "react";
import { api } from "@/api/client";
import type {
  AppSettings,
  FlightSummary,
  ShipmentDetail,
  SupplierSummary,
} from "@/api/types";
import { Modal } from "@/components/Modal";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import { useToast } from "@/components/beui/toast";
import { SearchSelect } from "@/components/SearchSelect";
import { ProgressBar } from "@/components/ui";
import { fmtBdt, fmtDate } from "@/lib/format";

const PAY_OPTIONS = [
  { value: "unpaid", label: "Pay on invoice" },
  { value: "cod", label: "Cash on delivery" },
  { value: "monthly", label: "Monthly billing" },
];

type PcsUnit = { model: string; serial: string };
type PcsDraft = Record<
  string,
  { count: string; rate: string; currency: "BDT" | "CNY"; units: PcsUnit[] }
>;

const resizeUnits = (units: PcsUnit[], count: number): PcsUnit[] =>
  Array.from(
    { length: Math.max(0, count) },
    (_, i) => units[i] ?? { model: "", serial: "" },
  );

function ShipmentFormSurface({
  open,
  onClose,
  embedded,
  children,
}: {
  open: boolean;
  onClose: () => void;
  embedded: boolean;
  children: ReactNode;
}) {
  return embedded ? (
    <section hidden={!open} className="space-y-5">
      {children}
    </section>
  ) : (
    <Modal open={open} onClose={onClose} className="max-w-4xl">
      {children}
    </Modal>
  );
}

export function NewShipmentModal({
  open,
  onClose,
  onDone,
  lockedFlight,
  editing,
  embedded = false,
}: {
  embedded?: boolean;
  open: boolean;
  onClose: () => void;
  onDone: (code: string) => void;
  /** When opened from a flight page the flight is fixed. */
  lockedFlight?: { code: string; date: string };
  /** When set, the modal edits this shipment instead of creating one. */
  editing?: ShipmentDetail;
}) {
  const { showToast } = useToast();
  const [busy, setBusy] = useState(false);
  const [addingSupplier, setAddingSupplier] = useState(false);
  const submitLock = useRef(false);
  const categoryInput = useRef<HTMLInputElement>(null);
  const [suppliers, setSuppliers] = useState<SupplierSummary[]>([]);
  const [flights, setFlights] = useState<FlightSummary[]>([]);
  const [categories, setCategories] = useState<string[]>([]);
  const [fxRate, setFxRate] = useState<number | null>(null);
  const [pcsDefaults, setPcsDefaults] = useState<Record<string, number>>({});

  const [supplier, setSupplier] = useState("");
  const [flight, setFlight] = useState("");
  const [flyerName, setFlyerName] = useState("");
  const [picked, setPicked] = useState<string[]>([]);
  const [catQuery, setCatQuery] = useState("");
  const [catOpen, setCatOpen] = useState(false);
  const [pcs, setPcs] = useState<PcsDraft>({});
  const [kg, setKg] = useState("");
  const [rate, setRate] = useState("");
  const [currency, setCurrency] = useState<"BDT" | "CNY">("BDT");
  const [description, setDescription] = useState("");
  const [pay, setPay] = useState("unpaid");

  /** A category charged per piece: has a settings rate or is a device type. */
  const isPcsCategory = (name: string) =>
    pcsDefaults[name] !== undefined || /mobile|laptop|drone/i.test(name);

  useEffect(() => {
    if (!open) return;
    if (editing) {
      setSupplier(editing.supplierCode);
      setFlight(editing.flightCode ?? "");
      setFlyerName(editing.flyerName ?? "");
      setPicked(editing.categories);
      // Older shipments carry a flat serial list — distribute it across the
      // device units in order so nothing typed before is lost.
      const leftoverSerials = [...editing.serials];
      setPcs(
        Object.fromEntries(
          editing.pcsItems.map((i) => [
            i.category,
            {
              count: String(i.count),
              rate: String(i.rate),
              currency: i.currency,
              units: i.units.length
                ? resizeUnits(i.units, i.count)
                : resizeUnits(
                    Array.from({ length: i.count }, () => ({
                      model: "",
                      serial: leftoverSerials.shift() ?? "",
                    })),
                    i.count,
                  ),
            },
          ]),
        ),
      );
      setKg(editing.bookedKg ? String(editing.bookedKg) : "");
      setRate(editing.chargeRate ? String(editing.chargeRate) : "");
      setCurrency(editing.chargeCurrency === "CNY" ? "CNY" : "BDT");
      setDescription(editing.description === "—" ? "" : editing.description);
      setPay(
        editing.paymentTerms === "invoice"
          ? "unpaid"
          : (editing.paymentTerms ?? "unpaid"),
      );
    } else {
      setSupplier("");
      setFlight(lockedFlight?.code ?? "");
      setFlyerName("");
      setPicked([]);
      setPcs({});
      setKg("");
      setRate("");
      setCurrency("BDT");
      setDescription("");
      setPay("unpaid");
    }
    setCatQuery("");
    api
      .get<{ suppliers: SupplierSummary[] }>("/suppliers")
      .then((r) => setSuppliers(r.suppliers))
      .catch(() => undefined);
    api
      .get<{ flights: FlightSummary[] }>("/flights")
      .then((r) => setFlights(r.flights))
      .catch(() => undefined);
    api
      .get<{ categories: string[] }>("/categories")
      .then((r) => setCategories(r.categories))
      .catch(() => undefined);
    api
      .get<{ settings: AppSettings }>("/settings")
      .then((r) => {
        setFxRate(editing?.pricingRates?.CNY || r.settings.rate);
        setPcsDefaults(r.settings.pcsRates);
      })
      .catch(() => undefined);
    // Refreshing the same record must not overwrite the open draft.
    // Reinitialize only when opened again or switched to a different record.
  }, [open, lockedFlight?.code, editing?.code]);

  // Keep the per-piece rows in lockstep with the picked categories: a newly
  // picked device category appears with the settings default rate, an
  // unpicked one drops out. Existing rows (and their overrides) are kept.
  useEffect(() => {
    setPcs((current) => {
      const next: PcsDraft = {};
      for (const name of picked) {
        if (!isPcsCategory(name)) continue;
        next[name] = current[name] ?? {
          count: "1",
          rate: String(pcsDefaults[name] ?? 0),
          currency: "BDT",
          units: [{ model: "", serial: "" }],
        };
      }
      return next;
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [picked, pcsDefaults]);

  const pcsSum = Object.values(pcs).reduce(
    (a, v) =>
      a +
      (parseInt(v.count) || 0) *
        (parseFloat(v.rate) || 0) *
        (v.currency === "CNY" ? (fxRate ?? 0) : 1),
    0,
  );
  const totalPcs = Object.values(pcs).reduce(
    (a, v) => a + (parseInt(v.count) || 0),
    0,
  );
  const devMode = Object.keys(pcs).length > 0;

  const setPcsField = (category: string, patch: Partial<PcsDraft[string]>) =>
    setPcs((p) => {
      const current = p[category];
      if (!current) return p;
      const next = { ...current, ...patch };
      next.units = resizeUnits(
        next.units,
        Math.max(1, parseInt(next.count) || 1),
      );
      return { ...p, [category]: next };
    });

  const setUnit = (category: string, index: number, patch: Partial<PcsUnit>) =>
    setPcs((p) => {
      const current = p[category];
      if (!current) return p;
      return {
        ...p,
        [category]: {
          ...current,
          units: current.units.map((u, i) =>
            i === index ? { ...u, ...patch } : u,
          ),
        },
      };
    });

  const selectedFlight = useMemo(
    () => flights.find((f) => f.code === flight) ?? null,
    [flights, flight],
  );

  /** Flight load with this shipment's weight projected in. */
  const load = useMemo(() => {
    if (!selectedFlight) return null;
    // When editing, the shipment's current weight is already inside the
    // flight's booked total — take it out before projecting the new value.
    const own =
      editing && editing.flightCode === selectedFlight.code
        ? editing.bookedKg
        : 0;
    const base = Math.max(
      0,
      Math.round((selectedFlight.bookedKg - own) * 100) / 100,
    );
    const entered = parseFloat(kg) || 0;
    const projected = Math.round((base + entered) * 100) / 100;
    const free = Math.round((selectedFlight.spaceKg - projected) * 100) / 100;
    return {
      base,
      entered,
      projected,
      free,
      spaceKg: selectedFlight.spaceKg,
      code: selectedFlight.code,
    };
  }, [selectedFlight, editing, kg]);

  const exceedsCapacity = Boolean(load && load.free < 0 && (!editing || editing.flightCode !== flight || (parseFloat(kg) || 0) > editing.bookedKg));

  const supplierOptions = useMemo(
    () =>
      suppliers.map((s) => ({
        value: s.code,
        label: `${s.code} · ${s.name}`,
        sub: s.terms === "monthly" ? "Monthly" : "Instant",
        keywords: `${s.code} ${s.name}`.toLowerCase(),
      })),
    [suppliers],
  );

  const flightOptions = useMemo(
    () =>
      flights
        .filter((f) => editing !== undefined || f.status === "upcoming")
        .map((f) => ({
          value: f.code,
          label: `${f.code.split("+").join(" · ")} · ${fmtDate(f.date)}`,
          sub: `${f.leftKg} kg free`,
          keywords: `${f.code} ${f.date} ${f.flyers.join(" ")}`.toLowerCase(),
        })),
    [flights, editing],
  );

  const suggestions = useMemo(() => {
    const q = catQuery.trim().toLowerCase();
    return categories
      .filter((c) => !picked.includes(c) && (!q || c.toLowerCase().includes(q)))
      .slice(0, 8);
  }, [categories, picked, catQuery]);

  const showAddCategory =
    Boolean(catQuery.trim()) &&
    !categories.some((c) => c.toLowerCase() === catQuery.trim().toLowerCase());

  const pickCategory = (name: string) => {
    setPicked((p) => [...p, name]);
    setCatQuery("");
    // The input keeps focus after a pick, so leave the list open for the
    // next category instead of forcing a blur/refocus.
    setCatOpen(true);
    categoryInput.current?.focus();
  };

  const addCategory = async () => {
    const name = catQuery.trim();
    if (!name) return;
    try {
      await api.post("/categories", { name });
      setCategories((c) => [...c, name].sort());
      pickCategory(name);
      showToast({ title: `Category "${name}" added` });
    } catch (e) {
      showToast({
        title: e instanceof Error ? e.message : "Failed",
        status: "error",
      });
    }
  };

  /** Live total preview: kg part (CNY at fx rate) + per-piece part. */
  const totalPreview = useMemo(() => {
    const r = parseFloat(rate) || 0;
    const kgN = parseFloat(kg) || 0;
    const kgPart = r * kgN * (currency === "CNY" ? (fxRate ?? 0) : 1);
    if (kgPart <= 0 && pcsSum <= 0) return null;
    const sign = currency === "CNY" ? "¥" : "৳";
    const parts: string[] = [];
    if (kgPart > 0)
      parts.push(
        `${kgN} kg × ${sign}${r}/kg${currency === "CNY" ? ` · ¥1 = ৳${fxRate ?? "?"}` : ""}`,
      );
    if (pcsSum > 0) parts.push(`${totalPcs} pc = ${fmtBdt(pcsSum)}`);
    return `Total ${fmtBdt(kgPart + pcsSum)} (${parts.join(" + ")})`;
  }, [rate, kg, currency, fxRate, pcsSum, totalPcs]);

  const submit = async () => {
    if (submitLock.current) return;
    if (!supplier) {
      showToast({ title: "Pick a customer", status: "error" });
      return;
    }
    if (!picked.length) {
      showToast({ title: "Pick at least one category", status: "error" });
      return;
    }
    if (exceedsCapacity) {
      showToast({ title: "Flight capacity exceeded. Choose another flight or update its confirmed baggage capacity.", status: "error" });
      return;
    }
    submitLock.current = true;
    setBusy(true);
    try {
      const payload = {
        supplierCode: supplier,
        flightCode: flight || (editing ? null : undefined),
        flyerName: flyerName || (editing ? null : undefined),
        categories: picked,
        bookedKg: parseFloat(kg) || 0,
        chargeRate: parseFloat(rate) || 0,
        chargeCurrency: currency,
        pcsItems: Object.entries(pcs).map(([category, v]) => {
          const count = Math.max(1, parseInt(v.count) || 1);
          return {
            category,
            count,
            rate: parseFloat(v.rate) || 0,
            currency: v.currency,
            units: resizeUnits(v.units, count).map((u) => ({
              model: u.model.trim(),
              serial: u.serial.trim(),
            })),
          };
        }),
        description,
        paymentTerms: pay === "unpaid" ? "invoice" : pay,
      };
      if (editing) {
        await api.patch(`/shipments/${editing.code}`, {
          ...payload,
        });
        showToast({ title: `${editing.code} updated`, status: "success" });
        onClose();
        onDone(editing.code);
      } else {
        const r = await api.post<{ code: string }>("/shipments", payload);
        showToast({ title: `Shipment ${r.code} created`, status: "success" });
        onClose();
        onDone(r.code);
      }
    } catch (e) {
      showToast({
        title: e instanceof Error ? e.message : "Failed",
        status: "error",
      });
    } finally {
      submitLock.current = false;
      setBusy(false);
    }
  };

  return (
    <>
      <AddSupplierModal
        open={addingSupplier}
        onClose={() => setAddingSupplier(false)}
        onDone={async (code) => {
          const result = await api.get<{ suppliers: SupplierSummary[] }>(
            "/suppliers",
          );
          setSuppliers(result.suppliers);
          if (code) {
            setSupplier(code);
            setPay(
              result.suppliers.find((s) => s.code === code)?.terms === "monthly"
                ? "monthly"
                : "unpaid",
            );
          }
          setAddingSupplier(false);
        }}
      />
      <ShipmentFormSurface
        embedded={embedded}
        open={open && !addingSupplier}
        onClose={() => {
          if (!busy) onClose();
        }}
      >
        {!embedded && (
          <header className="mb-6">
            <h2 data-dialog-title className="text-xl font-semibold">
              {editing ? `Edit shipment ${editing.code}` : "New shipment"}
            </h2>
            <p className="mt-2 text-sm text-muted-foreground">
              Enter the customer, cargo and agreed charges. You can assign a
              flight before dispatch.
            </p>
          </header>
        )}
        <fieldset disabled={busy} className="space-y-5">
          <Panel
            title="Customer & dispatch"
            description="Select the cargo owner. Flight assignment is optional at intake."
            actions={
              <Button
                variant="secondary"
                disabled={busy}
                onClick={() => setAddingSupplier(true)}
              >
                Add customer
              </Button>
            }
          >
            <FormGrid>
              <SearchSelect
                label="Customer"
                placeholder="Search name or customer code"
                options={supplierOptions}
                value={supplier}
                onChange={(value) => {
                  setSupplier(value);
                  if (!editing)
                    setPay(
                      suppliers.find((s) => s.code === value)?.terms ===
                        "monthly"
                        ? "monthly"
                        : "unpaid",
                    );
                }}
              />
              {lockedFlight && !editing ? (
                <div>
                  <p className="mb-2 text-xs font-medium text-muted-foreground">
                    Assigned flight
                  </p>
                  <p className="rounded-md border border-border bg-background px-3 py-2.5 text-sm">
                    {lockedFlight.code.split("+").join(" · ")} ·{" "}
                    {fmtDate(lockedFlight.date)}
                  </p>
                </div>
              ) : (
                <SearchSelect
                  clearable
                  disabled={!!editing && editing.statusIndex >= 3}
                  label="Flight (optional)"
                  placeholder="Search flight number or date"
                  options={flightOptions}
                  value={flight}
                  onChange={(value) => {
                    setFlight(value);
                    setFlyerName("");
                  }}
                />
              )}
              {selectedFlight && (
                <label className="text-xs font-medium text-muted-foreground">
                  Carrying flyer
                  <select
                    disabled={!!editing && editing.statusIndex >= 3}
                    aria-label="Carrying flyer"
                    className="mt-2 h-10 w-full rounded-md border border-border bg-card px-3 text-sm text-foreground"
                    value={
                      flyerName ||
                      (selectedFlight.flyers.length === 1
                        ? selectedFlight.flyers[0]
                        : "")
                    }
                    onChange={(e) => setFlyerName(e.target.value)}
                  >
                    <option value="">Assign before dispatch</option>
                    {selectedFlight.flyers.map((name) => (
                      <option key={name}>{name}</option>
                    ))}
                  </select>
                </label>
              )}
            </FormGrid>
            {editing && editing.statusIndex >= 3 && (
              <p className="mt-3 text-sm text-muted-foreground">
                Flight changes after dispatch use Manage shipment → Correct
                flight assignment, with a recorded reason.
              </p>
            )}
            {load && (
              <div className="mt-5 border-t border-border pt-4">
                <div className="mb-3 flex flex-wrap justify-between gap-2 text-sm">
                  <span>
                    {load.code.split("+").join(" · ")} · {load.projected} /{" "}
                    {load.spaceKg} kg after this booking
                  </span>
                  <span
                    className={
                      load.free < 0 ? "text-danger" : "text-muted-foreground"
                    }
                  >
                    {load.free < 0
                      ? `${Math.abs(load.free)} kg over capacity`
                      : `${load.free} kg remaining`}
                  </span>
                </div>
                {exceedsCapacity && <p role="alert" className="mb-3 text-sm text-danger">Choose another flight or update its confirmed baggage capacity before saving.</p>}
                <ProgressBar
                  pct={
                    load.spaceKg > 0
                      ? (load.projected / load.spaceKg) * 100
                      : 100
                  }
                  danger={load.free < 0}
                />
              </div>
            )}
          </Panel>
          <Panel
            title="Cargo details"
            description="Select all relevant categories and describe the contents."
          >
            <div className="space-y-5">
              <div
                className="relative"
                onBlur={(event) => {
                  if (
                    !event.currentTarget.contains(
                      event.relatedTarget as Node | null,
                    )
                  )
                    setCatOpen(false);
                }}
                onKeyDown={(event) => {
                  if (event.key === "Escape" && catOpen) {
                    event.preventDefault();
                    event.stopPropagation();
                    categoryInput.current?.focus();
                    setCatOpen(false);
                  }
                }}
              >
                <Input
                  ref={categoryInput}
                  label="Cargo categories"
                  placeholder="Search or add a category"
                  value={catQuery}
                  onChange={(value) => {
                    setCatQuery(value);
                    setCatOpen(true);
                  }}
                  onKeyDown={(event) => {
                    if (catOpen && event.key === "Enter" && suggestions[0]) {
                      event.preventDefault();
                      pickCategory(suggestions[0]);
                      setCatOpen(false);
                    } else if (
                      catOpen &&
                      event.key === "Enter" &&
                      showAddCategory
                    ) {
                      event.preventDefault();
                      void addCategory();
                    }
                  }}
                  onFocus={() => setCatOpen(true)}
                />
                {catOpen && (suggestions.length > 0 || showAddCategory) && (
                  <div className="absolute left-0 right-0 top-full z-20 mt-1 max-h-52 overflow-auto rounded-md border border-border bg-card py-1">
                    {suggestions.map((name) => (
                      <button
                        type="button"
                        key={name}
                        className="flex w-full items-center justify-between px-3 py-2.5 text-left text-sm hover:bg-muted"
                        onMouseDown={(event) => event.preventDefault()}
                        onClick={() => pickCategory(name)}
                      >
                        <span>{name}</span>
                        <span className="text-xs text-muted-foreground">
                          Select
                        </span>
                      </button>
                    ))}
                    {showAddCategory && (
                      <button
                        type="button"
                        className="w-full border-t border-border px-3 py-2.5 text-left text-sm font-medium text-primary hover:bg-muted"
                        onMouseDown={(event) => event.preventDefault()}
                        onClick={() => void addCategory()}
                      >
                        Add category “{catQuery.trim()}”
                      </button>
                    )}
                  </div>
                )}
              </div>
              {picked.length > 0 && (
                <ul className="flex flex-wrap gap-2">
                  {picked.map((name) => (
                    <li
                      key={name}
                      className="inline-flex items-center gap-3 rounded-md border border-border px-3 py-2 text-sm"
                    >
                      <span>{name}</span>
                      <button
                        type="button"
                        aria-label={`Remove ${name}`}
                        className="text-muted-foreground hover:text-danger"
                        onClick={() =>
                          setPicked((current) =>
                            current.filter((value) => value !== name),
                          )
                        }
                      >
                        ×
                      </button>
                    </li>
                  ))}
                </ul>
              )}
              <FormGrid>
                <Input
                  label="Description"
                  placeholder="Contents and packaging details"
                  value={description}
                  onChange={setDescription}
                />
                <Input
                  label="Booked weight (kg)"
                  inputMode="decimal"
                  placeholder="0.0"
                  value={kg}
                  onChange={setKg}
                />
              </FormGrid>
            </div>
          </Panel>
          <Panel
            title="Shipping charges"
            description="Choose the original currency for each rate. Reporting totals are calculated in BDT."
          >
            <FormGrid>
              <Input
                label="Charge per kg"
                inputMode="decimal"
                placeholder="0.00"
                value={rate}
                onChange={setRate}
              />
              <label className="text-xs font-medium text-muted-foreground">
                Rate currency
                <select
                  aria-label="Rate currency"
                  className="mt-2 h-10 w-full rounded-md border border-border bg-card px-3 text-sm text-foreground"
                  value={currency}
                  onChange={(e) => setCurrency(e.target.value as "BDT" | "CNY")}
                >
                  <option value="BDT">BDT · Bangladeshi taka</option>
                  <option value="CNY">CNY · Chinese yuan</option>
                </select>
              </label>
            </FormGrid>
            {currency === "CNY" && (
              <p className="mt-3 text-sm text-muted-foreground">
                Exchange rate: 1 CNY = {fxRate ?? "—"} BDT. The booking keeps
                this rate.
              </p>
            )}
            {devMode && (
              <div className="mt-6 space-y-6 border-t border-border pt-6">
                {Object.entries(pcs).map(([category, item]) => {
                  const lineTotal =
                    (parseInt(item.count) || 0) *
                    (parseFloat(item.rate) || 0) *
                    (item.currency === "CNY" ? (fxRate ?? 0) : 1);
                  return (
                    <FormSection
                      key={category}
                      title={`${category} · per-piece charges`}
                      description="Enter the quantity, unit price and identifying details for each device."
                    >
                      <div className="grid gap-4 sm:grid-cols-3">
                        <Input
                          label="Quantity"
                          type="number"
                          min={1}
                          max={20}
                          value={item.count}
                          onChange={(value) =>
                            setPcsField(category, { count: value })
                          }
                        />
                        <Input
                          label="Price per piece"
                          type="number"
                          min={0}
                          value={item.rate}
                          onChange={(value) =>
                            setPcsField(category, { rate: value })
                          }
                        />
                        <label className="text-xs font-medium text-muted-foreground">
                          Currency
                          <select
                            className="mt-2 h-10 w-full rounded-md border border-border bg-card px-3 text-sm text-foreground"
                            value={item.currency}
                            onChange={(e) =>
                              setPcsField(category, {
                                currency: e.target.value as "BDT" | "CNY",
                              })
                            }
                          >
                            <option value="BDT">BDT</option>
                            <option value="CNY">CNY</option>
                          </select>
                        </label>
                      </div>
                      <div className="mt-4 space-y-4">
                        {item.units.map((unit, index) => (
                          <FormGrid key={index}>
                            <Input
                              label={`Item ${index + 1} model`}
                              placeholder={
                                /laptop/i.test(category)
                                  ? "MacBook Air M2"
                                  : /drone/i.test(category)
                                    ? "DJI Mini 4"
                                    : "iPhone 15 Pro"
                              }
                              value={unit.model}
                              onChange={(value) =>
                                setUnit(category, index, { model: value })
                              }
                            />
                            <Input
                              label={`Item ${index + 1} serial / IMEI`}
                              placeholder="Device serial number"
                              value={unit.serial}
                              onChange={(value) =>
                                setUnit(category, index, { serial: value })
                              }
                            />
                          </FormGrid>
                        ))}
                      </div>
                      <p className="mt-3 text-right text-sm font-medium">
                        Subtotal: {fmtBdt(lineTotal)}
                      </p>
                    </FormSection>
                  );
                })}
              </div>
            )}
          </Panel>
          <Panel title="Billing & review">
            <div className="max-w-md">
              <label className="text-xs font-medium text-muted-foreground">
                Payment terms
                <select
                  aria-label="Payment terms"
                  className="mt-2 h-10 w-full rounded-md border border-border bg-card px-3 text-sm text-foreground"
                  value={pay}
                  disabled={busy}
                  onChange={(e) => setPay(e.target.value)}
                >
                  {!PAY_OPTIONS.some((option) => option.value === pay) && (
                    <option value={pay}>
                      {pay.charAt(0).toUpperCase() + pay.slice(1)}
                    </option>
                  )}
                  {PAY_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </label>
            </div>
            {editing && editing.paidAmount > 0 && (
              <p className="mt-3 text-xs text-muted-foreground">
                Payment status follows recorded payments. Manage payments and
                credits in Billing.
              </p>
            )}
            <div className="mt-5 border-t border-border pt-5">
              <DetailGrid
                columns={3}
                items={[
                  {
                    label: "Customer",
                    value:
                      suppliers.find((item) => item.code === supplier)?.name ??
                      "Not selected",
                  },
                  {
                    label: "Cargo",
                    value: picked.join(", ") || "Not selected",
                  },
                  {
                    label: "Flight",
                    value: flight || "Assign before dispatch",
                  },
                ]}
              />
            </div>
            <div className="mt-5">
              <SectionNotice>
                {totalPreview ||
                  "Enter a shipping rate or a per-piece charge to calculate the booking total."}
              </SectionNotice>
            </div>
            <p className="mt-3 text-sm text-muted-foreground">
              Add shipment expenses from Costs and manage invoices or payments
              in Billing after saving. Photos and videos belong in Attachments.
            </p>
          </Panel>
          <FormActions>
            {!embedded && (
              <Button variant="secondary" disabled={busy} onClick={onClose}>
                Cancel
              </Button>
            )}
            <Button
              disabled={busy || !supplier || !picked.length || exceedsCapacity}
              onClick={() => void submit()}
            >
              {busy ? "Saving…" : editing ? "Save changes" : "Create shipment"}
            </Button>
          </FormActions>
        </fieldset>
      </ShipmentFormSurface>
    </>
  );
}
