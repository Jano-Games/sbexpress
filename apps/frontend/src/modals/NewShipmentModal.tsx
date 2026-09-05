import { useEffect, useMemo, useState } from 'react'
import { api } from '@/api/client'
import type { AppSettings, FlightSummary, ShipmentDetail, SupplierSummary } from '@/api/types'
import { Modal } from '@/components/Modal'
import { Button } from '@/components/beui/button'
import { Input } from '@/components/beui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/beui/select'
import { useToast } from '@/components/beui/toast'
import { SearchSelect } from '@/components/SearchSelect'
import { ProgressBar } from '@/components/ui'
import { fmtBdt, fmtDate } from '@/lib/format'

const PAY_OPTIONS = [
  { value: 'unpaid', label: 'Unpaid' },
  { value: 'cod', label: 'COD' },
  { value: 'monthly', label: 'Monthly' },
]

type PcsUnit = { model: string; serial: string }
type PcsDraft = Record<string, { count: string; rate: string; currency: 'BDT' | 'CNY'; units: PcsUnit[] }>

const resizeUnits = (units: PcsUnit[], count: number): PcsUnit[] =>
  Array.from({ length: Math.max(0, count) }, (_, i) => units[i] ?? { model: '', serial: '' })

export function NewShipmentModal({
  open,
  onClose,
  onDone,
  lockedFlight,
  editing,
}: {
  open: boolean
  onClose: () => void
  onDone: (code: string) => void
  /** When opened from a flight page the flight is fixed. */
  lockedFlight?: { code: string; date: string }
  /** When set, the modal edits this shipment instead of creating one. */
  editing?: ShipmentDetail
}) {
  const { showToast } = useToast()
  const [busy, setBusy] = useState(false)
  const [suppliers, setSuppliers] = useState<SupplierSummary[]>([])
  const [flights, setFlights] = useState<FlightSummary[]>([])
  const [categories, setCategories] = useState<string[]>([])
  const [fxRate, setFxRate] = useState<number | null>(null)
  const [pcsDefaults, setPcsDefaults] = useState<Record<string, number>>({})

  const [supplier, setSupplier] = useState('')
  const [flight, setFlight] = useState('')
  const [flyerName,setFlyerName] = useState('')
  const [picked, setPicked] = useState<string[]>([])
  const [catQuery, setCatQuery] = useState('')
  const [catOpen, setCatOpen] = useState(false)
  const [pcs, setPcs] = useState<PcsDraft>({})
  const [kg, setKg] = useState('')
  const [rate, setRate] = useState('')
  const [currency, setCurrency] = useState<'BDT' | 'CNY'>('BDT')
  const [description, setDescription] = useState('')
  const [pay, setPay] = useState('unpaid')
  const [cnFare, setCnFare] = useState('')
  const [customsTax, setCustomsTax] = useState('')

  /** A category charged per piece: has a settings rate or is a device type. */
  const isPcsCategory = (name: string) => pcsDefaults[name] !== undefined || /mobile|laptop|drone/i.test(name)

  useEffect(() => {
    if (!open) return
    if (editing) {
      setSupplier(editing.supplierCode)
      setFlight(editing.flightCode ?? '')
      setFlyerName(editing.flyerName ?? '')
      setPicked(editing.categories)
      // Older shipments carry a flat serial list — distribute it across the
      // device units in order so nothing typed before is lost.
      const leftoverSerials = [...editing.serials]
      setPcs(
        Object.fromEntries(
          editing.pcsItems.map((i) => [
            i.category,
            {
              count: String(i.count),
              rate: String(i.rate),
              currency: i.currency,
              units: i.units.length
                ? resizeUnits(i.units, i.count)
                : resizeUnits(
                    Array.from({ length: i.count }, () => ({ model: '', serial: leftoverSerials.shift() ?? '' })),
                    i.count,
                  ),
            },
          ]),
        ),
      )
      setKg(editing.bookedKg ? String(editing.bookedKg) : '')
      setRate(editing.chargeRate ? String(editing.chargeRate) : '')
      setCurrency(editing.chargeCurrency === 'CNY' ? 'CNY' : 'BDT')
      setDescription(editing.description === '—' ? '' : editing.description)
      setPay(editing.payStatus)
      setCnFare(editing.costs ? String(editing.costs.cnFare) : '')
      setCustomsTax(editing.costs ? String(editing.costs.customsTax) : '')
    } else {
      setSupplier('')
      setFlight(lockedFlight?.code ?? '')
      setFlyerName('')
      setPicked([])
      setPcs({})
      setKg('')
      setRate('')
      setCurrency('BDT')
      setDescription('')
      setPay('unpaid')
    }
    setCatQuery('')
    api.get<{ suppliers: SupplierSummary[] }>('/suppliers').then((r) => setSuppliers(r.suppliers)).catch(() => undefined)
    api.get<{ flights: FlightSummary[] }>('/flights').then((r) => setFlights(r.flights)).catch(() => undefined)
    api.get<{ categories: string[] }>('/categories').then((r) => setCategories(r.categories)).catch(() => undefined)
    api
      .get<{ settings: AppSettings }>('/settings')
      .then((r) => {
        setFxRate(r.settings.rate)
        setPcsDefaults(r.settings.pcsRates)
      })
      .catch(() => undefined)
  }, [open, lockedFlight, editing])

  // Keep the per-piece rows in lockstep with the picked categories: a newly
  // picked device category appears with the settings default rate, an
  // unpicked one drops out. Existing rows (and their overrides) are kept.
  useEffect(() => {
    setPcs((current) => {
      const next: PcsDraft = {}
      for (const name of picked) {
        if (!isPcsCategory(name)) continue
        next[name] =
          current[name] ??
          { count: '1', rate: String(pcsDefaults[name] ?? 0), currency: 'BDT', units: [{ model: '', serial: '' }] }
      }
      return next
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [picked, pcsDefaults])

  const pcsSum = Object.values(pcs).reduce(
    (a, v) => a + (parseInt(v.count) || 0) * (parseFloat(v.rate) || 0) * (v.currency === 'CNY' ? (fxRate ?? 0) : 1),
    0,
  )
  const totalPcs = Object.values(pcs).reduce((a, v) => a + (parseInt(v.count) || 0), 0)
  const devMode = Object.keys(pcs).length > 0

  const setPcsField = (category: string, patch: Partial<PcsDraft[string]>) =>
    setPcs((p) => {
      const current = p[category]
      if (!current) return p
      const next = { ...current, ...patch }
      next.units = resizeUnits(next.units, Math.max(1, parseInt(next.count) || 1))
      return { ...p, [category]: next }
    })

  const setUnit = (category: string, index: number, patch: Partial<PcsUnit>) =>
    setPcs((p) => {
      const current = p[category]
      if (!current) return p
      return {
        ...p,
        [category]: { ...current, units: current.units.map((u, i) => (i === index ? { ...u, ...patch } : u)) },
      }
    })

  const selectedFlight = useMemo(() => flights.find((f) => f.code === flight) ?? null, [flights, flight])

  /** Flight load with this shipment's weight projected in. */
  const load = useMemo(() => {
    if (!selectedFlight) return null
    // When editing, the shipment's current weight is already inside the
    // flight's booked total — take it out before projecting the new value.
    const own = editing && editing.flightCode === selectedFlight.code ? editing.bookedKg : 0
    const base = Math.max(0, Math.round((selectedFlight.bookedKg - own) * 10) / 10)
    const entered = parseFloat(kg) || 0
    const projected = Math.round((base + entered) * 10) / 10
    const free = Math.round((selectedFlight.spaceKg - projected) * 10) / 10
    return { base, entered, projected, free, spaceKg: selectedFlight.spaceKg, code: selectedFlight.code }
  }, [selectedFlight, editing, kg])

  const supplierOptions = useMemo(
    () =>
      suppliers.map((s) => ({
        value: s.code,
        label: `${s.code} · ${s.name}`,
        sub: s.terms === 'monthly' ? 'Monthly' : 'Instant',
        keywords: `${s.code} ${s.name}`.toLowerCase(),
      })),
    [suppliers],
  )

  const flightOptions = useMemo(
    () =>
      flights
        .filter((f) => editing !== undefined || f.status === 'upcoming')
        .map((f) => ({
          value: f.code,
          label: `${f.code.split('+').join(' · ')} · ${fmtDate(f.date)}`,
          sub: `${f.leftKg} kg free`,
          keywords: `${f.code} ${f.date} ${f.flyers.join(' ')}`.toLowerCase(),
        })),
    [flights, editing],
  )

  const suggestions = useMemo(() => {
    const q = catQuery.trim().toLowerCase()
    return categories.filter((c) => !picked.includes(c) && (!q || c.toLowerCase().includes(q))).slice(0, 8)
  }, [categories, picked, catQuery])

  const showAddCategory =
    Boolean(catQuery.trim()) && !categories.some((c) => c.toLowerCase() === catQuery.trim().toLowerCase())

  const pickCategory = (name: string) => {
    setPicked((p) => [...p, name])
    setCatQuery('')
    // The input keeps focus after a pick, so leave the list open for the
    // next category instead of forcing a blur/refocus.
    setCatOpen(true)
  }

  const addCategory = async () => {
    const name = catQuery.trim()
    if (!name) return
    try {
      await api.post('/categories', { name })
      setCategories((c) => [...c, name].sort())
      pickCategory(name)
      showToast({ title: `Category "${name}" added` })
    } catch (e) {
      showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' })
    }
  }

  /** Live total preview: kg part (CNY at fx rate) + per-piece part. */
  const totalPreview = useMemo(() => {
    const r = parseFloat(rate) || 0
    const kgN = parseFloat(kg) || 0
    const kgPart = r * kgN * (currency === 'CNY' ? (fxRate ?? 0) : 1)
    if (kgPart <= 0 && pcsSum <= 0) return null
    const sign = currency === 'CNY' ? '¥' : '৳'
    const parts: string[] = []
    if (kgPart > 0) parts.push(`${kgN} kg × ${sign}${r}/kg${currency === 'CNY' ? ` · ¥1 = ৳${fxRate ?? '?'}` : ''}`)
    if (pcsSum > 0) parts.push(`${totalPcs} pc = ${fmtBdt(pcsSum)}`)
    return `Total ${fmtBdt(kgPart + pcsSum)} (${parts.join(' + ')})`
  }, [rate, kg, currency, fxRate, pcsSum, totalPcs])

  const submit = async () => {
    if (!supplier) {
      showToast({ title: 'Pick a supplier', status: 'error' })
      return
    }
    if (!picked.length) {
      showToast({ title: 'Pick at least one category', status: 'error' })
      return
    }
    setBusy(true)
    try {
      const payload = {
        supplierCode: supplier,
        flightCode: flight || undefined,
        flyerName: flyerName || undefined,
        categories: picked,
        bookedKg: parseFloat(kg) || 0,
        chargeRate: parseFloat(rate) || 0,
        chargeCurrency: currency,
        pcsItems: Object.entries(pcs).map(([category, v]) => {
          const count = Math.max(1, parseInt(v.count) || 1)
          return {
            category,
            count,
            rate: parseFloat(v.rate) || 0,
            currency: v.currency,
            units: resizeUnits(v.units, count).map((u) => ({ model: u.model.trim(), serial: u.serial.trim() })),
          }
        }),
        description,
        payStatus: pay,
      }
      if (editing) {
        await api.patch(`/shipments/${editing.code}`, {
          ...payload,
          cnFare: parseFloat(cnFare) || 0,
          customsTax: parseFloat(customsTax) || 0,
        })
        showToast({ title: `${editing.code} updated`, status: 'success' })
        onDone(editing.code)
      } else {
        const r = await api.post<{ code: string }>('/shipments', payload)
        showToast({ title: `Shipment ${r.code} created`, status: 'success' })
        onDone(r.code)
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
      <div data-dialog-title className="mb-3.5 text-[17px] font-extrabold">{editing ? `Edit ${editing.code}` : 'New shipment'}</div>
      <div className="flex flex-col gap-2.5 text-[12.5px]">
        <div className="flex flex-col gap-2.5 sm:flex-row">
          <SearchSelect
            className="min-w-0 flex-1"
            label="Supplier"
            placeholder="Name or short code…"
            options={supplierOptions}
            value={supplier}
            onChange={setSupplier}
          />
          {lockedFlight && !editing ? (
            <div className="flex min-w-0 flex-1 flex-col gap-1.5">
              <div className="text-[12px] text-muted-foreground">Flight</div>
              <div className="truncate rounded-[9px] border border-border bg-background p-2.5 font-semibold">
                ✈ {lockedFlight.code.split('+').join(' · ')} · {fmtDate(lockedFlight.date)}
              </div>
            </div>
          ) : (
            <SearchSelect
              className="min-w-0 flex-1"
              label="Flight (optional at intake)"
              placeholder="Flight no or date…"
              options={flightOptions}
              value={flight}
              onChange={v => {setFlight(v);setFlyerName('')}}
            />
          )}
        </div>

        {selectedFlight && <label className="block text-sm">Carrying flyer
          <select className="ml-2 rounded border p-2" value={flyerName || (selectedFlight.flyers.length === 1 ? selectedFlight.flyers[0] : '')} onChange={e => setFlyerName(e.target.value)}>
            <option value="">Assign before dispatch</option>{selectedFlight.flyers.map(name => <option key={name}>{name}</option>)}
          </select></label>}
        {load ? (
          <div className="rounded-[9px] border border-border bg-background px-3 py-2.5">
            <div className="mb-1.5 flex flex-wrap items-baseline justify-between gap-2 text-[11.5px]">
              <span className="text-[10.5px] font-bold uppercase tracking-[.05em] text-muted-foreground">
                Cargo space · {load.code.split('+').join(' · ')}
              </span>
              <span>
                {load.entered > 0 ? (
                  <>
                    {load.base} kg booked <span className="text-muted-foreground">+ this</span> ={' '}
                    <b>{load.projected}</b> / {load.spaceKg} kg
                  </>
                ) : (
                  <>
                    <b>{load.base}</b> / {load.spaceKg} kg booked
                  </>
                )}
              </span>
            </div>
            <ProgressBar pct={(load.projected / load.spaceKg) * 100} danger={load.free < 0} />
            <div className="mt-1.5 text-[11.5px] font-bold" style={{ color: load.free < 0 ? '#C92A2A' : '#1B7A3D' }}>
              {load.free < 0 ? `Over capacity by ${Math.abs(load.free)} kg` : `${load.free} kg free`}
            </div>
          </div>
        ) : null}

        <div className="rounded-[9px] border border-border p-2.5">
          <div className="mb-2 text-[11px] font-bold uppercase tracking-[.05em] text-muted-foreground">Categories</div>
          {picked.length ? (
            <div className="mb-2 flex flex-wrap gap-1.5">
              {picked.map((name) => (
                <span key={name} className="inline-flex items-center gap-1.5 rounded-full bg-primary-soft px-2.5 py-1.25 text-[11.5px] font-bold text-primary">
                  {name}
                  <button
                    type="button"
                    className="cursor-pointer border-0 bg-transparent p-0 font-extrabold text-primary"
                    onClick={() => setPicked((p) => p.filter((x) => x !== name))}
                  >
                    ×
                  </button>
                </span>
              ))}
            </div>
          ) : null}
          <div className="relative">
            <Input
              placeholder="Search or pick a category…"
              value={catQuery}
              onChange={(v) => {
                setCatQuery(v)
                setCatOpen(true)
              }}
              onFocus={() => setCatOpen(true)}
              onBlur={() => window.setTimeout(() => setCatOpen(false), 150)}
            />
            {catOpen && (suggestions.length > 0 || showAddCategory) ? (
              <div className="absolute left-0 right-0 top-[calc(100%+4px)] z-20 max-h-[190px] overflow-auto rounded-[10px] border border-border bg-card p-1 shadow-[0_10px_28px_rgba(0,0,0,.14)]">
                {suggestions.map((name) => (
                  <div
                    key={name}
                    className="flex cursor-pointer items-center justify-between rounded-[7px] px-3 py-2.25 text-[12.5px] font-semibold hover:bg-primary-soft hover:text-primary"
                    onMouseDown={(e) => {
                      e.preventDefault()
                      pickCategory(name)
                    }}
                  >
                    <span>{name}</span>
                    <span className="text-[11px] text-faint">select</span>
                  </div>
                ))}
                {showAddCategory ? (
                  <div
                    className="cursor-pointer rounded-[7px] border-t border-muted px-3 py-2.25 text-[12.5px] font-bold text-primary hover:bg-primary-soft"
                    onMouseDown={(e) => {
                      e.preventDefault()
                      void addCategory()
                    }}
                  >
                    + Add category "{catQuery.trim()}"
                  </div>
                ) : null}
              </div>
            ) : null}
          </div>
        </div>

        {devMode ? (
          <div className="rounded-[9px] border border-[#A8CFCA] bg-[#F4FAF9] p-2.5">
            <div className="mb-2 flex items-baseline justify-between gap-2">
              <div className="text-[11px] font-bold uppercase tracking-[.05em] text-primary">Devices · charged per piece</div>
              {pcsSum > 0 ? <div className="text-[11.5px] font-bold text-primary">{fmtBdt(pcsSum)}</div> : null}
            </div>
            <div className="flex flex-col gap-3">
              {Object.entries(pcs).map(([category, v]) => {
                const lineTotal =
                  (parseInt(v.count) || 0) * (parseFloat(v.rate) || 0) * (v.currency === 'CNY' ? (fxRate ?? 0) : 1)
                return (
                  <div key={category} className="rounded-lg border border-[#CBE4E0] bg-card/60 p-2">
                    <div className="flex flex-wrap items-end gap-2">
                      <div className="min-w-16 flex-1 pb-2 text-[12.5px] font-bold capitalize">{category}</div>
                      <div className="flex flex-col gap-1">
                        <span className="text-[11px] text-muted-foreground">Count</span>
                        <input
                          type="number"
                          min={1}
                          max={20}
                          value={v.count}
                          onChange={(e) => setPcsField(category, { count: e.target.value })}
                          className="w-14 rounded-lg border border-border bg-card px-2 py-1.75 text-[12.5px]"
                        />
                      </div>
                      <div className="flex flex-col gap-1">
                        <span className="text-[11px] text-muted-foreground">Rate /pc</span>
                        <div className="flex gap-1">
                          <input
                            type="number"
                            min={0}
                            value={v.rate}
                            onChange={(e) => setPcsField(category, { rate: e.target.value })}
                            className="w-20 rounded-lg border border-border bg-card px-2 py-1.75 text-[12.5px]"
                          />
                          <button
                            type="button"
                            role="switch"
                            aria-checked={v.currency === 'CNY'}
                            title="Toggle rate currency"
                            className="shrink-0 cursor-pointer overflow-hidden rounded-lg border border-border bg-card p-0 text-[10px] font-bold"
                            onClick={() => setPcsField(category, { currency: v.currency === 'BDT' ? 'CNY' : 'BDT' })}
                          >
                            <span className={`inline-grid h-full w-8 place-items-center ${v.currency === 'BDT' ? 'bg-primary text-white' : 'text-faint'}`}>BDT</span>
                            <span className={`inline-grid h-full w-8 place-items-center ${v.currency === 'CNY' ? 'bg-primary text-white' : 'text-faint'}`}>CNY</span>
                          </button>
                        </div>
                      </div>
                      <div className="ml-auto pb-2 text-[12px] font-bold text-muted-foreground">{fmtBdt(lineTotal)}</div>
                    </div>
                    <div className="mt-2 flex flex-col gap-1.5 border-t border-dashed border-[#CBE4E0] pt-2">
                      {v.units.map((unit, i) => (
                        <div key={i} className="flex items-end gap-1.5">
                          <span className="w-4 pb-2.5 text-[11px] text-muted-foreground">{i + 1}.</span>
                          <Input
                            className="min-w-0 flex-1"
                            label="Model"
                            placeholder={`e.g. ${/laptop/i.test(category) ? 'MacBook Air M2' : /drone/i.test(category) ? 'DJI Mini 4' : 'iPhone 15 Pro'}`}
                            value={unit.model}
                            onChange={(val) => setUnit(category, i, { model: val })}
                          />
                          <Input
                            className="min-w-0 flex-1"
                            label="Serial / IMEI"
                            placeholder="Number on the device"
                            value={unit.serial}
                            onChange={(val) => setUnit(category, i, { serial: val })}
                          />
                          <button
                            type="button"
                            className="h-10 cursor-pointer whitespace-nowrap rounded-lg border border-dashed border-[#C9C6BF] bg-card px-2.5 text-[11px] text-muted-foreground"
                            onClick={() => showToast({ title: 'Device image attached (demo)' })}
                          >
                            + Image
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        ) : null}

        <div className="flex flex-col gap-2.5 sm:flex-row">
          <Input className="flex-1" label="Weight (kg)" placeholder="e.g. 22.4" value={kg} onChange={setKg} />
          <div className="flex flex-1 flex-col gap-1.5">
            <div className="text-[12px] text-muted-foreground">Charge per kg</div>
            <div className="flex gap-1.5">
              <Input className="min-w-0 flex-1" placeholder={currency === 'CNY' ? 'e.g. 40' : 'e.g. 700'} value={rate} onChange={setRate} />
              <button
                type="button"
                role="switch"
                aria-checked={currency === 'CNY'}
                title="Toggle charge currency"
                className="h-10 shrink-0 cursor-pointer overflow-hidden rounded-[9px] border border-border bg-card p-0 text-[12px] font-bold"
                onClick={() => setCurrency((c) => (c === 'BDT' ? 'CNY' : 'BDT'))}
              >
                <span className={`inline-grid h-full w-11 place-items-center text-[11px] ${currency === 'BDT' ? 'bg-primary text-white' : 'text-faint'}`}>BDT</span>
                <span className={`inline-grid h-full w-11 place-items-center text-[11px] ${currency === 'CNY' ? 'bg-primary text-white' : 'text-faint'}`}>CNY</span>
              </button>
            </div>
          </div>
        </div>
        {totalPreview ? (
          <div className="rounded-[9px] bg-primary-soft px-3 py-2 text-xs font-semibold text-primary">{totalPreview}</div>
        ) : null}

        {editing ? (
          <div className="flex flex-col gap-2.5 sm:flex-row">
            <Input className="flex-1" label="CN transport (৳)" value={cnFare} onChange={setCnFare} />
            <Input className="flex-1" label="Customs tax (৳)" value={customsTax} onChange={setCustomsTax} />
          </div>
        ) : null}

        <div className="flex flex-col gap-2.5 sm:flex-row">
          <Input
            className="min-w-0 flex-[1.6]"
            label="Description"
            placeholder="e.g. 3 cartons / 2 mobiles / 1 drone"
            value={description}
            onChange={setDescription}
          />
          <div className="flex min-w-0 flex-1 flex-col gap-1.5">
            <div className="text-[12px] text-muted-foreground">Payment status</div>
            <Select value={pay} onValueChange={setPay}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {PAY_OPTIONS.map((o) => (
                  <SelectItem key={o.value} value={o.value}>
                    {o.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>

        {editing ? null : (
          <div className="flex gap-2">
            <div className="flex-1 rounded-[9px] border border-dashed border-[#C9C6BF] p-2.5 text-center text-[11.5px] text-muted-foreground">+ Product photo</div>
            <div className="flex-1 rounded-[9px] border border-dashed border-[#C9C6BF] p-2.5 text-center text-[11.5px] text-muted-foreground">+ Packing video</div>
          </div>
        )}
        <Button className="mt-1" size="lg" disabled={busy} onClick={() => void submit()}>
          {editing ? 'Save changes' : 'Create shipment'}
        </Button>
      </div>
    </Modal>
  )
}
