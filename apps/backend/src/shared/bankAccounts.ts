import type { Currency, PayMethod } from '@prisma/client'
import { z } from 'zod'
import { prisma } from '../core/db'
import { badRequest } from '../core/errors'

export const bankDetailsSchema = z.object({
  bankName: z.string().trim().min(1, 'Bank name required').max(80),
  accountNumber: z.string().trim().min(1, 'Account number required').max(80),
  accountName: z.string().trim().min(1, 'Account holder required').max(80),
  branch: z.string().trim().max(80).default(''),
  district: z.string().trim().max(80).default(''),
})

export async function assertUniqueBank(bank: z.infer<typeof bankDetailsSchema>, excludeId?: string) {
  const duplicate = await prisma.payMethod.findFirst({where:{kind:'bank_account',bankName:{equals:bank.bankName,mode:'insensitive'},accountNumber:bank.accountNumber,...(excludeId ? {id:{not:excludeId}} : {})}})
  if (duplicate) throw badRequest('This bank account already exists. Use its existing fund.')
}

export const mobileDetailsSchema = z.object({
  provider: z.string().trim().min(1, 'Provider required').max(60),
  number: z.string().trim().min(1, 'Account number required').max(80),
  label: z.string().trim().max(80).default(''),
})
export async function assertUniqueMobile(mobile: z.infer<typeof mobileDetailsSchema>, excludeId?: string) {
  if (await prisma.payMethod.findFirst({where:{kind:'mobile_banking',provider:{equals:mobile.provider,mode:'insensitive'},number:mobile.number,...(excludeId?{id:{not:excludeId}}:{})}})) throw badRequest('This mobile account already exists. Use its existing fund.')
}

/** Called inside the agency write transaction. An account has only one balance. */
export async function linkBankFund(method: PayMethod, currency?: Currency) {
  if (method.accountId) return method
  const isBank = method.kind === 'bank_account'
  const provider = isBank ? method.bankName : method.provider
  const number = isBank ? method.accountNumber : method.number
  const name = `${provider} · ${number}`
  let matches = await prisma.account.findMany({where:{name:{equals:name,mode:'insensitive'}},include:{paymentMethod:true}})
  if (!matches.length) {
    // Preserve an existing, unambiguous legacy receiving account and its balance.
    const legacy = await prisma.account.findMany({where:{name:{equals:provider,mode:'insensitive'}},include:{paymentMethod:true}})
    const methods = await prisma.payMethod.count({where:isBank?{kind:'bank_account',bankName:{equals:provider,mode:'insensitive'}}:{kind:'mobile_banking',provider:{equals:provider,mode:'insensitive'}}})
    if (legacy.length === 1 && !legacy[0]!.paymentMethod && methods === 1) matches = legacy
  }
  if (matches.length > 1 || matches.some(a=>a.paymentMethod)) throw badRequest('A fund with this name is already linked. Choose a unique account.')
  if (currency && matches[0] && matches[0].currency !== currency) throw badRequest('The existing fund uses a different currency. Use a separate account for this currency.')
  const account = matches[0] ?? await prisma.account.create({data:{name,kind:isBank?'bank':'mobile',currency:currency ?? 'BDT',balance:0}})
  return prisma.payMethod.update({where:{id:method.id},data:{accountId:account.id}})
}

/** Receipt snapshots use the stable fund name, not the ambiguous bank label. */
export async function receivingFundName(method: PayMethod) {
  const linked = await linkBankFund(method)
  const account = await prisma.account.findUnique({where:{id:linked.accountId!}})
  if (!account) throw badRequest('Receiving fund is unavailable')
  return account.name
}
