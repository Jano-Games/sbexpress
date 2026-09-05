import { PageTabs } from '@/components/Workspace'
import { InvoiceHistory } from '@/components/CustomerCredit'
import { ShipmentMedia } from '@/components/ShipmentMedia'
import { useState, type ReactNode } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { api } from '@/api/client'
import { useFetch } from '@/state/useFetch'
import { useAuth } from '@/state/auth'
import type { ShipmentDetail as Detail } from '@/api/types'
import { Button } from '@/components/beui/button'
import { Input } from '@/components/beui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/beui/select'
import { useToast } from '@/components/beui/toast'
import { Card, Chip, ErrorBlock, Field, FlightCode, LoadingBlock, PIPELINE_LABELS, StatusChip, Stepper } from '@/components/ui'
import { ConfirmDialog } from '@/components/ConfirmDialog'
import { NewShipmentModal } from '@/modals/NewShipmentModal'
import { ShipmentInvoiceModal } from '@/modals/ShipmentInvoiceModal'
import { TrackLinkModal } from '@/modals/TrackLinkModal'
import { PAY_CHIP, PAY_LABEL, deltaLabel, fmtBdt, fmtDate, fmtLogAt, supplierLabel } from '@/lib/format'

function Tile({ label, value, sub }: { label: string; value: ReactNode; sub?: ReactNode }) {
  return (
    <div className="rounded-[10px] bg-background px-3.5 py-3">
      <div className="text-[11px] text-muted-foreground">{label}</div>
      <div className="mt-0.75 text-[13px] font-bold">{value}</div>
      {sub ? <div className="mt-px text-[11px] text-muted-foreground">{sub}</div> : null}
    </div>
  )
}

function MoneyStat({ label, value, tone }: { label: string; value: number; tone?: 'success' | 'danger' }) {
  return (
    <div className="rounded-[10px] bg-background px-3 py-2.5 text-center">
      <div className="text-[10px] font-bold uppercase tracking-[.06em] text-muted-foreground">{label}</div>
      <div
        className="mt-0.5 text-[15px] font-extrabold"
        style={{ color: tone === 'success' ? '#1B7A3D' : tone === 'danger' ? '#C92A2A' : '#1A1C1E' }}
      >
        {fmtBdt(value)}
      </div>
    </div>
  )
}

