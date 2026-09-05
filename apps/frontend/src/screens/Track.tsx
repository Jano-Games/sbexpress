import { InvoicePdfActions } from '@/components/InvoicePdfActions'
import { ShipmentMedia } from '@/components/ShipmentMedia'
import { useState, type ReactNode } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Copy } from 'lucide-react'
import { motion, useReducedMotion } from 'motion/react'
import { api } from '@/api/client'
import { useFetch } from '@/state/useFetch'
import { useAuth } from '@/state/auth'
import type { TrackInfo } from '@/api/types'
import { Button } from '@/components/beui/button'
import { useToast } from '@/components/beui/toast'
import { Card, CONDENSED_STEPS, ErrorBlock, FlightCode, LoadingBlock, QrBlock, SbMark } from '@/components/ui'
import { fmtBdt, fmtDate, fmtLogAt } from '@/lib/format'

/** Condensed journey rail: filled connectors and a pulse on the current stop. */
function TrackSteps({ current }: { current: number }) {
  const reduce = useReducedMotion()
  const reached = (i: number) => current >= (CONDENSED_STEPS[i]?.minIndex ?? 99)
  return (
    <div className="flex items-start">
      {CONDENSED_STEPS.map((s, i) => {
        const done = reached(i)
        const isCurrent = done && (i === CONDENSED_STEPS.length - 1 ? current >= 8 : !reached(i + 1))
        return (
          <div key={s.label} className="flex flex-1 flex-col items-center gap-1.5">
            <div className="flex w-full items-center">
              <div className="h-0.5 flex-1" style={{ background: i === 0 ? 'transparent' : done ? '#0F766E' : '#E7E5E0' }} />
              <div className="relative">
                {isCurrent && !reduce ? (
                  <motion.span
                    aria-hidden
                    className="absolute inset-0 rounded-full bg-primary"
                    animate={{ scale: [1, 2.1], opacity: [0.4, 0] }}
                    transition={{ duration: 1.8, repeat: Infinity, ease: 'easeOut' }}
                  />
                ) : null}
                <div
                  className="relative grid size-4 place-items-center rounded-full text-[9px] font-extrabold text-white"
                  style={{ background: done ? '#0F766E' : '#E7E5E0' }}
                >
                  {done && !isCurrent ? '✓' : ''}
                </div>
              </div>
              <div
                className="h-0.5 flex-1"
                style={{ background: i === CONDENSED_STEPS.length - 1 ? 'transparent' : reached(i + 1) ? '#0F766E' : '#E7E5E0' }}
              />
            </div>
            <div
              className="px-1 text-center text-[10px] leading-tight"
              style={{ color: isCurrent ? '#0F766E' : done ? '#1A1C1E' : '#9B9EA3', fontWeight: isCurrent ? 800 : 600 }}
            >
              {s.label}
            </div>
          </div>
        )
      })}
    </div>
  )
}

function PayStat({
  label,
  value,
  original,
  sub,
  tone,
}: {
  label: string
  value: number
  /** Pre-discount amount, shown struck through beside the real one. */
  original?: number
  sub?: string
  tone?: 'success' | 'danger'
}) {
  return (
    <div className="rounded-[10px] bg-background px-3 py-2.5 text-center">
      <div className="text-[10px] font-bold uppercase tracking-[.06em] text-muted-foreground">{label}</div>
      <div className="mt-0.5 flex flex-wrap items-baseline justify-center gap-1.5">
        {original !== undefined && original > value ? (
          <span className="text-[12px] font-semibold text-faint line-through">{fmtBdt(original)}</span>
        ) : null}
        <span
          className="whitespace-nowrap text-[16px] font-extrabold"
          style={{ color: tone === 'success' ? '#1B7A3D' : tone === 'danger' ? '#C92A2A' : '#1A1C1E' }}
        >
          {fmtBdt(value)}
        </span>
      </div>
      {sub ? <div className="mt-px text-[10.5px] font-bold text-success">{sub}</div> : null}
    </div>
  )
}

function InfoTile({ label, children, sub }: { label: string; children: ReactNode; sub?: ReactNode }) {
  return (
    <div className="min-w-0 rounded-[10px] bg-background px-3.5 py-3">
      <div className="text-[10px] font-bold uppercase tracking-[.06em] text-muted-foreground">{label}</div>
      <div className="mt-0.75 text-[13px] font-bold">{children}</div>
      {sub ? <div className="mt-px text-[11px] text-muted-foreground">{sub}</div> : null}
    </div>
  )
}

