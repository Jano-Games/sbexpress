import { useEffect, useState } from 'react'
import { motion, useReducedMotion } from 'motion/react'
import { api } from '@/api/client'
import type { Flyer } from '@/api/types'
import { Modal } from '@/components/Modal'
import { Button } from '@/components/beui/button'
import { Input } from '@/components/beui/input'
import { useToast } from '@/components/beui/toast'
import { SPRING_PRESS } from '@/lib/ease'
import { cn } from '@/lib/utils'

const blank = (v: string) => (v === '—' ? '' : v)

const EMPTY = {
  firstName: '',
  lastName: '',
  cnPhone: '',
  bdPhone: '',
  university: '',
  batch: '',
  program: '',
  wechat: '',
  cnAddress: '',
  homeAddress: '',
  emergencyContact: '',
}

/** "Ashikur Rahman" typed in a search box → { firstName: 'Ashikur', lastName: 'Rahman' }. */
function splitPrefill(query: string): { firstName: string; lastName: string } {
  const tokens = query.trim().split(/\s+/)
  if (tokens.length < 2) return { firstName: tokens[0] ?? '', lastName: '' }
  return { firstName: tokens.slice(0, -1).join(' '), lastName: tokens[tokens.length - 1]! }
}

function WhatsAppGlyph({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="currentColor" aria-hidden>
      <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0 0 12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 0 0-3.48-8.413Z" />
    </svg>
  )
}

/** WhatsApp-available switch that sits beside a phone input. */
function WaToggle({ on, onToggle }: { on: boolean; onToggle: () => void }) {
  const reduce = useReducedMotion()
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      aria-label="WhatsApp available on this number"
      title={on ? 'WhatsApp available — click to turn off' : 'WhatsApp available? Click to turn on'}
      onClick={onToggle}
      className={cn(
        'flex h-10 shrink-0 cursor-pointer items-center gap-2 rounded-[9px] border px-2.5 transition-colors',
        on ? 'border-[#BEE7CA] bg-[#EFFBF3]' : 'border-border bg-card hover:border-[#BEE7CA] hover:bg-[#F7FDF9]',
      )}
    >
      <WhatsAppGlyph className={cn('size-4 transition-colors', on ? 'text-[#25A05A]' : 'text-[#C4C1BA]')} />
      <span
        className={cn(
          'relative inline-block h-[16px] w-[28px] rounded-full transition-colors',
          on ? 'bg-[#25A05A]' : 'bg-[#DDD9D1]',
        )}
      >
        <motion.span
          className="absolute top-[2px] left-0 size-[12px] rounded-full bg-white shadow-[0_1px_2px_rgba(0,0,0,.25)]"
          animate={{ x: on ? 14 : 2 }}
          transition={reduce ? { duration: 0 } : SPRING_PRESS}
        />
      </span>
    </button>
  )
}

