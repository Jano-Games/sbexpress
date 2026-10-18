import { BusinessSetup } from "@/components/BusinessSetup";
import { SettingsActivity } from "@/components/SettingsActivity";
import { StaffUsers } from "@/components/StaffUsers";
import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { Plus, Search } from "lucide-react";
import { api } from "@/api/client";
import { sniffImage } from "@/lib/uploadFile";
import { useFetch } from "@/state/useFetch";
import type { AppSettings, PayMethodKind, PayMethodRow } from "@/api/types";
import { CurrencyFields, useMoneyEntry } from "@/components/MoneyInput";
import {
  PageHeader,
  PageTabs,
  EmptyState,
  usePageSection,
} from "@/components/Workspace";
import {
  DetailGrid,
  FormActions,
  FormGrid,
  FormSection,
  Panel,
  SectionNotice,
} from "@/components/DesignSystem";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import { useToast } from "@/components/beui/toast";
import { ErrorBlock, LoadingBlock } from "@/components/ui";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { Modal } from "@/components/Modal";
import { fmtBdt } from "@/lib/format";

const EMPTY_METHOD = {
  currency: "BDT" as "BDT" | "CNY",
  provider: "",
  label: "",
  number: "",
  note: "",
  qrImage: null as string | null,
  bankName: "",
  accountNumber: "",
  accountName: "",
  branch: "",
  district: "",
};

function methodTitle(method: PayMethodRow) {
  return method.kind === "mobile_banking"
    ? `${method.provider}${method.label ? ` · ${method.label}` : ""}`
    : method.bankName;
}

function methodSummary(method: PayMethodRow) {
  return method.kind === "mobile_banking"
    ? [method.number, method.note].filter(Boolean).join(" · ")
    : [
        method.accountName,
        method.accountNumber,
        [method.branch, method.district].filter(Boolean).join(", "),
      ]
        .filter(Boolean)
        .join(" · ");
}

