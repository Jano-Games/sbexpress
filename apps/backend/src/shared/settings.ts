import { prisma } from '../core/db'

export interface AppSettings {
  /** ৳ per ¥1. */
  rate: number
  exchangeRates: Record<'BDT' | 'CNY', number>
  /** Weight-discrepancy alert threshold in kg. */
  threshold: number
  investBdt: number
  investCny: number
  /** Default per-piece shipping rates by category, BDT (Mobile, Laptop, Drone …). */
  pcsRates: Record<string, number>
  /** Usual amount of each everyday shipment cost, BDT; 0 = no suggestion. */
  costDefaults: CostDefaults
}

export const USUAL_COST_KEYS = ['packaging', 'courier', 'customs', 'transport'] as const
export type CostDefaults = Record<(typeof USUAL_COST_KEYS)[number], number>
const NO_COST_DEFAULTS: CostDefaults = { packaging: 0, courier: 0, customs: 0, transport: 0 }

const DEFAULTS: AppSettings = { exchangeRates: {BDT:1,CNY:17.05}, rate: 17.05, threshold: 1, investBdt: 0, investCny: 0, pcsRates: {}, costDefaults: NO_COST_DEFAULTS }

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
  const costDefaults: CostDefaults = { ...DEFAULTS.costDefaults }
  try {
    const parsed: unknown = JSON.parse(map.get('costDefaults') ?? '{}')
    if (parsed && typeof parsed === 'object') {
      for (const key of USUAL_COST_KEYS) {
        const value = (parsed as Record<string, unknown>)[key]
        if (typeof value === 'number' && value >= 0) costDefaults[key] = value
      }
    }
  } catch {
    // Malformed JSON — no suggestions rather than a failed read.
  }
  return {
    rate: numFrom('rate'),
    exchangeRates: {BDT:1,CNY:numFrom('rate')},
    threshold: numFrom('threshold'),
    investBdt: numFrom('investBdt'),
    investCny: numFrom('investCny'),
    pcsRates,
    costDefaults,
  }
}

export async function putCostDefaults(values: Partial<CostDefaults>): Promise<void> {
  const current = (await getSettings()).costDefaults
  await putRaw('costDefaults', JSON.stringify({ ...current, ...values }))
}

export async function putSetting(key: 'rate' | 'threshold' | 'investBdt' | 'investCny', value: number): Promise<void> {
  await putRaw(key, String(value))
}

export async function putPcsRates(rates: Record<string, number>): Promise<void> {
  await putRaw('pcsRates', JSON.stringify(rates))
}

export async function putRaw(key: string, value: string): Promise<void> {
  await prisma.setting.upsert({
    where: { key },
    update: { value },
    create: { key, value },
  })
}