export function AddFlyerModal({
  open,
  onClose,
  onDone,
  prefillName,
  assignFlightCode,
  editing,
}: {
  open: boolean
  onClose: () => void
  onDone: (name: string) => void
  prefillName?: string
  assignFlightCode?: string
  /** When set, the modal edits this flyer instead of registering a new one. */
  editing?: Flyer
}) {
  const { showToast } = useToast()
  const [busy, setBusy] = useState(false)
  const [form, setForm] = useState(EMPTY)
  const [cnWhatsapp, setCnWhatsapp] = useState(false)
  const [bdWhatsapp, setBdWhatsapp] = useState(false)
  const [docs, setDocs] = useState({ docStudentId: true, docVisa: false, docAdmission: false })

  useEffect(() => {
    if (!open) return
    if (editing) {
      setForm({
        firstName: editing.firstName,
        lastName: editing.lastName,
        cnPhone: blank(editing.cnPhone),
        bdPhone: blank(editing.bdPhone),
        university: blank(editing.university),
        batch: blank(editing.batch).replace(/^Batch\s*/i, ''),
        program: blank(editing.program),
        wechat: blank(editing.wechat),
        cnAddress: blank(editing.cnAddress),
        homeAddress: blank(editing.homeAddress),
        emergencyContact: blank(editing.emergencyContact),
      })
      setCnWhatsapp(editing.cnWhatsapp)
      setBdWhatsapp(editing.bdWhatsapp)
      setDocs({ docStudentId: editing.docStudentId, docVisa: editing.docVisa, docAdmission: editing.docAdmission })
    } else {
      setForm({ ...EMPTY, ...(prefillName ? splitPrefill(prefillName) : {}) })
      setCnWhatsapp(false)
      setBdWhatsapp(false)
    }
  }, [open, prefillName, editing])

  const set = (key: keyof typeof form) => (value: string) => setForm((f) => ({ ...f, [key]: value }))

  const submit = async () => {
    if (!form.firstName.trim()) {
      showToast({ title: 'First name required', status: 'error' })
      return
    }
    setBusy(true)
    try {
      const payload = {
        firstName: form.firstName.trim(),
        lastName: form.lastName.trim(),
        cnPhone: form.cnPhone || '—',
        cnWhatsapp,
        bdPhone: form.bdPhone || '—',
        bdWhatsapp,
        university: form.university || '—',
        batch: form.batch,
        program: form.program || '—',
        wechat: form.wechat || '—',
        cnAddress: form.cnAddress || '—',
        homeAddress: form.homeAddress || '—',
        emergencyContact: form.emergencyContact || '—',
      }
      if (editing) {
        const r = await api.patch<{ name: string }>(`/flyers/${encodeURIComponent(editing.name)}`, { ...payload, ...docs })
        showToast({ title: 'Flyer updated', status: 'success' })
        onDone(r.name)
      } else {
        const r = await api.post<{ name: string }>('/flyers', { ...payload, assignFlightCode })
        showToast({
          title: assignFlightCode ? 'Flyer registered & assigned to flight' : 'Flyer registered',
          status: 'success',
        })
        onDone(r.name)
      }
      onClose()
      setForm(EMPTY)
    } catch (e) {
      showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' })
    } finally {
      setBusy(false)
    }
  }

  const docToggles: { key: keyof typeof docs; label: string }[] = [
    { key: 'docStudentId', label: 'Student ID' },
    { key: 'docVisa', label: 'Visa / RP' },
    { key: 'docAdmission', label: 'JW / Adm.' },
  ]

  return (
    <Modal open={open} onClose={onClose}>
      <div data-dialog-title className="mb-3.5 text-[17px] font-extrabold">{editing ? `Edit flyer — ${editing.name}` : 'Register flyer'}</div>
      <div className="flex flex-col gap-2.5 text-[12.5px]">
        <div className="flex flex-col gap-2.5 sm:flex-row">
          <Input className="flex-1" label="First name" placeholder="e.g. Ashikur" value={form.firstName} onChange={set('firstName')} />
          <Input className="flex-1" label="Last name" placeholder="e.g. Rahman" value={form.lastName} onChange={set('lastName')} />
        </div>
        <div className="flex flex-col gap-2.5 sm:flex-row">
          <div className="flex min-w-0 flex-1 items-end gap-1.5">
            <Input className="min-w-0 flex-1" label="China number" placeholder="+86 …" value={form.cnPhone} onChange={set('cnPhone')} />
            <WaToggle on={cnWhatsapp} onToggle={() => setCnWhatsapp((v) => !v)} />
          </div>
          <div className="flex min-w-0 flex-1 items-end gap-1.5">
            <Input className="min-w-0 flex-1" label="BD number" placeholder="+880 …" value={form.bdPhone} onChange={set('bdPhone')} />
            <WaToggle on={bdWhatsapp} onToggle={() => setBdWhatsapp((v) => !v)} />
          </div>
        </div>
        <div className="flex flex-col gap-2.5 sm:flex-row">
          <Input className="min-w-0 flex-1" label="University" placeholder="e.g. Sichuan University" value={form.university} onChange={set('university')} />
          <Input className="w-24" label="Batch" placeholder="2025" value={form.batch} onChange={set('batch')} />
          <Input className="min-w-0 flex-1" label="Program" placeholder="e.g. MBBS" value={form.program} onChange={set('program')} />
        </div>
        <div className="flex flex-col gap-2.5 sm:flex-row">
          <Input className="flex-1" label="WeChat ID" placeholder="wxid…" value={form.wechat} onChange={set('wechat')} />
          <Input className="flex-1" label="Emergency contact" placeholder="Number (relation)" value={form.emergencyContact} onChange={set('emergencyContact')} />
        </div>
        <div className="flex flex-col gap-2.5 sm:flex-row">
          <Input className="flex-1" label="Address in China" placeholder="Dorm / campus" value={form.cnAddress} onChange={set('cnAddress')} />
          <Input className="flex-1" label="Home address (Bangladesh)" placeholder="Area, city" value={form.homeAddress} onChange={set('homeAddress')} />
        </div>
        <div className="text-[12px] text-muted-foreground">Documents</div>
        {editing ? (
          <div className="-mt-1 flex gap-2">
            {docToggles.map(({ key, label }) => {
              const on = docs[key]
              return (
                <button
                  key={key}
                  type="button"
                  className="flex-1 cursor-pointer rounded-[9px] border p-2.5 text-center text-[11px] font-bold transition-colors"
                  style={{
                    background: on ? '#E6F7EC' : '#FDE8E8',
                    borderColor: on ? '#BBE5C8' : '#F1C4C4',
                    color: on ? '#1B7A3D' : '#C92A2A',
                  }}
                  onClick={() => setDocs((d) => ({ ...d, [key]: !d[key] }))}
                >
                  {label} {on ? '✓' : 'missing'}
                </button>
              )
            })}
          </div>
        ) : (
          <div className="-mt-1 flex gap-2">
            {['+ Student ID', '+ Visa / RP', '+ JW / Adm.'].map((label) => (
              <div key={label} className="flex-1 rounded-[9px] border border-dashed border-[#C9C6BF] p-2.5 text-center text-[11px] text-muted-foreground">
                {label}
              </div>
            ))}
          </div>
        )}
        <Button className="mt-1" size="lg" disabled={busy} onClick={() => void submit()}>
          {editing ? 'Save changes' : 'Register flyer'}
        </Button>
      </div>
    </Modal>
  )
}
