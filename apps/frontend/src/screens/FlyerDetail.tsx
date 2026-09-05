import { EmptyState } from '@/components/Workspace'
import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { api } from '@/api/client'
import { useFetch } from '@/state/useFetch'
import type { FlyerDetail as Detail } from '@/api/types'
import { Button } from '@/components/beui/button'
import { useToast } from '@/components/beui/toast'
import { Card, Chip, ErrorBlock, FlightCode, LoadingBlock } from '@/components/ui'
import { ConfirmDialog } from '@/components/ConfirmDialog'
import { AddFlightModal } from '@/modals/AddFlightModal'
import { AddFlyerModal } from '@/modals/AddFlyerModal'
import { fmtDate } from '@/lib/format'

function Tile({ label, value, sub }: { label: string; value: React.ReactNode; sub?: React.ReactNode }) {
  return (
    <div className="rounded-[10px] bg-background px-3.5 py-3">
      <div className="text-[11px] text-muted-foreground">{label}</div>
      <div className="mt-0.75 text-[13px] font-bold">{value}</div>
      {sub ? <div className="text-[10.5px] font-semibold text-success">{sub}</div> : null}
    </div>
  )
}

function DocPill({ label, ok }: { label: string; ok: boolean }) {
  return (
    <span
      className="rounded-full px-3 py-1.25 text-[11px] font-semibold"
      style={{ background: ok ? '#E6F7EC' : '#FDE8E8', color: ok ? '#1B7A3D' : '#C92A2A' }}
    >
      {label} {ok ? '✓' : 'missing'}
    </span>
  )
}

