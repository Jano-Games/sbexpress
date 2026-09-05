import { useEffect, useRef, useState } from 'react'
import { getToken } from '@/api/client'
import { Button } from '@/components/beui/button'

export function InvoicePdfActions({path,filename}:{path:string;filename:string}) {
  const [url,setUrl]=useState(''),[busy,setBusy]=useState(false),[error,setError]=useState('')
  const locked=useRef(false)
  useEffect(()=>()=>{if(url)URL.revokeObjectURL(url)},[url])
  useEffect(()=>{setUrl('');setError('')},[path])
  async function load(download:boolean){
    if(locked.current)return
    locked.current=true;setBusy(true);setError('')
    try{
      const token=getToken()
      const response=await fetch(`${import.meta.env.VITE_API_BASE_URL??''}/api${path}`,{headers:token?{Authorization:`Bearer ${token}`}:{},cache:'no-store'})
      if(!response.ok){const body=await response.json().catch(()=>null);throw new Error(body?.error??'Could not generate PDF')}
      if(!response.headers.get('content-type')?.includes('application/pdf'))throw new Error('Invalid PDF response')
      const objectUrl=URL.createObjectURL(await response.blob())
      if(download){const a=document.createElement('a');a.href=objectUrl;a.download=filename;document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(objectUrl),60000)}else setUrl(objectUrl)
    }catch(e){setError(e instanceof Error?e.message:'Could not load PDF')}
    finally{locked.current=false;setBusy(false)}
  }
  return <div className="space-y-3"><div className="flex flex-wrap gap-2"><Button variant="secondary" disabled={busy} onClick={()=>url?setUrl(''):void load(false)}>{url?'Close PDF preview':'View PDF'}</Button><Button disabled={busy} onClick={()=>void load(true)}>{busy?'Generating PDF…':'Download PDF'}</Button></div>{error&&<p role="alert" className="text-sm text-danger">{error}</p>}{url&&<iframe title="Invoice PDF preview" src={url} className="h-[560px] w-full rounded-lg border border-border"/>}</div>
}
