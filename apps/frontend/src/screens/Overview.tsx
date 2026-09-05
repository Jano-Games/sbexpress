import { PageHeader, EmptyState } from '@/components/Workspace'
import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useFetch } from '@/state/useFetch'
import { useAuth } from '@/state/auth'
import type { AdminOverview } from '@/api/types'
import { Button } from '@/components/beui/button'
import { AnimatedNumber } from '@/components/beui/animated-number'
import { BillFigure, Card, Chip, ErrorBlock, FlightCode, KpiTile, LoadingBlock, NoticeList, ProgressBar, SbMark, StatusChip } from '@/components/ui'
import { AddFlightModal } from '@/modals/AddFlightModal'
import { FLIGHT_CHIP, PAY_CHIP, PAY_LABEL, deltaLabel, fmtBdt, fmtDate, supplierLabel } from '@/lib/format'

export function Overview() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const { data, error, loading, reload } = useFetch<AdminOverview>('/dashboard/overview')
  const [addFlight, setAddFlight] = useState(false)

  if (error) return <ErrorBlock message={error} />
  if (loading || !data) return <LoadingBlock />

  const firstName = user?.name.split(' ')[0] ?? 'there'

  return (
    <div>
      <PageHeader title="Business overview" description={`Welcome, ${firstName}. Keep track of shipments, collections, and upcoming flights.`} actions={<><Button variant="secondary" onClick={() => navigate('/shipments')}>View shipments</Button><Button onClick={() => setAddFlight(true)}>+ New flight</Button></>} />

      <Card className="overflow-hidden">
        <div className="flex flex-wrap items-center gap-3 bg-ink px-5.5 py-3.5 text-white">
          <SbMark />
          <span className="text-[11.5px] font-extrabold tracking-[.08em] text-[#E3E5E8]">BUSINESS THIS WEEK</span>
          <span className="text-[11.5px] text-[#B9BCC1]">{data.weekLabel}</span>
          <span className="ml-auto text-[12.5px] text-[#E3E5E8]">
            {data.todayLabel} · ¥1 = ৳{data.rate}
          </span>
        </div>
        <div className="grid gap-2.5 p-5 sm:grid-cols-2 xl:grid-cols-4">
          <KpiTile
            label="Available funds"
            value={<AnimatedNumber value={data.cash.worth} format={fmtBdt} />}
            sub="All accounts · BDT equivalent · includes capital"
            onClick={() => navigate('/finance')}
          />
          <KpiTile
            label="This week net cash"
            value={<AnimatedNumber value={data.net} format={fmtBdt} />}
            valueClassName={data.net >= 0 ? 'text-success' : 'text-danger'}
            sub={`${fmtBdt(data.received)} in − ${fmtBdt(data.expenses + data.refunded)} out · includes ${fmtBdt(data.capitalReceived)} capital`}
          />
          <KpiTile
            label="Supplier invoices to collect"
            value={<AnimatedNumber value={data.unpaid} format={fmtBdt} />}
            valueClassName="text-danger"
            sub="All suppliers · instant and monthly"
            onClick={() => navigate('/suppliers')}
          />
          <KpiTile
            label="This week net profit"
            value={<AnimatedNumber value={data.profit} format={fmtBdt} />}
            valueClassName={data.profit >= 0 ? 'text-success' : 'text-danger'}
            sub="All business revenue − all business costs"
            onClick={() => navigate('/finance')}
          />
          <KpiTile label="Flyer contributions to collect" value={fmtBdt(data.flyerReceivables)} sub="Across all flights" onClick={() => navigate('/flights')} />
          <KpiTile label="Costs to pay" value={fmtBdt(data.payables)} sub="Unpaid tickets + shipment costs" onClick={() => navigate('/finance')} />
          <KpiTile label="Receipts to review" value={data.reviewCount} sub="Pending approval" onClick={() => navigate('/review')} />
          {data.nextFlight ? (
            <KpiTile
              label={`Next flight · ${data.nextFlight.code} · ${fmtDate(data.nextFlight.date)}`}
              value={
                <>
                  {data.nextFlight.bookedKg}{' '}
                  <span className="text-xs font-medium text-[#44474C]">/ {data.nextFlight.spaceKg} kg</span>
                </>
              }
            >
              <ProgressBar className="mt-2" pct={(data.nextFlight.spaceKg ? data.nextFlight.bookedKg / data.nextFlight.spaceKg : 0) * 100} />
            </KpiTile>
          ) : (
            <KpiTile label="Next flight" value="—" sub="none scheduled" />
          )}
        </div>
      </Card>

      <NoticeList notices={data.notices} />

      <Card className="mt-4 p-5">
        <div className="mb-3 flex items-center justify-between">
          <div className="text-[15px] font-bold">Flights</div>
          <button
            type="button"
            className="cursor-pointer border-0 bg-transparent text-[12.5px] font-semibold text-blue"
            onClick={() => navigate('/flights')}
          >
            View all →
          </button>
        </div>
        <div className="flex flex-col gap-2">
          {!data.flights.length && <EmptyState title="No flights scheduled" description="Create a flight to assign flyers and start planning cargo." />}
          {data.flights.map((f) => (
            <Link
              key={f.code}
              className="flex cursor-pointer flex-wrap items-center gap-3.5 rounded-[10px] bg-background px-3.5 py-3 hover:bg-muted" to={`/flights/${f.code}`}
            >
              <div className="w-[170px] text-[13.5px] font-extrabold text-primary">
                <FlightCode code={f.code} />
              </div>
              <div className="w-[90px] text-[12.5px] font-semibold">{fmtDate(f.date)}</div>
              <div className="min-w-[140px] flex-1 text-[12.5px] text-[#44474C]">{f.flyers.join(', ') || 'no flyer yet'}</div>
              <div className="flex w-[150px] items-center gap-2">
                <ProgressBar className="flex-1" pct={(f.spaceKg ? f.bookedKg / f.spaceKg : 0) * 100} />
                <span className="whitespace-nowrap text-[11.5px] text-[#44474C]">
                  {f.bookedKg} / {f.spaceKg} kg
                </span>
              </div>
              <Chip colors={FLIGHT_CHIP[f.status] ?? FLIGHT_CHIP.completed!}>
                {f.status.charAt(0).toUpperCase() + f.status.slice(1)}
              </Chip>
              <div className="w-24 text-right text-xs text-[#44474C]">{f.shipmentCount} shipment(s)</div>
            </Link>
          ))}
        </div>
      </Card>

      <Card className="mt-3.5 p-5">
        <div className="mb-3 flex items-center justify-between">
          <div className="text-[15px] font-bold">Active shipments</div>
          <button
            type="button"
            className="cursor-pointer border-0 bg-transparent text-[12.5px] font-semibold text-blue"
            onClick={() => navigate('/shipments')}
          >
            View all →
          </button>
        </div>
        <div className="flex flex-col gap-2">
          {!data.activeShipments.length && <EmptyState title="No active shipments" description="New shipments will appear here as they move through the delivery process." />}
          {data.activeShipments.map((r) => (
            <Link
              key={r.code}
              className="flex cursor-pointer flex-wrap items-center gap-3.5 rounded-[10px] bg-background px-3.5 py-2.75 hover:bg-muted" to={`/shipments/${r.code}`}
            >
              <div className="w-[76px] text-[13px] font-bold">{r.code}</div>
              <div className="w-[150px] text-[12.5px] text-muted-foreground">{supplierLabel(r.supplierCode, r.supplierName)}</div>
              <div className="min-w-[140px] flex-1 text-[12.5px] text-muted-foreground">
                {r.categories.join(', ')} · {r.description}
              </div>
              <StatusChip index={r.statusIndex} label={r.statusLabel} />
              <Chip colors={PAY_CHIP[r.payStatus] ?? PAY_CHIP.unpaid!}>{PAY_LABEL[r.payStatus]}</Chip>
              {r.weightDelta !== null ? <span className="text-[11px] font-bold text-danger">{deltaLabel(r.weightDelta)}</span> : null}
              <div className="flex w-[76px] justify-end">
                <BillFigure bill={r.billAmount} discount={r.discountAmount} className="text-right text-[13px]" />
              </div>
            </Link>
          ))}
        </div>
      </Card>

      <AddFlightModal open={addFlight} onClose={() => setAddFlight(false)} onDone={reload} />
    </div>
  )
}
