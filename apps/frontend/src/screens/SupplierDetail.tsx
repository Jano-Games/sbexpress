import { PageTabs } from '@/components/Workspace'
import { StatementLinks } from '@/components/StatementLinks'
import { CustomerCredit } from '@/components/CustomerCredit'
import { useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { api } from '@/api/client'
import { useFetch } from '@/state/useFetch'
import type { InvoiceDoc, SupplierDetail as Detail } from '@/api/types'
import { Button } from '@/components/beui/button'
import { Input } from '@/components/beui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/beui/select'
import { useToast } from '@/components/beui/toast'
import { BillFigure, Card, Chip, ErrorBlock, Field, LoadingBlock, StatusChip } from '@/components/ui'
import { ConfirmDialog } from '@/components/ConfirmDialog'
import { InvoiceModal } from '@/modals/InvoiceModal'
import { AddSupplierModal } from '@/modals/AddSupplierModal'
import { PAY_CHIP, PAY_LABEL, deltaLabel, fmtBdt, fmtDate, fmtKg, fmtLogAt } from '@/lib/format'

export function SupplierDetail() {
  const { code = '' } = useParams()
  const navigate = useNavigate()
  const { showToast } = useToast()
  const {data:paymentAccounts} = useFetch<{accounts:{name:string}[]}>('/finance?period=all')
  const { data, error, loading, reload } = useFetch<{ supplier: Detail }>(`/suppliers/${code}`)
  const [params, setParams] = useSearchParams()
  const section = ['overview','credit','statements'].includes(params.get('section') ?? '') ? params.get('section')! : 'overview'
  const setSection = (value: string) => setParams(value === 'overview' ? {} : {section:value})
  const [statement, setStatement] = useState<InvoiceDoc | null>(null)
  const [statementOpen, setStatementOpen] = useState(false)
  const [editOpen, setEditOpen] = useState(false)
  const [deleteOpen, setDeleteOpen] = useState(false)
  const [payAmt, setPayAmt] = useState('')
  const [payMethod, setPayMethod] = useState('Cash')
  const [payBusy, setPayBusy] = useState(false)

  if (error) return <ErrorBlock message={error} />
  if (loading || !data) return <LoadingBlock />
  const s = data.supplier
  const monthLabel = new Date().toLocaleDateString('en-GB', { month: 'long' })

  const recordPayment = (amount: number) =>
    void (async () => {
      if (Number.isNaN(amount) || amount <= 0) {
        showToast({ title: 'Enter the amount received', status: 'error' })
        return
      }
      setPayBusy(true)
      try {
        const r = await api.post<{ allocations: { code: string; amount: number }[] }>(
          `/suppliers/${code}/payments`,
          { amount, method: payMethod },
        )
        showToast({
          title: `${fmtBdt(amount)} recorded`,
          description: r.allocations.map((a) => `${a.code} ${fmtBdt(a.amount)}`).join(' · '),
          status: 'success',
        })
        setPayAmt('')
        await reload()
      } catch (e) {
        showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' })
      } finally {
        setPayBusy(false)
      }
    })()

  const openStatement = () =>
    void api
      .get<{ statement: InvoiceDoc }>(`/suppliers/${s.code}/statement?month=${new Date().toISOString().slice(0, 7)}`)
      .then((r) => {
        setStatement(r.statement)
        setStatementOpen(true)
      })
      .catch((e: unknown) => showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' }))

  return (
    <div>
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2.5">
        <Link to="/suppliers" className="text-[12.5px] font-semibold text-blue no-underline">
          ← Suppliers
        </Link>
        <div className="flex flex-wrap gap-2">
          <Button variant="secondary" onClick={() => setEditOpen(true)}>
            Edit
          </Button>
          <Button variant="danger-outline" onClick={() => setDeleteOpen(true)}>
            Delete
          </Button>
          {s.terms === 'monthly' ? <Button onClick={openStatement}>{monthLabel} statement →</Button> : null}
        </div>
      </div>

      <h1 className="mb-1 text-[26px] font-extrabold break-words">{s.name}</h1>
      <p className="mb-3 text-xs text-muted-foreground">{s.code} · Supplier account</p>
      <PageTabs value={section} onChange={setSection} items={[{value:'overview',label:'Overview & payments'},{value:'credit',label:'Credit & refunds'},{value:'statements',label:'Statements & links'}]} />
      {section === 'credit' && <CustomerCredit key={JSON.stringify(data.supplier)} code={code} onChanged={reload} />}
      {section === 'statements' && <StatementLinks code={code} onChanged={reload} />}
      {section === 'overview' && <>
      <div className="flex flex-wrap items-start gap-3.5">
        <div className="flex min-w-0 w-full lg:min-w-[380px] lg:flex-[1.7] flex-col gap-3.5">
          <Card className="overflow-hidden">
            <div className="flex flex-wrap items-center gap-3.5 bg-ink px-5.5 py-4 text-white">
              <div className="grid h-10 place-items-center rounded-[11px] bg-primary px-3.25 text-[13px] font-extrabold">{s.code}</div>
              <div>
                <h2 className="m-0 text-[18px] font-extrabold break-words">Account details</h2>
                <div className="text-[12.5px] text-[#E3E5E8]">
                  {s.phone} · {s.address}
                </div>
              </div>
              <Chip
                colors={s.terms === 'monthly' ? { bg: '#E7F0FE', fg: '#0E4DA4' } : { bg: '#E6F7EC', fg: '#1B7A3D' }}
                className="ml-auto px-3.25 py-1.25 text-[11.5px] font-bold"
              >
                {s.terms === 'monthly' ? 'Monthly' : 'Instant'}
              </Chip>
            </div>
            <div className="p-5">
              <div className="grid gap-2.5 [grid-template-columns:repeat(auto-fit,minmax(120px,1fr))]">
                <div className="rounded-[10px] bg-background px-3.5 py-3">
                  <div className="text-[11px] text-[#44474C]">Orders</div>
                  <div className="mt-0.75 text-base font-extrabold">{s.orderCount}</div>
                </div>
                <div className="rounded-[10px] bg-background px-3.5 py-3">
                  <div className="text-[11px] text-[#44474C]">Delivered</div>
                  <div className="mt-0.75 text-base font-extrabold">{s.deliveredCount}</div>
                </div>
                <div className="rounded-[10px] bg-background px-3.5 py-3">
                  <div className="text-[11px] text-[#44474C]">Total weight</div>
                  <div className="mt-0.75 text-base font-extrabold">{s.shippedKg} kg</div>
                </div>
              </div>
            </div>
          </Card>

          <Card className="p-5 rounded-[14px]">
            <div className="mb-3 text-[15px] font-bold">All orders · {s.orderCount}</div>
            <div className="flex flex-col gap-2">
              {s.orders.map((r) => (
                <Link
                  key={r.code}
                  className="flex cursor-pointer flex-wrap items-center gap-3.5 rounded-[10px] bg-background px-3.5 py-2.75 hover:bg-muted" to={`/shipments/${r.code}`}
                >
                  <div className="w-[66px] text-[13px] font-bold">{r.code}</div>
                  <div className="min-w-[130px] flex-1 text-[12.5px] text-[#44474C]">
                    {r.categories.join(', ')} · {r.description}
                  </div>
                  <div className="w-20 text-[12.5px]">
                    {r.effectiveKg > 0 ? fmtKg(r.effectiveKg) : 'devices'}{' '}
                    {r.weightDelta !== null ? <span className="text-[11px] font-bold text-danger">{deltaLabel(r.weightDelta)}</span> : null}
                  </div>
                  <StatusChip index={r.statusIndex} label={r.statusLabel} />
                  <div className="w-[70px]">
                    <Chip colors={PAY_CHIP[r.payStatus] ?? PAY_CHIP.unpaid!}>{PAY_LABEL[r.payStatus]}</Chip>
                  </div>
                  <div className="flex w-[70px] justify-end">
                    <BillFigure bill={r.billAmount} discount={r.discountAmount} className="text-right text-[13px]" />
                  </div>
                </Link>
              ))}
            </div>
          </Card>
        </div>

        <div className="flex min-w-0 w-full lg:min-w-[300px] lg:flex-1 flex-col gap-3.5">
          <Card className="overflow-hidden rounded-[14px]">
            <div className="p-4.5 pb-3">
              <div className="mb-3 text-[13px] font-bold">Account</div>
              <div className="flex flex-col gap-2.25 text-[13.5px]">
                <div className="flex justify-between">
                  <span className="text-[#44474C]">Billed (all time)</span>
                  <b>{fmtBdt(s.billed)}</b>
                </div>
                <div className="flex justify-between">
                  <span className="text-[#44474C]">Paid</span>
                  <b className="text-success">{fmtBdt(s.paid)}</b>
                </div>
                {s.discountTotal > 0 ? (
                  <div className="flex justify-between">
                    <span className="text-[#44474C]">Discounts given</span>
                    <b className="text-danger">− {fmtBdt(s.discountTotal)}</b>
                  </div>
                ) : null}
                <div className="flex justify-between">
                  <span className="text-[#44474C]">Payment terms</span>
                  <b>{s.terms === 'monthly' ? 'Monthly' : 'Instant'}</b>
                </div>
              </div>
            </div>
            <div className="flex items-center justify-between bg-ink px-4.5 py-3.5 text-white">
              <span className="text-[11.5px] font-extrabold tracking-[.08em] text-[#E3E5E8]">BALANCE DUE</span>
              <span className="text-[19px] font-extrabold" style={{ color: s.balance > 0 ? '#FF8F8F' : '#7CE79A' }}>
                {fmtBdt(s.balance)}
              </span>
            </div>
            {true ? (
              <div className="p-4.5 pt-3.5">
                <div className="mb-2 text-[11px] font-bold uppercase tracking-[.05em] text-muted-foreground">
                  Record payment · oldest bills settle first; excess becomes credit
                </div>
                <div className="flex flex-wrap items-end gap-1.5">
                  <Input className="w-28" label="Amount (৳)" placeholder={String(s.balance)} value={payAmt} onChange={setPayAmt} />
                  <Field label="Method" className="w-26">
                    <Select value={payMethod} onValueChange={setPayMethod}>
                      <SelectTrigger className="h-10 text-xs">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {(paymentAccounts?.accounts ?? []).map(a => a.name).map((m) => (
                          <SelectItem key={m} value={m}>
                            {m}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </Field>
                  <Button variant="success" disabled={payBusy} onClick={() => recordPayment(parseFloat(payAmt))}>
                    Record
                  </Button>
                </div>
                <Button
                  variant="secondary"
                  size="sm"
                  className="mt-2"
                  disabled={payBusy || s.balance <= 0}
                  onClick={() => recordPayment(s.balance)}
                >
                  Settle full {fmtBdt(s.balance)}
                </Button>
              </div>
            ) : null}
          </Card>

          {s.payments.length ? (
            <Card className="p-4.5 rounded-[14px]">
              <div className="mb-3 text-[13px] font-bold">Payments received</div>
              <div className="flex flex-col gap-1.5">
                {s.payments.map((p, i) => (
                  <div key={i} className="flex items-center justify-between gap-2 text-[12px]">
                    <span className="min-w-0 truncate text-muted-foreground">
                      {fmtLogAt(p.at)} · <b className="text-foreground">{p.code}</b> · {p.method}
                    </span>
                    <b className="shrink-0 text-success">+ {fmtBdt(p.amount)}</b>
                  </div>
                ))}
              </div>
            </Card>
          ) : null}

          <Card className="p-4.5 rounded-[14px]">
            <div className="mb-3 text-[13px] font-bold">Invoices · {s.invoices.length}</div>
            {s.invoices.length ? (
              <div className="flex flex-col gap-2">
                {s.invoices.map((inv) => (
                  <Link
                    key={inv.number}
                    className="flex cursor-pointer flex-wrap items-center gap-2.5 rounded-[10px] bg-background px-3 py-2.5 hover:bg-muted" to={`/shipments/${inv.shipmentCode}`}
                  >
                    <div className="min-w-0 flex-1">
                      <div className="text-[12.5px] font-bold">{inv.number}</div>
                      <div className="text-[11px] text-muted-foreground">
                        {inv.shipmentCode} · {fmtDate(inv.issuedAt)}
                        {inv.discount > 0 ? ` · −${fmtBdt(inv.discount)} discount` : ''}
                      </div>
                    </div>
                    <div className="text-[13px] font-extrabold">{fmtBdt(inv.total)}</div>
                  </Link>
                ))}
              </div>
            ) : (
              <div className="rounded-[10px] border border-dashed border-[#C9C6BF] p-4 text-center text-xs text-muted-foreground">
                No invoices finalized yet.
              </div>
            )}
          </Card>
        </div>
      </div>

      </>}
      <InvoiceModal open={statementOpen} onClose={() => setStatementOpen(false)} doc={statement} />
      <AddSupplierModal
        open={editOpen}
        onClose={() => setEditOpen(false)}
        editing={s}
        onDone={(newCode) => {
          if (newCode && newCode !== s.code) navigate(`/suppliers/${newCode}`, { replace: true })
          else void reload()
        }}
      />
      <ConfirmDialog
        open={deleteOpen}
        onClose={() => setDeleteOpen(false)}
        title={`Delete supplier ${s.code}?`}
        body={
          s.orderCount > 0
            ? `${s.name} still has ${s.orderCount} shipment(s) — deleting will be refused until they are removed or reassigned.`
            : `${s.name} is removed permanently.`
        }
        onConfirm={async () => {
          try {
            await api.delete(`/suppliers/${s.code}`)
            showToast({ title: `${s.code} deleted`, status: 'success' })
            navigate('/suppliers')
          } catch (e) {
            showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' })
          }
        }}
      />
    </div>
  )
}