/** Public tracking page — reached from a shared link, no login required. */
export function Track() {
  const { token = '' } = useParams()
  const navigate = useNavigate()
  const { user } = useAuth()
  const { showToast } = useToast()
  const { data, error, loading, reload } = useFetch<{ shipment: TrackInfo }>(`/track/${token}`)
  const [methodId, setMethodId] = useState('')
  const [busy, setBusy] = useState(false)
  const [amount, setAmount] = useState('')
  const [txnRef, setTxnRef] = useState('')
  const reduce = useReducedMotion()

  // Methods are configured in settings, so the picked one must fall back to
  // the first available rather than assuming any particular rail exists.
  const methods = data?.shipment.payMethods ?? []
  const active = methods.find((m) => m.id === methodId) ?? methods[0] ?? null

  const copy = (value: string, what: string) =>
    void navigator.clipboard
      .writeText(value)
      .then(() => showToast({ title: `${what} copied`, status: 'success' }))
      .catch(() => showToast({ title: 'Copy failed', status: 'error' }))

  const upload = async () => {
    if (!active) return
    setBusy(true)
    try {
      await api.post(`/track/${token}/receipt`, { methodId: active.id, amount: Number(amount || data?.shipment.requestedAmount), txnRef: txnRef.trim() })
      showToast({ title: 'Payment submitted — pending confirmation', status: 'success' })
      await reload()
    } catch (e) {
      showToast({ title: e instanceof Error ? e.message : 'Upload failed', status: 'error' })
    } finally {
      setBusy(false)
    }
  }

  const appear = (order: number) =>
    reduce
      ? {}
      : {
          initial: { opacity: 0, y: 10 },
          animate: { opacity: 1, y: 0 },
          transition: { duration: 0.35, delay: order * 0.07 },
        }

  return (
    <div className="min-h-screen bg-background">
      <div className="flex flex-wrap items-center gap-2.5 bg-ink px-5.5 py-3.5 text-white">
        <SbMark />
        <div className="text-sm font-extrabold">Sichuan Bangla Express</div>
        <div className="ml-auto text-[11.5px] text-[#E3E5E8]">Shipment tracking</div>
        {user ? (
          <button
            type="button"
            className="ml-3.5 cursor-pointer border-0 bg-transparent text-xs font-bold text-[#7CC4FF]"
            onClick={() => navigate(`/shipments/${data?.shipment.code ?? ''}`)}
          >
            ← Back to app
          </button>
        ) : null}
      </div>

      <div className="mx-auto flex max-w-[680px] flex-col gap-3.5 px-4.5 py-6.5">
        {error ? (
          <Card className="p-6"><h1 className="text-xl font-bold">Tracking unavailable</h1><p className="mt-2 text-sm text-muted-foreground">This link may have expired or been revoked. Please contact your shipping agency for a fresh link.</p><ErrorBlock message={error} /></Card>
        ) : loading || !data ? (
          <LoadingBlock />
        ) : (
          <>
            <motion.div {...appear(0)}>
              <Card className="overflow-hidden">
                <div className="flex flex-wrap items-center gap-3 bg-primary px-5 py-4 text-white">
                  <div>
                    <div className="text-[11px] font-extrabold tracking-[.08em] text-[#CDE7E3]">TRACKING</div>
                    <h1 className="mt-0.5 break-all text-[24px] font-extrabold">{data.shipment.code}</h1>
                  </div>
                  <div className="ml-auto text-right">
                    <span className="rounded-full bg-white px-3.5 py-1.5 text-xs font-extrabold text-primary">
                      {data.shipment.statusLabel}
                    </span>
                    <div className="mt-1.5 text-[11px] font-semibold text-[#CDE7E3]">{data.shipment.routeLabel}</div>
                  </div>
                </div>
                <div className="p-5">
                  <TrackSteps current={data.shipment.statusIndex} />
                  <div className="mt-4.5 grid gap-2 [grid-template-columns:repeat(auto-fit,minmax(140px,1fr))]">
                    <InfoTile label="Contents">{data.shipment.contents}</InfoTile>
                    <InfoTile label="Weight">{data.shipment.kgLabel}</InfoTile>
                    <InfoTile label="Flight" sub={data.shipment.flightDate ? fmtDate(data.shipment.flightDate) : undefined}>
                      <FlightCode code={data.shipment.flightCode} />
                    </InfoTile>
                    <InfoTile
                      label="Route"
                      sub={
                        data.shipment.depTime
                          ? `${data.shipment.depTime} → ${data.shipment.arrTime ?? '—'}${data.shipment.via ? ` · ${data.shipment.via}` : ''}`
                          : (data.shipment.via ?? undefined)
                      }
                    >
                      {data.shipment.routeLabel}
                    </InfoTile>
                  </div>
                  <div className="mt-3.5 flex flex-wrap items-center justify-between gap-2 border-t border-muted pt-3">
                    <div className="text-[12.5px] font-semibold text-[#44474C]">{data.shipment.note}</div>
                    <div className="text-[11px] text-faint">Updated {fmtLogAt(data.shipment.updatedAt)}</div>
                  </div>
                </div>
              </Card>
            </motion.div>

            <ShipmentMedia token={token} />
            <Card className="overflow-hidden">
              <div className="border-b border-border px-5 py-4">
                <h2 className="text-base font-bold">Bill breakdown</h2>
                <div className="mt-3"><InvoicePdfActions path={`/track/${encodeURIComponent(token??'')}/invoice.pdf`} filename={`invoice-${data.shipment.code}.pdf`} /></div>
                <p className="mt-1 text-xs text-muted-foreground">{data.shipment.invoiceNumber ?? data.shipment.code} · All amounts in BDT</p>
              </div>
              <div className="px-5 py-3">
                {data.shipment.billLines.map((line,i)=><div key={i} className="flex items-start justify-between gap-5 border-b border-border py-3 text-sm last:border-0"><span className="min-w-0 break-words">{line.label}</span><b className={`shrink-0 tabular-nums ${line.amount<0?'text-success':''}`}>{fmtBdt(line.amount)}</b></div>)}
                <div className="mt-2 space-y-3 border-t border-border pt-4 text-sm">
                  <div className="flex justify-between gap-3"><span>Subtotal</span><b>{fmtBdt(data.shipment.billSubtotal)}</b></div>
                  {data.shipment.discount>0&&<div className="flex justify-between gap-3 text-success"><span>Discount / credit</span><b>− {fmtBdt(data.shipment.discount)}</b></div>}
                  <div className="flex justify-between gap-3 text-base font-bold"><span>Total bill</span><span>{fmtBdt(data.shipment.totalBill)}</span></div>
                  <div className="flex justify-between gap-3 text-success"><span>Verified paid amount</span><b>− {fmtBdt(data.shipment.paidSoFar)}</b></div>
                </div>
              </div>
              <div className="m-5 mt-2 flex justify-between gap-3 rounded-xl bg-primary-soft p-4 font-bold"><span>Amount due</span><span>{fmtBdt(data.shipment.due)}</span></div>
              {data.shipment.requestedAmount>0&&data.shipment.requestedAmount<data.shipment.due&&<p className="px-5 pb-4 text-sm">This link requests a partial payment of <b>{fmtBdt(data.shipment.requestedAmount)}</b>.</p>}
              {data.shipment.showPending&&<p className="px-5 pb-4 text-xs text-muted-foreground">Your submitted payment is awaiting verification and has not been deducted above.</p>}
              {data.shipment.invoice&&<div className="px-5 pb-4 text-xs text-muted-foreground"><p>{data.shipment.invoice.note}</p><button className="mt-2 font-semibold text-primary underline" onClick={()=>window.print()}>Print invoice</button></div>}
            </Card>
            {data.shipment.showPay ? (
              <motion.div {...appear(1)}>
                <Card className="overflow-hidden">
                  <div className="px-5 pb-3.5 pt-4">
                    <div className="mb-2.5 text-sm font-extrabold">Payment</div>
                    <div className="grid grid-cols-2 gap-2 [&>div:last-child]:col-span-2 sm:grid-cols-3 sm:[&>div:last-child]:col-span-1">
                      <PayStat
                        label="Total bill"
                        value={data.shipment.totalBill}
                        original={data.shipment.discount > 0 ? data.shipment.totalBill + data.shipment.discount : undefined}
                        sub={data.shipment.discount > 0 ? `You saved ${fmtBdt(data.shipment.discount)}` : undefined}
                      />
                      <PayStat label="Paid" value={data.shipment.paidSoFar} tone="success" />
                      <PayStat label="Amount due" value={data.shipment.due} tone="danger" />
                    </div>
                  </div>
                  <div className="px-5 pb-4.5">
                    {!methods.length ? (
                      <div className="rounded-[10px] border border-dashed border-[#C9C6BF] px-4 py-5 text-center text-[12.5px] text-muted-foreground">
                        Payment account details will appear here shortly. Need to pay now? Message us on{' '}
                        <a href="https://wa.me/8801711220340" target="_blank" rel="noreferrer" className="font-bold text-success no-underline hover:underline">
                          WhatsApp
                        </a>
                        .
                      </div>
                    ) : null}
                    <div className="flex gap-1.5">
                      {methods.map((m) => {
                        const isActive = m.id === active?.id
                        return (
                          <button
                            key={m.id}
                            type="button"
                            className="flex-1 cursor-pointer rounded-[9px] border px-1 py-2.5 text-center text-[12.5px] font-bold transition-colors"
                            style={{
                              background: isActive ? '#1A1C1E' : '#fff',
                              color: isActive ? '#fff' : '#5B5E63',
                              borderColor: isActive ? '#1A1C1E' : '#E7E5E0',
                            }}
                            onClick={() => setMethodId(m.id)}
                          >
                            {m.name}
                          </button>
                        )
                      })}
                    </div>
                    {active ? (
                      active.kind === 'mobile_banking' ? (
                        <div className="mt-3.5 flex items-center gap-4">
                          {active.qrImage ? (
                            <img
                              src={active.qrImage}
                              alt={`${active.name} QR`}
                              className="size-[110px] shrink-0 rounded-xl border border-border bg-white object-contain p-1.5"
                            />
                          ) : (
                            <QrBlock value={active.number} size={110} />
                          )}
                          <div className="min-w-0 flex-1 text-[12.5px] leading-relaxed text-[#44474C]">
                            <div className="text-[10.5px] font-bold uppercase tracking-[.05em] text-muted-foreground">
                              {active.provider}
                              {active.label && !active.label.toLowerCase().includes(active.provider.toLowerCase())
                                ? ` · ${active.label}`
                                : ''}
                            </div>
                            <div className="mt-0.5 flex items-center gap-2">
                              <span className="break-all text-[19px] font-extrabold tracking-wide text-foreground">{active.number}</span>
                              <button
                                type="button"
                                title="Copy number"
                                className="grid size-7 shrink-0 cursor-pointer place-items-center rounded-md border border-border bg-card text-muted-foreground hover:bg-muted hover:text-foreground"
                                onClick={() => copy(active.number, 'Number')}
                              >
                                <Copy className="size-3.5" />
                              </button>
                            </div>
                            {active.note ? <div className="mt-1">{active.note}</div> : null}
                          </div>
                        </div>
                      ) : (
                        <div className="mt-3.5 grid gap-x-6 gap-y-1.5 text-[12.5px] [grid-template-columns:auto_1fr]">
                          <span className="text-muted-foreground">Account name</span>
                          <b>{active.accountName}</b>
                          <span className="text-muted-foreground">Account number</span>
                          <span className="flex items-center gap-2 font-extrabold">
                            {active.accountNumber}
                            <button
                              type="button"
                              title="Copy account number"
                              className="grid size-6 shrink-0 cursor-pointer place-items-center rounded-md border border-border bg-card text-muted-foreground hover:bg-muted hover:text-foreground"
                              onClick={() => copy(active.accountNumber, 'Account number')}
                            >
                              <Copy className="size-3" />
                            </button>
                          </span>
                          <span className="text-muted-foreground">Bank</span>
                          <b>
                            {active.bankName}
                            {active.branch ? ` · ${active.branch} branch` : ''}
                          </b>
                          {active.district ? (
                            <>
                              <span className="text-muted-foreground">District</span>
                              <b>{active.district}</b>
                            </>
                          ) : null}
                        </div>
                      )
                    ) : null}
                    {active ? (
                      <div className="mt-3.5 border-t border-muted pt-3">
                        <div className="mb-2 text-xs text-muted-foreground">
                          After paying, enter the amount and your transaction reference. Our team verifies the transfer before crediting your balance.
                        </div>
                        <label className="block mb-2 text-sm">Amount paid (BDT)
                          <input type="number" min="0.01" step="0.01" max={data.shipment.requestedAmount} className="block w-full rounded border p-2" value={amount} placeholder={String(data.shipment.requestedAmount)} onChange={e => setAmount(e.target.value)} />
                        </label>
                        <label className="block mb-3 text-sm">Transaction reference
                          <input className="block w-full rounded border p-2" maxLength={100} value={txnRef} onChange={e => setTxnRef(e.target.value)} />
                        </label>
                        <Button size="lg" className="w-full" disabled={busy || txnRef.trim().length < 3} onClick={() => void upload()}>
                          Submit payment for verification
                        </Button>
                      </div>
                    ) : null}
                  </div>
                </Card>
              </motion.div>
            ) : null}

            {data.shipment.showPaid ? (
              <motion.div {...appear(1)}>
                <div className="rounded-[14px] border border-[#BBE5C8] bg-success-soft px-5 py-4 text-[13px] font-bold text-success">
                  ✓ Payment received — thank you.
                </div>
              </motion.div>
            ) : null}
            {data.shipment.showPending ? (
              <motion.div {...appear(1)}>
                <div className="rounded-[14px] border border-[#EED9A4] bg-warn-soft px-5 py-4 text-[13px] font-bold text-warn">
                  Payment verification pending. Only the verified amount will be credited.
                </div>
              </motion.div>
            ) : null}

            <motion.div {...appear(2)} className="text-center text-[11.5px] text-muted-foreground">
              Sichuan Bangla Express · Bashundhara R/A, Dhaka · Questions?{' '}
              <a
                href="https://wa.me/8801711220340"
                target="_blank"
                rel="noreferrer"
                className="font-bold text-success no-underline hover:underline"
              >
                WhatsApp +880 1711 220 340
              </a>
            </motion.div>
          </>
        )}
      </div>
    </div>
  )
}
