import {useState} from 'react'
import {api} from '@/api/client'
import {Card} from '@/components/ui'
import {Input} from '@/components/beui/input'
import {Button} from '@/components/beui/button'
import {fmtBdt} from '@/lib/format'
export function FlyerSettlement({code,rows,legacy,onSaved}:{code:string;rows:{name:string;contribution:number;paidAmount:number}[];legacy:number;onSaved:()=>void}){
 const [draft,setDraft]=useState(rows.map(r=>({...r,contribution:String(r.contribution),legacyPaid:'0'}))),[error,setError]=useState(''),[busy,setBusy]=useState(false)
 return <Card className="my-4 p-4"><h3 className="font-bold">Individual flyer settlements</h3>{legacy>0&&<p>Previously unattributed receipts: {fmtBdt(legacy)}. Allocate these to the correct flyers.</p>}{draft.map((r,i)=><div className="my-3 flex gap-3 items-end flex-wrap" key={r.name}><span>{r.name} · received {fmtBdt(r.paidAmount)}</span><Input label="Contribution (BDT)" value={r.contribution} onChange={v=>setDraft(d=>d.map((x,j)=>j===i?{...x,contribution:v}:x))}/>{legacy>0&&<Input label="Previously received (BDT)" value={r.legacyPaid} onChange={v=>setDraft(d=>d.map((x,j)=>j===i?{...x,legacyPaid:v}:x))}/>}</div>)}<Button disabled={busy||!rows.length} onClick={()=>void(async()=>{setBusy(true);setError('');try{await api.post(`/flights/${code}/settlements`,{allocations:draft.map(r=>({name:r.name,contribution:Number(r.contribution),legacyPaid:Number(r.legacyPaid)}))});onSaved()}catch(e){setError(e instanceof Error?e.message:'Failed')}finally{setBusy(false)}})()}>Save contribution split</Button>{error&&<p role="alert">{error}</p>}</Card>
}
