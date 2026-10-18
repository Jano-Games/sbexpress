import { Modal } from "@/components/Modal";
import { Button } from "@/components/beui/button";
import { DetailGrid, FormActions } from "@/components/DesignSystem";
import type { InvoiceDoc } from "@/api/types";
import { fmtBdt, fmtDate } from "@/lib/format";

export function InvoiceModal({
  open,
  onClose,
  doc,
}: {
  open: boolean;
  onClose: () => void;
  doc: InvoiceDoc | null;
}) {
  return (
    <Modal open={open} onClose={onClose} className="max-w-2xl">
      {doc && (
        <article className="space-y-6">
          <header className="border-b border-border pb-5">
            <p className="mb-3 text-sm font-medium text-muted-foreground">
              Sichuan Bangla Express
            </p>
            <h2 data-dialog-title className="text-xl font-semibold">
              {doc.title}
            </h2>
            <p className="mt-2 text-sm text-muted-foreground">{doc.number}</p>
          </header>
          <DetailGrid
            items={[
              { label: "Billed to", value: doc.to },
              {
                label: "Document date",
                value: fmtDate(new Date().toISOString()),
              },
            ]}
          />
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead>
                <tr className="border-b border-border text-xs text-muted-foreground">
                  <th scope="col" className="py-3 pr-4 font-medium">
                    Description
                  </th>
                  <th scope="col" className="py-3 text-right font-medium">
                    Amount · BDT
                  </th>
                </tr>
              </thead>
              <tbody>
                {doc.lines.map((line, index) => (
                  <tr key={index} className="border-b border-border">
                    <td className="py-3 pr-4">{line.label}</td>
                    <td className="whitespace-nowrap py-3 text-right tabular-nums">
                      {line.amount < 0
                        ? `− ${fmtBdt(-line.amount)}`
                        : fmtBdt(line.amount)}
                    </td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr>
                  <th className="py-5 pr-4 text-lg font-semibold">Total due</th>
                  <td className="whitespace-nowrap py-5 text-right text-lg font-semibold tabular-nums">
                    {fmtBdt(doc.total)}
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>
          <p className="border-t border-border pt-4 text-xs text-muted-foreground">
            Sichuan Bangla Express · Bashundhara R/A, Dhaka
          </p>
          <FormActions>
            <Button variant="secondary" onClick={onClose}>
              Close document
            </Button>
          </FormActions>
        </article>
      )}
    </Modal>
  );
}
