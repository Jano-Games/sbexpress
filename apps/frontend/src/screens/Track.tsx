import { ReceiptHistory } from "@/components/ReceiptHistory";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { Link, useParams } from "react-router-dom";
import {
  ArrowRight,
  Check,
  CheckCheck,
  Clock3,
  Copy,
  FileText,
  MessageCircle,
  Package,
  PackageCheck,
  Plane,
  ShieldCheck,
  Truck,
  Warehouse,
} from "lucide-react";
import { api } from "@/api/client";
import type { TrackInfo, TrackPayMethod } from "@/api/types";
import { useFetch } from "@/state/useFetch";
import { useAuth } from "@/state/auth";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import { useToast } from "@/components/beui/toast";
import { useMoneyEntry, nativeMoney } from "@/components/MoneyInput";
import { optionalScreenshotReference } from "@/lib/uploadFile";
import { InvoicePdfActions } from "@/components/InvoicePdfActions";
import { ShipmentMedia } from "@/components/ShipmentMedia";
import {
  ReceiptScreenshotInput,
  useReceiptScreenshot,
} from "@/components/ReceiptScreenshotInput";
import { ErrorBlock, CONDENSED_STEPS } from "@/components/ui";
import { fmtBdt, fmtDate } from "@/lib/format";
import "./Track.css";

type Billing = Extract<TrackInfo, { includesInvoice: true }>;
const supportUrl = "https://wa.me/8801711220340";
const stages = [
  { label: "Booked", icon: Package },
  { label: "China hub", icon: Warehouse },
  { label: "In transit", icon: Plane },
  { label: "Dhaka hub", icon: Truck },
  { label: "Delivered", icon: PackageCheck },
];
const statusCopy = [
  [
    "Shipment booked",
    "Your shipment is booked. The next update will appear when it reaches our China hub.",
  ],
  [
    "At our China hub",
    "Your shipment has arrived at our China hub and is being prepared for its journey.",
  ],
  [
    "Ready for departure",
    "Your shipment is ready for its flight. We’ll update this page when it is in transit.",
  ],
  [
    "Your shipment is on its way",
    "Your shipment is in transit from China to Bangladesh.",
  ],
  [
    "Customs cleared",
    "Customs clearance is complete. The next stop is our Dhaka hub.",
  ],
  [
    "At our Dhaka hub",
    "Your shipment has arrived in Dhaka and is being prepared for local delivery.",
  ],
  [
    "Getting ready for delivery",
    "Your shipment is ready for the final part of its journey.",
  ],
  [
    "Out for delivery",
    "Your shipment is on the final leg of its journey to you.",
  ],
  [
    "Your shipment has arrived",
    "Delivery is complete. Thank you for shipping with Sichuan Bangla Express.",
  ],
] as const;

function SupportLink({
  children = "Contact support",
}: {
  children?: ReactNode;
}) {
  return (
    <a href={supportUrl} target="_blank" rel="noreferrer">
      <MessageCircle size={16} aria-hidden="true" />
      {children}
    </a>
  );
}

function TrackSteps({ current }: { current: number }) {
  const activeIndex = CONDENSED_STEPS.reduce(
    (active, step, index) => (current >= step.minIndex ? index : active),
    0,
  );
  return (
    <ol className="track-steps" aria-label="Shipment progress">
      {stages.map((step, index) => {
        const active = index === activeIndex;
        const completed = index < activeIndex || current >= 8;
        const Icon = step.icon;
        return (
          <li
            key={step.label}
            className={`${active ? "is-current" : ""} ${completed ? "is-complete" : ""}`}
            aria-current={active ? "step" : undefined}
          >
            <span className="track-step-marker" aria-hidden="true">
              {completed ? <Check size={19} /> : <Icon size={19} />}
            </span>
            <div>
              <strong>{step.label}</strong>
              <span>
                {completed
                  ? "Completed"
                  : active
                    ? "Current stage"
                    : "Upcoming"}
              </span>
            </div>
          </li>
        );
      })}
    </ol>
  );
}

