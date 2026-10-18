import { writeShipmentLog } from '../shared/actor'
import { moneyBody, sourceFields, sourceAt, withSavedMoney } from '../shared/money'
import { Hono } from 'hono'
import { z } from 'zod'
import { prisma } from '../core/db'
import { badRequest, notFound } from '../core/errors'
import { requireRole,type AppEnv } from './auth'
import { changeCredit,money } from '../shared/customerCredit'
import { debitCash } from '../shared/ledger'
import { effectiveBill, sourceDto } from '../shared/serialize'
async function supplier(code:string){const s=await prisma.supplier.findUnique({where:{code}});if(!s)throw notFound('Customer not found');return s}
export const customerAccountRoutes=new Hono<AppEnv>()
 .get('/:code/credits',requireRole('admin'),async c=>{
  const s=await supplier(c.req.param('code')!)
  const rows=await prisma.customerCredit.findMany({where:{supplierId:s.id},orderBy:{createdAt:'desc'},take:100})
  const refunds=await prisma.customerRefund.findMany({where:{supplierId:s.id},orderBy:{createdAt:'desc'},take:100})
  return c.json({balance:Number(s.creditBalance),entries:rows.map(x=>({...sourceDto(x,Number(x.amount)),reference:x.reference,amount:Number(x.amount),kind:x.kind,reason:x.reason,shipmentCode:x.shipmentCode,at:x.createdAt.toISOString()})),refunds:refunds.map(x=>({...sourceDto(x,Number(x.amount)),reference:x.reference,amount:Number(x.amount),reason:x.reason,accountName:x.accountName,at:x.createdAt.toISOString()}))})
 })
 .get('/:code/activity',requireRole('admin'),async c=>{
  const s=await supplier(c.req.param('code')!),page=Math.max(1,Number(c.req.query('page'))||1),limit=25
  const [payments,credits,refunds,reversals]=await Promise.all([prisma.payment.findMany({where:{OR:[{supplierId:s.id},{shipment:{supplierId:s.id}}]},include:{shipment:{select:{code:true}}}}),prisma.customerCredit.findMany({where:{supplierId:s.id}}),prisma.customerRefund.findMany({where:{supplierId:s.id}}),prisma.ledgerReversal.findMany({where:{kind:'credit'}})])
  const entries=[...payments.map(p=>({...sourceDto(p,Number(p.amount)),id:p.id,kind:p.kind,label:p.kind==='customer-credit'?'Customer advance':'Payment',amount:Number(p.amount),at:p.createdAt.toISOString(),reference:p.reference,shipmentCode:p.shipment?.code??null,accountName:p.accountName,reason:'',reversalKind:'payment',canReverse:!p.reversalOfId&&!p.reversedAt})),...refunds.map(r=>({...sourceDto(r,Number(r.amount)),id:r.id,kind:'refund',label:'Refund',amount:-Number(r.amount),at:r.createdAt.toISOString(),reference:r.reference,shipmentCode:null,accountName:r.accountName,reason:r.reason,reversalKind:'refund',canReverse:!r.reversalOfId&&!r.reversedAt})),...credits.filter(x=>!['advance','refund','refund-reversal','payment-reversal'].includes(x.kind)).map(x=>({...sourceDto(x,Number(x.amount)),id:x.id,kind:x.kind,label:x.kind==='applied'?'Credit applied':'Credit adjustment',amount:Number(x.amount),at:x.createdAt.toISOString(),reference:x.reference,shipmentCode:x.shipmentCode,accountName:null,reason:x.reason,reversalKind:'credit',canReverse:x.kind==='applied'&&!reversals.some(r=>r.recordId===x.id)}))].sort((a,b)=>b.at.localeCompare(a.at)||b.id.localeCompare(a.id))
  return c.json({entries:entries.slice((page-1)*limit,page*limit),page,total:entries.length,limit})
 })
 .post('/:code/apply-credit',requireRole('admin'),async c=>{
  const s=await supplier(c.req.param('code')!)
  const b=z.object({shipmentCode:z.string().min(1),amount:z.number().positive().multipleOf(0.01).max(9999999999)}).parse(moneyBody(await c.req.json(), ['amount']))
  const sh=await prisma.shipment.findFirst({where:{supplierId:s.id,code:b.shipmentCode},include:{invoice:true}})
  if(!sh)throw notFound('Customer shipment not found')
  if(sh.invoice?.state!=='issued'||sh.invoice.needsReview)throw badRequest('Review and issue the invoice before applying credit')
  const total=effectiveBill(sh),paid=money(Number(sh.paidAmount)+b.amount)
  if(paid>total)throw badRequest('Credit exceeds shipment outstanding balance')
  await changeCredit(s.id,-b.amount,'applied','Applied to invoice',sh.code)
  await prisma.shipment.update({where:{id:sh.id},data:{paidAmount:paid,payStatus:paid>=total?'paid':'partial'}})
  await writeShipmentLog(sh.id,`Customer credit applied: BDT ${b.amount}`)
  return c.json({ok:true})
 })
 .post('/:code/refunds',requireRole('admin'),async c=>{
  const s=await supplier(c.req.param('code')!)
  const b=z.object({amount:z.number().positive().multipleOf(0.01).max(9999999999),accountName:z.string().trim().min(1),reason:z.string().trim().min(3).max(200)}).parse(moneyBody(await c.req.json(), ['amount']))
  await changeCredit(s.id,-b.amount,'refund',b.reason)
  const posted=await debitCash(b.amount,b.accountName)
  const refund=await prisma.customerRefund.create({data:{...sourceFields(b.amount),supplierId:s.id,amount:b.amount,reason:b.reason,...posted}})
  return c.json({ok:true,reference:refund.reference},201)
 })
export const invoiceHistoryRoutes=new Hono<AppEnv>()
 .get('/:code/invoice-history',requireRole('admin'),async c=>{
  const s=await prisma.shipment.findUnique({where:{code:c.req.param('code')!},include:{invoice:{include:{revisions:{orderBy:{version:'desc'}}}},creditNotes:{orderBy:{createdAt:'desc'}}}})
  if(!s)throw notFound('Shipment not found')
  return c.json({revisions:s.invoice?.revisions.map(v=>({version:v.version,snapshot:v.snapshot,reason:v.reason,at:v.createdAt.toISOString()}))??[],creditNotes:s.creditNotes.map(n=>({number:n.number,amount:Number(n.amount),reason:n.reason,previousTotal:Number(n.previousTotal),revisedTotal:Number(n.revisedTotal),at:n.createdAt.toISOString()}))})
 })
