import { useEffect, useState } from "react";
import { api } from "@/api/client";
import type { ShipmentInvoice } from "@/api/types";
import { Modal } from "@/components/Modal";
import {
  SavedCustomerLinks,
  type SavedCustomerLink,
} from "@/components/SavedCustomerLinks";
import { FormActions, SectionNotice } from "@/components/DesignSystem";
import { Input } from "@/components/beui/input";
import { Button } from "@/components/beui/button";
import { useToast } from "@/components/beui/toast";
import { LoadingBlock } from "@/components/ui";
import { useFetch } from "@/state/useFetch";
import { fmtBdt } from "@/lib/format";

export function TrackLinkModal({
  open,
  onClose,
  code,
  initialScope = "tracking",
}: {
  open: boolean;
  onClose: () => void;
  code: string;
  initialScope?: "tracking" | "invoice";
}) {
  const { showToast } = useToast();
  const [days, setDays] = useState("7");
  const [busy, setBusy] = useState(false);
  const [includeInvoice, setIncludeInvoice] = useState(
    initialScope === "invoice",
  );
  useEffect(() => {
    if (open) setIncludeInvoice(initialScope === "invoice");
  }, [open, code, initialScope]);
  const base = `/shipments/${encodeURIComponent(code)}`;
  const invoice = useFetch<{ saved: boolean; invoice: ShipmentInvoice }>(
    open && includeInvoice ? `${base}/invoice` : null,
  );
  const history = useFetch<{ links: SavedCustomerLink[] }>(
    open ? `${base}/track-links` : null,
  );
  const links = history.data?.links ?? [];
  const bill = invoice.data?.invoice;
  const cannotCreate =
    busy ||
    history.loading ||
    Boolean(history.error) ||
    (includeInvoice && (invoice.loading || !bill || Boolean(invoice.error)));
  async function act(action: "create" | "revoke") {
    if (busy || (action === "create" && cannotCreate)) return;
    setBusy(true);
    try {
      if (action === "create")
        await api.post(`${base}/track-link`, {
          scope: includeInvoice ? "invoice" : "tracking_only",
          days: Number(days),
        });
      else await api.delete(`${base}/track-link`);
      await Promise.all([
        history.reload(),
        ...(includeInvoice ? [invoice.reload()] : []),
      ]);
      showToast({
        title:
          action === "create"
            ? "Customer link saved"
            : "All shipment links revoked",
        status: "success",
      });
    } catch (error) {
      showToast({
        title:
          error instanceof Error
            ? error.message
            : "Could not update customer links",
        status: "error",
      });
    } finally {
      setBusy(false);
    }
  }
  return (
    <Modal
      open={open}
      onClose={onClose}
      className="max-w-2xl share-invoice-modal"
    >
      <header className="invoice-preview-heading">
        <h2 data-dialog-title>Share link</h2>
        <p>{code} · Share shipment tracking with your customer.</p>
      </header>
      <div className="space-y-5">
        <label className="share-include-invoice">
          <input
            type="checkbox"
            checked={includeInvoice}
            disabled={busy}
            onChange={(event) => setIncludeInvoice(event.target.checked)}
            aria-labelledby="include-invoice-label"
            aria-describedby="include-invoice-description"
          />
          <span>
            <strong id="include-invoice-label">Include invoice</strong>
            <span id="include-invoice-description">
              Add the itemized invoice, balance and payment options to the new
              link.
            </span>
          </span>
        </label>
        {includeInvoice &&
          (invoice.error ? (
            <div className="space-y-3">
              <SectionNotice tone="danger">{invoice.error}</SectionNotice>
              <Button variant="secondary" onClick={() => void invoice.reload()}>
                Retry invoice
              </Button>
            </div>
          ) : invoice.loading || !bill ? (
            <LoadingBlock label="Loading invoice…" />
          ) : (
            <div className="space-y-4">
              <section
                className="share-invoice-balance"
                aria-label="Invoice balance"
              >
                <div>
                  <span>Invoice total</span>
                  <strong>{fmtBdt(bill.total)}</strong>
                </div>
                <div>
                  <span>Paid</span>
                  <strong>{fmtBdt(bill.paidAmount ?? 0)}</strong>
                </div>
                <div>
                  <span>Amount due</span>
                  <strong>{fmtBdt(bill.dueAmount ?? bill.total)}</strong>
                </div>
              </section>
              <details className="share-invoice-breakdown" open>
                <summary>
                  Invoice breakdown{" "}
                  <span>
                    {invoice.data?.saved
                      ? bill.number
                      : "From shipment charges"}
                  </span>
                </summary>
                <table>
                  <thead>
                    <tr>
                      <th scope="col">Description</th>
                      <th scope="col">Amount · BDT</th>
                    </tr>
                  </thead>
                  <tbody>
                    {bill.lines.map((line, index) => (
                      <tr key={index}>
                        <td>{line.label}</td>
                        <td>{fmtBdt(line.amount)}</td>
                      </tr>
                    ))}
                    {bill.discount > 0 && (
                      <tr>
                        <td>Discount</td>
                        <td>− {fmtBdt(bill.discount)}</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </details>
              <p className="share-invoice-help">
                The customer pays the remaining invoice balance. Paid amounts
                update automatically.
                {!invoice.data?.saved &&
                  " Generating the link also saves this invoice."}
              </p>
            </div>
          ))}
        <form
          className="share-link-form"
          onSubmit={(event) => {
            event.preventDefault();
            void act("create");
          }}
        >
          <Input
            label="Link expiry · days"
            type="number"
            min={1}
            max={90}
            step={1}
            value={days}
            onChange={setDays}
            disabled={busy}
            required
          />
          <Button type="submit" disabled={cannotCreate}>
            {busy ? "Please wait…" : "Generate link"}
          </Button>
        </form>
        <div className="share-saved-section">
          {history.error ? (
            <div className="space-y-3">
              <SectionNotice tone="danger">{history.error}</SectionNotice>
              <Button variant="secondary" onClick={() => void history.reload()}>
                Retry saved links
              </Button>
            </div>
          ) : history.loading ? (
            <LoadingBlock label="Loading saved links…" />
          ) : (
            <SavedCustomerLinks links={links} />
          )}
        </div>
      </div>
      <FormActions>
        <Button variant="secondary" disabled={busy} onClick={onClose}>
          Close
        </Button>
        {links.some((link) => link.status === "active") && (
          <Button
            variant="secondary"
            disabled={busy}
            onClick={() => void act("revoke")}
          >
            Revoke all links
          </Button>
        )}
      </FormActions>
    </Modal>
  );
}
