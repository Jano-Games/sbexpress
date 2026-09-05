import { PageHeader, RecordList, SummaryStrip } from '@/components/Workspace'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useFetch } from '@/state/useFetch'
import type { Flyer } from '@/api/types'
import { Button } from '@/components/beui/button'
import { Card, ErrorBlock, LoadingBlock, PageTitle } from '@/components/ui'
import { AddFlyerModal } from '@/modals/AddFlyerModal'

function DocBadge({ label, ok }: { label: string; ok: boolean }) {
  return (
    <span
      className="rounded-full px-2 py-0.5 text-[10px] font-bold"
      style={{ background: ok ? '#E6F7EC' : '#FDE8E8', color: ok ? '#1B7A3D' : '#C92A2A' }}
    >
      {label} {ok ? '✓' : 'missing'}
    </span>
  )
}

export function Flyers() {
  const navigate = useNavigate()
  const { data, error, loading, reload } = useFetch<{ flyers: Flyer[] }>('/flyers')
  const [adding, setAdding] = useState(false)

  if (error) return <ErrorBlock message={error} />
  if (loading || !data) return <LoadingBlock />

  return <div><PageHeader title="Flyer registry" description="Keep flyer contacts, document readiness and flight history together." actions={<Button onClick={()=>setAdding(true)}>+ Register flyer</Button>}/><SummaryStrip items={[{label:'Registered flyers',value:data.flyers.length},{label:'Documents complete',value:data.flyers.filter(f=>f.docStudentId&&f.docVisa&&f.docAdmission).length},{label:'Needs document review',value:data.flyers.filter(f=>!f.docStudentId||!f.docVisa||!f.docAdmission).length}]}/>
  <RecordList rows={data.flyers} recordKey={f=>f.name} href={f=>`/flyers/${encodeURIComponent(f.name)}`} searchText={f=>`${f.name} ${f.university} ${f.program} ${f.cnPhone} ${f.bdPhone} ${f.wechat}`} placeholder="Search name, university or phone…" emptyTitle="Your flyer registry is empty" emptyDescription="Register a flyer to keep their contact details and assign them to a flight." columns={[
  {label:'Flyer',render:f=>f.name},{label:'University',render:f=><div>{f.university}<p className="mt-1 text-xs text-muted-foreground">{f.program} · {f.batch}</p></div>},{label:'China contact',render:f=>f.cnPhone},{label:'BD contact',render:f=>f.bdPhone},{label:'Documents',render:f=><div className="flex flex-wrap gap-1"><DocBadge label="ID" ok={f.docStudentId}/><DocBadge label="Visa" ok={f.docVisa}/><DocBadge label="JW" ok={f.docAdmission}/></div>}
  ]}/><AddFlyerModal open={adding} onClose={()=>setAdding(false)} onDone={()=>void reload()}/></div>
}
