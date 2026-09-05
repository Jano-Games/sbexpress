import { PageHeader, RecordList, SummaryStrip } from '@/components/Workspace'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useFetch } from '@/state/useFetch'
import type { FlightSummary } from '@/api/types'
import { Button } from '@/components/beui/button'
import { Card, Chip, ErrorBlock, FlightCode, LoadingBlock, PageTitle, ProgressBar } from '@/components/ui'
import { AddFlightModal } from '@/modals/AddFlightModal'
import { FLIGHT_CHIP, fmtBdt, fmtDate } from '@/lib/format'

export function Flights() {
  const navigate = useNavigate()
  const { data, error, loading, reload } = useFetch<{ flights: FlightSummary[] }>('/flights')
  const [adding, setAdding] = useState(false)

  if (error) return <ErrorBlock message={error} />
  if (loading || !data) return <LoadingBlock />

  return <div><PageHeader title="Flights" description="Plan departures, assign flyers and keep an eye on available capacity." actions={<Button onClick={()=>setAdding(true)}>+ Add flight</Button>}/><SummaryStrip items={[{label:'Flight bookings',value:data.flights.length},{label:'Upcoming',value:data.flights.filter(f=>f.status==='upcoming').length},{label:'Shipments assigned',value:data.flights.reduce((a,f)=>a+f.shipmentCount,0)}]}/>
  <RecordList rows={data.flights} recordKey={f=>f.code} href={f=>`/flights/${encodeURIComponent(f.code)}`} searchText={f=>`${f.code} ${f.date} ${f.flyers.join(' ')} ${f.statusLabel}`} placeholder="Search flight, flyer or date…" emptyTitle="No flights booked yet" emptyDescription="Add a flight, set its capacity and assign the flyers carrying your shipments." columns={[
   {label:'Booking',render:f=><FlightCode code={f.code}/>},{label:'Departure',render:f=>fmtDate(f.date)},{label:'Flyers',render:f=>f.flyers.join(', ')||'Not assigned'},
   {label:'Cargo capacity',render:f=><div className="min-w-[110px]"><span>{f.bookedKg} / {f.spaceKg} kg</span><ProgressBar className="mt-2" pct={f.spaceKg>0?f.bookedKg/f.spaceKg*100:0} danger={f.bookedKg>f.spaceKg}/></div>},
   {label:'Status',render:f=><Chip colors={FLIGHT_CHIP[f.status]??FLIGHT_CHIP.completed!}>{f.statusLabel}</Chip>},{label:'Flyer balance',render:f=>fmtBdt(f.flyerDue)},{label:'Shipments',render:f=>f.shipmentCount,mobile:false}
  ]}/><AddFlightModal open={adding} onClose={()=>setAdding(false)} onDone={()=>void reload()}/></div>
}
