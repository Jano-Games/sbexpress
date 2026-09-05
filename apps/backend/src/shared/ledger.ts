/**
 * Money movements. Customer payments credit the matching account and land in
 * the Payment ledger (the finance screen's monthly "received" figures);
 * expenses debit the BDT cash account.
 */

import { Prisma } from '@prisma/client'
import { prisma } from '../core/db'
import { getSettings } from './settings'
import { badRequest } from '../core/errors'

/** Route a received payment to the account its method implies. */
export async function creditPayment(
  method: string,
  amountBdt: number,
  reference: string,
  shipmentId?: string,
  kind = shipmentId ? 'customer' : 'income',
  flightId?: string,
): Promise<void> {
  const settings = await getSettings()
  const accounts = await prisma.account.findMany({ orderBy: { createdAt: 'asc' } })

  const lower = method.toLowerCase()
  const exact = accounts.filter(a => a.name.toLowerCase() === lower)
  const candidates = exact.length ? exact : accounts.filter(a => lower === 'cash' ? a.kind === 'cash' && a.currency === 'BDT' : lower === 'bank' ? a.kind === 'bank' : false)
  if (candidates.length !== 1) throw badRequest(`Select one receiving account with the exact name: ${method}`)
  const target = candidates[0]!
  const credited = target.currency === 'CNY' ? new Prisma.Decimal(amountBdt).div(settings.rate).toDecimalPlaces(2).toNumber() : amountBdt

  await prisma.$transaction([
    ...(target
      ? [
          prisma.account.update({
            where: { id: target.id },
            data: { balance: { increment: new Prisma.Decimal(credited) } },
          }),
        ]
      : []),
    prisma.payment.create({
      data: { date: new Date(), method, amount: new Prisma.Decimal(amountBdt), reference, shipmentId, kind, flightId, accountName:target.name, accountCurrency:target.currency, accountAmount:credited, fxRate:target.currency === 'CNY' ? settings.rate : 1 },
    }),
  ])
}

/** Expenses come out of the Dhaka cash drawer. */
export async function debitCash(amountBdt: number, accountName = 'Cash'): Promise<{accountName:string;accountCurrency:'BDT'|'CNY';accountAmount:number;fxRate:number}> {
  const accounts = await prisma.account.findMany({ orderBy: { createdAt: 'asc' } })
  const matches = accounts.filter(a => a.name.toLowerCase() === accountName.toLowerCase())
  if (matches.length !== 1) throw badRequest('Select an exact paying account; create a Cash account if needed')
  const target = matches[0]!
  const fxRate = target.currency === 'CNY' ? (await getSettings()).rate : 1
  const accountAmount = new Prisma.Decimal(amountBdt).div(fxRate).toDecimalPlaces(2).toNumber()
  if (accountAmount > Number(target.balance)) throw badRequest('Insufficient account balance')
  await prisma.account.update({
    where: { id: target.id },
    data: { balance: { decrement: new Prisma.Decimal(accountAmount) } },
  })
  return {accountName:target.name,accountCurrency:target.currency,accountAmount,fxRate}
}
