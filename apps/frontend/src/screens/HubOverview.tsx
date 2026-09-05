import { PageHeader, EmptyState } from '@/components/Workspace'
import { Link, useNavigate } from 'react-router-dom'
import { useFetch } from '@/state/useFetch'
import { useAuth } from '@/state/auth'
import type { HubOverview as HubData } from '@/api/types'
import { AnimatedNumber } from '@/components/beui/animated-number'
import { Card, ErrorBlock, KpiTile, LoadingBlock, NoticeList, SbMark, StatusChip } from '@/components/ui'
import { deltaLabel, fmtKg } from '@/lib/format'

export function HubOverview() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const { data, error, loading } = useFetch<HubData>('/dashboard/hub')

  if (error) return <ErrorBlock message={error} />
  if (loading || !data) return <LoadingBlock />

  const firstName = user?.name.split(' ')[0] ?? 'there'

  return (
    <div>
      <PageHeader title="Hub overview" description={`Welcome, ${firstName}. Receive shipments, verify weight, and prepare courier delivery.`} />

      <Card className="overflow-hidden">
        <div className="flex flex-wrap items-center gap-3 bg-ink px-5.5 py-3.5 text-white">
          <SbMark />
          <span className="text-[11.5px] font-extrabold tracking-[.08em] text-[#E3E5E8]">BASHUNDHARA HUB · DHAKA</span>
          <span className="ml-auto text-[12.5px] text-[#E3E5E8]">{data.todayLabel}</span>
        </div>
        <div className="grid gap-2.5 p-5 [grid-template-columns:repeat(auto-fit,minmax(180px,1fr))]">
          <KpiTile label="At BD hub now" value={<AnimatedNumber value={data.atHubCount} />} sub="shipments to process" />
          <KpiTile
            label={`Incoming${data.incoming.flightCode ? ` · ${data.incoming.flightCode}` : ''}`}
            value={fmtKg(data.incoming.kg)}
            sub={`${data.incoming.count} shipments in transit`}
          />
          <KpiTile
            label="Open tasks"
            value={<AnimatedNumber value={data.openTodoCount} />}
            valueClassName="text-primary"
            sub="on your to-do list"
            onClick={() => navigate('/todos')}
          />
        </div>
      </Card>

      <NoticeList notices={data.notices} />

      <Card className="mt-4 p-5">
        <div className="mb-3 text-[15px] font-bold">Ready for hub processing</div>
        <div className="flex flex-col gap-2">
          {data.toProcess.length === 0 ? (
            <div className="rounded-[10px] border border-dashed border-[#C9C6BF] p-8 text-center text-[13px] text-muted-foreground">
              Nothing waiting at the hub.
            </div>
          ) : (
            data.toProcess.map((r) => (
              <Link
                key={r.code}
                className="flex cursor-pointer flex-wrap items-center gap-3.5 rounded-[10px] bg-background px-3.5 py-2.75 hover:bg-muted" to={`/shipments/${r.code}`}
              >
                <div className="w-[76px] text-[13px] font-bold">{r.code}</div>
                <div className="w-20 text-[12.5px] font-bold text-primary">{r.supplierCode}</div>
                <div className="min-w-[120px] flex-1 text-[12.5px] text-muted-foreground">
                  {r.categories.join(', ')} · {r.description}
                </div>
                <div className="text-[12.5px]">
                  {r.effectiveKg > 0 ? fmtKg(r.effectiveKg) : 'devices'}{' '}
                  {r.weightDelta !== null ? <span className="text-[11px] font-bold text-danger">{deltaLabel(r.weightDelta)}</span> : null}
                </div>
                <StatusChip index={r.statusIndex} label={r.statusLabel} />
              </Link>
            ))
          )}
        </div>
      </Card>
    </div>
  )
}
