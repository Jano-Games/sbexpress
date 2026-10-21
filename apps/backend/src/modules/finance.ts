import { moneyBody, sourceFields, sourceAt, withSavedMoney } from '../shared/money'
import { openingCapital } from '../shared/openingBalance'
import { getSettings } from '../shared/settings'
import { addShipmentBillCharge } from '../shared/shipmentBilling'
import { assertUniqueBank, bankDetailsSchema, assertUniqueMobile, mobileDetailsSchema } from '../shared/bankAccounts'
import { Hono } from 'hono'
import { randomUUID } from 'node:crypto'
import { Prisma, type AccountKind, type Currency, type ExpenseCategory } from '@prisma/client'
import { z } from 'zod'
import { prisma } from '../core/db'
import { cacheInvalidate } from '../core/redis'
import { badRequest, notFound } from '../core/errors'
import { requireRole, type AppEnv } from './auth'
import { num } from '../shared/serialize'
import { creditPayment, debitCash, postOpeningCapital } from '../shared/ledger'

import { financialSummary } from '../shared/financialSummary'

export const financeRoutes = new Hono<AppEnv>()
  .get('/accounts', requireRole('admin'), async c => {
    const accounts=await prisma.account.findMany({select:{name:true,currency:true,balance:true},orderBy:{createdAt:'asc'}})
    return c.json({accounts:accounts.map(a=>({...a,balance:num(a.balance)}))})
  })

  .get('/', requireRole('admin'), async (c) => c.json(await financialSummary(c.req.query('period') ?? c.req.query('month') ?? new Date().toISOString().slice(0, 7))))

  .post('/accounts', requireRole('admin'), async (c) => {
    const body = z
      .object({
        name: z.string().trim().min(1, 'Account name required').max(200),
        kind: z.enum(['cash','mobile','bank','wallet','fund']).optional(),
        bank: bankDetailsSchema.optional(),
        mobile: mobileDetailsSchema.optional(),
        currency: z.enum(['BDT', 'CNY']).default('BDT'),
        balance: z.number().finite().min(0).max(9999999999).default(0),
      })
      .parse(await c.req.json())
    if (await prisma.account.findFirst({ where: { name: { equals: body.name.trim(), mode: 'insensitive' } } })) throw badRequest('An account with this name already exists')
    if (body.kind === 'bank' && !body.bank) throw badRequest('Bank details are required')
    if (body.kind !== 'bank' && body.bank) throw badRequest('Bank details require a bank account')
    if (['mobile','wallet'].includes(body.kind ?? '') && !body.mobile) throw badRequest('Mobile provider and account number are required')
    if (body.mobile && !['mobile','wallet'].includes(body.kind ?? '')) throw badRequest('Mobile details require mobile money or wallet type')
    const quoted = body.currency === 'CNY' ? (await getSettings()).exchangeRates.CNY : 1
    const capital = openingCapital(body.balance, body.currency, quoted)
    if (body.mobile) await assertUniqueMobile(body.mobile)
    if (body.bank) await assertUniqueBank(body.bank)
    const account = await prisma.account.create({
      data: {
        name: body.name.trim(),
        kind: body.kind ?? (body.name.trim().toLowerCase() === 'cash' && body.currency === 'BDT' ? 'cash' : 'fund') as AccountKind,
        currency: body.currency as Currency,
        balance: new Prisma.Decimal(0),
      },
    })
    if (body.bank) {
      const last = await prisma.payMethod.findFirst({orderBy:{order:'desc'}})
      await prisma.payMethod.create({data:{kind:'bank_account',...body.bank,accountId:account.id,order:(last?.order ?? -1)+1}})
    }
    if (body.mobile) {
      const last = await prisma.payMethod.findFirst({orderBy:{order:'desc'}})
      await prisma.payMethod.create({data:{kind:'mobile_banking',...body.mobile,accountId:account.id,order:(last?.order ?? -1)+1}})
    }
    if (capital) await postOpeningCapital(account, capital.opening, capital.amountBdt, capital.rate)
    await cacheInvalidate('dashboard')
    return c.json({ ok: true }, 201)
  })

  .patch('/accounts/:name', requireRole('admin'), async c => {
    const accounts=await prisma.account.findMany({where:{name:c.req.param('name')},include:{paymentMethod:true}})
    if(accounts.length!==1) throw notFound('Account not found or name is ambiguous')
    const account=accounts[0]!
    const b=z.object({kind:z.enum(['cash','mobile','bank','wallet','fund']),bank:bankDetailsSchema.optional(),mobile:mobileDetailsSchema.optional()}).parse(await c.req.json())
    if(account.paymentMethod && ((account.paymentMethod.kind==='bank_account' && b.kind!=='bank') || (account.paymentMethod.kind==='mobile_banking' && !['mobile','wallet'].includes(b.kind)))) throw badRequest('Keep the linked payment account type; its history must remain consistent')
    if(b.kind==='bank'&&!b.bank) throw badRequest('Bank details are required')
    if(['mobile','wallet'].includes(b.kind)&&!b.mobile) throw badRequest('Mobile provider and account number are required')
    if(b.bank && b.kind!=='bank' || b.mobile && !['mobile','wallet'].includes(b.kind)) throw badRequest('Details do not match the account type')
    if(b.bank) await assertUniqueBank(b.bank,account.paymentMethod?.id)
    if(b.mobile) await assertUniqueMobile(b.mobile,account.paymentMethod?.id)
    await prisma.account.update({where:{id:account.id},data:{kind:b.kind}})
    const details=b.bank?{kind:'bank_account' as const,...b.bank}:b.mobile?{kind:'mobile_banking' as const,...b.mobile}:null
    if(details){
      if(account.paymentMethod) await prisma.payMethod.update({where:{id:account.paymentMethod.id},data:details})
      else {const last=await prisma.payMethod.findFirst({orderBy:{order:'desc'}});await prisma.payMethod.create({data:{...details,accountId:account.id,order:(last?.order??-1)+1}})}
    }
    await cacheInvalidate('dashboard')
    return c.json({ok:true})
  })

  .delete('/accounts/:name', requireRole('admin'), async c => {
    const accounts=await prisma.account.findMany({where:{name:c.req.param('name')},include:{paymentMethod:true}})
    if(accounts.length!==1) throw notFound('Account not found or name is ambiguous')
    const account=accounts[0]!
    if(num(account.balance)!==0) throw badRequest('Move the remaining balance to another account before deleting this fund')
    const names=[account.name,...(account.paymentMethod?[account.paymentMethod.kind==='bank_account'?account.paymentMethod.bankName:account.paymentMethod.provider]:[])]
    const [payments,expenses,transfers,refunds,receipts,statements]=await Promise.all([
      prisma.payment.count({where:{OR:[{accountName:account.name},{method:{in:names}}]}}),
      prisma.expense.count({where:{accountName:account.name}}),
      prisma.fundTransfer.count({where:{OR:[{fromName:account.name},{toName:account.name}]}}),
      prisma.customerRefund.count({where:{accountName:account.name}}),
      prisma.receipt.count({where:{method:{in:names}}}),
      prisma.statementReceipt.count({where:{method:{in:names}}}),
    ])
    if(payments+expenses+transfers+refunds+receipts+statements>0) throw badRequest('This account has transaction or receipt history and cannot be deleted')
    if(account.paymentMethod) await prisma.payMethod.delete({where:{id:account.paymentMethod.id}})
    await prisma.account.delete({where:{id:account.id}})
    await cacheInvalidate('dashboard')
    return c.json({ok:true})
  })

  .post('/transfers', requireRole('admin'), async (c) => {
    const b = z.object({ from: z.string().min(1), to: z.string().min(1),
      amount: z.number().positive().max(9999999999).multipleOf(0.01),
      receivedAmount: z.number().positive().max(9999999999).multipleOf(0.01).optional(),
      note: z.string().trim().min(1).max(200), reference: z.string().uuid(),
    }).parse(await c.req.json())
    const previous = await prisma.fundTransfer.findUnique({ where: { reference: b.reference } })
    if (previous) {
      if (previous.fromName !== b.from || previous.toName !== b.to || num(previous.amount) !== b.amount || previous.note !== b.note || (b.receivedAmount !== undefined && num(previous.receivedAmount) !== b.receivedAmount)) throw badRequest('Transfer reference already used with different details')
      return c.json({ ok: true, reference: b.reference })
    }
    if (b.from === b.to) throw badRequest('Choose two different accounts')
    const [sources, targets] = await Promise.all([
      prisma.account.findMany({ where: { name: b.from } }), prisma.account.findMany({ where: { name: b.to } }),
    ])
    if (sources.length !== 1 || targets.length !== 1) throw badRequest('Account names must identify exactly one account')
    const source = sources[0]!, target = targets[0]!
    if (num(source.balance) < b.amount) throw badRequest('Insufficient funds')
    const received = source.currency === target.currency ? b.amount : b.receivedAmount
    if (!received) throw badRequest('Enter the actual amount received in the destination currency')
    if (source.currency === target.currency && b.receivedAmount !== undefined && b.receivedAmount !== b.amount) throw badRequest('Same-currency amounts must match')
    await prisma.account.update({ where: { id: source.id }, data: { balance: { decrement: new Prisma.Decimal(b.amount) } } })
    await prisma.account.update({ where: { id: target.id }, data: { balance: { increment: new Prisma.Decimal(received) } } })
    await prisma.fundTransfer.create({ data: { reference: b.reference, fromName: source.name, toName: target.name,
      fromCurrency: source.currency, toCurrency: target.currency, amount: b.amount, receivedAmount: received, note: b.note } })
    return c.json({ ok: true, reference: b.reference }, 201)
  })

  .post('/incomes', requireRole('admin'), async (c) => {
    const body = z
      .object({
        amount: z.number().positive('Amount is required'),
        method: z.string().min(1).max(200).default('Cash'),
        note: z.string().min(1, 'Note is required').max(160),
        kind: z.enum(['income','capital']).default('income'),
      })
      .parse(moneyBody(await c.req.json(), ['amount']))
    // Non-shipment money in (e.g. an owner deposit or misc income) — lands in
    // the matching account and the monthly received ledger like any payment.
    await creditPayment(body.method, body.amount, body.note, undefined, body.kind)
    await cacheInvalidate('dashboard')
    return c.json({ ok: true }, 201)
  })

  .post('/expenses', requireRole('admin'), async (c) => {
    const body = z
      .object({
        category: z.enum(['ticket', 'packaging', 'courier', 'salary', 'transport', 'customs', 'others']),
        amount: z.number().positive('Amount is required'),
        reason: z.string().trim().min(1, 'Cost name is required').max(500),
        label: z.string().trim().min(1).max(120).optional(),
        accountName: z.string().trim().min(1).default('Cash'),
        shipmentCode: z.string().optional(),
      })
      .parse(moneyBody(await c.req.json(), ['amount']))

    let shipmentId: string | undefined
    if (body.shipmentCode) {
      const shipment = await prisma.shipment.findUnique({ where: { code: body.shipmentCode } })
      if (!shipment) throw badRequest(`Unknown shipment ${body.shipmentCode}`)
      shipmentId = shipment.id
    }
    const cost=shipmentId?await prisma.shipmentCost.create({data:{shipmentId,name:body.label??`${body.category.charAt(0).toUpperCase()+body.category.slice(1)} charge`,category:body.category,amount:body.amount,...sourceFields(body.amount)}}):null
    const paidFrom = await debitCash(body.amount, body.accountName)
    await prisma.expense.create({
      data: {
        ...paidFrom, costId:cost?.id,
        ...sourceFields(body.amount),
        date: new Date(),
        category: body.category as ExpenseCategory,
        amount: new Prisma.Decimal(body.amount),
        reason: body.reason,
        shipmentId,
      },
    })
    if (shipmentId) await addShipmentBillCharge(shipmentId, body.category, body.amount, body.label)
    await cacheInvalidate('dashboard')
    return c.json({ ok: true }, 201)
  })