export function FlyerDetail() {
  const { name = '' } = useParams()
  const navigate = useNavigate()
  const { showToast } = useToast()
  const { data, error, loading, reload } = useFetch<{ flyer: Detail }>(`/flyers/${encodeURIComponent(name)}`)
  const [addingFlight, setAddingFlight] = useState(false)
  const [editOpen, setEditOpen] = useState(false)
  const [deleteOpen, setDeleteOpen] = useState(false)

  if (error) return <ErrorBlock message={error} />
  if (loading || !data) return <LoadingBlock />
  const y = data.flyer

  return (
    <div>
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2.5">
        <Link to="/flyers" className="text-[12.5px] font-semibold text-blue no-underline">
          ← Flyers
        </Link>
        <div className="flex flex-wrap gap-2">
          <Button variant="secondary" onClick={() => setEditOpen(true)}>
            Edit
          </Button>
          <Button variant="danger-outline" onClick={() => setDeleteOpen(true)}>
            Delete
          </Button>
          <Button onClick={() => setAddingFlight(true)}>+ Add flight for this flyer</Button>
        </div>
      </div>

      <div className="flex flex-wrap items-start gap-3.5">
        <div className="flex min-w-0 w-full lg:min-w-[380px] lg:flex-[1.7] flex-col gap-3.5">
          <Card className="overflow-hidden">
            <div className="flex flex-wrap items-center gap-3.5 bg-ink px-5.5 py-4 text-white">
              <div className="grid size-10 place-items-center rounded-[11px] bg-primary text-[17px] font-extrabold">{y.name.charAt(0)}</div>
              <div>
                <h1 className="m-0 break-words text-[24px] font-extrabold">{y.name}</h1>
                <div className="text-xs text-[#B9BCC1]">
                  {y.university} · {y.batch} · {y.program}
                </div>
              </div>
            </div>
            <div className="p-5.5">
              <div className="grid gap-2.5 [grid-template-columns:repeat(auto-fit,minmax(180px,1fr))]">
                <Tile label="China number" value={y.cnPhone} sub={y.cnWhatsapp ? 'WhatsApp ✓' : undefined} />
                <Tile label="BD number" value={y.bdPhone} sub={y.bdWhatsapp ? 'WhatsApp ✓' : undefined} />
                <Tile label="WeChat" value={y.wechat} />
                <Tile label="Address in China" value={y.cnAddress} />
                <Tile label="Home address (BD)" value={y.homeAddress} />
                <Tile label="Emergency contact" value={y.emergencyContact} />
              </div>
              <div className="mt-4 border-t border-dashed border-border pt-3.5">
                <div className="mb-2 text-[11px] font-bold uppercase tracking-[.05em] text-muted-foreground">Documents</div>
                <div className="flex flex-wrap gap-1.5">
                  <DocPill label="Student ID" ok={y.docStudentId} />
                  <DocPill label="Visa / Residence Permit" ok={y.docVisa} />
                  <DocPill label="Admission / JW" ok={y.docAdmission} />
                </div>
              </div>
            </div>
          </Card>

          <Card className="p-5 rounded-[14px]">
            <div className="mb-3 text-[15px] font-bold">Flights · {y.flights.length}</div>
            <div className="flex flex-col gap-2">
              {!y.flights.length && <EmptyState title="No flights yet" description="Add a flight to start this flyer’s travel and settlement history." />}
              {y.flights.map((q) => (
                <Link
                  key={q.code}
                  className="flex cursor-pointer flex-wrap items-center gap-3.5 rounded-[10px] bg-background px-3.5 py-2.75 hover:bg-muted" to={`/flights/${q.code}`}
                >
                  <div className="w-[170px] text-[13px] font-bold">
                    <FlightCode code={q.code} />
                  </div>
                  <div className="w-[84px] text-[12.5px] text-muted-foreground">{fmtDate(q.date)}</div>
                  <div className="min-w-[120px] flex-1 text-[12.5px] text-muted-foreground">
                    {q.bookedKg} kg of {q.spaceKg} kg + {q.mobiles} mob + {q.laptops} laptop
                  </div>
                  <Chip
                    colors={q.status === 'upcoming' ? { bg: '#E7F0FE', fg: '#0E4DA4' } : { bg: '#F3F2EE', fg: '#5B5E63' }}
                  >
                    {q.statusLabel}
                  </Chip>
                </Link>
              ))}
            </div>
          </Card>
        </div>

        <div className="flex min-w-0 w-full lg:min-w-[300px] lg:flex-1 flex-col gap-3.5">
          <Card className="overflow-hidden rounded-[14px]">
            <div className="p-4.5 pb-3">
              <div className="mb-3 text-[13px] font-bold">Flyer stats</div>
              <div className="flex flex-col gap-2.25 text-[13.5px]">
                <div className="flex justify-between">
                  <span className="text-[#44474C]">Flights flown</span>
                  <b>{y.flights.length}</b>
                </div>
                <div className="flex justify-between">
                  <span className="text-[#44474C]">Cargo carried</span>
                  <b>{y.totalKg} kg</b>
                </div>
                <div className="flex justify-between">
                  <span className="text-[#44474C]">Allowance per flight</span>
                  <b>
                    {(() => {
                      const ref = y.nextFlight ?? y.lastFlight
                      return ref ? `${ref.spaceKg} kg + ${ref.mobiles} mob + ${ref.laptops} laptop` : '—'
                    })()}
                  </b>
                </div>
              </div>
            </div>
            <div className="bg-primary px-4.5 py-3.5 text-white">
              <div className="text-[11.5px] font-extrabold tracking-[.08em]">NEXT FLIGHT</div>
              <div className="mt-1.5 flex items-baseline justify-between">
                <span className="break-all text-[19px] font-extrabold">{y.nextFlight?.code ?? '—'}</span>
                <span className="text-[13px] font-bold">{y.nextFlight ? fmtDate(y.nextFlight.date) : 'none scheduled'}</span>
              </div>
              {y.nextFlight ? (
                <>
                  <div className="mt-1 text-[12.5px]">
                    {y.nextFlight.depTime} CTU → DAC {y.nextFlight.arrTime}
                  </div>
                  <div className="mt-1 flex justify-between text-[12.5px]">
                    <span className="font-extrabold">{y.nextFlight.statusLabel}</span>
                    <span>{y.nextFlight.bookedKg} kg booked</span>
                  </div>
                </>
              ) : null}
            </div>
            <div className="bg-ink px-4.5 py-3.5 text-white">
              <div className="text-[11.5px] font-extrabold tracking-[.08em] text-[#E3E5E8]">LAST FLIGHT</div>
              <div className="mt-1.5 flex items-baseline justify-between">
                <span className="break-all text-[19px] font-extrabold">{y.lastFlight?.code ?? '—'}</span>
                <span className="text-[13px] font-bold text-[#E3E5E8]">{y.lastFlight ? fmtDate(y.lastFlight.date) : 'none yet'}</span>
              </div>
              {y.lastFlight ? (
                <>
                  <div className="mt-1 text-[12.5px] text-[#E3E5E8]">
                    {y.lastFlight.depTime} CTU → DAC {y.lastFlight.arrTime}
                  </div>
                  <div className="mt-1 flex justify-between text-[12.5px]">
                    <span className="font-extrabold text-[#7CE79A]">{y.lastFlight.statusLabel}</span>
                    <span className="text-[#E3E5E8]">{y.lastFlight.bookedKg} kg carried</span>
                  </div>
                </>
              ) : null}
            </div>
          </Card>
        </div>
      </div>

      <AddFlightModal open={addingFlight} onClose={() => setAddingFlight(false)} onDone={() => void reload()} lockedFlyer={y.name} />
      <AddFlyerModal
        open={editOpen}
        onClose={() => setEditOpen(false)}
        editing={y}
        onDone={(newName) => {
          if (newName !== y.name) navigate(`/flyers/${encodeURIComponent(newName)}`, { replace: true })
          else void reload()
        }}
      />
      <ConfirmDialog
        open={deleteOpen}
        onClose={() => setDeleteOpen(false)}
        title={`Delete flyer ${y.name}?`}
        body="The flyer and their flight assignments are removed permanently. Flights themselves stay."
        onConfirm={async () => {
          try {
            await api.delete(`/flyers/${encodeURIComponent(y.name)}`)
            showToast({ title: `${y.name} deleted`, status: 'success' })
            navigate('/flyers')
          } catch (e) {
            showToast({ title: e instanceof Error ? e.message : 'Failed', status: 'error' })
          }
        }}
      />
    </div>
  )
}