function Invoice({ billing, token }: { billing: Billing; token: string }) {
  const currency = billing.invoice?.sourceCurrency ?? "BDT";
  const rate = currency === "CNY" ? billing.invoice?.sourceFxRate || 1 : 1;
  const money = (value: number) => nativeMoney(value / rate, currency);
  return (
    <section
      className="track-card track-invoice"
      aria-labelledby="track-invoice-title"
    >
      <div className="track-card-heading">
        <div>
          <p className="track-eyebrow">BILLING</p>
          <h2 id="track-invoice-title" tabIndex={-1}>
            {billing.pricingState === "draft"
              ? "Draft estimate"
              : "Your invoice"}
          </h2>
          <p className="track-subtext">
            {billing.invoiceNumber ?? billing.code}
            {billing.invoice?.state === "issued" && billing.invoice.issuedAt
              ? ` · Issued ${fmtDate(billing.invoice.issuedAt)}`
              : ""}
          </p>
        </div>
        <span className="track-currency">{currency}</span>
      </div>
      <div className="track-invoice-table">
        <table aria-label="Invoice breakdown">
          <thead>
            <tr>
              <th scope="col">Description</th>
              <th scope="col">Amount</th>
            </tr>
          </thead>
          <tbody>
            {billing.billLines.map((line, index) => (
              <tr key={index}>
                <td>{line.label}</td>
                <td>{money(line.amount)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {!billing.billLines.length && (
          <p className="track-subtext py-4">
            Invoice details will appear here once available.
          </p>
        )}
      </div>
      <dl className="track-invoice-totals">
        <div>
          <dt>Subtotal</dt>
          <dd>{money(billing.billSubtotal)}</dd>
        </div>
        {billing.discount > 0 && (
          <div>
            <dt>Discount / credit</dt>
            <dd>− {money(billing.discount)}</dd>
          </div>
        )}
        <div className="track-invoice-total">
          <dt>Invoice total</dt>
          <dd>{money(billing.totalBill)}</dd>
        </div>
        <div>
          <dt>Verified payments</dt>
          <dd>− {money(billing.paidSoFar)}</dd>
        </div>
        <div className="track-invoice-due">
          <dt>
            {billing.pricingState === "issued"
              ? "Amount due"
              : "Estimate · not payable"}
          </dt>
          <dd>{money(billing.due)}</dd>
        </div>
      </dl>
      {currency === "CNY" && (
        <p className="track-subtext track-invoice-rate">
          Saved invoice rate: 1 CNY = {rate} BDT
          <br />
          Balance in BDT: {fmtBdt(billing.due)}
        </p>
      )}
      {billing.invoice?.note && (
        <div className="track-invoice-note">
          <strong>Invoice note</strong>
          <p>{billing.invoice.note}</p>
        </div>
      )}
      {billing.pricingState === "issued" && (
        <div className="track-invoice-actions">
          <InvoicePdfActions
            path={`/track/${encodeURIComponent(token)}/invoice.pdf`}
            filename={`invoice-${billing.code}.pdf`}
          />
        </div>
      )}
    </section>
  );
}

function PaymentAccount({
  method,
  copy,
}: {
  method: TrackPayMethod;
  copy: (value: string, label: string) => void;
}) {
  const mobile = method.kind === "mobile_banking";
  const number = mobile ? method.number : method.accountNumber;
  return (
    <div className="track-account">
      <div className="track-account-heading">
        <strong>
          {mobile
            ? method.provider || method.name
            : method.bankName || method.name}
        </strong>
        <span className="track-currency">{method.currency}</span>
      </div>
      <p className="track-subtext">
        {mobile ? "Payment number" : "Account number"}
      </p>
      <div className="track-account-number">
        <strong>{number}</strong>
        <Button
          variant="ghost"
          size="icon"
          aria-label="Copy payment account number"
          onClick={() => copy(number, "Account number")}
        >
          <Copy size={16} />
        </Button>
      </div>
      {!mobile && (
        <dl className="track-account-details">
          <div>
            <dt>Account name</dt>
            <dd>{method.accountName}</dd>
          </div>
          {method.branch && (
            <div>
              <dt>Branch</dt>
              <dd>
                {method.branch}
                {method.district ? `, ${method.district}` : ""}
              </dd>
            </div>
          )}
        </dl>
      )}
      {mobile && method.qrImage && (
        <div className="track-account-qr">
          <img src={method.qrImage} alt={`${method.name} payment QR`} />
          <p className="track-subtext">Scan using your payment app.</p>
        </div>
      )}
      {method.note && <p className="track-account-note">{method.note}</p>}
    </div>
  );
}

function Payment({
  billing,
  token,
  reload,
}: {
  billing: Billing;
  token: string;
  reload: () => Promise<unknown>;
}) {
  const { showToast } = useToast();
  const screenshot = useReceiptScreenshot(`/track/${token}`);
  const entry = useMoneyEntry(billing.exchangeRates, true);
  const [methodId, setMethodId] = useState("");
  const [amount, setAmount] = useState("");
  const [txnRef, setTxnRef] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const locked = useRef(false);
  const active =
    billing.payMethods.find((method) => method.id === methodId) ??
    billing.payMethods[0] ??
    null;
  useEffect(() => {
    entry.setCurrency(active?.currency ?? "BDT");
    setAmount("");
    setError("");
  }, [active?.id, active?.currency]);
  const partial =
    billing.requestedAmount > 0 && billing.requestedAmount < billing.due;
  const limit = partial ? billing.requestedAmount : billing.due;
  const overLimit = entry.valid && entry.toBdt(Number(amount)) > limit;
  const valid =
    !!active &&
    entry.valid &&
    Number.isFinite(Number(amount)) &&
    Number(amount) > 0 &&
    !overLimit &&
    txnRef.trim().length >= 3;
  const copy = (value: string, label: string) =>
    void navigator.clipboard
      .writeText(value)
      .then(() => showToast({ title: `${label} copied`, status: "success" }))
      .catch(() =>
        showToast({
          title: "Select and copy the account number.",
          status: "error",
        }),
      );
  async function submit() {
    if (!active || locked.current || !valid) return;
    locked.current = true;
    setBusy(true);
    setError("");
    try {
      const imageReference = await optionalScreenshotReference({
        hasFile: Boolean(screenshot.file),
        upload: () => screenshot.upload(),
        confirmWithoutScreenshot: () =>
          window.confirm(
            "The screenshot could not be uploaded. Submit this payment without a screenshot?",
          ),
      });
      await api.post(`/track/${token}/receipt`, {
        imageReference,
        ...entry.meta,
        methodId: active.id,
        amount: Number(amount),
        txnRef: txnRef.trim(),
      });
      screenshot.clear();
      setAmount("");
      setTxnRef("");
      showToast({
        title: "Payment submitted for verification",
        status: "success",
      });
      await reload();
    } catch (e) {
      setError(
        e instanceof Error
          ? e.message
          : "Could not submit payment. Please try again.",
      );
    } finally {
      locked.current = false;
      setBusy(false);
    }
  }
  const state = billing.showPaid
    ? "paid"
    : billing.showPending
      ? "pending"
      : "due";
  const invoiceCurrency = billing.invoice?.sourceCurrency ?? "BDT";
  const invoiceRate =
    invoiceCurrency === "CNY" ? billing.invoice?.sourceFxRate || 1 : 1;
  return (
    <section
      className="track-card track-payment"
      aria-labelledby="track-payment-title"
    >
      <div className={`track-payment-summary is-${state}`}>
        <div className="track-payment-title">
          <h2 id="track-payment-title" tabIndex={-1}>
            Payment
          </h2>
          <span className="track-payment-badge">
            {billing.showPaid ? (
              <CheckCheck size={14} />
            ) : billing.showPending ? (
              <Clock3 size={14} />
            ) : null}
            {billing.pricingState !== "issued"
              ? billing.pricingState === "review"
                ? "Pricing in review"
                : "Price pending"
              : billing.showPaid
                ? "Settled"
                : billing.showPending
                  ? "In review"
                  : "Balance due"}
          </span>
        </div>
        <p className="track-subtext">
          {billing.pricingState !== "issued"
            ? "Current estimate"
            : billing.showPaid
              ? "Outstanding balance"
              : "Amount due"}
        </p>
        <p className="track-balance">
          {nativeMoney(billing.due / invoiceRate, invoiceCurrency)}
        </p>
        {invoiceCurrency === "CNY" && (
          <p className="track-subtext">{fmtBdt(billing.due)} equivalent</p>
        )}
        {billing.showPaid ? (
          <p className="track-payment-message">
            Your payment is confirmed. There is nothing more to pay for this
            shipment.
          </p>
        ) : billing.showPending ? (
          <p className="track-payment-message">
            We’ve received your payment details. The balance will update after
            verification. No need to submit them again.
          </p>
        ) : (
          <p className="track-payment-message">
            {billing.pricingState !== "issued"
              ? "Please wait for the reviewed invoice before sending payment. Our team is confirming the final charges."
              : billing.showPay
                ? "Send your payment, then share the transaction details below."
                : "The payment requested by this link is complete. Contact our team about the remaining balance."}
          </p>
        )}
        {partial && !billing.showPaid && (
          <p className="track-partial">
            This link accepts a partial payment of{" "}
            {fmtBdt(billing.requestedAmount)}.
          </p>
        )}
      </div>
      <ReceiptHistory publicView items={billing.receiptHistory ?? []} />
      {billing.showPay && !billing.showPending && !billing.showPaid ? (
        <div className="track-payment-body">
          {!billing.payMethods.length ? (
            <div className="track-payment-empty">
              <h3>Need payment details?</h3>
              <p>
                Payment accounts haven’t been added yet. Contact our team before
                sending a payment.
              </p>
              <SupportLink />
            </div>
          ) : (
            <>
              <div className="track-payment-step">
                <span aria-hidden="true">1</span>
                <div>
                  <h3>Send your payment</h3>
                  <p>Transfer to the account below.</p>
                </div>
              </div>
              {billing.payMethods.length > 1 && (
                <label className="track-account-select">
                  Payment account
                  <select
                    className="form-control"
                    aria-label="Payment account"
                    value={active?.id ?? ""}
                    disabled={busy}
                    onChange={(e) => setMethodId(e.target.value)}
                  >
                    {billing.payMethods.map((method) => (
                      <option key={method.id} value={method.id}>
                        {method.name}
                        {method.label ? ` · ${method.label}` : ""} ·{" "}
                        {method.currency}
                      </option>
                    ))}
                  </select>
                </label>
              )}
              {active && <PaymentAccount method={active} copy={copy} />}
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  void submit();
                }}
                aria-label="Submit payment details"
              >
                <div className="track-payment-step">
                  <span aria-hidden="true">2</span>
                  <div>
                    <h3>Submit payment details</h3>
                    <p>Already paid? Complete this step.</p>
                  </div>
                </div>
                <Input
                  label={`Amount paid (${entry.currency})`}
                  type="number"
                  inputMode="decimal"
                  min="0.01"
                  step="0.01"
                  max="9999999999"
                  value={amount}
                  onChange={setAmount}
                  disabled={busy}
                  placeholder="0.00"
                  required
                  error={
                    overLimit
                      ? "This amount exceeds the balance accepted by this link."
                      : undefined
                  }
                  aria-describedby="track-payment-rate"
                />
                <p id="track-payment-rate" className="track-subtext">
                  {entry.currency === "CNY"
                    ? entry.valid
                      ? `1 CNY = ${entry.exchangeRate} BDT${Number(amount) > 0 ? ` · ${fmtBdt(entry.toBdt(Number(amount)))}` : ""}`
                      : "The CNY exchange rate is unavailable. Please contact support."
                    : "Enter the amount you transferred in BDT."}
                </p>
                <Input
                  label="Transaction reference"
                  placeholder="Reference from your bank or wallet"
                  value={txnRef}
                  onChange={setTxnRef}
                  minLength={3}
                  maxLength={100}
                  required
                  disabled={busy}
                />
                <ReceiptScreenshotInput entry={screenshot} disabled={busy} />
                {error && (
                  <p role="alert" className="track-form-error">
                    {error}
                  </p>
                )}
                <Button
                  type="submit"
                  disabled={busy || !valid || screenshot.preparing}
                  className="track-submit"
                >
                  {busy ? "Submitting…" : "Submit payment details"}
                  {!busy && <ArrowRight size={16} aria-hidden="true" />}
                </Button>
                <p className="track-verification-note">
                  <ShieldCheck size={15} aria-hidden="true" />
                  Payments are credited after verification.
                </p>
              </form>
            </>
          )}
        </div>
      ) : (
        <div className="track-payment-help">
          <SupportLink>Have a payment question?</SupportLink>
        </div>
      )}
    </section>
  );
}

/** Public tracking, invoice and receipt submission. Financial data only renders for invoice links. */
export function Track() {
  const { token = "" } = useParams();
  const { user } = useAuth();
  const { data, error, loading, reload } = useFetch<{ shipment: TrackInfo }>(
    `/track/${token}`,
  );
  const shipment = data?.shipment;
  const billing = shipment?.includesInvoice ? shipment : null;
  const status =
    (shipment
      ? statusCopy[Math.max(0, Math.min(8, shipment.statusIndex))]
      : undefined) ?? statusCopy[0];
  return (
    <div className="customer-track">
      <a className="track-skip" href="#track-main">
        Skip to shipment
      </a>
      <header className="track-header">
        <div className="track-container track-header-inner">
          <div className="track-brand">
            <span className="track-brand-mark" aria-hidden="true">
              SB
            </span>
            <div>
              <strong>Sichuan Bangla Express</strong>
              <span>Customer tracking</span>
            </div>
          </div>
          <div className="track-header-actions">
            {user && (
              <Link
                to={shipment ? `/shipments/${shipment.code}` : "/shipments"}
              >
                Back to workspace
              </Link>
            )}
            <SupportLink>Need help?</SupportLink>
          </div>
        </div>
      </header>
      <main id="track-main" className="track-container track-main">
        {error ? (
          <section className="track-card track-unavailable">
            <Package size={32} aria-hidden="true" />
            <h1>Tracking unavailable</h1>
            <p>
              This link may have expired or been revoked. Contact our team for
              help or a new tracking link.
            </p>
            <ErrorBlock message={error} />
            <div>
              <Button variant="secondary" onClick={() => void reload()}>
                Try again
              </Button>
              <SupportLink />
            </div>
          </section>
        ) : loading || !shipment ? (
          <div className="track-card track-loading" role="status">
            <Package size={28} aria-hidden="true" />
            <h1>Loading your shipment</h1>
            <p>Getting the latest tracking details…</p>
          </div>
        ) : (
          <>
            <div className="track-page-heading">
              <div>
                <p className="track-eyebrow">SHIPMENT TRACKING</p>
                <h1>{shipment.code}</h1>
              </div>
              {billing && (
                <nav aria-label="Customer page sections">
                  <a href="#track-invoice-title">
                    <FileText size={15} aria-hidden="true" />
                    View invoice
                  </a>
                  <a href="#track-payment-title">
                    {billing.showPaid
                      ? "Payment details"
                      : billing.showPending
                        ? "Payment status"
                        : "Payment"}
                    <ArrowRight size={15} aria-hidden="true" />
                  </a>
                </nav>
              )}
            </div>
            <section
              className={`track-card track-journey ${shipment.statusIndex >= 8 ? "is-delivered" : ""}`}
              aria-labelledby="track-status-title"
            >
              <div className="track-journey-top">
                <div className="track-status-copy">
                  <span className="track-status-label">
                    <span aria-hidden="true" />
                    {shipment.statusLabel}
                  </span>
                  <h2 id="track-status-title">{status[0]}</h2>
                  <p>{status[1]}</p>
                  {shipment.statusIndex >= 8 &&
                    shipment.note.startsWith("Delivered via") && (
                      <p className="track-delivery-note">{shipment.note}</p>
                    )}
                </div>
                <div className="track-route">
                  <span className="track-eyebrow">SHIPMENT ROUTE</span>
                  <strong>
                    <Plane size={21} aria-hidden="true" />
                    {shipment.routeLabel}
                  </strong>
                  <span className="track-subtext">
                    {shipment.via
                      ? `Via ${shipment.via}`
                      : "China to Bangladesh"}
                  </span>
                </div>
              </div>
              <TrackSteps current={shipment.statusIndex} />
              <div className="track-journey-footer">
                <Clock3 size={14} aria-hidden="true" />
                <span>
                  Last updated{" "}
                  {new Date(shipment.updatedAt).toLocaleString("en-GB", {
                    day: "numeric",
                    month: "short",
                    hour: "2-digit",
                    minute: "2-digit",
                    timeZoneName: "short",
                  })}
                </span>
                <span>Latest shipment update</span>
              </div>
            </section>
            <div className={`track-content ${billing ? "has-billing" : ""}`}>
              <div className="track-primary-column">
                <section
                  className="track-card track-details"
                  aria-labelledby="track-details-title"
                >
                  <div className="track-card-heading">
                    <div>
                      <p className="track-eyebrow">THE DETAILS</p>
                      <h2 id="track-details-title">Shipment overview</h2>
                    </div>
                    <Package size={21} aria-hidden="true" />
                  </div>
                  <dl className="track-details-grid">
                    <div className="track-contents">
                      <dt>Contents</dt>
                      <dd>{shipment.contents || "Not specified"}</dd>
                    </div>
                    <div>
                      <dt>Weight</dt>
                      <dd>{shipment.kgLabel}</dd>
                    </div>
                    <div>
                      <dt>Flight</dt>
                      <dd>
                        {!shipment.flightCode || shipment.flightCode === "—"
                          ? "Awaiting assignment"
                          : shipment.flightCode}
                      </dd>
                    </div>
                    <div>
                      <dt>Flight date</dt>
                      <dd>
                        {shipment.flightDate
                          ? fmtDate(shipment.flightDate)
                          : "Not scheduled yet"}
                      </dd>
                    </div>
                    {shipment.depTime && (
                      <div>
                        <dt>Flight times</dt>
                        <dd>
                          {shipment.depTime}
                          {shipment.arrTime ? ` → ${shipment.arrTime}` : ""}
                        </dd>
                      </div>
                    )}
                  </dl>
                </section>
                {billing && <Invoice billing={billing} token={token} />}
                <ShipmentMedia token={token} />
                <div className="track-support-card">
                  <MessageCircle size={22} aria-hidden="true" />
                  <div>
                    <h2>We’re here to help</h2>
                    <p>Share your shipment number when you contact our team.</p>
                  </div>
                  <SupportLink>Chat with us</SupportLink>
                </div>
              </div>
              {billing && (
                <Payment
                  key={token}
                  billing={billing}
                  token={token}
                  reload={reload}
                />
              )}
            </div>
          </>
        )}
      </main>
      <footer className="track-container track-footer">
        <div>
          <strong>Sichuan Bangla Express</strong>
          <span>Bashundhara R/A, Dhaka</span>
        </div>
        <div>
          {shipment && (
            <span>Link available until {fmtDate(shipment.expiresAt)}</span>
          )}
          <a href={supportUrl} target="_blank" rel="noreferrer">
            +880 1711 220 340
          </a>
        </div>
      </footer>
    </div>
  );
}
