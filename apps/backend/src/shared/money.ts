import { AsyncLocalStorage } from 'node:async_hooks'
import { Prisma, type Currency } from '@prisma/client'
import { z } from 'zod'
import { badRequest } from '../core/errors'
import { getSettings } from './settings'

export const currencySchema = z.enum(['BDT', 'CNY'])
export type MoneyInput = { currency: Currency; exchangeRate: number }
const context = new AsyncLocalStorage<MoneyInput>()
export const roundMoney = (value: number) => new Prisma.Decimal(value).toDecimalPlaces(2).toNumber()
export const toBdt = (amount: number, rate: number) => {
  if (!Number.isFinite(amount) || !Number.isFinite(rate) || rate <= 0) throw badRequest('Enter a valid amount and exchange rate')
  if (new Prisma.Decimal(amount).decimalPlaces()>2) throw badRequest('Money amounts may have at most two decimal places')
  const result = new Prisma.Decimal(amount).mul(rate).toDecimalPlaces(2).toNumber()
  if (Math.abs(result) >= 9999999999) throw badRequest('Amount exceeds the supported limit')
  return result
}
export async function withMoneyInput<T>(path: string, raw: unknown, work: () => Promise<T>) {
  const input = raw && typeof raw === 'object' ? (raw as {money?:unknown}).money : undefined
  if (!input) return context.run({currency:'BDT',exchangeRate:1}, work)
  const money = z.object({currency:currencySchema, exchangeRate:z.number().positive().max(1000000).optional()}).parse(input)
  const rates = (await getSettings()).exchangeRates
  const rate = money.currency === 'BDT' ? 1 : money.exchangeRate ?? rates[money.currency]
  if (!rate) throw badRequest(`Set the ${money.currency} exchange rate in Settings first`)
  if (path.startsWith('/api/track/') || path.startsWith('/api/statements/')) {
    if (!rates[money.currency] || rate !== rates[money.currency]) throw badRequest('The exchange rate changed. Refresh this page before submitting.')
  }
  return context.run({currency:money.currency,exchangeRate:rate}, work)
}
/** Called only by monetary routes. Canonical ledger amounts remain BDT. */
export function moneyBody(raw: unknown, fields: string[] = ['amount']) {
  if (!raw || typeof raw !== 'object') return raw
  const body = {...raw as Record<string,unknown>}
  const rate = context.getStore()?.exchangeRate ?? 1
  for (const field of fields) if (typeof body[field] === 'number') body[field] = toBdt(body[field] as number, rate)
  if (fields.includes('lines') && Array.isArray(body.lines)) body.lines = body.lines.map(line => line && typeof line === 'object' && typeof line.amount === 'number' ? {...line, amount:toBdt(line.amount,rate)} : line)
  if (fields.includes('allocations') && Array.isArray(body.allocations)) body.allocations=body.allocations.map(row=>row && typeof row === 'object' ? {...row,contribution:toBdt(row.contribution,rate),legacyPaid:toBdt(row.legacyPaid??0,rate)} : row)
  return body
}
export function sourceFields(amountBdt: number) {
  const source = context.getStore() ?? {currency:'BDT' as const,exchangeRate:1}
  return { sourceCurrency:source.currency, sourceFxRate:source.exchangeRate, sourceAmount:new Prisma.Decimal(amountBdt).div(source.exchangeRate).toDecimalPlaces(2).toNumber() }
}
export function sourceAt(amountBdt:number, source:{sourceCurrency:Currency;sourceFxRate:unknown}) {
  return {sourceCurrency:source.sourceCurrency, sourceFxRate:Number(source.sourceFxRate), sourceAmount:new Prisma.Decimal(amountBdt).div(Number(source.sourceFxRate)).toDecimalPlaces(2).toNumber()}
}
export async function withSavedMoney<T>(source:{sourceCurrency:Currency;sourceFxRate:unknown}, work:()=>Promise<T>) {
  return context.run({currency:source.sourceCurrency,exchangeRate:Number(source.sourceFxRate)},work)
}
export async function accountRate(currency: Currency) {
  const input=context.getStore()
  if (input?.currency===currency) return input.exchangeRate
  const rate=(await getSettings()).exchangeRates[currency]
  if(!rate) throw badRequest(`Set the ${currency} exchange rate in Settings first`)
  return rate
}
