import { useEffect, useState } from "react";
import { Plus, Trash2 } from "lucide-react";
import { api } from "@/api/client";
import type { ShipmentInvoice } from "@/api/types";
import {
  CurrencyFields,
  useMoneyEntry,
  nativeMoney,
} from "@/components/MoneyInput";
import { InvoicePdfActions } from "@/components/InvoicePdfActions";
import {
  DetailGrid,
  FormActions,
  FormGrid,
  FormSection,
  SectionNotice,
} from "@/components/DesignSystem";
import { TrackLinkModal } from "./TrackLinkModal";
import { Modal } from "@/components/Modal";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import { useToast } from "@/components/beui/toast";
import { fmtBdt, fmtDate } from "@/lib/format";

type LineDraft = { label: string; amount: string; costId?: string };

/** Invoice drafts and saved invoices share one editor; monetary snapshots stay attached to the saved invoice. */
export function ShipmentInvoiceModal({
  open,
  onClose,
  code,
  onSaved,
}: {
  open: boolean;
  onClose: () => void;
  code: string;
  onSaved: () => void;
}) {
  const entry = useMoneyEntry(undefined, false, open);
  const { showToast } = useToast();
  const [sharing, setSharing] = useState(false);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [saved, setSaved] = useState(false);
  const [invoice, setInvoice] = useState<ShipmentInvoice | null>(null);
  const [pricingMode, setPricingMode] = useState("automatic");
  const [revisionReason, setRevisionReason] = useState("");
  const [confirmFree, setConfirmFree] = useState(false);
  const issued = invoice?.state === "issued";
  const [loadError, setLoadError] = useState("");
  const [header, setHeader] = useState<Pick<
    ShipmentInvoice,
    "number" | "to" | "issuedAt"
  > | null>(null);
  const [lines, setLines] = useState<LineDraft[]>([]);
  const [discount, setDiscount] = useState("");
  const [note, setNote] = useState("");

  useEffect(() => {
    if (!open) return;
    let current = true;
    setLoading(true);
    setLoadError("");
    setHeader(null);
    api
      .get<{ saved: boolean; invoice: ShipmentInvoice }>(
        `/shipments/${code}/invoice`,
      )
      .then((response) => {
        if (!current) return;
        entry.restore(
          response.invoice.sourceCurrency ?? "BDT",
          response.invoice.sourceFxRate ?? 1,
        );
        setSaved(response.saved);
        setInvoice(response.invoice);
        setPricingMode(response.invoice.pricingMode);
        setRevisionReason("");
        setConfirmFree(false);
        setHeader({
          number: response.invoice.number,
          to: response.invoice.to,
          issuedAt: response.invoice.issuedAt,
        });
        setLines(
          response.invoice.lines.map((line) => ({
            label: line.label,
            costId: line.costId,
            amount: String(
              Math.round(
                (line.amount / (response.invoice.sourceFxRate || 1)) * 100,
              ) / 100,
            ),
          })),
        );
        setDiscount(
          response.invoice.discount
            ? String(
                Math.round(
                  (response.invoice.discount /
                    (response.invoice.sourceFxRate || 1)) *
                    100,
                ) / 100,
              )
            : "",
        );
        setNote(response.invoice.note);
      })
      .catch((error: unknown) => {
        if (current)
          setLoadError(
            error instanceof Error ? error.message : "Could not load invoice",
          );
      })
      .finally(() => {
        if (current) setLoading(false);
      });
    return () => {
      current = false;
    };
  }, [open, code]);

  const linesSum = lines.reduce(
    (sum, line) => sum + (parseFloat(line.amount) || 0),
    0,
  );
  const total = linesSum - (parseFloat(discount) || 0);

  async function save(state: "draft" | "issued" = "issued") {
    if (busy) return;
    const payload = {
      ...entry.meta,
      state,
      pricingMode,
      revisionReason,
      confirmFree,
      lines: lines
        .map((line) => ({
          label: line.label.trim(),
          costId: line.costId,
          amount: parseFloat(line.amount) || 0,
        }))
        .filter((line) => line.label),
      discount: parseFloat(discount) || 0,
      note: note.trim(),
    };
    if (!payload.lines.length) {
      showToast({
        title: "Add at least one line with a description",
        status: "error",
      });
      return;
    }
    setBusy(true);
    try {
      const response = await api.post<{ number: string }>(
        `/shipments/${code}/invoice`,
        payload,
      );
      showToast({
        title: `${response.number} ${state === "draft" ? "draft saved" : "issued"}`,
        status: "success",
      });
      onSaved();
      onClose();
    } catch (error) {
      showToast({
        title:
          error instanceof Error ? error.message : "Could not save invoice",
        status: "error",
      });
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <TrackLinkModal
        open={sharing}
        onClose={() => setSharing(false)}
        code={code}
        initialScope="invoice"
      />
      <Modal open={open && !sharing} onClose={onClose} className="max-w-3xl">
        <header className="mb-6">
          <h2 data-dialog-title className="text-xl font-semibold">
            {issued ? "Review / revise invoice" : "Prepare invoice"}
          </h2>
          <p className="mt-2 text-sm text-muted-foreground">Shipment {code}</p>
        </header>
        {loading ? (
          <p className="py-8 text-center text-sm text-muted-foreground">
            Loading invoice…
          </p>
        ) : loadError ? (
          <>
            <SectionNotice tone="danger">{loadError}</SectionNotice>
            <FormActions>
              <Button variant="secondary" onClick={onClose}>
                Close
              </Button>
            </FormActions>
          </>
        ) : (
          header && (
            <form
              className="space-y-6"
              onSubmit={(event) => {
                event.preventDefault();
                void save();
              }}
            >
              <DetailGrid
                columns={3}
                items={[
                  { label: "Invoice number", value: header.number },
                  { label: "Billed to", value: header.to },
                  {
                    label: issued ? "Issue date" : "State",
                    value: issued
                      ? fmtDate(header.issuedAt)
                      : "Draft · not payable",
                  },
                ]}
              />
              <SectionNotice
                tone={invoice?.needsReview ? "warning" : undefined}
              >
                {invoice?.needsReview
                  ? "Shipment pricing changed. Review the suggested breakdown and explicitly issue a revision. The previous invoice remains in history."
                  : issued
                    ? "Changes to an issued invoice are recorded as a revision. Explain any pricing change below."
                    : "This is a draft estimate. Review weight, rates and costs before issuing it. Customer payment opens only after issue."}
              </SectionNotice>
              <div className="flex flex-wrap gap-3">
                <Button
                  variant="secondary"
                  onClick={() => {
                    setLines(
                      (invoice?.suggestedLines ?? []).map((l) => ({
                        ...l,
                        amount: String(
                          Math.round((l.amount / entry.exchangeRate) * 100) /
                            100,
                        ),
                      })),
                    );
                  }}
                >
                  Load suggested breakdown
                </Button>
                <Button
                  variant="secondary"
                  onClick={() => {
                    setLines(
                      (invoice?.calculatedLines ?? []).map((l) => ({
                        ...l,
                        amount: String(
                          Math.round((l.amount / entry.exchangeRate) * 100) /
                            100,
                        ),
                      })),
                    );
                    setPricingMode("automatic");
                  }}
                >
                  Recalculate from shipment
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                {pricingMode === "automatic"
                  ? "Draft pricing follows shipment weight, rates and costs."
                  : "Manually agreed pricing. Later shipment changes will require review."}
              </p>
              <FormSection
                title="Invoice currency"
                description="The currency and agreed exchange rate are saved with this invoice."
              >
                <CurrencyFields
                  entry={{
                    ...entry,
                    setCurrency: (currency) => {
                      const nextRate =
                        currency === "BDT" ? 1 : Number(entry.rateText);
                      if (!nextRate) return;
                      const factor = entry.exchangeRate / nextRate;
                      setLines((rows) =>
                        rows.map((row) => ({
                          ...row,
                          amount: String(
                            Math.round(Number(row.amount) * factor * 100) / 100,
                          ),
                        })),
                      );
                      setDiscount(
                        String(
                          Math.round(Number(discount) * factor * 100) / 100,
                        ),
                      );
                      entry.setCurrency(currency);
                    },
                  }}
                  disabled={busy}
                />
              </FormSection>
              <FormSection
                title="Invoice items"
                description={`Enter all line amounts in ${entry.currency}. Use a negative amount for an adjustment.`}
              >
                <div className="space-y-4">
                  {lines.map((line, index) => (
                    <div
                      key={index}
                      className="grid items-end gap-3 border-b border-border pb-4 sm:grid-cols-[minmax(0,1fr)_150px_auto]"
                    >
                      <Input
                        label={`Item ${index + 1} · description`}
                        placeholder="Service or adjustment"
                        value={line.label}
                        onChange={(value) => {
                          setPricingMode("manual");
                          setLines((rows) =>
                            rows.map((row, rowIndex) =>
                              rowIndex === index
                                ? { ...row, label: value }
                                : row,
                            ),
                          );
                        }}
                        disabled={busy}
                      />
                      <Input
                        label={`Amount · ${entry.currency}`}
                        inputMode="decimal"
                        placeholder="0.00"
                        value={line.amount}
                        onChange={(value) => {
                          setPricingMode("manual");
                          setLines((rows) =>
                            rows.map((row, rowIndex) =>
                              rowIndex === index
                                ? { ...row, amount: value }
                                : row,
                            ),
                          );
                        }}
                        disabled={busy}
                      />
                      <Button
                        variant="secondary"
                        aria-label={`Remove invoice item ${index + 1}`}
                        disabled={busy}
                        onClick={() => {
                          setPricingMode("manual");
                          setLines((rows) =>
                            rows.filter((_, rowIndex) => rowIndex !== index),
                          );
                        }}
                      >
                        <Trash2 size={16} />
                        <span className="sm:sr-only">Remove item</span>
                      </Button>
                    </div>
                  ))}
                  <Button
                    variant="secondary"
                    disabled={busy}
                    onClick={() => {
                      setPricingMode("manual");
                      setLines((rows) => [...rows, { label: "", amount: "" }]);
                    }}
                  >
                    <Plus size={16} />
                    Add invoice item
                  </Button>
                </div>
              </FormSection>
              <FormSection title="Discount and notes">
                <FormGrid>
                  <Input
                    label={`Discount · ${entry.currency}`}
                    inputMode="decimal"
                    placeholder="0.00"
                    value={discount}
                    onChange={setDiscount}
                    disabled={busy}
                  />
                  <Input
                    label="Customer note (optional)"
                    placeholder="Additional invoice information"
                    value={note}
                    onChange={setNote}
                    disabled={busy}
                  />
                </FormGrid>
              </FormSection>
              <dl className="space-y-3 border-y border-border py-4 text-sm">
                <div className="flex justify-between gap-4">
                  <dt className="text-muted-foreground">Subtotal</dt>
                  <dd className="tabular-nums">
                    {nativeMoney(linesSum, entry.currency)}
                  </dd>
                </div>
                {parseFloat(discount) > 0 && (
                  <div className="flex justify-between gap-4">
                    <dt className="text-muted-foreground">Discount</dt>
                    <dd className="tabular-nums">
                      − {nativeMoney(parseFloat(discount), entry.currency)}
                    </dd>
                  </div>
                )}
                <div className="flex justify-between gap-4 text-lg font-semibold">
                  <dt>Invoice total</dt>
                  <dd className="tabular-nums">
                    {nativeMoney(total, entry.currency)}
                  </dd>
                </div>
                {entry.currency === "CNY" && (
                  <div className="flex justify-between gap-4 text-xs text-muted-foreground">
                    <dt>BDT equivalent</dt>
                    <dd className="tabular-nums">
                      {fmtBdt(entry.toBdt(total))}
                    </dd>
                  </div>
                )}
              </dl>
              {saved && issued && (
                <FormSection
                  title="Saved invoice document"
                  description="Save your edits before downloading or sharing the updated invoice."
                >
                  <InvoicePdfActions
                    path={`/shipments/${encodeURIComponent(code)}/invoice.pdf`}
                    filename={`invoice-${code}.pdf`}
                  />
                  <Button
                    className="mt-3"
                    variant="secondary"
                    disabled={busy}
                    onClick={() => setSharing(true)}
                  >
                    Share link
                  </Button>
                </FormSection>
              )}
              {issued && (
                <Input
                  label="Revision reason"
                  value={revisionReason}
                  onChange={setRevisionReason}
                  required
                  maxLength={500}
                />
              )}
              {total === 0 && (
                <label className="flex gap-3 text-sm">
                  <input
                    type="checkbox"
                    checked={confirmFree}
                    onChange={(e) => setConfirmFree(e.target.checked)}
                  />
                  Confirm this shipment is intentionally free of charge
                </label>
              )}
              <FormActions>
                <Button variant="secondary" onClick={onClose} disabled={busy}>
                  Cancel
                </Button>
                {!issued && (
                  <Button
                    variant="secondary"
                    disabled={busy || !entry.valid || total < 0}
                    onClick={() => void save("draft")}
                  >
                    Save draft
                  </Button>
                )}
                <Button
                  type="submit"
                  disabled={
                    busy ||
                    !entry.valid ||
                    total < 0 ||
                    (total === 0 && !confirmFree) ||
                    (issued && revisionReason.trim().length < 3)
                  }
                >
                  {busy
                    ? "Saving…"
                    : issued
                      ? "Issue revision"
                      : "Issue invoice"}
                </Button>
              </FormActions>
            </form>
          )
        )}
      </Modal>
    </>
  );
}
