import { useState } from 'react'
import { PageHeader, SummaryStrip } from '@/components/Workspace'
import { Link } from 'react-router-dom'
import { api } from '@/api/client'
import { useFetch } from '@/state/useFetch'
import type { ReviewItem } from '@/api/types'
import { Button } from '@/components/beui/button'
import { useToast } from '@/components/beui/toast'
import { Card, ErrorBlock, LoadingBlock } from '@/components/ui'
import { fmtBdt, fmtDayMonth } from '@/lib/format'

export function Review() {
  const [busy, setBusy] = useState<string | null>(null)
  const { showToast } = useToast()
  const { data, error, loading, reload } = useFetch<{ queue: ReviewItem[];statements:{reference:string;supplierCode:string;supplierName:string;month:string;amount:number;method:string;txnRef:string}[] }>('/review')

  if (error) return <ErrorBlock message={error} />
  if (loading || !data) return <LoadingBlock />

  const act = (code: string, action: 'approve' | 'reject') => {
    if (busy) return
    setBusy(code)
    void api
      .post(`/shipments/${code}/receipt/${action}`)
      .then(() => {
        showToast({
          title: action === 'approve' ? `Payment marked received — ${code}` : `Receipt rejected — ${code}`,
          status: action === 'approve' ? 'success' : 'neutral',
        })
        return reload()
      })
      .catch((e: unknown) => showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' }))
      .finally(() => setBusy(null))
  }

  return (
    <div>
      <PageHeader title="Payment review" description="Check each reference against your account before confirming that payment was received." />
      <SummaryStrip items={[{label:'Shipment payments',value:data.queue.length},{label:'Statement payments',value:data.statements.length}]} />

      {data.statements.map(r=><Card key={r.reference} className="my-4 p-5"><b>{r.supplierName} · {r.month} · {fmtBdt(r.amount)}</b><p>{r.method} · {r.txnRef}</p><Link to={`/suppliers/${r.supplierCode}?section=statements`}>Review statement payment →</Link></Card>)}
      {data.queue.length === 0 && data.statements.length === 0 ? (
        <div className="mt-4.5 rounded-[14px] border border-dashed border-[#C9C6BF] bg-card p-10 text-center text-[13px] text-muted-foreground">
          Queue is clear — no receipts waiting.
        </div>
      ) : (
        <div className="mt-4.5 grid gap-3.5 [grid-template-columns:repeat(auto-fit,minmax(min(100%,330px),1fr))]">
          {data.queue.map((q) => (
            <Card key={q.code} className="p-4.5 rounded-[14px]">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="text-sm font-extrabold">
                  {q.code} · {q.supplierCode} · {q.supplierName}
                </div>
                <div className="text-[15px] font-extrabold">{fmtBdt(q.amount)}</div>
              </div>
              <div className="mt-0.5 text-xs text-muted-foreground">
                {q.method} · uploaded {fmtDayMonth(q.date)}
              </div>
              <div className="mt-3 break-all border border-border p-4 rounded-[10px] bg-muted text-[11.5px] text-muted-foreground">
                Payment reference · {q.method} TXN {q.txnRef}
              </div>
              <div className="mt-3 flex gap-2">
                <Button disabled={busy !== null} variant="success" className="flex-1" onClick={() => act(q.code, 'approve')}>
                  Received ✓
                </Button>
                <Button disabled={busy !== null} variant="danger-outline" className="flex-1" onClick={() => act(q.code, 'reject')}>
                  Not received
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  )
}
