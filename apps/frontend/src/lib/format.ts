/** Formatting helpers and the design's chip color maps. */

export const fmtBdt = (n: number): string => `৳${Math.round(n || 0).toLocaleString('en-IN')}`

export const fmtKg = (n: number): string => `${Math.round(n * 10) / 10} kg`

/** '2026-08-31' → '31 Aug 2026'. */
export function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '—'
  return new Date(`${iso.slice(0, 10)}T00:00:00Z`).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    timeZone: 'UTC',
  })
}

/** '2026-08-31' → '31 Aug'. */
export function fmtDayMonth(iso: string | null | undefined): string {
  if (!iso) return '—'
  return new Date(`${iso.slice(0, 10)}T00:00:00Z`).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'short',
    timeZone: 'UTC',
  })
}

/** ISO timestamp → '24 Aug 14:05'. */
export function fmtLogAt(iso: string): string {
  const d = new Date(iso)
  return `${d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', timeZone: 'UTC' })} ${d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'UTC' })}`
}

export const deltaLabel = (delta: number | null): string =>
  delta === null ? '' : `Δ${delta > 0 ? '+' : ''}${delta}kg`

export type ChipColors = { bg: string; fg: string }

/** Pipeline status chips, keyed by status index 0–8 (design CHIP map). */
export const STATUS_CHIP: ChipColors[] = [
  { bg: '#F3F2EE', fg: '#5B5E63' },
  { bg: '#FFF4DE', fg: '#8A6D1C' },
  { bg: '#EDE9FE', fg: '#6D28D9' },
  { bg: '#E7F0FE', fg: '#0E4DA4' },
  { bg: '#DCFCE7', fg: '#166534' },
  { bg: '#E0F2F1', fg: '#0F766E' },
  { bg: '#E3F0EE', fg: '#0F766E' },
  { bg: '#FEF3C7', fg: '#B45309' },
  { bg: '#E6F7EC', fg: '#1B7A3D' },
]

export const PAY_CHIP: Record<string, ChipColors> = {
  paid: { bg: '#E6F7EC', fg: '#1B7A3D' },
  unpaid: { bg: '#FDE8E8', fg: '#C92A2A' },
  cod: { bg: '#FEF3C7', fg: '#B45309' },
  monthly: { bg: '#E7F0FE', fg: '#0E4DA4' },
  partial: { bg: '#FFF4DE', fg: '#8A6D1C' },
}

export const PAY_LABEL: Record<string, string> = {
  paid: 'Paid',
  unpaid: 'Unpaid',
  cod: 'COD',
  monthly: 'Monthly',
  partial: 'Partial',
}

export const FLIGHT_CHIP: Record<string, ChipColors> = {
  upcoming: { bg: '#E7F0FE', fg: '#0E4DA4' },
  departed: { bg: '#FEF3C7', fg: '#B45309' },
  completed: { bg: '#F3F2EE', fg: '#5B5E63' },
}

export const NOTICE_STYLE: Record<string, { bg: string; bd: string; fg: string }> = {
  WEIGHT: { bg: '#FDE8E8', bd: '#F1C4C4', fg: '#C92A2A' },
  FLIGHT: { bg: '#E7F0FE', bd: '#C4D8F5', fg: '#0E4DA4' },
  DUE: { bg: '#FFF4DE', bd: '#EED9A4', fg: '#8A6D1C' },
}

/** Composes the supplier label the current role is allowed to see. */
export const supplierLabel = (code: string, name: string | null): string =>
  name ? `${code} · ${name}` : code
