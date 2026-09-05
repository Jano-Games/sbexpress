import { EmptyState } from '@/components/Workspace'
import { FlyerSettlement } from '@/components/FlyerSettlement'
import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { api } from '@/api/client'
import { useFetch } from '@/state/useFetch'
import type { FlightDetail as Detail, FlightLookup, Flyer } from '@/api/types'
import { Button } from '@/components/beui/button'
import { Input } from '@/components/beui/input'
import { useToast } from '@/components/beui/toast'
import { BillFigure, Card, Chip, ErrorBlock, LoadingBlock, ProgressBar, SbMark, StatusChip } from '@/components/ui'
import { ConfirmDialog } from '@/components/ConfirmDialog'
import { NewShipmentModal } from '@/modals/NewShipmentModal'
import { AddFlyerModal } from '@/modals/AddFlyerModal'
import { AddFlightModal } from '@/modals/AddFlightModal'
import { FLIGHT_CHIP, fmtBdt, fmtDate, fmtDayMonth, fmtKg, supplierLabel } from '@/lib/format'

type LiveInfo = { status: string; sample?: boolean }

/** Live provider status, colored by lifecycle. Nothing to say → no badge. */
function LiveBadge({ info }: { info?: LiveInfo }) {
  if (!info || /unknown|not found/i.test(info.status)) return null
  const s = info.status
  const [bg, fg] = /cancel/i.test(s)
    ? ['#FDE8E8', '#C92A2A']
    : /land|arriv/i.test(s)
      ? ['#E6F7EC', '#1B7A3D']
      : /depart|route/i.test(s)
        ? ['#E0F2F1', '#0F766E']
        : /delay/i.test(s)
          ? ['#FEF3C7', '#B45309']
          : /sched|expect/i.test(s)
            ? ['#E7F0FE', '#0E4DA4']
            : ['#F3F2EE', '#5B5E63']
  return (
    <span className="whitespace-nowrap rounded-full px-2 py-0.5 text-[9.5px] font-extrabold tracking-[.04em]" style={{ background: bg, color: fg }}>
      LIVE · {s.toUpperCase()}
      {info.sample ? ' (SAMPLE)' : ''}
    </span>
  )
}

const liveKey = (code: string, date: string | null | undefined) => `${code}|${date ?? ''}`

