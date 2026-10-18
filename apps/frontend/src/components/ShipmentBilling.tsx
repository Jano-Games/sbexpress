import { ReverseEntry } from "./ReverseEntry";
import { ReceiptHistory } from "./ReceiptHistory";
import { SectionNotice } from "./DesignSystem";
import { ReceiptScreenshot } from "@/components/ReceiptScreenshot";
import { useState } from "react";
import { Link } from "react-router-dom";
import {
  ArrowDownLeft,
  CircleCheck,
  Clock3,
  Eye,
  FileText,
  Pencil,
  Plus,
  ReceiptText,
  Wallet,
} from "lucide-react";
import type { ShipmentDetail } from "@/api/types";
import { Button } from "@/components/beui/button";
import { Chip } from "@/components/ui";
import { nativeMoney } from "@/components/MoneyInput";
import { ShipmentInvoicePreview } from "@/components/ShipmentInvoicePreview";
import { fmtBdt, fmtDate, fmtLogAt, PAY_CHIP } from "@/lib/format";

export function ShipmentBilling({
  shipment: s,
  onPayment,
  onCredit,
  onInvoice,
  onChanged,
}: {
  shipment: ShipmentDetail;
  onPayment: () => void;
  onCredit: () => void;
  onInvoice: () => void;
  onChanged: () => unknown;
}) {
  const [preview, setPreview] = useState(false);
  const invoice = s.invoice;
  const paymentStatus =
    s.payStatus === "paid" ? "paid" : s.paidAmount > 0 ? "partial" : "unpaid";
  const statusLabel =
    paymentStatus === "paid"
      ? "Paid"
      : paymentStatus === "partial"
        ? "Partially paid"
        : "Unpaid";

  const ready = invoice?.state === "issued" && !invoice.needsReview;
  return (
    <div className="shipment-billing">
      <header className="billing-workspace-header">
        <div>
          <h2>Billing overview</h2>
          <p>Invoice, payments and customer balance · Summary in BDT</p>
        </div>
        <div className="billing-actions">
          <Button variant="secondary" onClick={onCredit}>
            Issue credit
          </Button>
          {ready && s.dueAmount > 0 && (
            <Button onClick={onPayment}>
              <Plus size={16} aria-hidden="true" />
              Record payment
            </Button>
          )}
        </div>
      </header>
      {!ready && (
        <SectionNotice tone="warning">
          {invoice?.needsReview
            ? "Pricing needs review. Review changes and issue a revision before collecting further payment."
            : "Pricing is a draft estimate. Review and issue an invoice before collecting payment."}{" "}
          <Button variant="secondary" size="sm" onClick={onInvoice}>
            Review invoice
          </Button>
        </SectionNotice>
      )}
      <p className="text-sm text-muted-foreground">
        Payment terms:{" "}
        {s.paymentTerms === "cod"
          ? "Cash on delivery"
          : s.paymentTerms === "monthly"
            ? "Monthly billing"
            : "Pay on invoice"}
      </p>
      <dl className="billing-summary">
        <div>
          <dt>
            {invoice?.state === "issued" ? "Invoice total" : "Draft estimate"}
            <FileText size={18} aria-hidden="true" />
          </dt>
          <dd>{fmtBdt(s.billAmount)}</dd>
          <p>
            {invoice?.state === "issued"
              ? "Current issued invoice"
              : "Invoice has not been issued"}
          </p>
        </div>
        <div>
          <dt>
            Paid to date
            <ArrowDownLeft size={18} aria-hidden="true" />
          </dt>
          <dd className="text-success">{fmtBdt(s.paidAmount)}</dd>
          <p>Payments and credit applied</p>
        </div>
        <div className="billing-balance">
          <dt>
            Outstanding balance
            {s.dueAmount > 0 ? (
              <Clock3 size={18} aria-hidden="true" />
            ) : (
              <CircleCheck size={18} aria-hidden="true" />
            )}
          </dt>
          <dd className={s.dueAmount > 0 ? "text-danger" : "text-success"}>
            {fmtBdt(s.dueAmount)}
          </dd>
          <p>
            {s.dueAmount > 0
              ? "Remaining amount to collect"
              : "No outstanding balance"}
          </p>
        </div>
      </dl>
      <section
        className="billing-register"
        aria-labelledby="billing-invoices-heading"
      >
        <header className="billing-register-header">
          <div>
            <h3 id="billing-invoices-heading">
              Invoices <span className="billing-count">{invoice ? 1 : 0}</span>
            </h3>
            <p>Select the invoice number or Preview to view the document.</p>
            {invoice && (
              <p className="billing-table-hint">
                Scroll to view amounts and actions →
              </p>
            )}
          </div>
          {!invoice && (
            <Button variant="secondary" onClick={onInvoice}>
              <Plus size={16} aria-hidden="true" />
              Create invoice
            </Button>
          )}
        </header>
        {invoice ? (
          <div
            className="billing-table-scroll"
            role="region"
            aria-label="Invoices"
            tabIndex={0}
          >
            <table className="billing-table invoice-register-table">
              <caption className="sr-only">
                Saved invoices for shipment {s.code}
              </caption>
              <thead>
                <tr>
                  <th scope="col">Invoice</th>
                  <th scope="col">Issued</th>
                  <th scope="col">Payment status</th>
                  <th scope="col" className="amount-column">
                    Original amount
                  </th>
                  <th scope="col" className="amount-column">
                    Total · BDT
                  </th>
                  <th scope="col" className="actions-column">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>
                    <button
                      type="button"
                      className="invoice-number-link"
                      onClick={() => setPreview(true)}
                      aria-label={`Preview invoice ${invoice.number}`}
                    >
                      <FileText size={17} aria-hidden="true" />
                      {invoice.number}
                    </button>
                  </td>
                  <td className="whitespace-nowrap">
                    {invoice.state === "issued"
                      ? fmtDate(invoice.issuedAt)
                      : "Draft"}
                  </td>
                  <td>
                    <Chip colors={PAY_CHIP[paymentStatus]!}>
                      {invoice.needsReview
                        ? "Needs review"
                        : invoice.state === "draft"
                          ? "Draft"
                          : statusLabel}
                    </Chip>
                  </td>
                  <td className="amount-column">
                    {invoice.sourceCurrency === "CNY"
                      ? nativeMoney(
                          invoice.sourceAmount ??
                            invoice.total / (invoice.sourceFxRate || 1),
                          "CNY",
                        )
                      : fmtBdt(invoice.total)}
                    {invoice.sourceCurrency === "CNY" && (
                      <small>1 CNY = {invoice.sourceFxRate} BDT</small>
                    )}
                  </td>
                  <td className="amount-column font-semibold">
                    {fmtBdt(invoice.total)}
                    {invoice.discount > 0 && (
                      <small>Discount {fmtBdt(invoice.discount)}</small>
                    )}
                  </td>
                  <td>
                    <div className="billing-row-actions">
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={() => setPreview(true)}
                      >
                        <Eye size={15} aria-hidden="true" />
                        Preview
                      </Button>
                      <Button variant="ghost" size="sm" onClick={onInvoice}>
                        <Pencil size={14} aria-hidden="true" />
                        Edit
                      </Button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        ) : (
          <div className="billing-empty">
            <FileText size={24} strokeWidth={1.5} aria-hidden="true" />
            <div>
              <strong>No invoice issued</strong>
              <p>
                Create an invoice to finalize the shipment charges. The balance
                above is an estimate.
              </p>
            </div>
          </div>
        )}
      </section>
      <section
        className="billing-register"
        aria-labelledby="billing-payments-heading"
      >
        <header className="billing-register-header">
          <div>
            <h3 id="billing-payments-heading">
              Payment history{" "}
              <span className="billing-count">{s.payments.length}</span>
            </h3>
            <p>
              Recorded receipts in their original currency and BDT equivalent.
            </p>
          </div>
          <Wallet
            size={20}
            className="text-muted-foreground"
            aria-hidden="true"
          />
        </header>
        {s.payments.length ? (
          <div
            className="billing-table-scroll"
            role="region"
            aria-label="Payment history"
            tabIndex={0}
          >
            <table className="billing-table payment-register-table">
              <caption className="sr-only">
                Payments received for shipment {s.code}
              </caption>
              <thead>
                <tr>
                  <th scope="col">Received</th>
                  <th scope="col">Account / method</th>
                  <th scope="col" className="amount-column">
                    Original amount
                  </th>
                  <th scope="col" className="amount-column">
                    Amount · BDT
                  </th>
                </tr>
              </thead>
              <tbody>
                {s.payments.map((payment, i) => (
                  <tr key={`${payment.at}-${i}`}>
                    <td>{fmtLogAt(payment.at)}</td>
                    <td>
                      {payment.method}
                      <small>
                        {payment.reference}
                        {payment.reversedAt
                          ? " · Reversed"
                          : payment.reversalOfId
                            ? " · Reversal"
                            : ""}
                      </small>
                    </td>
                    <td className="amount-column">
                      {payment.sourceCurrency === "CNY"
                        ? nativeMoney(
                            payment.sourceAmount ??
                              payment.amount / (payment.sourceFxRate || 1),
                            "CNY",
                          )
                        : fmtBdt(payment.amount)}
                      {payment.sourceCurrency === "CNY" && (
                        <small>1 CNY = {payment.sourceFxRate} BDT</small>
                      )}
                    </td>
                    <td className="amount-column font-semibold">
                      {fmtBdt(payment.amount)}
                      {payment.canReverse && (
                        <div className="mt-2">
                          <ReverseEntry
                            kind="payment"
                            id={payment.id}
                            onChanged={onChanged}
                          />
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="billing-empty">
            <ReceiptText size={24} strokeWidth={1.5} aria-hidden="true" />
            <div>
              <strong>No payments recorded yet</strong>
              <p>
                Use Record payment when a payment is received. It will appear
                here with its currency and account.
              </p>
            </div>
          </div>
        )}
      </section>
      <ReceiptHistory items={s.receiptHistory ?? []} />
      {s.receipt?.status === "pending" && (
        <Link
          to={`/review?receipt=${encodeURIComponent(`shipment:${s.code}`)}`}
          className="billing-review-link"
        >
          Review pending receipt →
        </Link>
      )}
      <ShipmentInvoicePreview
        open={preview}
        onClose={() => setPreview(false)}
        code={s.code}
      />
    </div>
  );
}
