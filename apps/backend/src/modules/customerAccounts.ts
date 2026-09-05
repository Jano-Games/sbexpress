import { Hono } from 'hono'
import { z } from 'zod'
import { prisma } from '../core/db'
import { badRequest, notFound } from '../core/errors'
import { requireRole,type AppEnv } from './auth'
import { changeCredit,money } from '../shared/customerCredit'
import { debitCash } from '../shared/ledger'
import { effectiveBill } from '../shared/serialize'
async function supplier(code:string){const s=await prisma.supplier.findUnique({where:{code}});if(!s)throw notFound('Supplier not found');return s}
export const customerAccountRoutes=new Hono<AppEnv>()
 .get('/:code/credits',requireRole('admin'),async c=>{
  const s=await supplier(c.req.param('code')!)
  const rows=await prisma.customerCredit.findMany({where:{supplierId:s.id},orderBy:{createdAt:'desc'},take:100})
  const refunds=await prisma.customerRefund.findMany({where:{supplierId:s.id},orderBy:{createdAt:'desc'},take:100})
  return c.json({balance:Number(s.creditBalance),entries:rows.map(x=>({reference:x.reference,amount:Number(x.amount),kind:x.kind,reason:x.reason,shipmentCode:x.shipmentCode,at:x.createdAt.toISOString()})),refunds:refunds.map(x=>({reference:x.reference,amount:Number(x.amount),reason:x.reason,accountName:x.accountName,at:x.createdAt.toISOString()}))})
 })
 .post('/:code/apply-credit',requireRole('admin'),async c=>{
  const s=await supplier(c.req.param('code')!)
  const b=z.object({shipmentCode:z.string().min(1),amount:z.number().positive().multipleOf(0.01).max(9999999999)}).parse(await c.req.json())
  const sh=await prisma.shipment.findFirst({where:{supplierId:s.id,code:b.shipmentCode},include:{invoice:true}})
  if(!sh)throw notFound('Supplier shipment not found')
  const total=effectiveBill(sh),paid=money(Number(sh.paidAmount)+b.amount)
  if(paid>total)throw badRequest('Credit exceeds shipment outstanding balance')
  await changeCredit(s.id,-b.amount,'applied','Applied to invoice',sh.code)
  await prisma.shipment.update({where:{id:sh.id},data:{paidAmount:paid,payStatus:paid>=total?'paid':'partial'}})
  await prisma.shipmentLog.create({data:{shipmentId:sh.id,actor:'Admin',message:`Customer credit applied: BDT ${b.amount}`}})
  return c.json({ok:true})
 })
 .post('/:code/refunds',requireRole('admin'),async c=>{
  const s=await supplier(c.req.param('code')!)
  const b=z.object({amount:z.number().positive().multipleOf(0.01).max(9999999999),accountName:z.string().trim().min(1),reason:z.string().trim().min(3).max(200)}).parse(await c.req.json())
  await changeCredit(s.id,-b.amount,'refund',b.reason)
  const posted=await debitCash(b.amount,b.accountName)
  const refund=await prisma.customerRefund.create({data:{supplierId:s.id,amount:b.amount,reason:b.reason,...posted}})
  return c.json({ok:true,reference:refund.reference},201)
 })
export const invoiceHistoryRoutes=new Hono<AppEnv>()
 .get('/:code/invoice-history',requireRole('admin'),async c=>{
  const s=await prisma.shipment.findUnique({where:{code:c.req.param('code')!},include:{invoice:{include:{revisions:{orderBy:{version:'desc'}}}},creditNotes:{orderBy:{createdAt:'desc'}}}})
  if(!s)throw notFound('Shipment not found')
  return c.json({revisions:s.invoice?.revisions.map(v=>({version:v.version,snapshot:v.snapshot,reason:v.reason,at:v.createdAt.toISOString()}))??[],creditNotes:s.creditNotes.map(n=>({number:n.number,amount:Number(n.amount),reason:n.reason,previousTotal:Number(n.previousTotal),revisedTotal:Number(n.revisedTotal),at:n.createdAt.toISOString()}))})
 })
