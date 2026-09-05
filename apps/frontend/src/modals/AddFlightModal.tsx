import { useFetch } from '@/state/useFetch'
import { fmtBdt } from '@/lib/format'
import { useEffect, useMemo, useRef, useState } from 'react'
import { Search } from 'lucide-react'
import { api } from '@/api/client'
import type { Flyer, FlightLeg, FlightLookup, FlightSummary } from '@/api/types'
import { Modal } from '@/components/Modal'
import { Button } from '@/components/beui/button'
import { Input } from '@/components/beui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/beui/select'
import { useToast } from '@/components/beui/toast'
import { fmtDayMonth } from '@/lib/format'
import { AddFlyerModal } from './AddFlyerModal'

const EMPTY = {
  code: '',
  date: '',
  agencyShare: '',
  actualCost: '',
  spaceKg: '44',
  mobiles: '2',
  laptops: '1',
  status: 'upcoming',
}

export function AddFlightModal({
  open,
  onClose,
  onDone,
  lockedFlyer,
  editing,
}: {
  open: boolean
  onClose: () => void
  /** Receives the (possibly renamed) flight code after an edit. */
  onDone: (code?: string) => void
  /** Pre-selected flyer when opened from a flyer page; more can be added. */
  lockedFlyer?: string
  /** When set, the modal edits this flight instead of adding a new one. */
  editing?: FlightSummary
}) {
  const { showToast } = useToast()
  const {data:funds,error:fundsError,loading:fundsLoading,reload:reloadFunds}=useFetch<{rate:number;accounts:{name:string;currency:string;balance:number}[]}>(open?'/finance?period=all':null)
  const [accountName,setAccountName]=useState('')
  const [submitError,setSubmitError]=useState('')
  const submitLock=useRef(false)
  const [busy, setBusy] = useState(false)
  const [flyers, setFlyers] = useState<Flyer[]>([])
  const [selected, setSelected] = useState<string[]>([])
  const [query, setQuery] = useState('')
  const [pickerOpen, setPickerOpen] = useState(false)
  const [registering, setRegistering] = useState(false)
  const [form, setForm] = useState(EMPTY)
  const [lookupBusy, setLookupBusy] = useState(false)
  const [lookupInfo, setLookupInfo] = useState<string | null>(null)
  /** Amber banner when a search replaced an existing itinerary. */
  const [lookupWarn, setLookupWarn] = useState(false)
  /** The last successful lookup, ready to be appended as a leg. */
  const [lookupLeg, setLookupLeg] = useState<FlightLeg | null>(null)
  /** A multi-code search result waiting for the Update button. */
  const [pendingLegs, setPendingLegs] = useState<FlightLeg[] | null>(null)
  const [legs, setLegs] = useState<FlightLeg[]>([])

  useEffect(() => {
    if (!open) return
    setAccountName('')
    setSubmitError('')
    setQuery('')
    setLookupInfo(null)
    setLookupWarn(false)
    setLookupLeg(null)
    setPendingLegs(null)
    setLegs(editing ? editing.legs : [])
    if (editing) {
      setForm({
        code: editing.code,
        date: editing.date,
        agencyShare: String(editing.agencyShare || ''),
        actualCost: String(editing.actualCost || ''),
        spaceKg: String(editing.spaceKg),
        mobiles: String(editing.mobiles),
        laptops: String(editing.laptops),
        status: editing.status,
      })
      return
    }
    setForm(EMPTY)
    setSelected(lockedFlyer ? [lockedFlyer] : [])
    api
      .get<{ flyers: Flyer[] }>('/flyers')
      .then((r) => setFlyers(r.flyers))
      .catch(() => undefined)
  }, [open, lockedFlyer, editing])

  const suggestions = useMemo(() => {
    const q = query.trim().toLowerCase()
    return flyers
      .filter((f) => !selected.includes(f.name) && (!q || f.name.toLowerCase().includes(q)))
      .slice(0, 8)
  }, [flyers, selected, query])

  const showRegister =
    query.trim().length > 1 && !flyers.some((f) => f.name.toLowerCase() === query.trim().toLowerCase())

  const legFromLookup = (fl: NonNullable<FlightLookup['flight']>): FlightLeg => ({
    code: fl.code,
    date: form.date || null,
    fromIata: fl.from.iata ?? '',
    fromCity: fl.from.city ?? '',
    toIata: fl.to.iata ?? '',
    toCity: fl.to.city ?? '',
    depTime: fl.depTime ?? '—',
    arrTime: fl.arrTime ?? '—',
  })

  const searchSchedule = async () => {
    // "MU5850+MU2035" or "MU5850, MU2035" searches both, in the typed order.
    const codes = form.code.split(/[+,]/).map((s) => s.trim()).filter(Boolean)
    if (!codes.length || !form.date) {
      showToast({ title: 'Enter flight no and date first', status: 'error' })
      return
    }
    setLookupBusy(true)
    setLookupInfo(null)
    setLookupWarn(false)
    setLookupLeg(null)
    setPendingLegs(null)
    try {
      if (codes.length > 1) {
        // Multi-code: look them up sequentially and show the itinerary as a
        // preview — the Update button commits it (replacing existing legs,
        // since a re-search usually means a new date).
        const found: FlightLeg[] = []
        const notes: string[] = []
        let sample = false
        for (const code of codes) {
          try {
            const r = await api.get<FlightLookup>(`/flights/lookup?code=${encodeURIComponent(code)}&date=${form.date}`)
            if (r.found && r.flight) {
              found.push(legFromLookup(r.flight))
              notes.push(`${r.flight.code} ✓`)
              sample ||= Boolean(r.sample)
            } else {
              notes.push(`${code} not found`)
            }
          } catch {
            notes.push(`${code} lookup failed`)
          }
        }
        if (found.length) setPendingLegs(found)
        setLookupWarn(Boolean(found.length && legs.length))
        setLookupInfo(`${notes.join(' · ')}${sample ? ' · sample data (no API key set)' : ''}`)
        return
      }

      const r = await api.get<FlightLookup>(`/flights/lookup?code=${encodeURIComponent(codes[0]!)}&date=${form.date}`)
      if (!r.found || !r.flight) {
        setLookupInfo('No flight found for that number on that date.')
        return
      }
      const fl = r.flight
      setLookupLeg(legFromLookup(fl))
      const route = `${fl.from.iata ?? '?'} ${fl.from.city ?? ''} → ${fl.to.iata ?? '?'} ${fl.to.city ?? ''}`
      setLookupInfo(
        `${fl.airline ?? 'Unknown airline'} · ${route}${fl.status ? ` · ${fl.status}` : ''}${r.sample ? ' · sample data (no API key set)' : ''}`,
      )
    } catch (e) {
      showToast({ title: e instanceof Error ? e.message : 'Lookup failed', status: 'error' })
    } finally {
      setLookupBusy(false)
    }
  }

  const addLeg = () => {
    if (!lookupLeg) return
    setLegs((l) => [...l, lookupLeg])
    setLookupLeg(null)
    setLookupInfo(null)
    setForm((f) => ({ ...f, code: '' }))
  }

  /** Endpoint chain for display: CTU → CAN → DAC. */
  const routeLabel = useMemo(() => {
    if (!legs.length) return null
    const stops = [legs[0]!.fromIata || legs[0]!.fromCity || '?', ...legs.map((l) => l.toIata || l.toCity || '?')]
    return stops.join(' → ')
  }, [legs])

  const pick = (name: string) => {
    setSelected((s) => [...s, name])
    setQuery('')
    // Keep the list open — the input still has focus and more flyers may follow.
    setPickerOpen(true)
  }

  const actualCost=Number(form.actualCost || 0), agencyShare=Number(form.agencyShare || 0)
  const ticketMovement=actualCost-(editing?.ticketPaid ?? 0)
  const payingAccount=funds?.accounts.find(a=>a.name===accountName)
  const accountMovement=payingAccount?.currency==='CNY' ? Math.round(ticketMovement/(funds?.rate || 1)*100)/100 : ticketMovement
  const paymentError=!Number.isFinite(actualCost)||actualCost<0||!Number.isFinite(agencyShare)||agencyShare<0
    ? 'Enter valid, non-negative ticket amounts.'
    : agencyShare>actualCost ? 'Agency share cannot exceed the actual ticket cost.'
    : ticketMovement===0 || !accountName ? ''
    : fundsLoading ? 'Loading accounts…'
    : fundsError ? 'Could not load funds. Refresh accounts and try again.'
    : !funds?.accounts.length ? 'Add an account in Finance first, then refresh accounts here.'
    : !payingAccount ? 'This account is no longer available. Choose another account or save without payment.'
    : ticketMovement>0 && accountMovement>payingAccount.balance ? `Insufficient balance in ${payingAccount.name}. Add funds or choose another account.`
    : ''

  const submit = async () => {
    if(submitLock.current) return
    setSubmitError('')
    if(paymentError){setSubmitError(paymentError);return}
    if (!editing && !legs.length) {
      setSubmitError('Search the flight and add it to the itinerary first.')
      return
    }
    if (!editing && !selected.length) {
      setSubmitError('Pick at least one flyer.')
      return
    }
    submitLock.current=true
    setBusy(true)
    try {
      const common = {
        // With legs the backend derives the real code; the field still needs a value.
        code: form.code.trim() || legs[0]?.code || editing?.code || '',
        date: form.date || new Date().toISOString().slice(0, 10),
        accountName: ticketMovement!==0 && accountName ? accountName : undefined,
        agencyShare: parseFloat(form.agencyShare) || 0,
        actualCost: parseFloat(form.actualCost) || 0,
        spaceKg: Number.isNaN(parseInt(form.spaceKg)) ? 44 : parseInt(form.spaceKg),
        mobiles: Number.isNaN(parseInt(form.mobiles)) ? 2 : parseInt(form.mobiles),
        laptops: Number.isNaN(parseInt(form.laptops)) ? 1 : parseInt(form.laptops),
        legs: legs.length ? legs : undefined,
      }
      if (editing) {
        const r = await api.patch<{ code: string }>(`/flights/${editing.code}`, { ...common, status: form.status })
        showToast({ title: 'Flight updated', status: 'success' })
        onDone(r.code)
      } else {
        await api.post('/flights', { ...common, flyerNames: selected })
        showToast({ title: 'Flight added', status: 'success' })
        onDone()
      }
      onClose()
      setForm(EMPTY)
      setSelected([])
    } catch (e) {
      setSubmitError(e instanceof Error ? e.message : 'Could not save the flight. Your entries are still here.')
      void reloadFunds()
    } finally {
      submitLock.current=false
      setBusy(false)
    }
  }

  return (
    <>
      <Modal open={open && !registering} onClose={()=>{if(!submitLock.current)onClose()}}>
        <div data-dialog-title className="mb-3.5 text-[17px] font-extrabold">{editing ? `Edit flight — ${editing.code}` : 'Add flight'}</div>
        <div className="flex flex-col gap-2.5 text-[12.5px]">
          {editing ? null : (
            <div className="rounded-[9px] border border-border p-2.5">
              <div className="mb-2 flex items-center justify-between gap-2">
                <div className="text-[11px] font-bold uppercase tracking-[.05em] text-muted-foreground">
                  Flyers on this flight
                </div>
                <button
                  type="button"
                  className="cursor-pointer border-0 bg-transparent p-0 text-xs font-semibold text-blue"
                  onClick={() => setRegistering(true)}
                >
                  + Register new
                </button>
              </div>
              {selected.length ? (
                <div className="mb-2 flex flex-wrap gap-1.5">
                  {selected.map((name) => (
                    <span
                      key={name}
                      className="inline-flex items-center gap-1.5 rounded-full bg-primary-soft px-2.5 py-1.25 text-[11.5px] font-bold text-primary"
                    >
                      {name}
                      <button
                        type="button"
                        className="cursor-pointer border-0 bg-transparent p-0 font-extrabold text-primary"
                        onClick={() => setSelected((s) => s.filter((x) => x !== name))}
                      >
                        ×
                      </button>
                    </span>
                  ))}
                </div>
              ) : null}
              <div className="relative">
                <Input
                  placeholder="Search flyer to add…"
                  value={query}
                  onChange={(v) => {
                    setQuery(v)
                    setPickerOpen(true)
                  }}
                  onFocus={() => setPickerOpen(true)}
                  onBlur={() => window.setTimeout(() => setPickerOpen(false), 150)}
                />
                {pickerOpen && (suggestions.length > 0 || showRegister) ? (
                  <div className="absolute left-0 right-0 top-[calc(100%+4px)] z-20 max-h-[190px] overflow-auto rounded-[10px] border border-border bg-card p-1 shadow-[0_10px_28px_rgba(0,0,0,.14)]">
                    {suggestions.map((f) => (
                      <div
                        key={f.name}
                        className="flex cursor-pointer items-center justify-between gap-2.5 rounded-[7px] px-3 py-2.25 text-[12.5px] font-semibold hover:bg-primary-soft hover:text-primary"
                        onMouseDown={(e) => {
                          e.preventDefault()
                          pick(f.name)
                        }}
                      >
                        <span>{f.name}</span>
                        <span className="text-[11px] font-normal text-faint">{f.bdPhone}</span>
                      </div>
                    ))}
                    {showRegister ? (
                      <div
                        className="cursor-pointer rounded-[7px] border-t border-muted px-3 py-2.25 text-[12.5px] font-bold text-primary hover:bg-primary-soft"
                        onMouseDown={(e) => {
                          e.preventDefault()
                          setRegistering(true)
                        }}
                      >
                        + Register "{query.trim()}" as a new flyer
                      </div>
                    ) : null}
                  </div>
                ) : null}
              </div>
            </div>
          )}
          <div className="flex items-end gap-2.5">
            <Input
              className="flex-1"
              label="Flight no"
              placeholder="e.g. CA945"
              value={form.code}
              onChange={(v) => setForm((f) => ({ ...f, code: v }))}
            />
            <Input
              className="flex-1"
              label="Date"
              type="date"
              value={form.date}
              onChange={(v) => setForm((f) => ({ ...f, date: v }))}
            />
            <Button
              variant="dark"
              className="shrink-0"
              disabled={lookupBusy}
              onClick={() => void searchSchedule()}
            >
              <Search className="size-3.5" />
              {lookupBusy ? 'Searching…' : 'Search'}
            </Button>
          </div>
          {lookupInfo ? (
            <div
              className={`flex items-center gap-2 rounded-[9px] px-3 py-1.5 text-xs font-semibold ${
                lookupWarn ? 'border border-[#EED9A4] bg-warn-soft text-warn' : 'bg-primary-soft text-primary'
              }`}
            >
              <span className="min-w-0 flex-1">{lookupInfo}</span>
              {lookupLeg ? (
                <Button size="sm" className="shrink-0" onClick={addLeg}>
                  + Add flight
                </Button>
              ) : null}
            </div>
          ) : null}

          {pendingLegs ? (
            <div className={`rounded-[9px] border p-2.5 ${lookupWarn ? 'border-[#EED9A4] bg-warn-soft/40' : 'border-[#A8CFCA] bg-[#F4FAF9]'}`}>
              <div className="mb-2 flex items-center justify-between gap-2">
                <div className="text-[11px] font-bold uppercase tracking-[.05em] text-muted-foreground">
                  Found itinerary · {fmtDayMonth(form.date)}
                </div>
                {lookupWarn ? (
                  <span className="text-[11px] font-bold text-warn">⚠ will replace the current {legs.length} leg(s)</span>
                ) : null}
              </div>
              <div className="flex flex-col gap-1.5">
                {pendingLegs.map((leg, i) => (
                  <div key={`${leg.code}-${i}`} className="flex items-center gap-2.5 rounded-lg bg-card px-2.5 py-2 text-[12px]">
                    <span className="text-[11px] text-muted-foreground">{i + 1}.</span>
                    <b className="w-[64px]">{leg.code}</b>
                    <span className="min-w-0 flex-1 truncate text-muted-foreground">
                      {leg.fromIata || leg.fromCity} {leg.depTime} → {leg.toIata || leg.toCity} {leg.arrTime}
                    </span>
                  </div>
                ))}
              </div>
              <div className="mt-2 flex gap-2">
                <Button
                  size="sm"
                  onClick={() => {
                    setLegs(pendingLegs)
                    setPendingLegs(null)
                    setLookupWarn(false)
                    setLookupInfo(`Itinerary ${legs.length ? 'updated' : 'set'} — ${pendingLegs.length} leg(s)`)
                    setForm((f) => ({ ...f, code: '' }))
                  }}
                >
                  {legs.length ? 'Update itinerary' : 'Use itinerary'}
                </Button>
                <Button variant="secondary" size="sm" onClick={() => setPendingLegs(null)}>
                  Cancel
                </Button>
              </div>
            </div>
          ) : null}

          {legs.length ? (
            <div className="rounded-[9px] border border-border p-2.5">
              <div className="mb-2 flex items-center justify-between gap-2">
                <div className="text-[11px] font-bold uppercase tracking-[.05em] text-muted-foreground">Itinerary</div>
                <div className="text-[11.5px] font-bold text-primary">{routeLabel}</div>
              </div>
              <div className="flex flex-col gap-1.5">
                {legs.map((leg, i) => (
                  <div key={`${leg.code}-${i}`} className="flex items-center gap-2.5 rounded-lg bg-background px-2.5 py-2 text-[12px]">
                    <span className="text-[11px] text-muted-foreground">{i + 1}.</span>
                    <b className="w-[64px]">{leg.code}</b>
                    <span className="min-w-0 flex-1 truncate text-muted-foreground">
                      {leg.date ? `${fmtDayMonth(leg.date)} · ` : ''}
                      {leg.fromIata || leg.fromCity} {leg.depTime} → {leg.toIata || leg.toCity} {leg.arrTime}
                    </span>
                    <button
                      type="button"
                      className="grid size-5 shrink-0 cursor-pointer place-items-center rounded-full border border-[#F1C4C4] bg-card text-[11px] font-extrabold text-danger"
                      onClick={() => setLegs((l) => l.filter((_, j) => j !== i))}
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
              <div className="mt-1.5 text-[11px] text-muted-foreground">
                For a connection, search the next flight no above and add it as the next leg. Times and route derive
                from the legs.
              </div>
            </div>
          ) : (
            <div className="rounded-[9px] border border-dashed border-[#C9C6BF] px-3 py-2.5 text-[11.5px] text-muted-foreground">
              Search the flight above and press "+ Add flight" — times fill in from the schedule. For a connection,
              search both at once: <b>MU5850+MU2035</b> (or comma-separated) adds the legs in order.
            </div>
          )}
          <div className="flex flex-col gap-2.5 sm:flex-row">
            <Input
              className="flex-1"
              label="Agency share of ticket (৳)"
              placeholder="0"
              value={form.agencyShare}
              onChange={(v) => setForm((f) => ({ ...f, agencyShare: v }))}
            />
            <Input
              className="flex-1"
              label="Actual ticket cost (৳)"
              placeholder="0"
              value={form.actualCost}
              onChange={(v) => setForm((f) => ({ ...f, actualCost: v }))}
            />
          </div>
          <div className="rounded-xl border border-border bg-background p-4 space-y-3">
            <div className="flex flex-wrap justify-between gap-2 text-sm"><span>Flyer contribution</span><b>{fmtBdt(Math.max(0,actualCost-agencyShare)||0)}</b></div>
            {ticketMovement!==0 && <>
              <label className="block text-xs font-medium">{ticketMovement<0?'Receive ticket refund into (optional)':'Pay ticket from (optional)'}
                <select className="mt-1.5 h-10 w-full rounded-lg border border-border bg-card px-3 text-sm" disabled={busy||fundsLoading} value={accountName} onChange={e=>{setAccountName(e.target.value);setSubmitError('')}}>
                  <option value="">{ticketMovement<0?'Record refund later':'Pay later — no fund deduction'}</option>
                  {funds?.accounts.map(a=><option key={a.name} value={a.name}>{a.name} · {a.currency} {a.balance.toLocaleString('en-IN',{maximumFractionDigits:2})} available</option>)}
                </select>
              </label>
              <p className="text-xs text-muted-foreground">{!accountName ? (ticketMovement<0?`Refund of ${fmtBdt(-ticketMovement)} will remain outstanding. No money moves now.`:`Save now with ${fmtBdt(ticketMovement)} unpaid. You can pay from a fund later.`) : ticketMovement<0?`Record ${fmtBdt(-ticketMovement)} only after the refund has actually arrived.`:`${fmtBdt(ticketMovement)} will be deducted when you save. Flyer contributions are collected separately.`}</p>
              {payingAccount?.currency==='CNY'&&<p className="text-xs text-muted-foreground">Account movement: ¥{Math.abs(accountMovement).toFixed(2)} at ৳{funds?.rate} per CNY.</p>}
              {fundsError&&<p className="text-xs text-danger">Accounts could not load. You can still save unpaid or refresh to pay now.</p>}{!fundsLoading&&!fundsError&&!funds?.accounts.length&&<p className="text-xs text-muted-foreground">No funds yet. Save unpaid, or add an account to pay now.</p>}
              <div className="flex flex-wrap gap-4 text-xs font-semibold text-primary"><a href="/finance" target="_blank" rel="noreferrer">Manage / add funds ↗</a><button type="button" disabled={busy||fundsLoading} onClick={()=>void reloadFunds()}>Refresh accounts</button></div>
            </>}
            {paymentError&&<p role="status" className="text-sm text-danger">{paymentError}</p>}
          </div>
          <div className="flex flex-col gap-2.5 sm:flex-row">
            <Input
              className="flex-1"
              label="Cargo space (kg)"
              type="number"
              min={0}
              value={form.spaceKg}
              onChange={(v) => setForm((f) => ({ ...f, spaceKg: v }))}
            />
            <Input
              className="flex-1"
              label="Mobiles"
              type="number"
              min={0}
              value={form.mobiles}
              onChange={(v) => setForm((f) => ({ ...f, mobiles: v }))}
            />
            <Input
              className="flex-1"
              label="Laptops"
              type="number"
              min={0}
              value={form.laptops}
              onChange={(v) => setForm((f) => ({ ...f, laptops: v }))}
            />
            {editing ? (
              <div className="flex min-w-0 flex-1 flex-col gap-1.5">
                <div className="text-[12px] text-muted-foreground">Status</div>
                <Select value={form.status} onValueChange={(v) => setForm((f) => ({ ...f, status: v }))}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="upcoming">Upcoming</SelectItem>
                    <SelectItem value="departed">Departed</SelectItem>
                    <SelectItem value="completed">Completed</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            ) : null}
          </div>
          {submitError&&<p role="alert" className="rounded-lg bg-danger-soft p-3 text-sm text-danger">{submitError}</p>}
          <Button className="mt-1" size="lg" disabled={busy||!!paymentError} onClick={() => void submit()}>
            {busy ? 'Saving…' : editing ? 'Save changes' : 'Add flight'}
          </Button>
        </div>
      </Modal>

      <AddFlyerModal
        open={registering}
        onClose={() => setRegistering(false)}
        prefillName={query.trim() || undefined}
        onDone={(name) => {
          setFlyers((f) => [...f.filter((x) => x.name !== name), { name, bdPhone: '—' } as Flyer])
          setSelected((s) => (s.includes(name) ? s : [...s, name]))
          setQuery('')
        }}
      />
    </>
  )
}
