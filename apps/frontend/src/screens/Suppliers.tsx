import { PageHeader, RecordList, SummaryStrip } from '@/components/Workspace'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useFetch } from '@/state/useFetch'
import type { SupplierSummary } from '@/api/types'
import { Button } from '@/components/beui/button'
import { Card, Chip, ErrorBlock, LoadingBlock, PageTitle } from '@/components/ui'
import { AddSupplierModal } from '@/modals/AddSupplierModal'
import { fmtBdt } from '@/lib/format'

const TERMS_CHIP = {
  monthly: { bg: '#E7F0FE', fg: '#0E4DA4' },
  instant: { bg: '#E6F7EC', fg: '#1B7A3D' },
}

export function Suppliers() {
  const navigate = useNavigate()
  const { data, error, loading, reload } = useFetch<{ suppliers: SupplierSummary[] }>('/suppliers')
  const [adding, setAdding] = useState(false)

  if (error) return <ErrorBlock message={error} />
  if (loading || !data) return <LoadingBlock />

  return <div><PageHeader title="Suppliers" description="Manage your shipping partners, billing terms and outstanding balances." actions={<Button onClick={()=>setAdding(true)}>+ Add supplier</Button>}/><SummaryStrip items={[{label:'Suppliers',value:data.suppliers.length},{label:'Monthly billing',value:data.suppliers.filter(s=>s.terms==='monthly').length},{label:'Total outstanding',value:fmtBdt(data.suppliers.reduce((a,s)=>a+s.balance,0))}]}/>
  <RecordList rows={data.suppliers} recordKey={s=>s.code} href={s=>`/suppliers/${encodeURIComponent(s.code)}`} searchText={s=>`${s.code} ${s.name} ${s.phone} ${s.address}`} placeholder="Search supplier, code or phone…" emptyTitle="No suppliers yet" emptyDescription="Add a supplier to start receiving shipments and managing their bills." columns={[
  {label:'Supplier',render:s=><div>{s.name}<p className="mt-1 text-xs font-normal text-muted-foreground">{s.code}</p></div>},{label:'Contact',render:s=>s.phone},{label:'Delivery address',render:s=>s.address,mobile:false},{label:'Billing terms',render:s=><Chip colors={TERMS_CHIP[s.terms]}>{s.terms==='monthly'?'Monthly':'Instant'}</Chip>},{label:'Shipped weight',render:s=>`${s.shippedKg} kg`},{label:'Outstanding',render:s=><span className={s.balance>0?'font-semibold text-danger':'text-muted-foreground'}>{fmtBdt(s.balance)}</span>}
  ]}/><AddSupplierModal open={adding} onClose={()=>setAdding(false)} onDone={()=>void reload()}/></div>
}
