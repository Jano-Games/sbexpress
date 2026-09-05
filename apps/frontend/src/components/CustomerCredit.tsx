import {useState} from 'react'
import {api} from '@/api/client'
import {useFetch} from '@/state/useFetch'
import {Card} from '@/components/ui'
import {Button} from '@/components/beui/button'
import {Input} from '@/components/beui/input'
import {fmtBdt} from '@/lib/format'
export function CustomerCredit({code,onChanged}:{code:string;onChanged:()=>void}){
 const {data,reload,error}=useFetch<{balance:number;entries:{reference:string;amount:number;kind:string;reason:string;shipmentCode:string|null;at:string}[]}>(`/suppliers/${code}/credits`)
 const {data:accounts}=useFetch<{accounts:{name:string}[]}>('/finance?period=all')
 const [amount,setAmount]=useState(''),[account,setAccount]=useState(''),[reason,setReason]=useState(''),[shipment,setShipment]=useState(''),[busy,setBusy]=useState(false),[message,setMessage]=useState('')
 async function act(path:string,body:unknown){setBusy(true);setMessage('');try{await api.post(`/suppliers/${code}/${path}`,body);setAmount('');await reload();onChanged()}catch(e){setMessage(e instanceof Error?e.message:'Failed')}finally{setBusy(false)}}
 return <Card className="my-4 p-5"><h3 className="font-bold">Customer credit: {fmtBdt(data?.balance??0)}</h3><p className="text-sm my-2">Overpayments stay here for future bills or refunds. To refund a paid shipment, issue a credit note on that shipment first.</p>
 <div className="flex flex-wrap gap-3 items-end"><Input label="Amount (BDT)" value={amount} onChange={setAmount}/><Input label="Shipment code" value={shipment} onChange={setShipment}/><Button disabled={busy} onClick={()=>void act('apply-credit',{amount:Number(amount),shipmentCode:shipment})}>Apply credit to bill</Button></div>
 <div className="flex flex-wrap gap-3 items-end my-3"><label>Account<select className="block rounded border p-2" value={account} onChange={e=>setAccount(e.target.value)}><option value="">Select account</option>{accounts?.accounts.map(a=><option key={a.name}>{a.name}</option>)}</select></label><Input label="Refund reason" value={reason} onChange={setReason}/><Button disabled={busy} onClick={()=>void act('refunds',{amount:Number(amount),accountName:account,reason})}>Record refund paid</Button></div>
 {(message||error)&&<p role="alert" className="text-red-700">{message||error}</p>}
 <details><summary>Credit history</summary>{data?.entries.map(e=><p key={e.reference} className="border-b py-2 text-sm">{e.at.slice(0,10)} · {e.kind} · {fmtBdt(e.amount)} · {e.shipmentCode} · {e.reason}</p>)}</details></Card>
}
export function InvoiceHistory({code}:{code:string}){
 const {data,error}=useFetch<{revisions:{version:number;reason:string;at:string;snapshot:{total:number;discount:number;note:string;lines:{label:string;amount:number}[]}}[];creditNotes:{number:string;amount:number;reason:string;previousTotal:number;revisedTotal:number;at:string}[]}>(`/shipments/${code}/invoice-history`)
 return <Card className="my-4 p-5"><details><summary className="font-bold">Invoice revisions & credit notes</summary>{error&&<p>{error}</p>}{data?.creditNotes.map(n=><p key={n.number} className="border-b py-2 text-sm">Credit note {n.number} · {fmtBdt(n.amount)} · {n.reason} · Bill {fmtBdt(n.previousTotal)} → {fmtBdt(n.revisedTotal)}</p>)}{data?.revisions.map(v=><details key={v.version} className="border-b py-2 text-sm"><summary>Revision {v.version} · {v.at.slice(0,10)} · {fmtBdt(v.snapshot.total)} · {v.reason}</summary>{v.snapshot.lines.map((l,i)=><p key={i}>{l.label}: {fmtBdt(l.amount)}</p>)}<p>Discount: {fmtBdt(v.snapshot.discount)} · {v.snapshot.note}</p></details>)}</details></Card>
}