export function FlightDetail() {
  const { code = '' } = useParams()
  const navigate = useNavigate()
  const { showToast } = useToast()
  const { data, error, loading, reload } = useFetch<{ flight: Detail }>(`/flights/${code}`)
  const { data: flyersData, reload: reloadFlyers } = useFetch<{ flyers: Flyer[] }>('/flyers')

  const [query, setQuery] = useState('')
  const [flyerAmount, setFlyerAmount] = useState('')
  const [payingFlyer,setPayingFlyer]=useState('')
  const [flyerMethod, setFlyerMethod] = useState('')
  const [payBusy, setPayBusy] = useState(false)
  const { data: accountData } = useFetch<{accounts:{name:string}[]}>('/finance?period=all')
  const [addingShipment, setAddingShipment] = useState(false)
  const [registering, setRegistering] = useState(false)
  const [editOpen, setEditOpen] = useState(false)
  const [deleteOpen, setDeleteOpen] = useState(false)
  const [live, setLive] = useState<Record<string, LiveInfo>>({})

  // Live schedule status per segment from the provider (cached server-side).
  useEffect(() => {
    if (!data) return
    const f = data.flight
    const targets = f.legs.length
      ? f.legs.map((l) => ({ code: l.code, date: l.date ?? f.date }))
      : f.code.includes('+')
        ? []
        : [{ code: f.code, date: f.date }]
    const seen = new Set<string>()
    for (const t of targets) {
      const key = liveKey(t.code, t.date)
      if (seen.has(key)) continue
      seen.add(key)
      api
        .get<FlightLookup>(`/flights/lookup?code=${encodeURIComponent(t.code)}&date=${t.date}`)
        .then((r) =>
          setLive((s) => ({
            ...s,
            [key]: { status: r.found ? (r.flight?.status ?? 'Unknown') : 'Not found', sample: r.sample },
          })),
        )
        .catch(() => undefined)
    }
  }, [data])

  const suggestions = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q || !data || !flyersData) return []
    const current = new Set(data.flight.flyers)
    return flyersData.flyers.filter((f) => !current.has(f.name) && f.name.toLowerCase().includes(q)).slice(0, 5)
  }, [query, data, flyersData])

  if (error) return <ErrorBlock message={error} />
  if (loading || !data) return <LoadingBlock />
  const f = data.flight
  const pct = (f.bookedKg / f.spaceKg) * 100
  const showRegisterNew = query.trim().length > 1 && suggestions.length === 0

  const addFlyer = (name: string) =>
    void api
      .post(`/flights/${f.code}/flyers`, { name })
      .then(() => {
        showToast({ title: `${name} added to ${f.code}`, status: 'success' })
        setQuery('')
        return reload()
      })
      .catch((e: unknown) => showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' }))

  const removeFlyer = (name: string) =>
    void api
      .delete(`/flights/${f.code}/flyers/${encodeURIComponent(name)}`)
      .then(() => {
        showToast({ title: `${name} removed from ${f.code}` })
        return reload()
      })
      .catch((e: unknown) => showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' }))

  return (
    <div>
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2.5">
        <Link to="/flights" className="text-[12.5px] font-semibold text-blue no-underline">
          ← Flights
        </Link>
        <div className="flex flex-wrap gap-2">
          <Button variant="secondary" onClick={() => setEditOpen(true)}>
            Edit
          </Button>
          <Button variant="danger-outline" onClick={() => setDeleteOpen(true)}>
            Delete
          </Button>
          <Button onClick={() => setAddingShipment(true)}>+ Add shipment to this flight</Button>
        </div>
      </div>

      <div className="flex flex-wrap items-start gap-3.5">
        <div className="flex min-w-0 w-full lg:min-w-[380px] lg:flex-[1.7] flex-col gap-3.5">
          <Card className="overflow-hidden">
            <div className="flex flex-wrap items-center gap-3 bg-ink px-5.5 py-4 text-white">
              <SbMark />
              <h1 className="m-0 break-words text-[24px] font-extrabold">{f.code.split('+').join(' · ')}</h1>
              <Chip colors={FLIGHT_CHIP[f.status] ?? FLIGHT_CHIP.completed!} className="px-3 py-1 text-[11.5px] font-bold">
                {f.statusLabel}
              </Chip>
              {!f.legs.length ? <LiveBadge info={live[liveKey(f.code, f.date)]} /> : null}
              <div className="ml-auto text-[12.5px] text-[#B9BCC1]">
                {fmtDate(f.date)} · {f.via}
              </div>
            </div>
            {f.legs.length > 0 ? (
              <div className="flex items-center gap-3 overflow-x-auto p-5.5">
                {(() => {
                  const points = [
                    {
                      iata: f.legs[0]!.fromIata || '?',
                      city: f.legs[0]!.fromCity,
                      time: f.legs[0]!.depTime,
                      align: 'left' as const,
                    },
                    ...f.legs.slice(0, -1).map((leg, i) => ({
                      iata: leg.toIata || '?',
                      city: leg.toCity,
                      time: `${leg.arrTime} · ${f.legs[i + 1]!.depTime}`,
                      align: 'center' as const,
                    })),
                    {
                      iata: f.legs[f.legs.length - 1]!.toIata || '?',
                      city: f.legs[f.legs.length - 1]!.toCity,
                      time: f.legs[f.legs.length - 1]!.arrTime,
                      align: 'right' as const,
                    },
                  ]
                  const big = points.length > 2 ? 'text-[26px]' : 'text-[34px]'
                  return points.map((p, i) => (
                    <div key={`${p.iata}-${i}`} className="contents">
                      {i > 0 ? (
                        <div className="flex min-w-14 flex-1 flex-col items-center gap-1">
                          <div className="flex w-full items-center gap-2">
                            <div className="flex-1 border-t-2 border-dashed border-[#C9C6BF]" />
                            <div className="text-[15px] text-primary">✈</div>
                            <div className="flex-1 border-t-2 border-dashed border-[#C9C6BF]" />
                          </div>
                          <div className="text-[10.5px] font-bold text-muted-foreground">
                            {f.legs[i - 1]!.code} · {fmtDayMonth(f.legs[i - 1]!.date ?? f.date)}
                          </div>
                          <LiveBadge info={live[liveKey(f.legs[i - 1]!.code, f.legs[i - 1]!.date ?? f.date)]} />
                        </div>
                      ) : null}
                      <div
                        className={`shrink-0 ${p.align === 'left' ? 'text-left' : p.align === 'right' ? 'text-right' : 'text-center'}`}
                      >
                        <div className={`${big} font-extrabold leading-none`}>{p.iata}</div>
                        <div className="mt-1 text-[11px] text-muted-foreground">{p.city}</div>
                        <div className="mt-1 text-[14px] font-extrabold text-primary">{p.time}</div>
                      </div>
                    </div>
                  ))
                })()}
              </div>
            ) : (
              <div className="flex items-center gap-4.5 p-5.5">
                <div className="shrink-0">
                  <div className="text-[34px] font-extrabold leading-none">CTU</div>
                  <div className="mt-1 text-[11px] text-muted-foreground">Chengdu Tianfu</div>
                  <div className="mt-1 text-[15px] font-extrabold text-primary">{f.depTime}</div>
                </div>
                <div className="flex min-w-20 flex-1 items-center gap-2">
                  <div className="flex-1 border-t-2 border-dashed border-[#C9C6BF]" />
                  <div className="text-[17px] text-primary">✈</div>
                  <div className="flex-1 border-t-2 border-dashed border-[#C9C6BF]" />
                </div>
                <div className="shrink-0 text-right">
                  <div className="text-[34px] font-extrabold leading-none">DAC</div>
                  <div className="mt-1 text-[11px] text-muted-foreground">Hazrat Shahjalal, Dhaka</div>
                  <div className="mt-1 text-[15px] font-extrabold text-primary">{f.arrTime}</div>
                </div>
              </div>
            )}
            <div className="border-t border-dashed border-border px-5.5 py-4">
              <div className="mb-1.75 flex flex-wrap justify-between gap-1.5 text-[12.5px]">
                <span className="text-[11px] font-bold uppercase tracking-[.05em] text-muted-foreground">Cargo space</span>
                <span>
                  <b>{f.bookedKg} kg</b> of {f.spaceKg} kg · <b className="text-success">{f.leftKg} kg free</b> · + {f.mobiles}{' '}
                  mobile{f.mobiles === 1 ? '' : 's'} + {f.laptops} laptop{f.laptops === 1 ? '' : 's'}
                </span>
              </div>
              <ProgressBar pct={pct} danger={pct > 90} height={10} />
            </div>
          </Card>

          <Card className="p-5 rounded-[14px]">
            <div className="mb-3 text-[15px] font-bold">Bookings · {f.shipmentCount}</div>
            <div className="flex flex-col gap-2">
              {f.bookings.map((r) => (
                <Link
                  key={r.code}
                  className="flex cursor-pointer flex-wrap items-center gap-3.5 rounded-[10px] bg-background px-3.5 py-2.75 hover:bg-muted" to={`/shipments/${r.code}`}
                >
                  <div className="w-[66px] text-[13px] font-bold">{r.code}</div>
                  <div className="min-w-[130px] flex-1 text-[12.5px] text-muted-foreground">
                    {supplierLabel(r.supplierCode, r.supplierName)} · {r.description}
                  </div>
                  <div className="text-[12.5px]">{r.bookedKg > 0 ? fmtKg(r.bookedKg) : r.description}</div>
                  <StatusChip index={r.statusIndex} label={r.statusLabel} />
                  <div className="flex w-[70px] justify-end">
                    <BillFigure bill={r.billAmount} discount={r.discountAmount} className="text-right text-[13px]" />
                  </div>
                </Link>
              ))}
            </div>
          </Card>
        </div>

        <div className="flex min-w-0 w-full lg:min-w-[300px] lg:flex-1 flex-col gap-3.5">
          <Card className="p-4.5 rounded-[14px]">
            <div className="mb-3 text-[13px] font-bold">Flyers on this flight</div>
            <div className="relative mb-3">
              <Input
                placeholder="Search flyer to add…"
                value={query}
                onChange={setQuery}
                fieldClassName="border-dashed border-[#C9C6BF] bg-background"
              />
              {suggestions.length ? (
                <div className="absolute left-0 right-0 top-[42px] z-20 overflow-hidden rounded-[10px] border border-border bg-card shadow-[0_8px_24px_rgba(0,0,0,.12)]">
                  {suggestions.map((flyer) => (
                    <div
                      key={flyer.name}
                      className="flex cursor-pointer justify-between gap-2.5 px-3.5 py-2.5 text-[12.5px] hover:bg-primary-soft"
                      onClick={() => addFlyer(flyer.name)}
                    >
                      <b>{flyer.name}</b>
                      <span className="text-muted-foreground">{flyer.bdPhone}</span>
                    </div>
                  ))}
                </div>
              ) : showRegisterNew ? (
                <div className="absolute left-0 right-0 top-[42px] z-20 overflow-hidden rounded-[10px] border border-border bg-card shadow-[0_8px_24px_rgba(0,0,0,.12)]">
                  <div
                    className="cursor-pointer px-3.5 py-2.5 text-[12.5px] font-bold text-primary hover:bg-primary-soft"
                    onClick={() => setRegistering(true)}
                  >
                    + Add "{query.trim()}" as a new flyer
                  </div>
                </div>
              ) : null}
            </div>
            <div className="flex flex-col gap-2">
              {f.flyerDetails.map((flyer) => (
                <div key={flyer.name} className="flex items-center gap-2.5 rounded-[10px] bg-background px-3 py-2.5">
                  <div className="grid size-8 shrink-0 place-items-center rounded-[9px] bg-primary-soft text-[13px] font-extrabold text-primary">
                    {flyer.initial}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div
                      className="cursor-pointer text-[12.5px] font-bold text-blue"
                      onClick={() => navigate(`/flyers/${encodeURIComponent(flyer.name)}`)}
                    >
                      {flyer.name} →
                    </div>
                    <div className="text-[11px] text-muted-foreground">{flyer.bdPhone}</div>
                  </div>
                  <button
                    type="button"
                    className="grid size-5.5 shrink-0 cursor-pointer place-items-center rounded-full border border-[#F1C4C4] bg-card text-xs font-extrabold text-danger"
                    onClick={() => removeFlyer(flyer.name)}
                  >
                    ×
                  </button>
                </div>
              ))}
            </div>
          </Card>

          <Card className="overflow-hidden rounded-[14px]">
            <div className="p-4.5 pb-3">
              <div className="mb-3 text-[13px] font-bold">Flight profitability</div>
              <div className="mb-3 rounded-lg bg-background p-3 text-sm"><p>Ticket paid: {fmtBdt(f.ticketPaid)} · Unpaid: {fmtBdt(f.ticketDue)}</p>{f.ticketRefundDue>0&&<p>Refund to collect: {fmtBdt(f.ticketRefundDue)}</p>}{(f.ticketDue>0||f.ticketRefundDue>0)&&<Button className="mt-2" variant="secondary" onClick={()=>setEditOpen(true)}>{f.ticketDue>0?'Pay ticket from a fund':'Record ticket refund'}</Button>}</div>
              <p className="text-sm mb-2">Agency share: {fmtBdt(f.agencyShare)}</p>
              <p className="text-sm mb-2">Received from flyer: {fmtBdt(f.flyerPaidAmount)} · Still due: {fmtBdt(f.flyerDue)}</p>
              {f.flyerDue > 0 && <div className="mb-4 space-y-2">
                <Input label="Amount received from flyer (BDT)" value={flyerAmount} onChange={setFlyerAmount} />
                <label className="text-sm">Paying flyer<select className="block border rounded p-2" value={payingFlyer} onChange={e=>setPayingFlyer(e.target.value)}><option value="">Select flyer</option>{f.settlements.map(x=><option key={x.name}>{x.name}</option>)}</select></label>
                <label className="text-sm">Receiving account<select className="block w-full rounded border p-2" value={flyerMethod} onChange={e => setFlyerMethod(e.target.value)}><option value="" disabled>Select account</option>{(accountData?.accounts ?? []).map(a => <option key={a.name}>{a.name}</option>)}</select></label>
                <Button disabled={payBusy} onClick={() => void (async () => {
                  setPayBusy(true)
                  try { await api.post(`/flights/${code}/payments`,{amount:Number(flyerAmount),method:flyerMethod,flyerName:payingFlyer||undefined}); setFlyerAmount(''); await reload(); showToast({title:'Flyer payment recorded',status:'success'}) }
                  catch(e) { showToast({title:e instanceof Error?e.message:'Failed',status:'error'}) } finally {setPayBusy(false)}
                })()}>Record flyer payment</Button>
              </div>}
              <FlyerSettlement key={JSON.stringify(f.settlements)} code={code} rows={f.settlements} legacy={f.unallocatedFlyerPaid} onSaved={reload} />
              <div className="flex flex-col gap-2 text-[12.5px]">
                <div className="flex justify-between gap-3">
                  <span className="text-muted-foreground">Shipment charges</span>
                  <b className="text-success">+ {fmtBdt(f.revenue)}</b>
                </div>
                <div className="flex justify-between gap-3">
                  <span className="text-muted-foreground">Flyer contribution</span>
                  <b className="text-success">+ {fmtBdt(f.fare)}</b>
                </div>
                <div className="flex justify-between gap-3 border-t border-dashed border-border pt-2">
                  <span className="text-muted-foreground">Ticket cost</span>
                  <b className="text-danger">− {fmtBdt(f.actualCost)}</b>
                </div>
                {([
                  ['CN transport', f.shipmentCosts.cnTransport],
                  ['BD transport / courier', f.shipmentCosts.courier],
                  ['Customs costs', f.shipmentCosts.customs],
                  ['Other shipment costs', f.shipmentCosts.other],
                ] as const).map(([label, amount]) => (
                  <div key={label} className="flex justify-between gap-3">
                    <span className="text-muted-foreground">{label}</span>
                    <b className="text-danger">− {fmtBdt(amount)}</b>
                  </div>
                ))}
              </div>
            </div>
            <div className="flex items-center justify-between bg-ink px-4.5 py-3.25 text-white">
              <span className="text-[11px] font-extrabold tracking-[.08em] text-[#B9BCC1]">{f.margin >= 0 ? 'PROFIT' : 'LOSS'}</span>
              <span className="text-lg font-extrabold" style={{ color: f.margin >= 0 ? '#7CE79A' : '#FF8F8F' }}>
                {fmtBdt(f.margin)}
              </span>
            </div>
          </Card>
        </div>
      </div>

      <NewShipmentModal
        open={addingShipment}
        onClose={() => setAddingShipment(false)}
        onDone={() => void reload()}
        lockedFlight={{ code: f.code, date: f.date }}
      />
      <AddFlyerModal
        open={registering}
        onClose={() => setRegistering(false)}
        prefillName={query.trim()}
        assignFlightCode={f.code}
        onDone={() => {
          setQuery('')
          void reload()
          void reloadFlyers()
        }}
      />
      <AddFlightModal
        open={editOpen}
        onClose={() => setEditOpen(false)}
        editing={f}
        onDone={(newCode) => {
          if (newCode && newCode !== f.code) navigate(`/flights/${newCode}`, { replace: true })
          else void reload()
        }}
      />
      <ConfirmDialog
        open={deleteOpen}
        onClose={() => setDeleteOpen(false)}
        title={`Delete flight ${f.code}?`}
        body={
          f.shipmentCount > 0
            ? `${f.code} still has ${f.shipmentCount} booking(s) — deleting will be refused until they are moved or deleted.`
            : 'The flight and its flyer assignments are removed permanently.'
        }
        onConfirm={async () => {
          try {
            await api.delete(`/flights/${f.code}`)
            showToast({ title: `${f.code} deleted`, status: 'success' })
            navigate('/flights')
          } catch (e) {
            showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' })
          }
        }}
      />
    </div>
  )
}
