import type { CSSProperties, ReactNode } from 'react'
import { QRCodeSVG } from 'qrcode.react'
import { cn } from '@/lib/utils'
import { fmtBdt, NOTICE_STYLE, STATUS_CHIP, type ChipColors } from '@/lib/format'
import type { Notice } from '@/api/types'

export function Chip({ colors, children, className }: { colors: ChipColors; children: ReactNode; className?: string }) {
  return (
    <span
      className={cn('inline-block rounded-full px-2.5 py-[3px] text-[11px] font-semibold whitespace-nowrap', className)}
      style={{ background: colors.bg, color: colors.fg }}
    >
      {children}
    </span>
  )
}

export function StatusChip({ index, label, className }: { index: number; label: string; className?: string }) {
  return (
    <Chip colors={STATUS_CHIP[Math.max(0, Math.min(8, index))]!} className={className}>
      {label}
    </Chip>
  )
}

export function Card({
  children,
  className,
  style,
  onClick,
}: {
  children: ReactNode
  className?: string
  style?: CSSProperties
  onClick?: () => void
}) {
  return (
    <div className={cn('min-w-0 rounded-2xl border border-border bg-card', className)} style={style} onClick={onClick} role={onClick ? 'button' : undefined} tabIndex={onClick ? 0 : undefined} onKeyDown={e=>{if(onClick && e.target===e.currentTarget && (e.key==='Enter'||e.key===' ')){e.preventDefault();onClick()}}}>
      {children}
    </div>
  )
}

export function PageTitle({ children, actions }: { children: ReactNode; actions?: ReactNode }) {
  return (
    <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
      <h1 className="m-0 text-[23px] font-extrabold">{children}</h1>
      {actions}
    </div>
  )
}

/** A shipment's bill with the invoice discount called out beneath it. */
export function BillFigure({ bill, discount, className }: { bill: number; discount: number; className?: string }) {
  return (
    <div className={cn('font-bold leading-tight', className)}>
      <div>{fmtBdt(bill)}</div>
      {discount > 0 ? <div className="text-[10px] font-bold text-danger">−{fmtBdt(discount)} disc</div> : null}
    </div>
  )
}

/** Label-on-top wrapper for controls that don't carry their own label prop. */
export function Field({ label, children, className }: { label: string; children: ReactNode; className?: string }) {
  return (
    <div role="group" aria-label={label} className={cn('flex min-w-0 flex-col gap-1.5', className)}>
      <div className="text-[12px] text-muted-foreground">{label}</div>
      {children}
    </div>
  )
}

/** Itinerary codes ("CZ3444+CZ391") render one segment per line, no "+". */
export function FlightCode({ code, className }: { code: string | null | undefined; className?: string }) {
  if (!code) return <span className={className}>—</span>
  return (
    <span className={cn('leading-tight', className)}>
      {code.split('+').map((part, i) => (
        <span key={`${part}-${i}`} className="block">
          {part}
        </span>
      ))}
    </span>
  )
}

export function SbMark({ size = 32 }: { size?: number }) {
  return (
    <div
      className="grid shrink-0 place-items-center rounded-lg bg-primary font-extrabold text-white"
      style={{ width: size, height: size, fontSize: size * 0.4 }}
    >
      SB
    </div>
  )
}

export function ProgressBar({
  pct,
  danger,
  className,
  height = 6,
}: {
  pct: number
  danger?: boolean
  className?: string
  height?: number
}) {
  const clamped = Math.max(0, Math.min(100, pct))
  return (
    <div className={cn('rounded-full bg-[#EBE9E4]', className)} style={{ height }}>
      <div
        className="rounded-full transition-[width] duration-500"
        style={{ width: `${clamped}%`, height, background: danger ? '#C92A2A' : '#0F766E' }}
      />
    </div>
  )
}

export function KpiTile({
  label,
  value,
  sub,
  valueClassName,
  onClick,
  children,
}: {
  label: string
  value: ReactNode
  sub?: ReactNode
  valueClassName?: string
  onClick?: () => void
  children?: ReactNode
}) {
  return (
    <div
      className={cn('rounded-[10px] bg-background px-4 py-3.5', onClick && 'cursor-pointer hover:bg-muted')}
      onClick={onClick}
      role={onClick?'button':undefined}
      tabIndex={onClick?0:undefined}
      onKeyDown={e=>{if(onClick&&(e.key==='Enter'||e.key===' ')){e.preventDefault();onClick()}}}
    >
      <div className="text-[11px] text-[#44474C]">{label}</div>
      <div className={cn('mt-1 text-xl font-extrabold', valueClassName)}>{value}</div>
      {sub ? <div className="mt-0.5 text-[11.5px] text-[#44474C]">{sub}</div> : null}
      {children}
    </div>
  )
}

