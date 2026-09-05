import { receivingFundName } from '../shared/bankAccounts'
import {Hono} from 'hono'
import {z} from 'zod'
import {prisma} from '../core/db'
import {badRequest,notFound,HttpError} from '../core/errors'
import {rateLimit} from '../core/redis'
import {config} from '../core/config'
import {requireRole,type AppEnv} from './auth'
import {newPublicToken,tokenHash,validToken,isLive,publicMethodKey} from '../shared/publicLinks'
import {effectiveBill,num} from '../shared/serialize'
import {money} from '../shared/customerCredit'
import {payMethodsFor,payMethodName} from './track'
import {recordShipmentPayment} from './shipments'
const monthSchema=z.string().regex(/^20\d{2}-(0[1-9]|1[0-2])$/)
async function rowsFor(supplierId:string,month:string){
 const start=new Date(`${month}-01T00:00:00Z`),end=new Date(start);end.setUTCMonth(end.getUTCMonth()+1)
 return prisma.shipment.findMany({where:{supplierId,createdAt:{gte:start,lt:end}},include:{supplier:true,flight:true,receipt:true,invoice:true,expenses:true},orderBy:[{createdAt:'asc'},{code:'asc'}]})
}
async function resolve(token:string){
 if(!validToken(token))throw notFound('Link unavailable or expired')
 const link=await prisma.statementLink.findUnique({where:{tokenHash:tokenHash(token)},include:{supplier:true}})
 if(!link||!isLive(link))throw notFound('Link unavailable or expired')
 return link
}
async function amounts(link:{supplierId:string;month:string;requestedAmount:unknown;paidAtIssue:unknown}){
 const rows=await rowsFor(link.supplierId,link.month)
 const due=money(rows.reduce((a,s)=>a+Math.max(0,effectiveBill(s)-num(s.paidAmount)),0))
 const paid=money(rows.reduce((a,s)=>a+num(s.paidAmount),0))
 const requested=link.requestedAmount===null?due:money(Math.max(0,Math.min(due,Number(link.requestedAmount)-Math.max(0,paid-Number(link.paidAtIssue)))))
 return {rows,due,paid,requested}
}
export const statementAdminRoutes=new Hono<AppEnv>()
 .post('/:code/statement-link',requireRole('admin'),async c=>{
  const b=z.object({month:monthSchema,days:z.number().int().min(1).max(90).default(7),amount:z.number().positive().multipleOf(0.01).optional()}).parse(await c.req.json())
  const s=await prisma.supplier.findUnique({where:{code:c.req.param('code')!}});if(!s)throw notFound('Supplier not found')
  const a=await amounts({supplierId:s.id,month:b.month,requestedAmount:null,paidAtIssue:0})
  if(!a.rows.length)throw badRequest('No shipments in this month')
  if(b.amount!==undefined&&b.amount>a.due)throw badRequest('Requested amount exceeds outstanding balance')
  const token=newPublicToken(),expiresAt=new Date(Date.now()+b.days*86400000)
  await prisma.statementLink.create({data:{tokenHash:tokenHash(token),supplierId:s.id,month:b.month,requestedAmount:b.amount,paidAtIssue:a.paid,expiresAt}})
  return c.json({url:`${config.publicTrackBaseUrl}/s/${token}`,token,expiresAt:expiresAt.toISOString()},201)
 })
 .delete('/:code/statement-link',requireRole('admin'),async c=>{
  const s=await prisma.supplier.findUnique({where:{code:c.req.param('code')!}});if(!s)throw notFound('Supplier not found')
  await prisma.statementLink.updateMany({where:{supplierId:s.id,revokedAt:null},data:{revokedAt:new Date()}})
  return c.json({ok:true})
 })
 .get('/:code/statement-receipts',requireRole('admin'),async c=>{
  const rows=await prisma.statementReceipt.findMany({where:{link:{supplier:{code:c.req.param('code')!}}},include:{link:true},orderBy:{createdAt:'desc'},take:100})
  return c.json({receipts:rows.map(r=>({reference:r.reference,amount:num(r.amount),method:r.method,txnRef:r.txnRef,status:r.status,month:r.link.month,at:r.createdAt.toISOString()}))})
 })
 .post('/:code/statement-receipts/:reference/approve',requireRole('admin'),async c=>{
  const receipt=await prisma.statementReceipt.findFirst({where:{reference:c.req.param('reference')!,link:{supplier:{code:c.req.param('code')!}}},include:{link:true}})
  if(!receipt||receipt.status!=='pending')throw badRequest('No pending receipt')
  const a=await amounts(receipt.link)
  let left=num(receipt.amount)
  if(left>a.requested)throw badRequest('Receipt exceeds the current outstanding request; reconcile the receipt before approval')
  for(const s of a.rows){const amount=Math.min(left,Math.max(0,money(effectiveBill(s)-num(s.paidAmount))));if(amount>0){await recordShipmentPayment(s,amount,receipt.method,'Admin',receipt.txnRef);left=money(left-amount)}}
  if(left>0)throw badRequest('Receipt allocation failed')
  await prisma.statementReceipt.update({where:{id:receipt.id},data:{status:'approved'}})
  return c.json({ok:true})
 })
 .post('/:code/statement-receipts/:reference/reject',requireRole('admin'),async c=>{
  const r=await prisma.statementReceipt.findFirst({where:{reference:c.req.param('reference')!,status:'pending',link:{supplier:{code:c.req.param('code')!}}}})
  if(!r)throw badRequest('No pending receipt')
  await prisma.statementReceipt.update({where:{id:r.id},data:{status:'rejected'}})
  return c.json({ok:true})
 })
