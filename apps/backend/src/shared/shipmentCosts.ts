import type { Expense, Shipment, ShipmentCost } from '@prisma/client'

type CostField = 'cnFare' | 'bdFare' | 'customsTax'
const round = (value: number) => Math.round(value * 100) / 100
const original = (
  row: {
    sourceCurrency?: string
    sourceAmount?: unknown
    sourceFxRate?: unknown
  },
  amount: number,
) => ({
  sourceCurrency: row.sourceCurrency ?? 'BDT',
  sourceAmount: row.sourceAmount == null ? amount : Number(row.sourceAmount),
  sourceFxRate: Number(row.sourceFxRate ?? 1),
})
export interface ShipmentCostItem {
  id: string
  name: string
  category: string
  amount: number
  paidAmount: number
  dueAmount: number
  sourceCurrency: string
  sourceAmount: number
  sourceFxRate: number
  recordedAt: string | null
  voidedAt?: string | null
  costField: CostField | null
  payments: {
    id: string
    canReverse: boolean
    reversedAt: string | null
    reversalOfId: string | null
    amount: number
    sourceCurrency: string
    sourceAmount: number
    sourceFxRate: number
    accountName: string | null
    accountCurrency: string | null
    accountAmount: number | null
    at: string
  }[]
}
/** Present old accrued fields and new expenses in one register. Settlement rows are payments, never extra costs. */
export function shipmentCostItems(
  s: Pick<Shipment, 'cnFare' | 'bdFare' | 'customsTax' | 'costSources'> & {
    expenses: Expense[]
    costs?: ShipmentCost[]
  },
): ShipmentCostItem[] {
  const payment = (e: Expense) => ({
    id: e.id,
    canReverse: !e.reversedAt && !e.reversalOfId && Number(e.amount) > 0,
    reversedAt: e.reversedAt?.toISOString() ?? null,
    reversalOfId: e.reversalOfId,
    amount: Number(e.amount),
    ...original(e, Number(e.amount)),
    accountName: e.accountName,
    accountCurrency: e.accountCurrency,
    accountAmount: e.accountAmount === null ? null : Number(e.accountAmount),
    at: e.date.toISOString(),
  })
  const sources = s.costSources as Record<
    string,
    { sourceCurrency?: string; sourceAmount?: number; sourceFxRate?: number }
  >
  const legacy = [
    {
      field: 'cnFare' as const,
      name: 'China transport',
      category: 'transport',
    },
    { field: 'bdFare' as const, name: 'Dhaka transport', category: 'courier' },
    { field: 'customsTax' as const, name: 'Customs', category: 'customs' },
  ].flatMap(({ field, name, category }): ShipmentCostItem[] => {
    const payments = s.expenses
      .filter((e) => e.costField === field)
      .sort((a, b) => a.date.getTime() - b.date.getTime())
      .map(payment)
    const amount = Number(s[field] ?? 0),
      paidAmount = round(payments.reduce((sum, p) => sum + p.amount, 0))
    if (!amount && !payments.length) return []
    return [
      {
        id: field,
        name,
        category,
        amount,
        paidAmount,
        dueAmount: Math.max(0, round(amount - paidAmount)),
        ...original(sources?.[field] ?? {}, amount),
        recordedAt: null,
        costField: field,
        payments,
      },
    ]
  })
  return [
    ...legacy,
    ...(s.costs ?? []).map((cost): ShipmentCostItem => {
      const payments = s.expenses
          .filter((e) => e.costId === cost.id)
          .map(payment),
        paidAmount = round(payments.reduce((sum, p) => sum + p.amount, 0))
      return {
        id: cost.id,
        name: cost.name,
        category: cost.category,
        amount: Number(cost.amount),
        paidAmount,
        dueAmount: cost.voidedAt
          ? 0
          : Math.max(0, round(Number(cost.amount) - paidAmount)),
        ...original(cost, Number(cost.amount)),
        recordedAt: cost.createdAt.toISOString(),
        costField: null,
        voidedAt: cost.voidedAt?.toISOString() ?? null,
        payments,
      }
    }),
    ...s.expenses
      .filter((e) => !e.costField && !e.costId && !e.reversalOfId)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .map(
        (e): ShipmentCostItem => ({
          id: e.id,
          name: e.reason,
          category: e.category,
          amount: Number(e.amount),
          paidAmount: Number(e.amount),
          dueAmount: 0,
          ...original(e, Number(e.amount)),
          recordedAt: e.date.toISOString(),
          costField: null,
          payments: [payment(e)],
        }),
      ),
  ]
}

/** The four costs almost every shipment has, in checklist order. */
export const USUAL_COSTS = ['packaging', 'courier', 'customs', 'transport'] as const

/** What is recorded so far for each usual cost; 0 means it has not been added. */
export function usualCosts(
  s: Parameters<typeof shipmentCostItems>[0],
): { category: (typeof USUAL_COSTS)[number]; amount: number }[] {
  const items = shipmentCostItems(s).filter((item) => !item.voidedAt)
  return USUAL_COSTS.map((category) => ({
    category,
    amount: round(
      items
        .filter((item) => item.category === category)
        .reduce((sum, item) => sum + item.amount, 0),
    ),
  }))
}
