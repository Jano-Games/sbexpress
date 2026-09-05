import { PageHeader, PageTabs, SummaryStrip, EmptyState } from '@/components/Workspace'
import { useState } from 'react'
import { api } from '@/api/client'
import { useFetch } from '@/state/useFetch'
import type { Todo } from '@/api/types'
import { Button } from '@/components/beui/button'
import { Input } from '@/components/beui/input'
import { useToast } from '@/components/beui/toast'
import { Card, ErrorBlock, LoadingBlock } from '@/components/ui'

export function Todos() {
  const { showToast } = useToast()
  const { data, error, loading, reload } = useFetch<{ todos: Todo[] }>('/todos')
  const [filter, setFilter] = useState('open')
  const [busy, setBusy] = useState(false)
  const [text, setText] = useState('')

  if (error) return <ErrorBlock message={error} />
  if (loading || !data) return <LoadingBlock />

  const act = async (job: () => Promise<unknown>) => {
    if (busy) return
    setBusy(true)
    try { await job(); await reload() } catch(e) { showToast({title:e instanceof Error ? e.message : 'Could not save task',status:'error'}) } finally {setBusy(false)}
  }
  const toggle = (id:string) => void act(() => api.post(`/todos/${id}/toggle`))
  const add = () => { if (!text.trim()) return; void act(async () => { await api.post('/todos',{text:text.trim()});setText('');showToast({title:'Task added',status:'success'}) }) }
  const visible = data.todos.filter(t => filter === 'all' || (filter === 'done' ? t.done : !t.done))

  return (
    <div>
      <PageHeader title="Tasks" description="Keep operational follow-ups in one place and mark them complete as work gets done." />
      <SummaryStrip items={[{label:'Open',value:data.todos.filter(t=>!t.done).length},{label:'Completed',value:data.todos.filter(t=>t.done).length}]} />
      <form className="mb-5 flex max-w-[900px] items-end gap-3" onSubmit={e=>{e.preventDefault();add()}}><Input className="min-w-0 flex-1" label="New task" placeholder="What needs to happen next?" value={text} onChange={setText}/><Button type="submit" disabled={busy || !text.trim()}>Add task</Button></form>
      <PageTabs value={filter} onChange={setFilter} items={[{value:'open',label:'Open tasks'},{value:'done',label:'Completed'},{value:'all',label:'All tasks'}]} />
      <Card className="max-w-[900px] px-4 py-2 rounded-[14px]">
        {!visible.length && <EmptyState title={filter==='done'?'No completed tasks':'No tasks here'} description={filter==='open'?'You are caught up. Add a task when something needs follow-up.':'Tasks matching this view will appear here.'} />}
        {visible.map((t) => (
          <div key={t.id} className="flex items-center gap-3 border-b border-muted py-2.75 last:border-b-0">
            <button
              type="button"
              role="checkbox"
              aria-checked={t.done}
              disabled={busy}
              aria-label={t.done ? 'Mark not done' : 'Mark done'}
              className="grid size-9 shrink-0 cursor-pointer place-items-center rounded-md border-2 text-xs font-extrabold text-white"
              style={{ borderColor: t.done ? '#1B7A3D' : '#C9C6BF', background: t.done ? '#1B7A3D' : '#fff' }}
              onClick={() => toggle(t.id)}
            >
              {t.done ? '✓' : ''}
            </button>
            <div
              className="min-w-0 flex-1 break-words text-[13px]"
              style={{ color: t.done ? '#9B9EA3' : '#1A1C1E', textDecoration: t.done ? 'line-through' : 'none' }}
            >
              {t.text}
            </div>
            {t.auto ? <span className="rounded-[10px] bg-blue-soft px-2 py-0.5 text-[10px] font-bold text-blue">AUTO</span> : null}
          </div>
        ))}
      </Card>
    </div>
  )
}