export function ShipmentDetail() {
  const { code = '' } = useParams()
  const { user } = useAuth()
  const { showToast } = useToast()
  const {data:paymentAccounts} = useFetch<{accounts:{name:string}[]}>(user?.role === 'admin' ? '/finance?period=all' : null)
  const navigate = useNavigate()
  const { data, error, loading, reload } = useFetch<{ shipment: Detail }>(`/shipments/${code}`)

  const [section, setSection] = useState('overview')
  const [invoiceOpen, setInvoiceOpen] = useState(false)
  const [trackOpen, setTrackOpen] = useState(false)
  const [editOpen, setEditOpen] = useState(false)
  const [deleteOpen, setDeleteOpen] = useState(false)
  const [weighInput, setWeighInput] = useState('')
  const [creditAmount,setCreditAmount] = useState('')
  const [creditReason,setCreditReason] = useState('')
  const [packageCount,setPackageCount] = useState('1')
  const [bdFareInput, setBdFareInput] = useState('')
  const [courier, setCourier] = useState('Pathao')
  const [lmRef, setLmRef] = useState('')
  const [expCat, setExpCat] = useState('packaging')
  const [expAmt, setExpAmt] = useState('')
  const [expReason, setExpReason] = useState('')
  const [costField,setCostField] = useState('cnFare')
  const [costPayment,setCostPayment] = useState('')
  const [costAccount,setCostAccount] = useState('')
  const [payAmt, setPayAmt] = useState('')
  const [payMethod, setPayMethod] = useState('Cash')

  if (error) return <ErrorBlock message={error} />
  if (loading || !data) return <LoadingBlock />
  const s = data.shipment
  const isAdmin = user?.role === 'admin'
  const isStaff = isAdmin || user?.role === 'hub'
  const canAdvance = s.statusIndex < 8 && (isAdmin || (user?.role === 'hub' && s.statusIndex >= 4))

  const act = (fn: () => Promise<unknown>, success?: string) => () =>
    void fn()
      .then(() => {
        if (success) showToast({ title: success, status: 'success' })
        return reload()
      })
      .catch((e: unknown) => showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' }))

  return (
    <div>
      {/* ── Header: navigation + the few actions that change the shipment itself ── */}
      <div className="flex flex-wrap items-center justify-between gap-2.5">
        <Link to="/shipments" className="text-[12.5px] font-semibold text-blue no-underline">
          ← Shipments
        </Link>
        <div className="flex flex-wrap gap-2">
          {isAdmin ? (
            <>
              <Button variant="secondary" onClick={() => setEditOpen(true)}>
                Edit
              </Button>
              <Button variant="danger-outline" onClick={() => setDeleteOpen(true)}>
                Delete
              </Button>
            </>
          ) : null}
          {isAdmin ? (
            <Button variant="secondary" onClick={() => setTrackOpen(true)}>
              Tracking link
            </Button>
          ) : null}
          {canAdvance ? (
            <Button onClick={act(() => api.post(`/shipments/${s.code}/advance`), 'Status updated')}>
              Mark: {PIPELINE_LABELS[s.statusIndex + 1]} →
            </Button>
          ) : null}
        </div>
      </div>

      {/* ── Identity: who/what/where + pipeline position ── */}
      <Card className="mt-3 overflow-hidden">
        <div className="flex flex-wrap items-center gap-3.5 bg-ink px-5.5 py-4 text-white">
          <div>
            <div className="flex flex-wrap items-center gap-3">
              <h1 className="m-0 break-all text-[24px] font-extrabold">{s.code}</h1>
              <StatusChip index={s.statusIndex} label={s.statusLabel} className="px-3 py-1.25 text-xs" />
              <Chip colors={PAY_CHIP[s.payStatus] ?? PAY_CHIP.unpaid!} className="px-3 py-1.25 text-xs">
                {PAY_LABEL[s.payStatus]}
              </Chip>
            </div>
            <div className="mt-1 text-[12.5px] text-[#E3E5E8]">
              {supplierLabel(s.supplierCode, s.supplierName)} · {s.categories.join(', ')} · {s.description}
            </div>
          </div>
          <div className="ml-auto flex items-center gap-2.5 rounded-xl bg-ink-soft px-4 py-2.5">
            <div className="text-center">
              <div className="text-sm font-extrabold">CTU</div>
              <div className="text-[10px] text-[#E3E5E8]">Chengdu</div>
            </div>
            <div className="font-extrabold text-primary">✈ →</div>
            <div className="text-center">
              <div className="text-sm font-extrabold">DAC</div>
              <div className="text-[10px] text-[#E3E5E8]">Dhaka</div>
            </div>
            <div className="ml-1 border-l border-[#44474C] pl-3">
              <div className="text-[12.5px] font-bold text-[#7BD8CF]">
                <FlightCode code={s.flightCode} />
              </div>
              <div className="text-[10.5px] text-[#E3E5E8]">{fmtDate(s.flightDate)}</div>
            </div>
          </div>
        </div>
        <Stepper steps={PIPELINE_LABELS} current={s.statusIndex} />
      </Card>

      <PageTabs value={section} onChange={setSection} items={[{value:'overview',label:'Overview & processing'},{value:'media',label:'Photos & videos'},...(isAdmin ? [{value:'history',label:'Invoice history'}] : [])]} />
      {section === 'media' && <ShipmentMedia code={code} admin={isAdmin} />}
      {section === 'history' && isAdmin && <InvoiceHistory key={JSON.stringify(s)} code={code} />}
      {section === 'overview' && <>
      {s.weightDelta !== null ? (
        <div className="mt-3 flex items-center gap-2.5 rounded-[10px] border border-[#F1C4C4] bg-danger-soft px-4 py-2.75 text-[12.5px]">
          <span className="font-extrabold text-danger">WEIGHT</span>
          <span>
            Weight discrepancy: weighed {s.weighedKg} kg vs {s.bookedKg} kg booked ({deltaLabel(s.weightDelta)}). Verify with CN hub
            before billing.
          </span>
        </div>
      ) : null}

      <div className="mt-3.5 flex flex-wrap items-start gap-3.5">
        {/* ══ Left: what the shipment is, and its money ══ */}
        <div className="flex min-w-0 w-full lg:min-w-[340px] lg:flex-[1.6] flex-col gap-3.5">
          <Card className="p-4.5 rounded-[14px]">
            <div className="mb-3.5 text-[13px] font-bold">Shipment</div>
            <div className="grid gap-2.5 [grid-template-columns:repeat(auto-fit,minmax(130px,1fr))]">
              <Tile label="Supplier" value={supplierLabel(s.supplierCode, s.supplierName)} />
              <Tile label="Product" value={s.categories.join(', ')} sub={s.description} />
              <Tile label="Booked (CN)" value={`${s.bookedKg} kg`} />
              <Tile
                label="Weighed (BD)"
                value={
                  <>
                    {s.weighedKg !== null ? `${s.weighedKg} kg` : '—'}{' '}
                    {s.weightDelta !== null ? <span className="text-[11px] font-bold text-danger">{deltaLabel(s.weightDelta)}</span> : null}
                  </>
                }
              />
              {s.pcsItems.length ? (
                <Tile
                  label="Devices (per piece)"
                  value={s.pcsItems
                    .map((i) => `${i.count}× ${i.category} @ ${i.currency === 'CNY' ? '¥' : '৳'}${i.rate}`)
                    .join(' · ')}
                />
              ) : null}
              {s.serials.length ? <Tile label="Serial / IMEI" value={s.serials.join(', ')} /> : null}
              <Tile label="Created" value={fmtDate(s.date)} />
              <Tile label="Last mile" value={s.lastMile ? `${s.lastMile.courier} · ${s.lastMile.ref}` : 'none'} />
            </div>
              <p className="mt-3 text-sm text-muted-foreground">Carrying flyer: {s.flyerName ?? 'Unassigned'} · Packages: {s.packageCount || 'Not packed'}</p>
          </Card>

          {isAdmin ? (
            <Card className="p-4.5 rounded-[14px]">
              <div className="mb-3 flex items-center justify-between gap-2">
                <div className="text-[13px] font-bold">Billing &amp; payments</div>
                <Chip colors={PAY_CHIP[s.payStatus] ?? PAY_CHIP.unpaid!}>{PAY_LABEL[s.payStatus]}</Chip>
              </div>

              <div className="grid grid-cols-3 gap-2">
                <MoneyStat label="Bill" value={s.billAmount} />
                <MoneyStat label="Paid" value={s.paidAmount} tone="success" />
                <MoneyStat label="Remaining" value={s.dueAmount} tone={s.dueAmount > 0 ? 'danger' : 'success'} />
              </div>

              <div className="mt-2.5 flex flex-wrap items-center justify-between gap-2 rounded-[10px] bg-background px-3 py-2.5 text-[12.5px]">
                {s.invoice ? (
                  <div className="min-w-0">
                    <b>{s.invoice.number}</b>
                    <span className="text-muted-foreground">
                      {' '}
                      · issued {fmtDate(s.invoice.issuedAt)}
                      {s.invoice.discount > 0 ? (
                        <>
                          {' '}
                          · <span className="font-bold text-danger">−{fmtBdt(s.invoice.discount)} discount</span>
                        </>
                      ) : null}
                    </span>
                  </div>
                ) : (
                  <span className="text-muted-foreground">No invoice yet — the bill uses the computed charge.</span>
                )}
                <Button variant="secondary" size="sm" onClick={() => setInvoiceOpen(true)}>
                  {s.invoice ? 'View / Edit invoice' : 'Generate invoice'}
                </Button>
              </div>

              {s.payments.length ? (
                <div className="mt-3 border-t border-dashed border-border pt-2.5">
                  <div className="mb-1.5 text-[11px] font-bold uppercase tracking-[.05em] text-muted-foreground">
                    Payments received
                  </div>
                  <div className="flex flex-col gap-1">
                    {s.payments.map((p, i) => (
                      <div key={i} className="flex justify-between text-[12px]">
                        <span className="text-muted-foreground">
                          {fmtLogAt(p.at)} · {p.method}
                        </span>
                        <b className="text-success">+ {fmtBdt(p.amount)}</b>
                      </div>
                    ))}
                  </div>
                </div>
              ) : null}

              {s.receipt ? (
                <div className="mt-2.5 text-[12px] text-muted-foreground">
                  Customer receipt: <b className="text-foreground">{s.receipt.method}</b> · {fmtBdt(s.receipt.amount)} ·{' '}
                  <span
                    className="font-bold"
                    style={{ color: s.receipt.status === 'approved' ? '#1B7A3D' : s.receipt.status === 'pending' ? '#B45309' : '#C92A2A' }}
                  >
                    {s.receipt.status}
                  </span>
                </div>
              ) : null}

              {s.dueAmount > 0 ? (
                <div className="mt-3 flex flex-wrap items-end gap-1.5 border-t border-dashed border-border pt-3">
                  <Input className="w-28" label="Amount (৳)" placeholder={String(s.dueAmount)} value={payAmt} onChange={setPayAmt} />
                  <Field label="Method" className="w-28">
                    <Select value={payMethod} onValueChange={setPayMethod}>
                      <SelectTrigger className="h-10 text-xs">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {(paymentAccounts?.accounts ?? []).map(a => a.name).map((m) => (
                          <SelectItem key={m} value={m}>
                            {m}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </Field>
                  <Button
                    variant="success"
                    onClick={act(async () => {
                      const amount = parseFloat(payAmt)
                      if (Number.isNaN(amount) || amount <= 0) throw new Error('Enter the amount received')
                      await api.post(`/shipments/${s.code}/payments`, { amount, method: payMethod })
                      setPayAmt('')
                    }, 'Payment recorded')}
                  >
                    Record payment
                  </Button>
                  <Button
                    variant="secondary"
                    onClick={act(() => api.post(`/shipments/${s.code}/mark-paid`), 'Settled in cash')}
                  >
                    Settle {fmtBdt(s.dueAmount)} (cash)
                  </Button>
                </div>
              ) : null}

              <div className="mt-3 flex flex-wrap gap-2">
                <Input label="Credit amount (BDT)" value={creditAmount} onChange={setCreditAmount} />
                <Input label="Credit reason" value={creditReason} onChange={setCreditReason} />
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={act(() => api.post(`/shipments/${s.code}/after-sales`,{amount:Number(creditAmount),reason:creditReason}), 'Credit applied')}
                >
                  Apply damage / goodwill credit
                </Button>
              </div>
            </Card>
          ) : null}

          {isAdmin && s.costs ? (
            <Card className="overflow-hidden rounded-[14px]">
              <div className="p-4.5 pb-3.5">
                <div className="mb-3 text-[13px] font-bold">Costs &amp; profit</div>
                <div className="flex flex-col gap-2 text-[12.5px]">
                  <div className="flex items-center justify-between rounded-lg bg-background px-3 py-2">
                    <span className="font-semibold">Net invoice / billing</span>
                    <b className="text-[13.5px]">{fmtBdt(s.billAmount)}</b>
                  </div>
                  <div className="flex justify-between px-3">
                    <span className="text-muted-foreground">
                      Estimated agency ticket share ({s.bookedKg} kg of {s.flightSpaceKg ?? '—'} kg)
                    </span>
                    <span className="text-danger">− {fmtBdt(s.costs.fareShare)}</span>
                  </div>
                  <div className="flex justify-between px-3">
                    <span className="text-muted-foreground">CN transport</span>
                    <span className="text-danger">− {fmtBdt(s.costs.cnFare)}</span>
                  </div>
                  <div className="flex justify-between px-3">
                    <span className="text-muted-foreground">BD transport</span>
                    <span className="text-danger">− {fmtBdt(s.costs.bdFare ?? 0)}</span>
                  </div>
                  <div className="flex justify-between px-3">
                    <span className="text-muted-foreground">Customs tax</span>
                    <span className="text-danger">− {fmtBdt(s.costs.customsTax)}</span>
                  </div>
                  <div className="flex justify-between px-3">
                    <span className="text-muted-foreground">Credit already included in net billing</span>
                    <span className="text-danger">− {fmtBdt(s.costs.afterSalesFee)}</span>
                  </div>
                  {s.costs.extraLines.map((line, i) => (
                    <div key={i} className="flex justify-between px-3">
                      <span className="text-muted-foreground">
                        {line.category} — {line.reason}
                      </span>
                      <span className="text-danger">− {fmtBdt(line.amount)}</span>
                    </div>
                  ))}
                </div>
                <div className="mt-3 border-t pt-3 space-y-2">
                  <h3 className="font-bold text-sm">Pay a recorded cost</h3>
                  <p className="text-xs text-muted-foreground">Unpaid: CN {fmtBdt(s.costs.unpaidCosts.cnFare)} · BD {fmtBdt(s.costs.unpaidCosts.bdFare)} · Customs {fmtBdt(s.costs.unpaidCosts.customsTax)}</p>
                  <select aria-label="Recorded cost" className="border rounded p-2" value={costField} onChange={e=>setCostField(e.target.value)}><option value="cnFare">CN transport</option><option value="bdFare">BD transport</option><option value="customsTax">Customs</option></select>
                  <select aria-label="Cost paying account" className="border rounded p-2 ml-2" value={costAccount} onChange={e=>setCostAccount(e.target.value)}><option value="" disabled>Select account</option>{(paymentAccounts?.accounts ?? []).map(a=><option key={a.name}>{a.name}</option>)}</select>
                  <Input label="Cost payment (BDT)" value={costPayment} onChange={setCostPayment} />
                  <Button onClick={act(()=>api.post(`/shipments/${s.code}/expenses`,{category:costField === 'customsTax'?'customs':'transport',amount:Number(costPayment),reason:`Payment of ${costField}`,accountName:costAccount,costField}),'Recorded cost paid')}>Record cost payment</Button>
                  <p className="text-xs text-muted-foreground">This settles an existing cost without adding another customer charge. A new additional expense is added to both the cost ledger and customer bill.</p>
                </div>
                <div className="mt-3 flex flex-wrap items-end gap-1.5 border-t border-dashed border-border pt-3">
                  <Field label="Category" className="w-30">
                    <Select value={expCat} onValueChange={setExpCat}>
                      <SelectTrigger className="h-10 text-[11.5px]">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {['packaging', 'courier', 'transport', 'customs', 'others'].map((c) => (
                          <SelectItem key={c} value={c}>
                            {c.charAt(0).toUpperCase() + c.slice(1)}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </Field>
                  <label className="text-xs">Pay from<select className="mt-1 block rounded border p-2" value={costAccount} onChange={e=>setCostAccount(e.target.value)}><option value="" disabled>Select account</option>{(paymentAccounts?.accounts ?? []).map(a=><option key={a.name}>{a.name}</option>)}</select></label>
                  <Input className="w-20" label="Amount (৳)" placeholder="0" value={expAmt} onChange={setExpAmt} />
                  <Input className="min-w-[90px] flex-1" label="Reason" placeholder="Required" value={expReason} onChange={setExpReason} />
                  <Button
                    variant="dark"
                    onClick={act(async () => {
                      const amount = parseFloat(expAmt)
                      if (!Number.isFinite(amount) || amount <= 0 || !expReason.trim() || !costAccount) throw new Error('Enter a positive amount, reason and paying account')
                      await api.post(`/shipments/${s.code}/expenses`, { category: expCat, amount, reason: expReason, accountName: costAccount })
                      setExpAmt('')
                      setExpReason('')
                    }, `Expense added to ${s.code}`)}
                  >
                    + Expense & customer charge
                  </Button>
                </div>
              </div>
              <div className="flex items-center justify-between bg-ink px-4.5 py-3.5 text-white">
                <div className="flex items-center gap-2.5">
                  <span
                    className="rounded-[10px] px-2.25 py-0.75 text-[10px] font-extrabold tracking-[.08em]"
                    style={{ background: s.costs.profit >= 0 ? '#1B7A3D' : '#C92A2A' }}
                  >
                    {s.costs.profit >= 0 ? 'PROFIT' : 'LOSS'}
                  </span>
                  <span className="text-[11.5px] text-[#B9BCC1]">
                    {s.costs.profitPct !== null ? `${s.costs.profitPct}% margin` : '—'}
                  </span>
                </div>
                <div className="text-xl font-extrabold" style={{ color: s.costs.profit >= 0 ? '#7CE79A' : '#FF8F8F' }}>
                  {fmtBdt(s.costs.profit)}
                </div>
              </div>
            </Card>
          ) : null}
        </div>

        {/* ══ Right: Dhaka-side operations and the audit trail ══ */}
        <div className="flex min-w-0 w-full lg:min-w-[300px] lg:flex-1 flex-col gap-3.5">
          {isStaff ? (
            <Card className="p-4.5 rounded-[14px]">
              <div className="mb-3 text-[13px] font-bold">BD hub handling</div>
              <div className="flex flex-col gap-3 text-[12.5px]">
                <div className="flex gap-2.5">
                  <Field label="Weighed (kg)" className="flex-1">
                    <div className="flex gap-2">
                      <Input className="min-w-0 flex-1" placeholder={s.weighedKg !== null ? String(s.weighedKg) : '0.0'} value={weighInput} onChange={setWeighInput} />
                      <Button
                        variant="dark"
                        className="bg-blue hover:bg-blue/90"
                        onClick={act(async () => {
                          const v = parseFloat(weighInput)
                          if (Number.isNaN(v)) throw new Error('Enter a weight first')
                          await api.post(`/shipments/${s.code}/weigh`, { kg: v })
                          setWeighInput('')
                        }, 'Weight saved')}
                      >
                        Save
                      </Button>
                    </div>
                  </Field>
                  <Field label="BD transport (৳)" className="flex-1">
                    <div className="flex gap-2">
                      <Input className="min-w-0 flex-1" placeholder={s.costs?.bdFare != null ? String(s.costs.bdFare) : '0'} value={bdFareInput} onChange={setBdFareInput} />
                      <Button
                        variant="dark"
                        className="bg-blue hover:bg-blue/90"
                        onClick={act(async () => {
                          const v = parseFloat(bdFareInput)
                          if (Number.isNaN(v)) throw new Error('Enter an amount first')
                          await api.post(`/shipments/${s.code}/bd-fare`, { amount: v })
                          setBdFareInput('')
                        }, 'BD fare saved')}
                      >
                        Save
                      </Button>
                    </div>
                  </Field>
                </div>
                <div className="flex items-end gap-2">
                  <Input label="Number of packages" value={packageCount} onChange={setPackageCount} />
                  <Button onClick={act(() => api.post(`/shipments/${s.code}/pack`,{count:Number(packageCount)}),'Packing confirmed')}>Confirm packing</Button>
                </div>
                <Field label="Last mile booking">
                  <div className="flex gap-2">
                    <Select value={courier} onValueChange={setCourier} className="w-30">
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {['Pathao', 'Steadfast', 'Hub pickup'].map((c) => (
                          <SelectItem key={c} value={c}>
                            {c}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <Input className="min-w-0 flex-1" placeholder="Booking ref" value={lmRef} onChange={setLmRef} />
                    <Button
                      variant="dark"
                      className="bg-blue hover:bg-blue/90"
                      onClick={act(async () => {
                        await api.post(`/shipments/${s.code}/last-mile`, { courier, ref: lmRef })
                        setLmRef('')
                      }, `Last mile booked: ${courier}`)}
                    >
                      Book
                    </Button>
                  </div>
                </Field>
                <div className="text-muted-foreground">
                  Current booking: <b className="text-foreground">{s.lastMile ? `${s.lastMile.courier} · ${s.lastMile.ref}` : 'none'}</b>
                </div>
              </div>
            </Card>
          ) : null}

          <Card className="p-4.5 rounded-[14px]">
            <div className="mb-3 text-[13px] font-bold">Edit log</div>
            <div className="flex flex-col gap-2">
              {s.log.map((entry, i) => (
                <div key={i} className="border-l-2 border-border pl-2.5 text-xs leading-relaxed text-muted-foreground">
                  {entry.actor} · {fmtLogAt(entry.at)} — {entry.message}
                </div>
              ))}
            </div>
          </Card>
        </div>
      </div>

      </>}
      <ShipmentInvoiceModal open={invoiceOpen} onClose={() => setInvoiceOpen(false)} code={s.code} onSaved={() => void reload()} />
      <TrackLinkModal open={trackOpen} onClose={() => setTrackOpen(false)} code={s.code} />
      <NewShipmentModal open={editOpen} onClose={() => setEditOpen(false)} editing={s} onDone={() => void reload()} />
      <ConfirmDialog
        open={deleteOpen}
        onClose={() => setDeleteOpen(false)}
        title={`Delete ${s.code}?`}
        body="The shipment, its edit log, receipt and tracking link are removed permanently. Booked expenses stay in the finance ledger."
        onConfirm={async () => {
          try {
            await api.delete(`/shipments/${s.code}`)
            showToast({ title: `${s.code} deleted`, status: 'success' })
            navigate('/shipments')
          } catch (e) {
            showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' })
          }
        }}
      />
    </div>
  )
}