export function Settings() {
  const { showToast } = useToast();
  const pcsEntry = useMoneyEntry();
  const { data, error, loading } = useFetch<{ settings: AppSettings }>(
    "/settings",
  );
  const {
    data: payData,
    error: payError,
    loading: payLoading,
    reload: reloadMethods,
  } = useFetch<{ methods: PayMethodRow[] }>("/settings/pay-methods");
  const [section, setSection] = usePageSection("general", [
    "general",
    "rates",
    "payments",
    "users",
    "activity",
  ]);
  const [rate, setRate] = useState("");
  const [threshold, setThreshold] = useState("");
  const [saving, setSaving] = useState<"general" | "rates" | null>(null);
  const [pcsRates, setPcsRates] = useState<Record<string, string>>({});
  const [categoryOpen, setCategoryOpen] = useState(false);
  const [newPcsCat, setNewPcsCat] = useState("");
  const [newPcsRate, setNewPcsRate] = useState("");
  const [kind, setKind] = useState<PayMethodKind>("mobile_banking");
  const [form, setForm] = useState(EMPTY_METHOD);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [methodOpen, setMethodOpen] = useState(false);
  const [methodBusy, setMethodBusy] = useState(false);
  const [visibilityBusy, setVisibilityBusy] = useState<string | null>(null);
  const [methodQuery, setMethodQuery] = useState("");
  const [deleting, setDeleting] = useState<PayMethodRow | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const dirty = useRef({ rate: false, threshold: false, pcsRates: false });

  useEffect(() => {
    if (!data) return;
    // Background revalidation can follow an unrelated payment-method change.
    // Keep edits in progress, and keep saved prices in the displayed currency.
    if (!dirty.current.rate) setRate(String(data.settings.rate));
    if (!dirty.current.threshold) setThreshold(String(data.settings.threshold));
    if (!dirty.current.pcsRates)
      setPcsRates(
        Object.fromEntries(
          Object.entries(data.settings.pcsRates).map(([category, value]) => [
            category,
            String(pcsEntry.fromBdt(value)),
          ]),
        ),
      );
  }, [data]);

  const fail = (problem: unknown) =>
    showToast({
      title:
        problem instanceof Error
          ? problem.message
          : "The change could not be saved",
      status: "error",
    });
  const set =
    (key: Exclude<keyof typeof EMPTY_METHOD, "currency">) => (value: string) =>
      setForm((current) => ({ ...current, [key]: value }));

  async function saveGeneral() {
    if (saving) return;
    const nextRate = Number(rate),
      nextThreshold = Number(threshold);
    if (
      !rate.trim() ||
      !threshold.trim() ||
      !Number.isFinite(nextRate) ||
      nextRate <= 0 ||
      !Number.isFinite(nextThreshold) ||
      nextThreshold < 0
    ) {
      fail(
        new Error(
          "Enter a positive exchange rate and a non-negative weight threshold",
        ),
      );
      return;
    }
    setSaving("general");
    try {
      await api.patch("/settings", {
        rate: nextRate,
        threshold: nextThreshold,
      });
      dirty.current.rate = false;
      dirty.current.threshold = false;
      setRate(String(nextRate));
      setThreshold(String(nextThreshold));
      showToast({ title: "General settings saved", status: "success" });
    } catch (problem) {
      fail(problem);
    } finally {
      setSaving(null);
    }
  }

  async function savePcsRates() {
    if (saving) return;
    if (
      !pcsEntry.valid ||
      Object.values(pcsRates).some(
        (value) =>
          !value.trim() || !Number.isFinite(Number(value)) || Number(value) < 0,
      )
    ) {
      fail(
        new Error(
          "Enter a valid exchange rate and a non-negative rate for every category",
        ),
      );
      return;
    }
    setSaving("rates");
    try {
      const parsed = Object.fromEntries(
        Object.entries(pcsRates).map(([category, value]) => [
          category,
          pcsEntry.toBdt(Number(value)),
        ]),
      );
      await api.patch("/settings", { pcsRates: parsed });
      dirty.current.pcsRates = false;
      setPcsRates(
        Object.fromEntries(
          Object.entries(parsed).map(([category, value]) => [
            category,
            String(pcsEntry.fromBdt(value)),
          ]),
        ),
      );
      showToast({ title: "Shipping rates saved", status: "success" });
    } catch (problem) {
      fail(problem);
    } finally {
      setSaving(null);
    }
  }

  function addCategory() {
    const category = newPcsCat.trim();
    if (
      !category ||
      !newPcsRate.trim() ||
      !Number.isFinite(Number(newPcsRate)) ||
      Number(newPcsRate) < 0
    ) {
      fail(new Error("Enter a category name and a valid non-negative rate"));
      return;
    }
    if (
      Object.keys(pcsRates).some(
        (existing) => existing.toLowerCase() === category.toLowerCase(),
      )
    ) {
      fail(
        new Error("This category already exists. Edit its rate in the table."),
      );
      return;
    }
    dirty.current.pcsRates = true;
    setPcsRates((current) => ({ ...current, [category]: newPcsRate }));
    setNewPcsCat("");
    setNewPcsRate("");
    setCategoryOpen(false);
  }

  function startAdd() {
    setEditingId(null);
    setKind("mobile_banking");
    setForm(EMPTY_METHOD);
    setMethodOpen(true);
  }

  function startEdit(method: PayMethodRow) {
    setEditingId(method.id);
    setKind(method.kind);
    setForm({
      currency: method.currency,
      provider: method.provider,
      label: method.label,
      number: method.number,
      note: method.note,
      qrImage: method.qrImage,
      bankName: method.bankName,
      accountNumber: method.accountNumber,
      accountName: method.accountName,
      branch: method.branch,
      district: method.district,
    });
    setMethodOpen(true);
  }

  function pickQr(file: File | undefined) {
    if (!file) return;
    const allowed = ["image/png", "image/jpeg", "image/webp"];
    if (!allowed.includes(file.type)) {
      fail(new Error("Use a PNG, JPEG or WebP image for the payment QR."));
      return;
    }
    if (file.size > 300 * 1024) {
      fail(new Error("QR image too large — keep it under 300 KB"));
      return;
    }
    void file.arrayBuffer().then((buffer) => {
      const kind = sniffImage(new Uint8Array(buffer).subarray(0, 32));
      const expected = file.type === "image/png" ? "png" : file.type === "image/webp" ? "webp" : "jpeg";
      if (kind !== expected) {
        fail(new Error("That file is not a PNG, JPEG or WebP image."));
        return;
      }
      const reader = new FileReader();
      reader.onload = () =>
        setForm((current) => ({ ...current, qrImage: String(reader.result) }));
      reader.onerror = () => fail(new Error("The QR image could not be read"));
      reader.readAsDataURL(file);
    }).catch(() => fail(new Error("The QR image could not be read")));
  }

  async function submitMethod() {
    if (methodBusy) return;
    const details =
      kind === "mobile_banking"
        ? {
            kind,
            provider: form.provider,
            label: form.label,
            number: form.number,
            note: form.note,
            qrImage: form.qrImage,
          }
        : {
            kind,
            bankName: form.bankName,
            accountNumber: form.accountNumber,
            accountName: form.accountName,
            branch: form.branch,
            district: form.district,
          };
    setMethodBusy(true);
    try {
      const payload = { ...details, currency: form.currency };
      if (editingId)
        await api.patch(`/settings/pay-methods/${editingId}`, payload);
      else await api.post("/settings/pay-methods", payload);
      showToast({
        title: editingId ? "Payment method updated" : "Payment method added",
        status: "success",
      });
      setMethodOpen(false);
      setEditingId(null);
      setForm(EMPTY_METHOD);
      await reloadMethods();
    } catch (problem) {
      fail(problem);
    } finally {
      setMethodBusy(false);
    }
  }

  async function toggleMethod(method: PayMethodRow) {
    if (visibilityBusy) return;
    setVisibilityBusy(method.id);
    try {
      await api.patch(`/settings/pay-methods/${method.id}`, {
        enabled: !method.enabled,
      });
      await reloadMethods();
    } catch (problem) {
      fail(problem);
    } finally {
      setVisibilityBusy(null);
    }
  }

  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  const methods = (payData?.methods ?? []).filter((method) =>
    `${methodTitle(method)} ${methodSummary(method)} ${method.currency}`
      .toLowerCase()
      .includes(methodQuery.trim().toLowerCase()),
  );

  return (
    <div>
      <PageHeader
        title="Settings"
        description="Manage business defaults, shipment pricing, payment methods and team access."
      />
      <PageTabs
        value={section}
        onChange={setSection}
        items={[
          { value: "general", label: "General" },
          { value: "rates", label: "Shipping rates" },
          { value: "payments", label: "Payment methods" },
          { value: "users", label: "Users" },
          { value: "activity", label: "Team activity" },
        ]}
      />

      {section === "users" && <StaffUsers />}
      {section === "activity" && <SettingsActivity />}

      {section === "general" && (
        <div className="space-y-5">
          <BusinessSetup />
          <Panel
            title="Currency and reporting"
            description="The business accepts BDT and CNY. Combined reports are displayed in BDT."
          >
            <DetailGrid
              items={[
                {
                  label: "Transaction currencies",
                  value: "BDT · Bangladeshi taka / CNY · Chinese yuan",
                },
                { label: "Report currency", value: "BDT · Bangladeshi taka" },
              ]}
            />
          </Panel>
          <div id="operating-defaults" />
          <Panel title="Operating defaults">
            <form
              onSubmit={(event) => {
                event.preventDefault();
                void saveGeneral();
              }}
              className="space-y-6"
            >
              <FormSection
                title="Default exchange rate"
                description="Used for new CNY entries and current account valuations. Saved transactions and shipment prices retain their original exchange rates."
              >
                <FormGrid>
                  <Input
                    label="BDT per 1 CNY"
                    inputMode="decimal"
                    value={rate}
                    onChange={(value) => {
                      dirty.current.rate = true;
                      setRate(value);
                    }}
                    disabled={saving !== null}
                  />
                  <div className="self-end pb-2 text-sm text-muted-foreground">
                    1 CNY = {rate || "—"} BDT
                  </div>
                </FormGrid>
              </FormSection>
              <FormSection
                title="Weight discrepancy alerts"
                description="Flag shipments when the Bangladesh measured weight differs from the China booked weight by at least this amount."
              >
                <FormGrid>
                  <Input
                    label="Weight difference threshold (kg)"
                    inputMode="decimal"
                    value={threshold}
                    onChange={(value) => {
                      dirty.current.threshold = true;
                      setThreshold(value);
                    }}
                    disabled={saving !== null}
                  />
                </FormGrid>
              </FormSection>
              <FormActions>
                <Button type="submit" disabled={saving !== null}>
                  {saving === "general" ? "Saving…" : "Save general settings"}
                </Button>
              </FormActions>
            </form>
          </Panel>
        </div>
      )}

      {section === "rates" && (
        <Panel
          title="Per-piece shipping rates"
          description="Default charges for device categories, added to the shipment’s weight charge. Each shipment can override these rates."
          actions={
            <Button
              variant="secondary"
              disabled={saving !== null}
              onClick={() => setCategoryOpen(true)}
            >
              <Plus size={16} /> Add category
            </Button>
          }
        >
          <form
            onSubmit={(event) => {
              event.preventDefault();
              void savePcsRates();
            }}
            className="space-y-5"
          >
            <CurrencyFields
              disabled={saving !== null}
              entry={{
                ...pcsEntry,
                setRate: (value) => {
                  dirty.current.pcsRates = true;
                  pcsEntry.setRate(value);
                },
                setCurrency: (currency) => {
                  const nextRate =
                    currency === "BDT" ? 1 : Number(pcsEntry.rateText);
                  if (!(nextRate > 0)) return;
                  dirty.current.pcsRates = true;
                  setPcsRates((current) =>
                    Object.fromEntries(
                      Object.entries(current).map(([category, value]) => [
                        category,
                        String(
                          Math.round(
                            (pcsEntry.toBdt(Number(value) || 0) / nextRate) *
                              100,
                          ) / 100,
                        ),
                      ]),
                    ),
                  );
                  if (newPcsRate.trim())
                    setNewPcsRate(
                      String(
                        Math.round(
                          (pcsEntry.toBdt(Number(newPcsRate) || 0) / nextRate) *
                            100,
                        ) / 100,
                      ),
                    );
                  pcsEntry.setCurrency(currency);
                },
              }}
            />
            <SectionNotice>
              Enter rates in BDT or CNY. Saving converts the defaults to BDT.
              Category additions and removals take effect when you save shipping
              rates.
            </SectionNotice>
            {Object.keys(pcsRates).length ? (
              <div className="data-table">
                <table>
                  <thead>
                    <tr>
                      <th>Category</th>
                      <th>Charge per piece · {pcsEntry.currency}</th>
                      {pcsEntry.currency === "CNY" && (
                        <th className="text-right">BDT equivalent</th>
                      )}
                      <th className="text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {Object.entries(pcsRates).map(([category, value]) => (
                      <tr key={category}>
                        <td className="font-medium">{category}</td>
                        <td>
                          <Input
                            className="max-w-52"
                            inputMode="decimal"
                            value={value}
                            onChange={(next) => {
                              dirty.current.pcsRates = true;
                              setPcsRates((current) => ({
                                ...current,
                                [category]: next,
                              }));
                            }}
                            aria-label={`${category} rate in ${pcsEntry.currency} per piece`}
                            disabled={saving !== null}
                          />
                        </td>
                        {pcsEntry.currency === "CNY" && (
                          <td className="text-right tabular-nums">
                            {fmtBdt(pcsEntry.toBdt(Number(value) || 0))}
                          </td>
                        )}
                        <td className="text-right">
                          <Button
                            variant="ghost"
                            size="sm"
                            disabled={saving !== null}
                            aria-label={`Remove ${category} category`}
                            onClick={() => {
                              dirty.current.pcsRates = true;
                              setPcsRates((current) =>
                                Object.fromEntries(
                                  Object.entries(current).filter(
                                    ([key]) => key !== category,
                                  ),
                                ),
                              );
                            }}
                          >
                            Remove
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <EmptyState
                title="No per-piece rates"
                description="Add a category to set its default price. Categories without a rate start at BDT 0 per piece."
              />
            )}
            <FormActions>
              <Button
                type="submit"
                disabled={saving !== null || !pcsEntry.valid}
              >
                {saving === "rates" ? "Saving…" : "Save shipping rates"}
              </Button>
            </FormActions>
          </form>
        </Panel>
      )}

      {section === "payments" && (
        <div className="space-y-5">
          <SectionNotice>
            Visible methods appear on customer tracking pages for payment and
            receipt upload. Each method is linked to an account in{" "}
            <Link
              className="font-medium text-primary"
              to="/finance?tab=accounts"
            >
              Finance
            </Link>
            .
          </SectionNotice>
          <Panel
            title="Customer payment methods"
            description="Manage where customers send their payments."
            actions={
              <Button onClick={startAdd}>
                <Plus size={16} /> Add payment method
              </Button>
            }
          >
            <div className="mb-5 max-w-lg">
              <Input
                label="Search payment methods"
                leftIcon={<Search size={16} />}
                placeholder="Search provider, account or currency"
                value={methodQuery}
                onChange={setMethodQuery}
              />
            </div>
            {payError ? (
              <ErrorBlock message={payError} />
            ) : payLoading ? (
              <LoadingBlock />
            ) : methods.length ? (
              <div className="data-table">
                <table>
                  <thead>
                    <tr>
                      <th>Payment method</th>
                      <th>Type</th>
                      <th>Currency</th>
                      <th>Customer visibility</th>
                      <th className="text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {methods.map((method) => (
                      <tr key={method.id}>
                        <td>
                          <div className="flex items-start gap-3">
                            {method.qrImage && (
                              <img
                                src={method.qrImage}
                                alt={`${methodTitle(method)} payment QR`}
                                className="size-12 shrink-0 border border-border bg-white object-contain"
                              />
                            )}
                            <div>
                              <p className="font-medium">
                                {methodTitle(method)}
                              </p>
                              <p className="mt-1 text-xs text-muted-foreground">
                                {methodSummary(method)}
                              </p>
                            </div>
                          </div>
                        </td>
                        <td>
                          {method.kind === "mobile_banking"
                            ? "Mobile banking"
                            : "Bank account"}
                        </td>
                        <td>{method.currency}</td>
                        <td>{method.enabled ? "Visible" : "Hidden"}</td>
                        <td>
                          <div className="flex flex-wrap justify-end gap-2">
                            <Button
                              variant="secondary"
                              size="sm"
                              aria-label={`Edit ${methodTitle(method)}`}
                              onClick={() => startEdit(method)}
                            >
                              Edit
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              disabled={visibilityBusy !== null}
                              aria-label={`${method.enabled ? "Hide" : "Show"} ${methodTitle(method)} to customers`}
                              onClick={() => void toggleMethod(method)}
                            >
                              {visibilityBusy === method.id
                                ? "Updating…"
                                : method.enabled
                                  ? "Hide"
                                  : "Show"}
                            </Button>
                            <Button
                              variant="danger-outline"
                              size="sm"
                              aria-label={`Delete ${methodTitle(method)}`}
                              onClick={() => setDeleting(method)}
                            >
                              Delete
                            </Button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <EmptyState
                title={
                  methodQuery
                    ? "No matching payment methods"
                    : "No payment methods added"
                }
                description={
                  methodQuery
                    ? "Try another provider, account name or currency."
                    : "Add a payment method so customers can see where to pay."
                }
              />
            )}
          </Panel>
        </div>
      )}

      <Modal open={categoryOpen} onClose={() => setCategoryOpen(false)}>
        <h2 className="text-xl font-semibold">Add shipping category</h2>
        <p className="mt-2 mb-6 text-sm text-muted-foreground">
          Create a per-piece rate in {pcsEntry.currency}. Save shipping rates
          after adding the category.
        </p>
        <form
          onSubmit={(event) => {
            event.preventDefault();
            addCategory();
          }}
        >
          <FormGrid>
            <Input
              label="Category name"
              required
              maxLength={60}
              placeholder="e.g. Mobile or Laptop"
              value={newPcsCat}
              onChange={setNewPcsCat}
            />
            <Input
              label={`Charge per piece (${pcsEntry.currency})`}
              required
              inputMode="decimal"
              value={newPcsRate}
              onChange={setNewPcsRate}
            />
          </FormGrid>
          <FormActions>
            <Button variant="secondary" onClick={() => setCategoryOpen(false)}>
              Cancel
            </Button>
            <Button type="submit">Add category</Button>
          </FormActions>
        </form>
      </Modal>

      <Modal
        open={methodOpen}
        onClose={() => {
          if (!methodBusy) setMethodOpen(false);
        }}
        className="max-w-3xl"
      >
        <h2 className="text-xl font-semibold">
          {editingId ? "Edit payment method" : "Add payment method"}
        </h2>
        <p className="mt-2 mb-6 text-sm text-muted-foreground">
          Add the payment details customers need. Saving also updates the linked
          finance account.
        </p>
        <form
          onSubmit={(event) => {
            event.preventDefault();
            void submitMethod();
          }}
          className="space-y-6"
        >
          <FormSection title="Method and currency">
            <FormGrid>
              <label className="flex flex-col gap-2 text-xs font-medium text-muted-foreground">
                Payment method type
                <select
                  aria-label="Payment method type"
                  className="form-control"
                  value={kind}
                  disabled={methodBusy}
                  onChange={(event) =>
                    setKind(event.target.value as PayMethodKind)
                  }
                >
                  <option value="mobile_banking">Mobile banking</option>
                  <option value="bank_account">Bank account</option>
                </select>
              </label>
              <label className="flex flex-col gap-2 text-xs font-medium text-muted-foreground">
                Account currency
                <select
                  aria-label="Payment account currency"
                  className="form-control"
                  value={form.currency}
                  disabled={!!editingId || methodBusy}
                  onChange={(event) =>
                    setForm((current) => ({
                      ...current,
                      currency: event.target.value as "BDT" | "CNY",
                    }))
                  }
                >
                  <option value="BDT">BDT · Taka</option>
                  <option value="CNY">CNY · Yuan</option>
                </select>
              </label>
            </FormGrid>
            {editingId && (
              <p className="mt-3 text-xs text-muted-foreground">
                The currency is fixed for this linked account. Create a separate
                method for another currency.
              </p>
            )}
          </FormSection>
          {kind === "mobile_banking" ? (
            <>
              <FormSection title="Mobile payment details">
                <FormGrid>
                  <Input
                    label="Provider"
                    required
                    maxLength={60}
                    placeholder="e.g. bKash, Nagad or Alipay"
                    value={form.provider}
                    onChange={set("provider")}
                    disabled={methodBusy}
                  />
                  <Input
                    label="Account label"
                    maxLength={80}
                    placeholder="e.g. Merchant or Personal"
                    value={form.label}
                    onChange={set("label")}
                    disabled={methodBusy}
                  />
                  <Input
                    label="Payment number"
                    required
                    maxLength={80}
                    value={form.number}
                    onChange={set("number")}
                    disabled={methodBusy}
                  />
                  <Input
                    label="Customer instructions"
                    maxLength={200}
                    placeholder="Payment reference: {code}"
                    value={form.note}
                    onChange={set("note")}
                    disabled={methodBusy}
                  />
                </FormGrid>
                <p className="mt-3 text-xs text-muted-foreground">
                  Use {"{code}"} in the instructions to insert the customer’s
                  shipment number.
                </p>
              </FormSection>
              <FormSection
                title="Payment QR image"
                description="Optional PNG, JPEG or WebP image, up to 300 KB. SVG files are not accepted. Without an uploaded image, the tracking page generates a QR from the payment number."
              >
                <input
                  ref={fileRef}
                  type="file"
                  accept="image/png,image/jpeg,image/webp"
                  className="hidden"
                  aria-label="Payment QR image"
                  onChange={(event) => {
                    pickQr(event.target.files?.[0]);
                    event.target.value = "";
                  }}
                />
                <div className="flex flex-wrap items-center gap-3">
                  {form.qrImage && (
                    <img
                      src={form.qrImage}
                      alt="Payment QR preview"
                      className="size-24 border border-border bg-white object-contain p-2"
                    />
                  )}
                  <Button
                    variant="secondary"
                    disabled={methodBusy}
                    onClick={() => fileRef.current?.click()}
                  >
                    {form.qrImage ? "Replace QR image" : "Upload QR image"}
                  </Button>
                  {form.qrImage && (
                    <Button
                      variant="ghost"
                      disabled={methodBusy}
                      onClick={() =>
                        setForm((current) => ({ ...current, qrImage: null }))
                      }
                    >
                      Remove image
                    </Button>
                  )}
                </div>
              </FormSection>
            </>
          ) : (
            <FormSection title="Bank account details">
              <FormGrid>
                <Input
                  label="Bank name"
                  required
                  placeholder="e.g. City Bank"
                  value={form.bankName}
                  onChange={set("bankName")}
                  disabled={methodBusy}
                />
                <Input
                  label="Account holder name"
                  required
                  value={form.accountName}
                  onChange={set("accountName")}
                  disabled={methodBusy}
                />
                <Input
                  label="Account number"
                  required
                  value={form.accountNumber}
                  onChange={set("accountNumber")}
                  disabled={methodBusy}
                />
                <Input
                  label="Branch"
                  value={form.branch}
                  onChange={set("branch")}
                  disabled={methodBusy}
                />
                <Input
                  label="District"
                  value={form.district}
                  onChange={set("district")}
                  disabled={methodBusy}
                />
              </FormGrid>
            </FormSection>
          )}
          <FormActions>
            <Button
              variant="secondary"
              disabled={methodBusy}
              onClick={() => setMethodOpen(false)}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={methodBusy}>
              {methodBusy
                ? "Saving…"
                : editingId
                  ? "Save changes"
                  : "Add payment method"}
            </Button>
          </FormActions>
        </form>
      </Modal>

      <ConfirmDialog
        open={deleting !== null}
        onClose={() => setDeleting(null)}
        title={`Delete ${deleting ? methodTitle(deleting) : ""}?`}
        body="It disappears from every tracking page immediately. Receipts already uploaded with this method keep their record."
        onConfirm={async () => {
          if (!deleting) return;
          try {
            await api.delete(`/settings/pay-methods/${deleting.id}`);
            showToast({ title: "Payment method deleted", status: "success" });
            await reloadMethods();
          } catch (problem) {
            fail(problem);
          }
        }}
      />
    </div>
  );
}
