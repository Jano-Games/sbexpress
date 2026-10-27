import { Hono } from 'hono'
import { createHash } from 'node:crypto'
import { z } from 'zod'
import { prisma } from '../core/db'
import { requireRole, type AppEnv } from './auth'
import { isUnpaidFlightCost } from '../shared/flightCosts'

type Entry = { recordId:string;reversalKind:string;canReverse:boolean;reversedAt?:string|null;reversalOfId?:string|null; sourceCurrency?:string; sourceAmount?:number; sourceFxRate?:number; baseAmount?:number; key:string; at:string; type:string; description:string; reference:string; account:string|null; currency:string; amount:number; shipmentCode?:string|null; flightCode?:string|null; supplierCode?:string|null }
const key=(kind:string,id:string)=>createHash('sha256').update(`${kind}:${id}`).digest('hex')
export const financeLedgerRoutes=new Hono<AppEnv>().get('/ledger',requireRole('admin'),async c=>{
 const q=z.object({period:z.string().regex(/^(all|week|20\d{2}-(0[1-9]|1[0-2]))$/).default('all'),account:z.string().optional(),type:z.enum(['all','customer','flyer','income','capital','customer-credit','expense','refund','transfer']).default('all'),search:z.string().max(200).default(''),page:z.coerce.number().int().min(1).default(1),limit:z.coerce.number().int().min(1).max(100).default(25)}).parse(c.req.query())
 const now=new Date(),week=new Date(Date.UTC(now.getUTCFullYear(),now.getUTCMonth(),now.getUTCDate()-((now.getUTCDay()+6)%7)))
 const range=q.period==='all'?undefined:q.period==='week'?{gte:week}:{gte:new Date(`${q.period}-01T00:00:00Z`),lt:new Date(Date.UTC(Number(q.period.slice(0,4)),Number(q.period.slice(5,7)),1))}
 const [payments,expenses,refunds,transfers]=await Promise.all([
  prisma.payment.findMany({where:{date:range},include:{shipment:{select:{code:true}},flight:{select:{code:true}}}}),
  prisma.expense.findMany({where:{date:range},include:{shipment:{select:{code:true}},flight:{select:{code:true}}}}),
  prisma.customerRefund.findMany({where:{createdAt:range},include:{supplier:{select:{code:true}}}}),
  prisma.fundTransfer.findMany({where:{createdAt:range}}),
 ])
 const entries:Entry[]=[
  ...payments.map(p=>({recordId:p.id,reversalKind:'payment',canReverse:!p.reversedAt&&!p.reversalOfId,reversedAt:p.reversedAt?.toISOString()??null,reversalOfId:p.reversalOfId,sourceCurrency:p.sourceCurrency,sourceAmount:Number(p.sourceAmount),sourceFxRate:Number(p.sourceFxRate),baseAmount:Number(p.amount),key:key('payment',p.id),at:p.date.toISOString(),type:p.kind,description:p.reference||'Payment received',reference:p.reference,account:p.accountName,currency:p.accountCurrency??'BDT',amount:Number(p.accountAmount??p.amount),shipmentCode:p.shipment?.code,flightCode:p.flight?.code})),
  // A pay-later flight cost has not moved money yet; it appears once it is paid.
  ...expenses.filter(e=>!isUnpaidFlightCost(e)).map(e=>({recordId:e.id,reversalKind:'expense',canReverse:!e.reversedAt&&!e.reversalOfId,reversedAt:e.reversedAt?.toISOString()??null,reversalOfId:e.reversalOfId,sourceCurrency:e.sourceCurrency,sourceAmount:Number(e.sourceAmount),sourceFxRate:Number(e.sourceFxRate),baseAmount:Number(e.amount),key:key('expense',e.id),at:e.date.toISOString(),type:'expense',description:e.reason,reference:e.category,account:e.accountName,currency:e.accountCurrency??'BDT',amount:-Number(e.accountAmount??e.amount),shipmentCode:e.shipment?.code,flightCode:e.flight?.code})),
  ...refunds.map(r=>({recordId:r.id,reversalKind:'refund',canReverse:!r.reversedAt&&!r.reversalOfId,reversedAt:r.reversedAt?.toISOString()??null,reversalOfId:r.reversalOfId,sourceCurrency:r.sourceCurrency,sourceAmount:Number(r.sourceAmount),sourceFxRate:Number(r.sourceFxRate),baseAmount:Number(r.amount),key:key('refund',r.id),at:r.createdAt.toISOString(),type:'refund',description:r.reason,reference:r.reference,account:r.accountName,currency:r.accountCurrency,amount:-Number(r.accountAmount),supplierCode:r.supplier.code})),
  ...transfers.flatMap(t=>[{recordId:t.id,reversalKind:'transfer',canReverse:!t.reversedAt&&!t.reversalOfId,reversedAt:t.reversedAt?.toISOString()??null,reversalOfId:t.reversalOfId,key:key('transfer-out',t.id),at:t.createdAt.toISOString(),type:'transfer',description:`To ${t.toName} · ${t.note}`,reference:t.reference,account:t.fromName,currency:t.fromCurrency,amount:-Number(t.amount)},{recordId:t.id,reversalKind:'transfer',canReverse:!t.reversedAt&&!t.reversalOfId,reversedAt:t.reversedAt?.toISOString()??null,reversalOfId:t.reversalOfId,key:key('transfer-in',t.id),at:t.createdAt.toISOString(),type:'transfer',description:`From ${t.fromName} · ${t.note}`,reference:t.reference,account:t.toName,currency:t.toCurrency,amount:Number(t.receivedAmount)}]),
 ]
 const search=q.search.toLowerCase().trim()
 const filtered=entries.filter(e=>(!q.account||(q.account==='__unassigned'?e.account===null:e.account===q.account))&&(q.type==='all'||e.type===q.type)&&(!search||[e.description,e.reference,e.account,e.shipmentCode,e.flightCode,e.supplierCode].some(v=>v?.toLowerCase().includes(search)))).sort((a,b)=>b.at.localeCompare(a.at)||a.key.localeCompare(b.key))
 const totals=['BDT','CNY'].map(currency=>({currency,moneyIn:Math.round(filtered.filter(e=>e.currency===currency&&e.amount>0).reduce((a,e)=>a+e.amount,0)*100)/100,moneyOut:Math.round(filtered.filter(e=>e.currency===currency&&e.amount<0).reduce((a,e)=>a-e.amount,0)*100)/100}))
 return c.json({entries:filtered.slice((q.page-1)*q.limit,q.page*q.limit),total:filtered.length,page:q.page,limit:q.limit,totals})
})
