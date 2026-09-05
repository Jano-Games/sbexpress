import { useEffect, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { Search, ChevronLeft, ChevronRight } from 'lucide-react'
import { Button } from '@/components/beui/button'
export function PageHeader({title,description,actions}:{title:string;description:string;actions?:ReactNode}){return <header className="mb-6 flex flex-wrap items-start justify-between gap-4"><div><p className="mb-1 text-[10px] font-bold uppercase tracking-[.16em] text-primary">Sichuan Bangla Express</p><h1 className="text-[28px] font-extrabold tracking-tight">{title}</h1><p className="mt-1.5 max-w-2xl text-[13px] leading-relaxed text-muted-foreground">{description}</p></div>{actions&&<div className="flex flex-wrap gap-2">{actions}</div>}</header>}
export function PageTabs({value,onChange,items}:{value:string;onChange:(value:string)=>void;items:{value:string;label:string}[]}){return <nav aria-label="Page sections" className="mb-5 flex max-w-full gap-5 overflow-x-auto overflow-y-hidden border-b border-border">{items.map(t=><button key={t.value} onClick={()=>onChange(t.value)} aria-current={value===t.value?'page':undefined} className={`whitespace-nowrap border-b-2 px-0.5 py-3 text-[13px] font-semibold ${value===t.value?'border-primary text-primary':'border-transparent text-muted-foreground hover:text-foreground'}`}>{t.label}</button>)}</nav>}
type SummaryItem = {
  label: string
  value: ReactNode
  description?: string
  icon?: ReactNode
  tone?: 'neutral' | 'primary' | 'amber' | 'success'
}

const summaryTones = {
  neutral: { accent: 'bg-border', icon: 'bg-muted text-muted-foreground', value: 'text-foreground' },
  primary: { accent: 'bg-primary', icon: 'bg-primary-soft text-primary', value: 'text-primary' },
  amber: { accent: 'bg-amber-500', icon: 'bg-amber-50 text-amber-700', value: 'text-foreground' },
  success: { accent: 'bg-success', icon: 'bg-success-soft text-success', value: 'text-success' },
}

export function SummaryStrip({ items }: { items: SummaryItem[] }) {
  return (
    <dl className={`mb-5 grid grid-cols-2 gap-3 ${items.length === 3 ? 'sm:grid-cols-3 [&>div:last-child]:col-span-2 sm:[&>div:last-child]:col-span-1' : ''}`}>
      {items.map(item => {
        const tone = summaryTones[item.tone ?? 'neutral']
        return (
          <div key={item.label} className="relative min-w-0 overflow-hidden rounded-xl border border-border bg-card p-4 shadow-[0_2px_5px_rgba(26,28,30,0.025)] sm:p-5">
            <span aria-hidden="true" className={`absolute inset-y-5 left-0 w-[3px] rounded-r-full ${tone.accent}`} />
            <div className="flex items-start justify-between gap-2">
              <dt className="pt-1 text-xs font-medium leading-relaxed text-muted-foreground sm:text-[13px]">{item.label}</dt>
              {item.icon && <span aria-hidden="true" className={`grid size-8 shrink-0 place-items-center rounded-lg sm:size-9 [&>svg]:size-4 ${tone.icon}`}>{item.icon}</span>}
            </div>
            <dd className={`mt-2 break-words text-[28px] font-bold leading-tight tracking-tight tabular-nums sm:text-[34px] ${tone.value}`}>{item.value}</dd>
            {item.description && <p className="mt-2 text-[11px] leading-relaxed text-muted-foreground sm:text-xs">{item.description}</p>}
          </div>
        )
      })}
    </dl>
  )
}

export function EmptyState({title,description,action}:{title:string;description:string;action?:ReactNode}){return <div className="px-5 py-12 text-center"><h3 className="text-sm font-semibold">{title}</h3><p className="mx-auto mt-2 max-w-md text-xs leading-relaxed text-muted-foreground">{description}</p>{action&&<div className="mt-4">{action}</div>}</div>}
type Column<T>={label:string;render:(row:T)=>ReactNode;mobile?:boolean}
export function RecordList<T>({rows,columns,recordKey,href,searchText,placeholder='Search records…',emptyTitle='No records yet',emptyDescription='New records will appear here.',filters}:{rows:T[];columns:Column<T>[];recordKey:(row:T)=>string;href:(row:T)=>string;searchText:(row:T)=>string;placeholder?:string;emptyTitle?:string;emptyDescription?:string;filters?:ReactNode}){
 const [query,setQuery]=useState(''),[page,setPage]=useState(1)
 const filtered=rows.filter(r=>searchText(r).toLowerCase().includes(query.toLowerCase().trim()))
 useEffect(()=>setPage(1),[query,rows])
 const pages=Math.max(1,Math.ceil(filtered.length/20)),current=Math.min(page,pages),visible=filtered.slice((current-1)*20,current*20)
 return <section className="relative min-w-0 overflow-hidden rounded-2xl border border-border bg-card"><div className="flex flex-wrap items-end gap-3 border-b border-border p-4"><label className="relative min-w-0 flex-[1_1_220px]"><span className="sr-only">Search records</span><Search size={15} className="absolute left-3 top-3 text-muted-foreground"/><input className="h-10 w-full rounded-lg border border-border bg-background pl-9 pr-3 text-[13px]" value={query} onChange={e=>setQuery(e.target.value)} placeholder={placeholder}/></label>{filters}<span className="py-2 text-xs text-muted-foreground">{filtered.length} records</span>{query&&<Button variant="ghost" size="sm" onClick={()=>setQuery('')}>Clear search</Button>}</div>
 {!filtered.length?<EmptyState title={query?'No matching records':emptyTitle} description={query?'Try a different name, reference or contact detail.':emptyDescription}/>:<><div className="relative hidden overflow-x-auto xl:block"><table className="w-full min-w-[760px] text-left text-[13px]"><thead className="border-b border-border bg-background text-[10px] uppercase tracking-wider text-muted-foreground"><tr>{columns.map(c=><th key={c.label} className="px-4 py-3 font-semibold">{c.label}</th>)}<th className="px-3"><span className="sr-only">Open record</span></th></tr></thead><tbody>{visible.map(row=><tr key={recordKey(row)} className="border-b border-border/60 last:border-0 hover:bg-background/60">{columns.map((c,i)=><td key={c.label} className="max-w-[240px] break-words px-4 py-4 align-middle">{i===0?<Link className="font-semibold text-primary hover:underline" to={href(row)}>{c.render(row)}</Link>:c.render(row)}</td>)}<td className="px-3"><Link aria-label={`Open ${recordKey(row)}`} to={href(row)} className="inline-block rounded-lg p-2 text-primary"><ChevronRight size={16}/></Link></td></tr>)}</tbody></table></div>
 <div className="divide-y divide-border xl:hidden">{visible.map(row=><article key={recordKey(row)} className="p-4"><Link to={href(row)} className="mb-3 flex items-center justify-between gap-3 text-sm font-bold text-primary">{columns[0]?.render(row)}<ChevronRight size={16}/></Link><dl className="grid grid-cols-2 gap-x-4 gap-y-3">{columns.slice(1).filter(c=>c.mobile!==false).map(c=><div key={c.label} className="min-w-0"><dt className="mb-1 text-[10px] text-muted-foreground">{c.label}</dt><dd className="break-words text-xs">{c.render(row)}</dd></div>)}</dl></article>)}</div></>}
 <footer className="flex items-center justify-between border-t border-border px-4 py-3 text-xs text-muted-foreground"><span>{filtered.length?`${(current-1)*20+1}–${Math.min(current*20,filtered.length)} of ${filtered.length}`:'0 records'}</span><div className="flex items-center gap-3"><button aria-label="Previous records page" disabled={current<=1} onClick={()=>setPage(p=>p-1)} className="rounded border border-border p-1.5 disabled:opacity-30"><ChevronLeft size={15}/></button><span>{current} / {pages}</span><button aria-label="Next records page" disabled={current>=pages} onClick={()=>setPage(p=>p+1)} className="rounded border border-border p-1.5 disabled:opacity-30"><ChevronRight size={15}/></button></div></footer></section>
}
