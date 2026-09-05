import { PageHeader, PageTabs } from '@/components/Workspace'
import { useEffect, useRef, useState } from 'react'
import { api } from '@/api/client'
import { useFetch } from '@/state/useFetch'
import type { AppSettings, PayMethodKind, PayMethodRow } from '@/api/types'
import { Button } from '@/components/beui/button'
import { Input } from '@/components/beui/input'
import { useToast } from '@/components/beui/toast'
import { Card, ErrorBlock, LoadingBlock } from '@/components/ui'
import { ConfirmDialog } from '@/components/ConfirmDialog'

const EMPTY_METHOD = {
  provider: '',
  label: '',
  number: '',
  note: '',
  qrImage: null as string | null,
  bankName: '',
  accountNumber: '',
  accountName: '',
  branch: '',
  district: '',
}

const methodTitle = (m: PayMethodRow): string =>
  m.kind === 'mobile_banking' ? `${m.provider}${m.label ? ` · ${m.label}` : ''}` : `${m.bankName}`

const methodSummary = (m: PayMethodRow): string =>
  m.kind === 'mobile_banking'
    ? [m.number, m.note].filter(Boolean).join(' · ')
    : [m.accountName, m.accountNumber, [m.branch, m.district].filter(Boolean).join(', ')].filter(Boolean).join(' · ')

