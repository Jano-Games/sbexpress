import { Package, Truck, CircleCheck } from 'lucide-react'
import { PageHeader, RecordList, SummaryStrip } from '@/components/Workspace'
import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useFetch } from '@/state/useFetch'
import { useAuth } from '@/state/auth'
import type { ShipmentRow } from '@/api/types'
import { Button } from '@/components/beui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/beui/select'
import { BillFigure, Card, Chip, ErrorBlock, Field, LoadingBlock, PageTitle, StatusChip, PIPELINE_LABELS } from '@/components/ui'
import { NewShipmentModal } from '@/modals/NewShipmentModal'
import { PAY_CHIP, PAY_LABEL, deltaLabel, fmtBdt, fmtKg, supplierLabel } from '@/lib/format'

export function Shipments() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const { data, error, loading, reload } = useFetch<{ shipments: ShipmentRow[] }>('/shipments')
  const [status, setStatus] = useState('all')
  const [supplier, setSupplier] = useState('all')
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')
  const [creating, setCreating] = useState(false)

  const rows = useMemo(() => {
    let list = data?.shipments ?? []
    if (status !== 'all') list = list.filter((r) => r.statusLabel === status)
    if (supplier !== 'all') list = list.filter((r) => r.supplierCode === supplier)
    if (from) list = list.filter((r) => r.date >= from)
    if (to) list = list.filter((r) => r.date <= to)
    return list
  }, [data, status, supplier, from, to])

  const supplierCodes = useMemo(() => [...new Set((data?.shipments ?? []).map((r) => r.supplierCode))].sort(), [data])

  if (error) return <ErrorBlock message={error} />
  if (loading || !data) return <LoadingBlock />

  const delivered = rows.filter((r) => r.statusIndex === 8)

  return <div><PageHeader title="Shipments" description="Follow every shipment from supplier intake to its final delivery." actions={user?.role==='admin'?<Button onClick={()=>setCreating(true)}>+ New shipment</Button>:undefined}/><SummaryStrip items={[
    {label:'All shipments',value:data.shipments.length,description:'Across your entire operation',icon:<Package />,tone:'primary'},
    {label:'In progress',value:data.shipments.filter(s=>s.statusIndex<8).length,description:'Awaiting final delivery',icon:<Truck />,tone:'amber'},
    {label:'Delivered',value:data.shipments.filter(s=>s.statusIndex===8).length,description:data.shipments.length ? `${Math.round(data.shipments.filter(s=>s.statusIndex===8).length / data.shipments.length * 100)}% of all shipments` : 'Completed deliveries',icon:<CircleCheck />,tone:'success'},
  ]}/>
  <div className="mb-4 flex flex-wrap items-end gap-3 rounded-xl border border-border bg-card p-4">
  <label className="min-w-[150px] flex-1 text-xs text-muted-foreground">Shipment status<select className="mt-1.5 block h-10 w-full rounded-lg border border-border bg-background px-3 text-xs" value={status} onChange={e=>setStatus(e.target.value)}><option value="all">All statuses</option>{PIPELINE_LABELS.map(s=><option key={s}>{s}</option>)}</select></label>
  <label className="min-w-[140px] flex-1 text-xs text-muted-foreground">Supplier<select className="mt-1.5 block h-10 w-full rounded-lg border border-border bg-background px-3 text-xs" value={supplier} onChange={e=>setSupplier(e.target.value)}><option value="all">All suppliers</option>{supplierCodes.map(s=><option key={s}>{s}</option>)}</select></label>
  <label className="text-xs text-muted-foreground">From date<input type="date" value={from} onChange={e=>setFrom(e.target.value)} className="mt-1.5 block h-10 rounded-lg border border-border bg-background px-3"/></label><label className="text-xs text-muted-foreground">To date<input type="date" min={from||undefined} value={to} onChange={e=>setTo(e.target.value)} className="mt-1.5 block h-10 rounded-lg border border-border bg-background px-3"/></label>
  {(status!=='all'||supplier!=='all'||from||to)&&<Button variant="ghost" onClick={()=>{setStatus('all');setSupplier('all');setFrom('');setTo('')}}>Reset filters</Button>}</div>
  <RecordList rows={rows} recordKey={s=>s.code} href={s=>`/shipments/${encodeURIComponent(s.code)}`} searchText={s=>`${s.code} ${s.supplierCode} ${s.supplierName??''} ${s.description} ${s.categories.join(' ')}`} placeholder="Search shipment, supplier or product…" emptyTitle={data.shipments.length?'No shipments match these filters':'No shipments yet'} emptyDescription={data.shipments.length?'Reset the status, supplier or date filters to see more shipments.':'Create a shipment to record the product, supplier and initial booking details.'} columns={[
   {label:'Shipment',render:s=>s.code},{label:'Supplier',render:s=>supplierLabel(s.supplierCode,s.supplierName)},{label:'Contents',render:s=><div>{s.description||'No description'}<p className="mt-1 text-xs text-muted-foreground">{s.categories.join(', ')}</p></div>},
   {label:'Weight',render:s=><div>{s.effectiveKg>0?fmtKg(s.effectiveKg):'Devices'}{s.weightDelta!==null&&<p className="text-xs text-danger">{deltaLabel(s.weightDelta)}</p>}</div>},{label:'Status',render:s=><StatusChip index={s.statusIndex} label={s.statusLabel}/>},
   ...(user?.role==='admin' ? [{label:'Payment',render:(s:ShipmentRow)=><Chip colors={PAY_CHIP[s.payStatus]??PAY_CHIP.unpaid!}>{PAY_LABEL[s.payStatus]}</Chip>},{label:'Bill',render:(s:ShipmentRow)=><BillFigure bill={s.billAmount} discount={s.discountAmount}/>}]: [])
  ]}/><NewShipmentModal open={creating} onClose={()=>setCreating(false)} onDone={()=>void reload()}/></div>
}
