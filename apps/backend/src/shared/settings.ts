import { prisma } from '../core/db'

export interface AppSettings {
  /** ৳ per ¥1. */
  rate: number
  /** Weight-discrepancy alert threshold in kg. */
  threshold: number
  investBdt: number
  investCny: number
  /** Default per-piece shipping rates by category, BDT (Mobile, Laptop, Drone …). */
  pcsRates: Record<string, number>
}

const DEFAULTS: AppSettings = { rate: 17.05, threshold: 1, investBdt: 0, investCny: 0, pcsRates: {} }

export async function getSettings(): Promise<AppSettings> {
  const rows = await prisma.setting.findMany()
  const map = new Map(rows.map((r) => [r.key, r.value]))
  const numFrom = (key: 'rate' | 'threshold' | 'investBdt' | 'investCny') => {
    const raw = map.get(key)
    const parsed = raw === undefined ? NaN : Number(raw)
    return Number.isFinite(parsed) ? parsed : DEFAULTS[key]
  }
  let pcsRates: Record<string, number> = {}
  try {
    const parsed: unknown = JSON.parse(map.get('pcsRates') ?? '{}')
    if (parsed && typeof parsed === 'object') {
      pcsRates = Object.fromEntries(
        Object.entries(parsed as Record<string, unknown>).filter(([, v]) => typeof v === 'number' && v >= 0),
      ) as Record<string, number>
    }
  } catch {
    // Malformed JSON — fall back to no rates rather than failing every read.
  }
  return {
    rate: numFrom('rate'),
    threshold: numFrom('threshold'),
    investBdt: numFrom('investBdt'),
    investCny: numFrom('investCny'),
    pcsRates,
  }
}

export async function putSetting(key: 'rate' | 'threshold' | 'investBdt' | 'investCny', value: number): Promise<void> {
  await putRaw(key, String(value))
}

export async function putPcsRates(rates: Record<string, number>): Promise<void> {
  await putRaw('pcsRates', JSON.stringify(rates))
}

async function putRaw(key: string, value: string): Promise<void> {
  await prisma.setting.upsert({
    where: { key },
    update: { value },
    create: { key, value },
  })
}