export const publicStatementRoutes=new Hono()
 .get('/:token',async c=>{
  if(!await rateLimit('statement-public',120))throw new HttpError(429,'Too many requests')
  const link=await resolve(c.req.param('token')),a=await amounts(link)
  const pending=await prisma.statementReceipt.count({where:{status:'pending',link:{supplierId:link.supplierId,month:link.month}}})
  return c.json({statement:{supplier:link.supplier.name,month:link.month,expiresAt:link.expiresAt.toISOString(),due:a.due,paid:a.paid,requested:a.requested,pending:pending>0,rows:a.rows.map(s=>({code:s.code,billed:effectiveBill(s),paid:num(s.paidAmount),due:money(Math.max(0,effectiveBill(s)-num(s.paidAmount)))})),payMethods:await payMethodsFor(link.supplier.code)}})
 })
 .post('/:token/receipt',async c=>{
  if(!await rateLimit('statement-receipt',10))throw new HttpError(429,'Too many requests')
  const link=await resolve(c.req.param('token'))
  const b=z.object({methodId:z.string(),amount:z.number().positive().multipleOf(0.01).max(9999999999),txnRef:z.string().trim().min(3).max(100)}).parse(await c.req.json())
  const method=(await prisma.payMethod.findMany({where:{enabled:true}})).find(m=>publicMethodKey(m.id)===b.methodId)
  if(!method)throw badRequest('Unknown payment method')
  const name=await receivingFundName(method),a=await amounts(link)
  if(b.amount>a.requested)throw badRequest('Amount exceeds the current payment request')
  if(await prisma.statementReceipt.count({where:{status:'pending',link:{supplierId:link.supplierId,month:link.month}}}))throw badRequest('A receipt is already awaiting review')
  if(await prisma.statementReceipt.count({where:{method:name,txnRef:b.txnRef,status:{in:['pending','approved']}}})||await prisma.receipt.count({where:{method:name,txnRef:b.txnRef,status:{in:['pending','approved']}}})||await prisma.payment.count({where:{method:name,reference:{endsWith:`/ ${b.txnRef}`}}}))throw badRequest('This transaction reference was already submitted')
  await prisma.statementReceipt.create({data:{linkId:link.id,amount:b.amount,method:name,txnRef:b.txnRef}})
  return c.json({ok:true},201)
 })