export function Settings() {
  const { showToast } = useToast()
  const { data, error, loading } = useFetch<{ settings: AppSettings }>('/settings')
  const { data: payData, reload: reloadMethods } = useFetch<{ methods: PayMethodRow[] }>('/settings/pay-methods')
  const [section, setSection] = useState('general')
  const [rate, setRate] = useState('')
  const [threshold, setThreshold] = useState('')

  const [pcsRates, setPcsRates] = useState<Record<string, string>>({})
  const [newPcsCat, setNewPcsCat] = useState('')
  const [newPcsRate, setNewPcsRate] = useState('')

  const [kind, setKind] = useState<PayMethodKind>('mobile_banking')
  const [form, setForm] = useState(EMPTY_METHOD)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [methodBusy, setMethodBusy] = useState(false)
  const [deleting, setDeleting] = useState<PayMethodRow | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (data) {
      setRate(String(data.settings.rate))
      setThreshold(String(data.settings.threshold))
      setPcsRates(Object.fromEntries(Object.entries(data.settings.pcsRates).map(([k, v]) => [k, String(v)])))
    }
  }, [data])

  if (error) return <ErrorBlock message={error} />
  if (loading || !data) return <LoadingBlock />

  const save = (patch: Partial<AppSettings>) =>
    void api
      .patch('/settings', patch)
      .then(() => showToast({ title: 'Settings saved', status: 'success' }))
      .catch((e: unknown) => showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' }))

  const fail = (e: unknown) => showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' })

  const savePcsRates = (next: Record<string, string>) => {
    if (Object.values(next).some(v => !v.trim() || !Number.isFinite(Number(v)) || Number(v) < 0)) { fail(new Error('Enter a valid non-negative rate for every category')); return }
    setPcsRates(next)
    const parsed = Object.fromEntries(
      Object.entries(next)
        .map(([k, v]) => [k, parseFloat(v)] as const)
        .filter(([, v]) => !Number.isNaN(v) && v >= 0),
    )
    void api
      .patch('/settings', { pcsRates: parsed })
      .then(() => showToast({ title: 'Per-piece rates saved', status: 'success' }))
      .catch(fail)
  }

  const set = (key: keyof typeof EMPTY_METHOD) => (value: string) => setForm((f) => ({ ...f, [key]: value }))

  const resetForm = () => {
    setForm(EMPTY_METHOD)
    setEditingId(null)
  }

  const pickQr = (file: File | undefined) => {
    if (!file) return
    if (file.size > 300 * 1024) {
      showToast({ title: 'QR image too large — keep it under 300 KB', status: 'error' })
      return
    }
    const reader = new FileReader()
    reader.onload = () => setForm((f) => ({ ...f, qrImage: String(reader.result) }))
    reader.readAsDataURL(file)
  }

  const submitMethod = () =>
    void (async () => {
      const payload =
        kind === 'mobile_banking'
          ? { kind, provider: form.provider, label: form.label, number: form.number, note: form.note, qrImage: form.qrImage }
          : {
              kind,
              bankName: form.bankName,
              accountNumber: form.accountNumber,
              accountName: form.accountName,
              branch: form.branch,
              district: form.district,
            }
      setMethodBusy(true)
      try {
        if (editingId) {
          await api.patch(`/settings/pay-methods/${editingId}`, payload)
          showToast({ title: 'Payment method updated', status: 'success' })
        } else {
          await api.post('/settings/pay-methods', payload)
          showToast({ title: 'Payment method added', status: 'success' })
        }
        resetForm()
        await reloadMethods()
      } catch (e) {
        fail(e)
      } finally {
        setMethodBusy(false)
      }
    })()

  const toggleMethod = (m: PayMethodRow) =>
    void api
      .patch(`/settings/pay-methods/${m.id}`, { enabled: !m.enabled })
      .then(reloadMethods)
      .catch(fail)

  const startEdit = (m: PayMethodRow) => {
    setEditingId(m.id)
    setKind(m.kind)
    setForm({
      provider: m.provider,
      label: m.label,
      number: m.number,
      note: m.note,
      qrImage: m.qrImage,
      bankName: m.bankName,
      accountNumber: m.accountNumber,
      accountName: m.accountName,
      branch: m.branch,
      district: m.district,
    })
  }

  return (
    <div>
      <PageHeader title="Settings" description="Manage operating defaults, shipping rates, and the payment details customers see." />
      <PageTabs value={section} onChange={setSection} items={[{value:'general',label:'General'},{value:'rates',label:'Shipping rates'},{value:'payments',label:'Payment methods'}]} />

      {section === 'general' && <Card className="mt-4 flex max-w-[900px] flex-col gap-4 p-5 rounded-[14px]">
        <div>
          <div className="text-[13px] font-bold">Exchange rate</div>
          <div className="mb-2 mt-0.75 text-xs text-muted-foreground">Used for total-worth figures across CNY and BDT</div>
          <div className="flex items-center gap-2 text-[13px]">
            ¥1 = ৳{' '}
            <Input
              label="BDT per CNY"
              className="w-28"
              value={rate}
              onChange={setRate}
            />
          </div>
        </div>
        <div>
          <div className="text-[13px] font-bold">Weight discrepancy alert</div>
          <div className="mb-2 mt-0.75 text-xs text-muted-foreground">
            Alert when BD weighed weight differs from CN booked weight by at least
          </div>
          <div className="flex items-center gap-2 text-[13px]">
            <Input
              label="Threshold (kg)"
              className="w-28"
              value={threshold}
              onChange={setThreshold}
            />{' '}
            kg
          </div>
        </div>
        <div className="border-t border-border pt-4"><Button onClick={() => {
          const nextRate = Number(rate), nextThreshold = Number(threshold)
          if (!rate.trim() || !threshold.trim() || !Number.isFinite(nextRate) || nextRate <= 0 || !Number.isFinite(nextThreshold) || nextThreshold < 0) { showToast({title:'Enter a positive exchange rate and a non-negative threshold',status:'error'}); return }
          save({rate:nextRate,threshold:nextThreshold})
        }}>Save general settings</Button></div>
      </Card>}

      {section === 'rates' && <Card className="mt-4 max-w-[900px] p-5 rounded-[14px]">
        <div className="text-[13px] font-bold">Per-piece shipping rates</div>
        <div className="mb-3 mt-0.75 text-xs text-muted-foreground">
          Fixed charge per piece for device categories (Mobile, Laptop, Drone …) — used as the default on new
          shipments, overridable per shipment. Added on top of the per-kg charge.
        </div>
        <div className="flex flex-col gap-2">
          {Object.entries(pcsRates).map(([category, value]) => (
            <div key={category} className="flex flex-wrap items-center gap-3 rounded-[10px] bg-background px-3.5 py-2">
              <div className="min-w-0 flex-1 text-[13px] font-bold">{category}</div>
              <span className="text-xs text-muted-foreground">৳</span>
              <Input
                className="w-24"
                value={value}
                onChange={(v) => setPcsRates((r) => ({ ...r, [category]: v }))}
                aria-label={`${category} rate in BDT per piece`}
              />
              <span className="text-xs text-muted-foreground">/pc</span>
              <Button
                variant="danger-outline"
                size="sm"
                onClick={() => {
                  const { [category]: _removed, ...rest } = pcsRates
                  setPcsRates(rest)
                }}
              >
                Remove
              </Button>
            </div>
          ))}
          {!Object.keys(pcsRates).length ? (
            <div className="rounded-[10px] border border-dashed border-[#C9C6BF] p-4 text-center text-xs text-muted-foreground">
              No per-piece rates yet — device categories will default to ৳0/pc on the shipment form.
            </div>
          ) : null}
          <div className="flex items-end gap-2">
            <Input className="min-w-0 flex-1" label="Category" placeholder="e.g. Mobile / Laptop / Drone" value={newPcsCat} onChange={setNewPcsCat} />
            <Input className="w-28" label="Rate ৳/pc" placeholder="0" value={newPcsRate} onChange={setNewPcsRate} />
            <Button
              onClick={() => {
                const cat = newPcsCat.trim()
                if (!cat || Number.isNaN(parseFloat(newPcsRate))) {
                  showToast({ title: 'Category and rate required', status: 'error' })
                  return
                }
                setPcsRates({ ...pcsRates, [cat]: newPcsRate })
                setNewPcsCat('')
                setNewPcsRate('')
              }}
            >
              + Add
            </Button>
          </div>
        </div>
        <Button className="mt-4" onClick={() => savePcsRates(pcsRates)}>Save shipping rates</Button>
      </Card>}

      {section === 'payments' && <Card className="mt-4 max-w-[900px] p-5 rounded-[14px]">
        <div className="text-[13px] font-bold">Payment methods</div>
        <p className="my-2 text-xs text-primary">Bank and mobile banking accounts are linked to Finance → Accounts & funds. Adding one here also creates its fund.</p>
        <div className="mb-3 mt-0.75 text-xs text-muted-foreground">
          Shown on the public tracking page — customers pay to one of these and upload the receipt. Write{' '}
          <code className="rounded bg-muted px-1">{'{code}'}</code> in a note to insert the shipment ID.
        </div>

        <div className="flex flex-col gap-2">
          {(payData?.methods ?? []).map((m) => (
            <div key={m.id} className="flex items-start gap-3 rounded-[10px] bg-background px-3.5 py-3">
              <button
                type="button"
                role="switch"
                aria-checked={m.enabled}
                aria-label={`Show ${methodTitle(m)} to customers`}
                title={m.enabled ? 'Shown on tracking pages — click to hide' : 'Hidden — click to show on tracking pages'}
                className={`mt-1 h-[16px] w-[28px] shrink-0 cursor-pointer rounded-full border-0 p-0 transition-colors ${m.enabled ? 'bg-primary' : 'bg-[#DDD9D1]'}`}
                onClick={() => toggleMethod(m)}
              >
                <span
                  className="block size-[12px] rounded-full bg-white shadow-[0_1px_2px_rgba(0,0,0,.25)] transition-transform"
                  style={{ transform: `translateX(${m.enabled ? 14 : 2}px)` }}
                />
              </button>
              {m.qrImage ? (
                <img src={m.qrImage} alt="" className="size-9 shrink-0 rounded-md border border-border bg-white object-contain" />
              ) : null}
              <div className="min-w-0 flex-1">
                <div className="text-[13px] font-bold">
                  {methodTitle(m)}{' '}
                  <span className="rounded-full bg-muted px-2 py-0.5 text-[10px] font-bold text-muted-foreground">
                    {m.kind === 'mobile_banking' ? 'Mobile banking' : 'Bank account'}
                  </span>{' '}
                  {!m.enabled ? (
                    <span className="rounded-full bg-danger-soft px-2 py-0.5 text-[10px] font-bold text-danger">hidden</span>
                  ) : null}
                </div>
                <div className="truncate text-xs text-muted-foreground">{methodSummary(m)}</div>
              </div>
              <Button variant="secondary" size="sm" onClick={() => startEdit(m)}>
                Edit
              </Button>
              <Button variant="danger-outline" size="sm" onClick={() => setDeleting(m)}>
                Delete
              </Button>
            </div>
          ))}
          {payData && !payData.methods.length ? (
            <div className="rounded-[10px] border border-dashed border-[#C9C6BF] p-5 text-center text-xs text-muted-foreground">
              No payment methods yet — tracking pages will show none until one is added.
            </div>
          ) : null}
        </div>

        <div className="mt-4 border-t border-dashed border-border pt-3.5">
          <div className="mb-2.5 flex items-center justify-between gap-2">
            <div className="text-[12px] font-bold">{editingId ? 'Edit payment method' : 'Add payment method'}</div>
            <div className="flex overflow-hidden rounded-[9px] border border-border text-[11.5px] font-bold">
              {(
                [
                  ['mobile_banking', 'Mobile banking'],
                  ['bank_account', 'Bank account'],
                ] as [PayMethodKind, string][]
              ).map(([value, label]) => (
                <button
                  key={value}
                  type="button"
                  className={`cursor-pointer border-0 px-3 py-1.75 ${kind === value ? 'bg-primary text-white' : 'bg-card text-muted-foreground'}`}
                  onClick={() => setKind(value)}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>

          {kind === 'mobile_banking' ? (
            <div className="flex flex-col gap-2.5">
              <div className="flex flex-col gap-2.5 sm:flex-row">
                <Input className="flex-1" label="Provider" placeholder="e.g. bKash / Nagad / Rocket" value={form.provider} onChange={set('provider')} />
                <Input className="flex-1" label="Label" placeholder="e.g. Merchant / Personal" value={form.label} onChange={set('label')} />
              </div>
              <Input label="Number" placeholder="e.g. 01711-220340" value={form.number} onChange={set('number')} />
              <Input label="Note (optional)" placeholder="e.g. Use Payment · Reference: {code}" value={form.note} onChange={set('note')} />
              <div className="flex items-center gap-2.5">
                <input
                  ref={fileRef}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => {
                    pickQr(e.target.files?.[0])
                    e.target.value = ''
                  }}
                />
                {form.qrImage ? (
                  <>
                    <img src={form.qrImage} alt="QR preview" className="size-14 rounded-lg border border-border bg-white object-contain p-1" />
                    <Button variant="secondary" size="sm" onClick={() => fileRef.current?.click()}>
                      Replace QR
                    </Button>
                    <Button variant="danger-outline" size="sm" onClick={() => setForm((f) => ({ ...f, qrImage: null }))}>
                      Remove
                    </Button>
                  </>
                ) : (
                  <>
                    <Button variant="secondary" size="sm" onClick={() => fileRef.current?.click()}>
                      + QR image (optional)
                    </Button>
                    <span className="text-[11px] text-muted-foreground">Without one, the page generates a QR from the number.</span>
                  </>
                )}
              </div>
            </div>
          ) : (
            <div className="flex flex-col gap-2.5">
              <div className="flex flex-col gap-2.5 sm:flex-row">
                <Input className="flex-1" label="Bank name" placeholder="e.g. City Bank" value={form.bankName} onChange={set('bankName')} />
                <Input className="flex-1" label="Account name" placeholder="e.g. SB Express Ltd." value={form.accountName} onChange={set('accountName')} />
              </div>
              <Input label="Account number" placeholder="e.g. 2201-448812-001" value={form.accountNumber} onChange={set('accountNumber')} />
              <div className="flex flex-col gap-2.5 sm:flex-row">
                <Input className="flex-1" label="Branch" placeholder="e.g. Bashundhara" value={form.branch} onChange={set('branch')} />
                <Input className="flex-1" label="District" placeholder="e.g. Dhaka" value={form.district} onChange={set('district')} />
              </div>
            </div>
          )}

          <div className="mt-3 flex gap-2">
            <Button disabled={methodBusy} onClick={submitMethod}>
              {editingId ? 'Save changes' : '+ Add method'}
            </Button>
            {editingId ? (
              <Button variant="secondary" onClick={resetForm}>
                Cancel
              </Button>
            ) : null}
          </div>
        </div>
      </Card>}

      <ConfirmDialog
        open={deleting !== null}
        onClose={() => setDeleting(null)}
        title={`Delete ${deleting ? methodTitle(deleting) : ''}?`}
        body="It disappears from every tracking page immediately. Receipts already uploaded with this method keep their record."
        onConfirm={async () => {
          if (!deleting) return
          try {
            await api.delete(`/settings/pay-methods/${deleting.id}`)
            showToast({ title: 'Payment method deleted', status: 'success' })
            await reloadMethods()
          } catch (e) {
            fail(e)
          }
        }}
      />
    </div>
  )
}
