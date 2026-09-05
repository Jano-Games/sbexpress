import { useEffect, useState } from 'react'
import { api } from '@/api/client'
import type { SupplierSummary } from '@/api/types'
import { Modal } from '@/components/Modal'
import { Button } from '@/components/beui/button'
import { Input } from '@/components/beui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/beui/select'
import { useToast } from '@/components/beui/toast'
import { Field } from '@/components/ui'

const blank = (v: string) => (v === '—' ? '' : v)

export function AddSupplierModal({
  open,
  onClose,
  onDone,
  editing,
}: {
  open: boolean
  onClose: () => void
  /** Receives the (possibly renamed) supplier code after an edit. */
  onDone: (code?: string) => void
  /** When set, the modal edits this supplier instead of adding a new one. */
  editing?: SupplierSummary
}) {
  const { showToast } = useToast()
  const [busy, setBusy] = useState(false)
  const [nextCode, setNextCode] = useState('')
  const [form, setForm] = useState({ code: '', name: '', phone: '', address: '', terms: 'instant' })

  useEffect(() => {
    if (!open) return
    if (editing) {
      setForm({
        code: editing.code,
        name: editing.name,
        phone: blank(editing.phone),
        address: blank(editing.address),
        terms: editing.terms,
      })
      return
    }
    setForm({ code: '', name: '', phone: '', address: '', terms: 'instant' })
    api.get<{ code: string }>('/suppliers/next-code').then((r) => setNextCode(r.code)).catch(() => undefined)
  }, [open, editing])

  const submit = async () => {
    if (!form.name.trim()) {
      showToast({ title: 'Name required', status: 'error' })
      return
    }
    setBusy(true)
    try {
      const payload = {
        code: form.code.trim() || undefined,
        name: form.name.trim(),
        phone: form.phone || '—',
        address: form.address || '—',
        terms: form.terms,
      }
      if (editing) {
        const r = await api.patch<{ code: string }>(`/suppliers/${editing.code}`, payload)
        showToast({ title: 'Supplier updated', status: 'success' })
        onDone(r.code)
      } else {
        await api.post('/suppliers', payload)
        showToast({ title: 'Supplier added', status: 'success' })
        onDone()
      }
      onClose()
    } catch (e) {
      showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' })
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal open={open} onClose={onClose}>
      <div data-dialog-title className="mb-3.5 text-[17px] font-extrabold">{editing ? `Edit supplier — ${editing.code}` : 'Add supplier'}</div>
      <div className="flex flex-col gap-2.5">
        <div className="flex flex-col gap-2.5 sm:flex-row">
          <Input
            className="w-40"
            label="Short code"
            placeholder={editing ? 'e.g. SUP-014' : `auto: ${nextCode || '…'}`}
            value={form.code}
            onChange={(v) => setForm((f) => ({ ...f, code: v }))}
          />
          <Input className="flex-1" label="Name" placeholder="e.g. Rahim Traders" value={form.name} onChange={(v) => setForm((f) => ({ ...f, name: v }))} />
        </div>
        <div className="flex flex-col gap-2.5 sm:flex-row">
          <Input className="min-w-0 flex-1" label="Number" placeholder="+880 …" value={form.phone} onChange={(v) => setForm((f) => ({ ...f, phone: v }))} />
          <Field label="Payment terms" className="w-40">
            <Select value={form.terms} onValueChange={(v) => setForm((f) => ({ ...f, terms: v }))}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="instant">Instant</SelectItem>
                <SelectItem value="monthly">Monthly</SelectItem>
              </SelectContent>
            </Select>
          </Field>
        </div>
        <Input label="Delivery address (optional)" placeholder="Area, city" value={form.address} onChange={(v) => setForm((f) => ({ ...f, address: v }))} />
        <Button className="mt-1" size="lg" disabled={busy} onClick={() => void submit()}>
          {editing ? 'Save changes' : 'Add supplier'}
        </Button>
      </div>
    </Modal>
  )
}
