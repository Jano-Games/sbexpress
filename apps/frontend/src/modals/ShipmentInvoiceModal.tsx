import { useEffect, useState } from 'react'
import { api } from '@/api/client'
import type { ShipmentInvoice } from '@/api/types'
import { TrackLinkModal } from './TrackLinkModal'
import { Modal } from '@/components/Modal'
import { Button } from '@/components/beui/button'
import { Input } from '@/components/beui/input'
import { useToast } from '@/components/beui/toast'
import { SbMark } from '@/components/ui'
import { fmtBdt, fmtDate } from '@/lib/format'

type LineDraft = { label: string; amount: string }

/**
 * Editable per-shipment invoice: opens as a draft built from the shipment,
 * lines and discount are adjustable, Finalize persists it. Reopening a saved
 * invoice edits it in place.
 */
export function ShipmentInvoiceModal({
  open,
  onClose,
  code,
  onSaved,
}: {
  open: boolean
  onClose: () => void
  code: string
  onSaved: () => void
}) {
  const { showToast } = useToast()
  const [sharing, setSharing] = useState(false)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [saved, setSaved] = useState(false)
  const [header, setHeader] = useState<Pick<ShipmentInvoice, 'number' | 'to' | 'issuedAt'> | null>(null)
  const [lines, setLines] = useState<LineDraft[]>([])
  const [discount, setDiscount] = useState('')
  const [note, setNote] = useState('')

  useEffect(() => {
    if (!open) return
    setLoading(true)
    api
      .get<{ saved: boolean; invoice: ShipmentInvoice }>(`/shipments/${code}/invoice`)
      .then((r) => {
        setSaved(r.saved)
        setHeader({ number: r.invoice.number, to: r.invoice.to, issuedAt: r.invoice.issuedAt })
        setLines(r.invoice.lines.map((l) => ({ label: l.label, amount: String(l.amount) })))
        setDiscount(r.invoice.discount ? String(r.invoice.discount) : '')
        setNote(r.invoice.note)
      })
      .catch((e: unknown) => showToast({ title: e instanceof Error ? e.message : 'Failed to load', status: 'error' }))
      .finally(() => setLoading(false))
  }, [open, code, showToast])

  const linesSum = lines.reduce((a, l) => a + (parseFloat(l.amount) || 0), 0)
  const total = linesSum - (parseFloat(discount) || 0)

  const save = () =>
    void (async () => {
      const payload = {
        lines: lines
          .map((l) => ({ label: l.label.trim(), amount: parseFloat(l.amount) || 0 }))
          .filter((l) => l.label),
        discount: parseFloat(discount) || 0,
        note: note.trim(),
      }
      if (!payload.lines.length) {
        showToast({ title: 'At least one line with a label is required', status: 'error' })
        return
      }
      setBusy(true)
      try {
        const r = await api.post<{ number: string }>(`/shipments/${code}/invoice`, payload)
        showToast({ title: `${r.number} ${saved ? 'updated' : 'finalized'}`, status: 'success' })
        onSaved()
        onClose()
      } catch (e) {
        showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' })
      } finally {
        setBusy(false)
      }
    })()

  return (
    <>
    <TrackLinkModal open={sharing} onClose={() => setSharing(false)} code={code} initialScope="invoice" />
    <Modal open={open && !sharing} onClose={onClose} className="max-w-[560px]">
      {loading || !header ? (
        <div className="p-8 text-center text-[13px] text-muted-foreground">Loading…</div>
      ) : (
        <>
          <div className="flex items-start justify-between">
            <div>
              <div data-dialog-title className="text-[17px] font-extrabold">{saved ? 'Edit invoice' : 'Finalize invoice'}</div>
              <div className="text-[11.5px] text-muted-foreground">
                {header.number} · {fmtDate(header.issuedAt)}
              </div>
            </div>
            <SbMark size={30} />
          </div>
          <div className="mt-3 text-xs text-muted-foreground">Billed to</div>
          <div className="text-[13.5px] font-bold">{header.to}</div>

          <div className="mt-3.5 flex flex-col gap-1.5 border-t border-border pt-3">
            {lines.map((line, i) => (
              <div key={i} className="flex items-center gap-1.5">
                <Input
                  className="min-w-0 flex-1"
                  placeholder="Line description"
                  value={line.label}
                  onChange={(v) => setLines((l) => l.map((x, j) => (j === i ? { ...x, label: v } : x)))}
                />
                <Input
                  className="w-28"
                  placeholder="Amount ৳"
                  value={line.amount}
                  onChange={(v) => setLines((l) => l.map((x, j) => (j === i ? { ...x, amount: v } : x)))}
                />
                <button
                  type="button"
                  title="Remove line"
                  className="grid size-6 shrink-0 cursor-pointer place-items-center rounded-full border border-[#F1C4C4] bg-card text-[11px] font-extrabold text-danger"
                  onClick={() => setLines((l) => l.filter((_, j) => j !== i))}
                >
                  ×
                </button>
              </div>
            ))}
            <button
              type="button"
              className="cursor-pointer self-start border-0 bg-transparent p-0 text-xs font-semibold text-blue"
              onClick={() => setLines((l) => [...l, { label: '', amount: '' }])}
            >
              + Add line (use a negative amount for an adjustment)
            </button>
          </div>

          <div className="mt-3 flex items-end gap-2.5 border-t border-dashed border-border pt-3">
            <Input className="w-32" label="Discount (৳)" placeholder="0" value={discount} onChange={setDiscount} />
            <Input className="min-w-0 flex-1" label="Note (optional)" placeholder="e.g. Eid discount" value={note} onChange={setNote} />
          </div>

          <div className="mt-3 flex items-center justify-between border-t border-border pt-3">
            <div className="text-[12.5px] text-muted-foreground">
              {fmtBdt(linesSum)}
              {parseFloat(discount) > 0 ? <span className="text-danger"> − {fmtBdt(parseFloat(discount) || 0)}</span> : null}
            </div>
            <div className="text-[15px]">
              <span className="mr-2 font-extrabold">Total due</span>
              <span className="font-extrabold text-primary">{fmtBdt(total)}</span>
            </div>
          </div>

          {saved && <Button className="mt-3" variant="secondary" onClick={() => setSharing(true)}>Share saved invoice / request partial payment</Button>}
          <div className="mt-4 flex gap-2">
            <Button className="flex-1" size="lg" disabled={busy} onClick={save}>
              {saved ? 'Save changes' : 'Finalize invoice'}
            </Button>
            <Button variant="secondary" size="lg" onClick={onClose}>
              Cancel
            </Button>
          </div>
        </>
      )}
    </Modal>
    </>
  )
}
