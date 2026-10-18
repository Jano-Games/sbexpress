import {
  ShipmentOperations,
  DeliveryBooking,
} from "@/components/ShipmentOperations";
import {
  Panel,
  FormGrid,
  FormActions,
  DetailGrid,
  SectionNotice,
} from "@/components/DesignSystem";
import { Modal } from "@/components/Modal";
import {
  MoneyInput,
  useMoneyEntry,
  nativeMoney,
} from "@/components/MoneyInput";
import { PageTabs, usePageSection } from "@/components/Workspace";
import { InvoiceHistory } from "@/components/CustomerCredit";
import { ShipmentMedia } from "@/components/ShipmentMedia";
import { ShipmentCosts } from "@/components/ShipmentCosts";
import { ShipmentBilling } from "@/components/ShipmentBilling";
import { useState, useRef } from "react";
import { Plane, UserRound, Weight, CircleCheck } from "lucide-react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { api } from "@/api/client";
import { useFetch } from "@/state/useFetch";
import { useAuth } from "@/state/auth";
import type { ShipmentDetail as Detail } from "@/api/types";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/beui/select";
import { useToast } from "@/components/beui/toast";
import {
  Chip,
  ErrorBlock,
  Field,
  LoadingBlock,
  PIPELINE_LABELS,
  StatusChip,
  Stepper,
} from "@/components/ui";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { NewShipmentModal } from "@/modals/NewShipmentModal";
import { ShipmentInvoiceModal } from "@/modals/ShipmentInvoiceModal";
import { TrackLinkModal } from "@/modals/TrackLinkModal";
import {
  PAY_CHIP,
  PAY_LABEL,
  deltaLabel,
  fmtBdt,
  fmtDate,
  fmtLogAt,
  supplierLabel,
} from "@/lib/format";