export function NoticeList({ notices }: { notices: Notice[] }) {
  if (!notices.length) return null
  return (
    <div className="mt-4 flex flex-col gap-2">
      {notices.map((n, i) => {
        const s = NOTICE_STYLE[n.tag] ?? NOTICE_STYLE.FLIGHT!
        return (
          <div
            key={i}
            className="flex items-center gap-2.5 rounded-[10px] border px-3.5 py-2.5 text-[12.5px]"
            style={{ background: s.bg, borderColor: s.bd }}
          >
            <span className="font-extrabold" style={{ color: s.fg }}>
              {n.tag}
            </span>
            <span className="text-foreground">{n.text}</span>
          </div>
        )
      })}
    </div>
  )
}

/** The decorative QR placeholder used on payment panels. */
export function QrBlock({ value, size = 104 }: { value: string; size?: number }) {
  return (
    <div
      className="grid shrink-0 place-items-center rounded-xl border border-border bg-card p-2"
      style={{ width: size, height: size }}
    >
      <QRCodeSVG value={value} size={size - 20} fgColor="#1A1C1E" bgColor="#ffffff" />
    </div>
  )
}

/** 9-step progress rail on the shipment detail header. */
export function Stepper({ steps, current }: { steps: string[]; current: number }) {
  return (
    <div className="overflow-x-auto"><div className="flex min-w-[620px] px-5 py-4">
      {steps.map((label, i) => {
        const donePast = current > i
        const active = current === i
        return (
          <div key={label} className="flex min-w-0 flex-1 flex-col items-center gap-1.5">
            <div className="flex w-full items-center">
              <div className="h-0.5 flex-1" style={{ background: i === 0 ? 'transparent' : current >= i ? '#0F766E' : '#E7E5E0' }} />
              <div
                className="grid size-6 shrink-0 place-items-center rounded-full border-2 text-[11px] font-extrabold"
                style={{
                  background: donePast ? '#0F766E' : active ? '#fff' : '#F3F2EE',
                  borderColor: current >= i ? '#0F766E' : '#E7E5E0',
                  color: donePast ? '#fff' : active ? '#0F766E' : '#9B9EA3',
                }}
              >
                {donePast ? '✓' : i + 1}
              </div>
              <div
                className="h-0.5 flex-1"
                style={{ background: i === steps.length - 1 ? 'transparent' : current > i ? '#0F766E' : '#E7E5E0' }}
              />
            </div>
            <div
              className="px-0.5 text-center text-[10px] leading-tight"
              style={{ color: active ? '#0F766E' : donePast ? '#1A1C1E' : '#9B9EA3', fontWeight: active ? 800 : 500 }}
            >
              {label}
            </div>
          </div>
        )
      })}
    </div></div>
  )
}

/** Condensed dot rail used on tracking cards. */
export function DotSteps({ steps, size = 12 }: { steps: { label: string; done: boolean }[]; size?: number }) {
  return (
    <div className="flex items-center">
      {steps.map((s) => (
        <div key={s.label} className="flex flex-1 flex-col items-center gap-1.5">
          <div className="rounded-full" style={{ width: size, height: size, background: s.done ? '#0F766E' : '#E7E5E0' }} />
          <div className="text-center text-[9.5px] font-semibold" style={{ color: s.done ? '#1A1C1E' : '#9B9EA3' }}>
            {s.label}
          </div>
        </div>
      ))}
    </div>
  )
}

export const CONDENSED_STEPS: { minIndex: number; label: string }[] = [
  { minIndex: 0, label: 'Booked' },
  { minIndex: 1, label: 'CN Hub' },
  { minIndex: 3, label: 'In Transit' },
  { minIndex: 5, label: 'BD Hub' },
  { minIndex: 8, label: 'Delivered' },
]

export const PIPELINE_LABELS = [
  'Pending',
  'Received at CN Hub',
  'Ready for Shipment',
  'In Transit',
  'Customs Cleared',
  'Received at BD Hub',
  'Ready for Last Mile',
  'Out for Delivery',
  'Delivered',
]

export function LoadingBlock({ label = 'Loading…' }: { label?: string }) {
  return <div className="rounded-2xl border border-dashed border-[#C9C6BF] p-10 text-center text-[13px] text-muted-foreground">{label}</div>
}

export function ErrorBlock({ message }: { message: string }) {
  return (
    <div className="rounded-2xl border border-[#F1C4C4] bg-danger-soft p-6 text-center text-[13px] font-semibold text-danger">
      {message}
    </div>
  )
}
