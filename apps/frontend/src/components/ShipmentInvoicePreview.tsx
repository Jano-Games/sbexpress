import type { ShipmentInvoice } from "@/api/types";
import { useFetch } from "@/state/useFetch";
import { Modal } from "@/components/Modal";
import { Button } from "@/components/beui/button";
import { SectionNotice } from "@/components/DesignSystem";
import { InvoicePdfActions } from "@/components/InvoicePdfActions";
import { LoadingBlock, SbMark } from "@/components/ui";
import { nativeMoney } from "@/components/MoneyInput";
import { fmtBdt, fmtDate } from "@/lib/format";

export function ShipmentInvoicePreview({
  open,
  onClose,
  code,
}: {
  open: boolean;
  onClose: () => void;
  code: string;
}) {
  const { data, error, reload } = useFetch<{
    saved: boolean;
    invoice: ShipmentInvoice;
  }>(open ? `/shipments/${encodeURIComponent(code)}/invoice` : null);
  const invoice = data?.invoice;
  const currency = invoice?.sourceCurrency ?? "BDT";
  const rate = currency === "CNY" ? (invoice?.sourceFxRate ?? 1) : 1;
  const native = (bdt: number) => nativeMoney(bdt / rate, currency);
  const subtotal =
    invoice?.lines.reduce((sum, line) => sum + line.amount, 0) ?? 0;

  return (
    <Modal
      open={open}
      onClose={onClose}
      className="invoice-preview-modal max-w-4xl"
    >
      <header className="invoice-preview-heading">
        <h2 data-dialog-title>Invoice preview</h2>
        <p>Shipment {code} · Read-only document</p>
      </header>
      {error ? (
        <div className="space-y-4">
          <SectionNotice tone="danger">{error}</SectionNotice>
          <Button variant="secondary" onClick={() => void reload()}>
            Try again
          </Button>
        </div>
      ) : !invoice ? (
        <LoadingBlock label="Loading invoice…" />
      ) : (
        <>
          {invoice.state !== "issued" && (
            <SectionNotice>
              This invoice is a draft and has not been finalized.
            </SectionNotice>
          )}
          {invoice.needsReview && (
            <SectionNotice tone="warning">
              Pricing has changed. This issued invoice is awaiting review.
            </SectionNotice>
          )}
          <article
            className="invoice-document"
            aria-label={`Invoice ${invoice.number}`}
          >
            <header className="invoice-document-header">
              <div className="invoice-document-brand">
                <SbMark size={36} />
                <div>
                  <strong>Sichuan Bangla Express</strong>
                  <span>Bashundhara R/A, Dhaka</span>
                </div>
              </div>
              <div className="invoice-document-number">
                <span>
                  {invoice.state === "issued" ? "INVOICE" : "DRAFT ESTIMATE"}
                </span>
                <strong>{invoice.number}</strong>
              </div>
            </header>
            <dl className="invoice-document-parties">
              <div>
                <dt>Billed to</dt>
                <dd>{invoice.to}</dd>
              </div>
              <div>
                <dt>Issue date</dt>
                <dd>{fmtDate(invoice.issuedAt)}</dd>
              </div>
              <div>
                <dt>Currency</dt>
                <dd>{currency}</dd>
              </div>
            </dl>
            {currency === "CNY" && (
              <p className="invoice-exchange-rate">
                Saved exchange rate: 1 CNY = {rate} BDT
              </p>
            )}
            <div
              className="billing-table-scroll"
              role="region"
              aria-label="Invoice line items"
              tabIndex={0}
            >
              <table className="invoice-lines-table">
                <thead>
                  <tr>
                    <th scope="col">Description</th>
                    {currency === "CNY" && (
                      <th
                        scope="col"
                        className="amount-column invoice-source-column"
                      >
                        Amount · CNY
                      </th>
                    )}
                    <th scope="col" className="amount-column">
                      Amount · BDT
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {invoice.lines.map((line, index) => (
                    <tr key={index}>
                      <td>{line.label}</td>
                      {currency === "CNY" && (
                        <td className="amount-column invoice-source-column">
                          {native(line.amount)}
                        </td>
                      )}
                      <td className="amount-column">
                        {fmtBdt(line.amount)}
                        {currency === "CNY" && (
                          <small className="invoice-mobile-source">
                            {native(line.amount)}
                          </small>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <dl className="invoice-document-totals">
              <div>
                <dt>Subtotal</dt>
                <dd>{fmtBdt(subtotal)}</dd>
              </div>
              <div>
                <dt>Discount</dt>
                <dd>
                  {invoice.discount > 0 ? "− " : ""}
                  {fmtBdt(invoice.discount)}
                </dd>
              </div>
              <div className="invoice-grand-total">
                <dt>Invoice total</dt>
                <dd>{fmtBdt(invoice.total)}</dd>
              </div>
              {currency === "CNY" && (
                <div>
                  <dt>Original total</dt>
                  <dd>
                    {nativeMoney(
                      invoice.sourceAmount ?? invoice.total / rate,
                      currency,
                    )}
                  </dd>
                </div>
              )}
              <div>
                <dt>Verified payments</dt>
                <dd>− {fmtBdt(invoice.paidAmount ?? 0)}</dd>
              </div>
              <div className="invoice-grand-total">
                <dt>Amount due</dt>
                <dd>{fmtBdt(invoice.dueAmount ?? invoice.total)}</dd>
              </div>
              {currency === "CNY" && (
                <div>
                  <dt>Amount due · CNY</dt>
                  <dd>{native(invoice.dueAmount ?? invoice.total)}</dd>
                </div>
              )}
            </dl>
            {invoice.note && (
              <div className="invoice-document-note">
                <strong>Notes</strong>
                <p>{invoice.note}</p>
              </div>
            )}
            <footer className="invoice-document-footer">
              Shipment {invoice.shipmentCode} · {invoice.number}
            </footer>
          </article>
        </>
      )}
      <footer className="invoice-preview-actions">
        {invoice && !error && data?.saved && (
          <InvoicePdfActions
            path={`/shipments/${encodeURIComponent(code)}/invoice.pdf`}
            filename={`${invoice.number}.pdf`}
            showPreview={false}
          />
        )}
        <Button variant="secondary" onClick={onClose}>
          Close preview
        </Button>
      </footer>
    </Modal>
  );
}
