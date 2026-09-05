import { Modal } from '@/components/Modal'
import { SbMark } from '@/components/ui'
import type { InvoiceDoc } from '@/api/types'
import { fmtBdt, fmtDate } from '@/lib/format'

export function InvoiceModal({ open, onClose, doc }: { open: boolean; onClose: () => void; doc: InvoiceDoc | null }) {
  return (
    // Invoices read like a printed slip — keep the narrow document width.
    <Modal open={open} onClose={onClose} className="max-w-[460px]">
      {doc ? (
        <>
          <div className="flex items-start justify-between">
            <div>
              <div data-dialog-title className="text-[17px] font-extrabold">{doc.title}</div>
              <div className="text-[11.5px] text-muted-foreground">
                {doc.number} · {fmtDate(new Date().toISOString())}
              </div>
            </div>
            <SbMark size={30} />
          </div>
          <div className="mt-3 text-xs text-muted-foreground">Billed to</div>
          <div className="text-[13.5px] font-bold">{doc.to}</div>
          <div className="mt-3.5 border-t border-border pt-1.5">
            {doc.lines.map((line, i) => (
              <div key={i} className="flex justify-between border-b border-muted py-1.75 text-[12.5px]">
                <span className="text-muted-foreground">{line.label}</span>
                <b>{line.amount < 0 ? `− ${fmtBdt(-line.amount)}` : fmtBdt(line.amount)}</b>
              </div>
            ))}
            <div className="flex justify-between py-3 text-[15px]">
              <span className="font-extrabold">Total due</span>
              <span className="font-extrabold text-primary">{fmtBdt(doc.total)}</span>
            </div>
          </div>
          <div className="text-[11px] text-muted-foreground">
            Sichuan Bangla Express · Bashundhara R/A, Dhaka · Pay via bKash, BD Bank, Alipay or WeChat
          </div>
        </>
      ) : null}
    </Modal>
  )
}
