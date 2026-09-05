import { useEffect, useState } from 'react'
import { api } from '@/api/client'
import { Modal } from '@/components/Modal'
import { Input } from '@/components/beui/input'
import { Button } from '@/components/beui/button'
import { useToast } from '@/components/beui/toast'
export function TrackLinkModal({ open, onClose, code, initialScope = 'tracking' }: { open: boolean; onClose: () => void; code: string; initialScope?: 'tracking' | 'invoice' }) {
  const { showToast } = useToast()
  const [link, setLink] = useState<{ token: string; url: string; expiresAt: string } | null>(null)
  const [scope, setScope] = useState(initialScope)
  const [days, setDays] = useState('7')
  const [amount, setAmount] = useState('')
  const [busy, setBusy] = useState(false)
  useEffect(() => { if (open) { setLink(null); setScope(initialScope); setAmount('') } }, [open, code, initialScope])
  const fail = (e: unknown) => showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' })
  const create = async () => {
    setBusy(true)
    try { setLink(await api.post(`/shipments/${code}/track-link`, { scope, days: Number(days), amount: amount.trim() ? Number(amount) : undefined })) }
    catch(e) { fail(e) } finally { setBusy(false) }
  }
  const revoke = async () => {
    setBusy(true)
    try { await api.delete(`/shipments/${code}/track-link`); setLink(null); showToast({ title: 'All links for this shipment revoked', status: 'success' }) }
    catch(e) { fail(e) } finally { setBusy(false) }
  }
  return <Modal open={open} onClose={onClose}>
    <h2 className="text-lg font-bold">Share {code}</h2>
    <p className="my-2 text-sm text-muted-foreground">Anyone holding this link can view it until expiry. Share only with the intended customer.</p>
    <label className="block my-3 text-sm">Page
      <select className="ml-3 border rounded p-2" value={scope} onChange={e => setScope(e.target.value as typeof scope)}>
        <option value="tracking">Tracking and payment</option><option value="invoice">Invoice and payment</option>
      </select>
    </label>
    <Input label="Expires in days (1–90)" value={days} onChange={setDays} />
    <Input label="Request amount (BDT) — blank for full balance" value={amount} onChange={setAmount} />
    <Button className="mt-3" disabled={busy} onClick={() => void create()}>Generate secure link</Button>
    {link && <div className="my-4 space-y-2">
      <input aria-label="Share URL" className="w-full border rounded p-2" readOnly value={link.url} />
      <p className="text-xs">Expires {new Date(link.expiresAt).toLocaleString()}</p>
      <Button onClick={() => void navigator.clipboard.writeText(link.url).then(() => showToast({title:'Link copied',status:'success'})).catch(fail)}>Copy link</Button>
      <a className="ml-4 underline" href={link.url} target="_blank" rel="noreferrer">Preview</a>
    </div>}
    <Button className="mt-3 ml-2" variant="secondary" disabled={busy} onClick={() => void revoke()}>Revoke all links</Button>
  </Modal>
}