export function ShipmentDetail() {
  const { code = "" } = useParams();
  const { user } = useAuth();
  const { showToast } = useToast();
  const navigate = useNavigate();
  const { data, error, loading, reload } = useFetch<{ shipment: Detail }>(
    `/shipments/${code}`,
  );

  const actionLock = useRef(false);
  const [busy, setBusy] = useState(false);
  const [section, setSection] = usePageSection(
    "overview",
    user?.role === "admin"
      ? ["overview", "handling", "billing", "costs", "media", "history"]
      : ["overview", "handling", "media", "history"],
  );
  const [billingAction, setBillingAction] = useState<
    "payment" | "credit" | null
  >(null);
  const { data: paymentAccounts } = useFetch<{ accounts: { name: string }[] }>(
    user?.role === "admin" && billingAction === "payment"
      ? "/finance/accounts"
      : null,
  );
  const paymentEntry = useMoneyEntry(
    undefined,
    false,
    billingAction === "payment",
  );
  const creditEntry = useMoneyEntry(
    undefined,
    false,
    billingAction === "credit",
  );
  const [invoiceOpen, setInvoiceOpen] = useState(false);
  const [trackOpen, setTrackOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [weighInput, setWeighInput] = useState("");
  const [creditAmount, setCreditAmount] = useState("");
  const [creditReason, setCreditReason] = useState("");
  const [packageCount, setPackageCount] = useState("1");
  const [payAmt, setPayAmt] = useState("");
  const [payMethod, setPayMethod] = useState("");

  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  const s = data.shipment;
  const isAdmin = user?.role === "admin";
  const isStaff = isAdmin || user?.role === "hub";
  const canAdvance =
    s.statusIndex < 6 &&
    !s.exception &&
    (isAdmin || (user?.role === "hub" && s.statusIndex >= 4)) &&
    !(s.statusIndex === 2 && (!s.flightCode || !s.flyerName)) &&
    !(s.statusIndex === 5 && !s.packedAt) &&
    !(s.statusIndex >= 6 && !s.lastMile);
  const nextTitle =
    s.statusIndex === 8
      ? "Shipment delivered"
      : s.statusIndex === 2 && (!s.flightCode || !s.flyerName)
        ? "Assign a flight and carrying flyer"
        : s.statusIndex === 5
          ? "Weigh and pack at the Dhaka hub"
          : s.statusIndex === 6
            ? "Book the courier or confirm pickup"
            : `Next: ${PIPELINE_LABELS[s.statusIndex + 1]}`;
  const nextDescription =
    s.statusIndex === 8
      ? "Delivery is complete. Check Billing for any outstanding balance."
      : s.statusIndex === 2 && (!s.flightCode || !s.flyerName)
        ? "Choose the flight and the person carrying this cargo before dispatch."
        : s.statusIndex === 5
          ? "Record the measured weight, then confirm the number of packages."
          : s.statusIndex === 6
            ? "Save the delivery booking, then confirm dispatch or hub collection when it happens."
            : "Confirm that this step is complete before updating the shipment.";

  const act = (fn: () => Promise<unknown>, success?: string) => async () => {
    if (actionLock.current) return;
    actionLock.current = true;
    setBusy(true);
    try {
      await fn();
      if (success) showToast({ title: success, status: "success" });
      await reload();
    } catch (e) {
      showToast({
        title: e instanceof Error ? e.message : "Failed",
        status: "error",
      });
    } finally {
      actionLock.current = false;
      setBusy(false);
    }
  };

  return (
    <div className="space-y-5">
      <Link
        to="/shipments"
        className="inline-block text-sm text-muted-foreground hover:text-primary"
      >
        ← Shipments
      </Link>
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <div className="flex flex-wrap items-center gap-3">
            <h1 className="text-2xl font-semibold">{s.code}</h1>
            <StatusChip index={s.statusIndex} label={s.statusLabel} />
            <Chip colors={PAY_CHIP[s.payStatus] ?? PAY_CHIP.unpaid!}>
              {PAY_LABEL[s.payStatus]}
            </Chip>
          </div>
          <p className="mt-2 text-sm text-muted-foreground">
            {supplierLabel(s.supplierCode, s.supplierName)} · Created{" "}
            {fmtDate(s.date)}
          </p>
        </div>
        {isAdmin && (
          <div className="flex flex-wrap gap-2">
            <Button variant="secondary" onClick={() => setTrackOpen(true)}>
              Share link
            </Button>
            <Button onClick={() => setEditOpen(true)}>Edit shipment</Button>
            <Button
              variant="danger-outline"
              onClick={() => setDeleteOpen(true)}
            >
              Delete
            </Button>
          </div>
        )}
      </header>
      <section
        className="shipment-status"
        aria-labelledby="shipment-status-heading"
      >
        <header className="shipment-status-header">
          <div>
            <p id="shipment-status-heading">Shipment status</p>
            <h2 className={s.statusIndex === 8 ? "is-delivered" : ""}>
              {s.statusIndex === 8 && (
                <CircleCheck size={20} aria-hidden="true" />
              )}
              {s.statusLabel}
            </h2>
          </div>
          <div className="shipment-status-next">
            <span>
              {s.statusIndex === 8 ? "Journey complete" : "Next checkpoint"}
            </span>
            <strong>
              {s.statusIndex === 8
                ? "Delivered to recipient"
                : PIPELINE_LABELS[s.statusIndex + 1]}
            </strong>
          </div>
        </header>
        <div className="shipment-status-journey">
          <Stepper steps={PIPELINE_LABELS} current={s.statusIndex} />
        </div>
        <dl className="shipment-status-details">
          <div>
            <Plane size={18} aria-hidden="true" />
            <div>
              <dt>Flight</dt>
              <dd>
                {s.flightCode && isAdmin ? (
                  <Link
                    to={`/flights/${s.flightCode}`}
                    className="text-primary"
                  >
                    {s.flightCode}
                  </Link>
                ) : (
                  (s.flightCode ?? "Unassigned")
                )}
              </dd>
            </div>
          </div>
          <div>
            <UserRound size={18} aria-hidden="true" />
            <div>
              <dt>Carrying flyer</dt>
              <dd>{s.flyerName ?? "Unassigned"}</dd>
            </div>
          </div>
          <div>
            <Weight size={18} aria-hidden="true" />
            <div>
              <dt>
                {s.weighedKg !== null ? "Measured weight" : "Booked weight"}
              </dt>
              <dd>{s.weighedKg ?? s.bookedKg} kg</dd>
            </div>
          </div>
        </dl>
      </section>
      <PageTabs
        value={section}
        onChange={setSection}
        items={[
          { value: "overview", label: "Details" },
          { value: "handling", label: "Handling & delivery" },
          ...(isAdmin
            ? [
                { value: "billing", label: "Billing" },
                { value: "costs", label: "Costs" },
              ]
            : []),
          { value: "media", label: "Attachments" },
          { value: "history", label: "Activity" },
        ]}
      />
      {["overview", "handling"].includes(section) && (
        <ShipmentOperations shipment={s} admin={isAdmin} onChanged={reload} />
      )}
      {["overview", "handling"].includes(section) && (
        <Panel
          title={nextTitle}
          description={nextDescription}
          actions={
            s.statusIndex === 8 ? (
              <Button
                variant="secondary"
                onClick={() => setSection(isAdmin ? "billing" : "history")}
              >
                Review {isAdmin ? "billing" : "activity"}
              </Button>
            ) : s.statusIndex === 2 &&
              (!s.flightCode || !s.flyerName) &&
              isAdmin ? (
              <Button onClick={() => setEditOpen(true)}>
                Assign flight & flyer
              </Button>
            ) : s.statusIndex === 5 ||
              s.statusIndex === 6 ||
              s.statusIndex === 7 ? (
              section !== "handling" ? (
                <Button onClick={() => setSection("handling")}>
                  Open handling
                </Button>
              ) : null
            ) : canAdvance ? (
              <Button
                disabled={busy}
                onClick={act(
                  () => api.post(`/shipments/${s.code}/advance`),
                  "Status updated",
                )}
              >
                {busy
                  ? "Saving…"
                  : `Confirm ${PIPELINE_LABELS[s.statusIndex + 1]}`}
              </Button>
            ) : null
          }
        >
          <p className="text-sm text-muted-foreground">
            Current stage: {s.statusLabel}
          </p>
        </Panel>
      )}
      {s.weightDelta !== null &&
        ["overview", "handling", "billing"].includes(section) && (
          <SectionNotice tone="warning">
            Measured weight is {s.weighedKg} kg; booked weight is {s.bookedKg}{" "}
            kg ({deltaLabel(s.weightDelta)}). Verify this difference with the
            China hub before billing.
          </SectionNotice>
        )}
      {section === "overview" && (
        <div className="space-y-5">
          <Panel title="Cargo information">
            <DetailGrid
              columns={3}
              items={[
                {
                  label: "Customer",
                  value: supplierLabel(s.supplierCode, s.supplierName),
                },
                {
                  label: "Categories",
                  value: s.categories.join(", ") || "Not specified",
                },
                {
                  label: "Description",
                  value: s.description || "Not specified",
                },
                { label: "Booked weight", value: `${s.bookedKg} kg` },
                {
                  label: "Measured weight",
                  value:
                    s.weighedKg !== null ? `${s.weighedKg} kg` : "Not weighed",
                },
                { label: "Packages", value: s.packageCount || "Not packed" },
                {
                  label: "Serial numbers / IMEI",
                  value: s.serials.join(", ") || "None recorded",
                },
                {
                  label: "Delivery service",
                  value: s.lastMile?.courier ?? "Not booked",
                },
                {
                  label: "Delivery reference",
                  value: s.lastMile?.ref ?? "Not booked",
                },
              ]}
            />
          </Panel>
          {s.pcsItems.length > 0 && (
            <Panel title="Items billed per piece">
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm">
                  <thead className="border-b border-border text-xs text-muted-foreground">
                    <tr>
                      <th className="py-3 font-medium">Category</th>
                      <th className="py-3 font-medium">Quantity</th>
                      <th className="py-3 text-right font-medium">
                        Rate per piece
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {s.pcsItems.map((item, i) => (
                      <tr key={i}>
                        <td className="py-3">{item.category}</td>
                        <td className="py-3">{item.count}</td>
                        <td className="py-3 text-right">
                          {nativeMoney(item.rate, item.currency)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Panel>
          )}
        </div>
      )}
      {section === "handling" && isStaff && (
        <fieldset disabled={busy || !!s.exception} className="space-y-5">
          <Panel
            title="1. Weigh the shipment"
            description={
              s.statusIndex < 5
                ? "Available when the shipment reaches the Dhaka hub."
                : s.statusIndex >= 7
                  ? "Weight and packing are locked after dispatch."
                  : "Record the actual weight before confirming packing."
            }
          >
            <FormGrid>
              <Input
                label="Measured weight (kg)"
                placeholder={s.weighedKg !== null ? String(s.weighedKg) : "0.0"}
                inputMode="decimal"
                value={weighInput}
                onChange={setWeighInput}
              />
              <div className="flex items-end">
                <Button
                  disabled={
                    busy ||
                    ![5, 6].includes(s.statusIndex) ||
                    !weighInput.trim()
                  }
                  onClick={act(async () => {
                    const value = parseFloat(weighInput);
                    if (!Number.isFinite(value) || value < 0)
                      throw new Error("Enter a valid weight");
                    await api.post(`/shipments/${s.code}/weigh`, { kg: value });
                    setWeighInput("");
                  }, "Weight saved")}
                >
                  Save measured weight
                </Button>
              </div>
            </FormGrid>
          </Panel>
          <Panel
            title="2. Confirm packing"
            description="Check the measured weight, then enter the final package count."
          >
            <FormGrid>
              <Input
                label="Number of packages"
                type="number"
                min={1}
                value={packageCount}
                onChange={setPackageCount}
              />
              <div className="flex items-end">
                <Button
                  disabled={
                    busy ||
                    s.weighedKg === null ||
                    ![5, 6].includes(s.statusIndex)
                  }
                  onClick={act(
                    () =>
                      api.post(`/shipments/${s.code}/pack`, {
                        count: Number(packageCount),
                      }),
                    "Packing confirmed",
                  )}
                >
                  Confirm packing
                </Button>
              </div>
            </FormGrid>
            <p className="mt-3 text-sm text-muted-foreground">
              {s.packedAt
                ? `${s.packageCount} packages confirmed.`
                : "Packing is not yet confirmed."}
            </p>
          </Panel>
          <DeliveryBooking shipment={s} onChanged={reload} />
        </fieldset>
      )}
      {section === "billing" && isAdmin && (
        <ShipmentBilling
          key={s.code}
          shipment={s}
          onPayment={() => setBillingAction("payment")}
          onCredit={() => setBillingAction("credit")}
          onInvoice={() => setInvoiceOpen(true)}
          onChanged={reload}
        />
      )}
      {section === "costs" && isAdmin && (
        <ShipmentCosts key={s.code} shipment={s} onSaved={reload} />
      )}
      {section === "media" && <ShipmentMedia code={code} admin={isAdmin} />}
      {section === "history" && (
        <div className="space-y-5">
          <Panel title="Activity log">
            {s.log.length ? (
              <ol className="divide-y divide-border">
                {s.log.map((entry, i) => (
                  <li key={i} className="py-4 first:pt-0 last:pb-0">
                    <p className="text-sm">{entry.message}</p>
                    <p className="mt-1 text-xs text-muted-foreground">
                      {entry.actor} · {fmtLogAt(entry.at)}
                    </p>
                  </li>
                ))}
              </ol>
            ) : (
              <p className="text-sm text-muted-foreground">
                No activity recorded.
              </p>
            )}
          </Panel>
          {isAdmin && <InvoiceHistory key={JSON.stringify(s)} code={code} />}
        </div>
      )}

      <Modal
        open={billingAction !== null}
        onClose={() => {
          if (!busy) setBillingAction(null);
        }}
      >
        <h2 className="text-xl font-semibold">
          {billingAction === "payment"
            ? "Record customer payment"
            : "Issue customer credit"}
        </h2>
        <p className="mt-2 mb-6 text-sm text-muted-foreground">
          {s.code} · Outstanding {fmtBdt(s.dueAmount)}
        </p>
        <fieldset disabled={busy || !!s.exception} className="space-y-5">
          {billingAction === "payment" ? (
            <>
              <MoneyInput
                entry={paymentEntry}
                label="Amount received"
                value={payAmt}
                onChange={setPayAmt}
              />
              <Field label="Receiving account">
                <Select value={payMethod} onValueChange={setPayMethod}>
                  <SelectTrigger aria-label="Receiving account">
                    <SelectValue placeholder="Select account" />
                  </SelectTrigger>
                  <SelectContent>
                    {(paymentAccounts?.accounts ?? []).map((account) => (
                      <SelectItem key={account.name} value={account.name}>
                        {account.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>
              <FormActions>
                <Button
                  variant="secondary"
                  onClick={() => setBillingAction(null)}
                >
                  Cancel
                </Button>
                <Button
                  disabled={busy || !paymentEntry.valid || !payMethod}
                  onClick={act(async () => {
                    const amount = parseFloat(payAmt);
                    if (!Number.isFinite(amount) || amount <= 0)
                      throw new Error("Enter the amount received");
                    await api.post(`/shipments/${s.code}/payments`, {
                      ...paymentEntry.meta,
                      amount,
                      method: payMethod,
                    });
                    setPayAmt("");
                    setBillingAction(null);
                  }, "Payment recorded")}
                >
                  {busy ? "Saving…" : "Record payment"}
                </Button>
              </FormActions>
            </>
          ) : (
            <>
              <MoneyInput
                entry={creditEntry}
                label="Credit amount"
                value={creditAmount}
                onChange={setCreditAmount}
              />
              <Input
                label="Reason for credit"
                value={creditReason}
                onChange={setCreditReason}
              />
              <FormActions>
                <Button
                  variant="secondary"
                  onClick={() => setBillingAction(null)}
                >
                  Cancel
                </Button>
                <Button
                  disabled={busy || !creditEntry.valid || !creditReason.trim()}
                  onClick={act(async () => {
                    await api.post(`/shipments/${s.code}/after-sales`, {
                      ...creditEntry.meta,
                      amount: Number(creditAmount),
                      reason: creditReason,
                    });
                    setBillingAction(null);
                    setCreditAmount("");
                    setCreditReason("");
                  }, "Credit applied")}
                >
                  {busy ? "Saving…" : "Issue credit"}
                </Button>
              </FormActions>
            </>
          )}
        </fieldset>
      </Modal>
      <ShipmentInvoiceModal
        open={invoiceOpen}
        onClose={() => setInvoiceOpen(false)}
        code={s.code}
        onSaved={() => void reload()}
      />
      <TrackLinkModal
        open={trackOpen}
        onClose={() => setTrackOpen(false)}
        code={s.code}
      />
      <NewShipmentModal
        open={editOpen}
        onClose={() => setEditOpen(false)}
        editing={s}
        onDone={() => void reload()}
      />
      <ConfirmDialog
        open={deleteOpen}
        onClose={() => setDeleteOpen(false)}
        title={`Delete ${s.code}?`}
        body="Only an unused shipment without payments, applied credit, invoices or receipts can be deleted. This permanently removes its details and tracking links."
        onConfirm={async () => {
          try {
            await api.delete(`/shipments/${s.code}`);
            showToast({ title: `${s.code} deleted`, status: "success" });
            navigate("/shipments");
          } catch (error) {
            showToast({
              title: error instanceof Error ? error.message : "Failed",
              status: "error",
            });
          }
        }}
      />
    </div>
  );
}
