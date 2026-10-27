import { publicReceiptSummary } from '../shared/receiptHistory'
import { sealLinkToken, savedLink } from '../shared/savedLinks'
import { reserveReceiptScreenshot, acceptReceiptScreenshot, screenshotSelect } from '../shared/receiptScreenshots'
import { moneyBody, sourceFields, sourceAt, withSavedMoney } from '../shared/money'
import { getSettings } from '../shared/settings'
import { receivingFundName } from '../shared/bankAccounts'
import {Hono} from 'hono'
import {z} from 'zod'
import {prisma} from '../core/db'
import {badRequest,notFound,HttpError} from '../core/errors'
import {rateLimit} from '../core/redis'
import {config} from '../core/config'
import {requireRole,type AppEnv} from './auth'
import {newPublicToken,tokenHash,validToken,isLive} from '../shared/publicLinks'
import {effectiveBill,num} from '../shared/serialize'
import {money} from '../shared/customerCredit'
import {payMethodsFor,payMethodName} from './track'
import {recordShipmentPayment} from './shipments'
import {issuePendingInvoices} from '../shared/shipmentBilling'
const monthSchema=z.string().regex(/^20\d{2}-(0[1-9]|1[0-2])$/)
async function rowsFor(supplierId:string,month:string){
 const start=new Date(`${month}-01T00:00:00Z`),end=new Date(start);end.setUTCMonth(end.getUTCMonth()+1)
 return prisma.shipment.findMany({where:{supplierId,createdAt:{gte:start,lt:end}},include:{supplier:true,flight:true,receipts:true,invoice:true,expenses:true,costs:true},orderBy:[{createdAt:'asc'},{code:'asc'}]})
}
async function resolve(token:string){
 if(!validToken(token))throw notFound('Link unavailable or expired')
 const link=await prisma.statementLink.findUnique({where:{tokenHash:tokenHash(token)},include:{supplier:true}})
 if(!link||!isLive(link))throw notFound('Link unavailable or expired')
 return link
}
async function amounts(link:{supplierId:string;month:string;requestedAmount:unknown;paidAtIssue:unknown}){
 const rows=(await rowsFor(link.supplierId,link.month)).filter(s=>s.invoice?.state==='issued'&&!s.invoice.needsReview)
 const due=money(rows.reduce((a,s)=>a+Math.max(0,effectiveBill(s)-num(s.paidAmount)),0))
 const paid=money(rows.reduce((a,s)=>a+num(s.paidAmount),0))
 const requested=link.requestedAmount===null?due:money(Math.max(0,Math.min(due,Number(link.requestedAmount)-Math.max(0,paid-Number(link.paidAtIssue)))))
 return {rows,due,paid,requested}
}
export const statementAdminRoutes=new Hono<AppEnv>()
 .get('/:code/statement-links',requireRole('admin'),async c=>{
  const supplier=await prisma.supplier.findUnique({where:{code:c.req.param('code')!}})
  if(!supplier)throw notFound('Customer not found')
  const month=monthSchema.parse(c.req.query('month'))
  const rows=await prisma.statementLink.findMany({where:{supplierId:supplier.id,month},orderBy:{createdAt:'desc'}})
  const balance=await amounts({supplierId:supplier.id,month,requestedAmount:null,paidAtIssue:0})
  return c.json({links:rows.map(row=>savedLink(row,'s')),balance:{billed:money(balance.rows.reduce((sum,row)=>sum+effectiveBill(row),0)),paid:balance.paid,due:balance.due}})
 })
 .post('/:code/statement-link',requireRole('admin'),async c=>{
  const b=z.object({month:monthSchema,days:z.number().int().min(1).max(90).default(7),amount:z.number().positive().multipleOf(0.01).optional()}).parse(moneyBody(await c.req.json(), ['amount']))
  const s=await prisma.supplier.findUnique({where:{code:c.req.param('code')!}});if(!s)throw notFound('Customer not found')
  // This customer's bills still waiting to be issued are issued first, so the statement includes them.
  await issuePendingInvoices({supplierId:s.id})
  const a=await amounts({supplierId:s.id,month:b.month,requestedAmount:null,paidAtIssue:0})
  if(!a.rows.length)throw badRequest('No reviewed, issued invoices in this month. Issue invoices before sharing a payment statement.')
  if(b.amount!==undefined&&b.amount>a.due)throw badRequest('Requested amount exceeds outstanding balance')
  const token=newPublicToken(),expiresAt=new Date(Date.now()+b.days*86400000)
  await prisma.statementLink.create({data:{tokenHash:tokenHash(token),tokenCiphertext:sealLinkToken(token),supplierId:s.id,month:b.month,requestedAmount:b.amount,paidAtIssue:a.paid,expiresAt}})
  return c.json({url:`${config.publicTrackBaseUrl}/s/${token}`,token,expiresAt:expiresAt.toISOString()},201)
 })
 .delete('/:code/statement-link',requireRole('admin'),async c=>{
  const s=await prisma.supplier.findUnique({where:{code:c.req.param('code')!}});if(!s)throw notFound('Customer not found')
  await prisma.statementLink.updateMany({where:{supplierId:s.id,revokedAt:null},data:{revokedAt:new Date()}})
  return c.json({ok:true})
 })
 .get('/:code/statement-receipts',requireRole('admin'),async c=>{
  const rows=await prisma.statementReceipt.findMany({where:{link:{supplier:{code:c.req.param('code')!}}},include:{link:true,screenshot:{select:screenshotSelect}},orderBy:{createdAt:'desc'},take:100})
  return c.json({receipts:rows.map(r=>({reference:r.reference,sourceCurrency:r.sourceCurrency,sourceAmount:num(r.sourceAmount),sourceFxRate:num(r.sourceFxRate),screenshot:r.screenshot,amount:num(r.amount),method:r.method,txnRef:r.txnRef,status:r.status,reason:r.reviewReason,reviewedBy:r.reviewedByName,month:r.link.month,at:r.createdAt.toISOString()}))})
 })
 .post('/:code/statement-receipts/:reference/approve',requireRole('admin'),async c=>{
  const receipt=await prisma.statementReceipt.findFirst({where:{reference:c.req.param('reference')!,link:{supplier:{code:c.req.param('code')!}}},include:{link:true}})
  if(!receipt||receipt.status!=='pending')throw badRequest('No pending receipt')
  const a=await amounts(receipt.link)
  let left=num(receipt.amount)
  if(left>a.requested)throw badRequest('Receipt exceeds the current outstanding request; reconcile the receipt before approval')
  for(const s of a.rows){const amount=Math.min(left,Math.max(0,money(effectiveBill(s)-num(s.paidAmount))));if(amount>0){await withSavedMoney(receipt, () => recordShipmentPayment(s,amount,receipt.method,c.get('user').name,receipt.txnRef,{statementReceiptId:receipt.id}));left=money(left-amount)}}
  if(left>0)throw badRequest('Receipt allocation failed')
  await prisma.todo.updateMany({where:{statementReceiptId:receipt.id},data:{done:true}})
  await prisma.statementReceipt.update({where:{id:receipt.id},data:{status:'approved',reviewedAt:new Date(),reviewedById:c.get('user').id,reviewedByName:c.get('user').name,reviewReason:''}})
  return c.json({ok:true})
 })
 .post('/:code/statement-receipts/:reference/reject',requireRole('admin'),async c=>{
  const {reason}=z.object({reason:z.string().trim().min(3).max(500)}).parse(await c.req.json())
  const r=await prisma.statementReceipt.findFirst({where:{reference:c.req.param('reference')!,status:'pending',link:{supplier:{code:c.req.param('code')!}}}})
  if(!r)throw badRequest('No pending receipt')
  await prisma.todo.updateMany({where:{statementReceiptId:r.id},data:{done:true}})
  await prisma.statementReceipt.update({where:{id:r.id},data:{status:'rejected',reviewedAt:new Date(),reviewedById:c.get('user').id,reviewedByName:c.get('user').name,reviewReason:reason}})
  return c.json({ok:true})
 })
export const publicStatementRoutes=new Hono()
 .get('/:token',async c=>{
  if(!await rateLimit(`statement-public:${tokenHash(c.req.param('token'))}`,120))throw new HttpError(429,'Too many requests')
  const link=await resolve(c.req.param('token')),a=await amounts(link)
  const pricingPending=(await rowsFor(link.supplierId,link.month)).filter(s=>s.invoice?.state!=='issued'||s.invoice.needsReview).length
  const pending=await prisma.statementReceipt.count({where:{status:'pending',link:{supplierId:link.supplierId,month:link.month}}})
  const receiptHistory=await prisma.statementReceipt.findMany({where:{link:{supplierId:link.supplierId,month:link.month}},orderBy:{createdAt:'desc'},include:{payments:true}})
  return c.json({statement:{pricingPending,receiptHistory:receiptHistory.map(publicReceiptSummary),exchangeRates:(await getSettings()).exchangeRates,supplier:link.supplier.name,month:link.month,expiresAt:link.expiresAt.toISOString(),due:a.due,paid:a.paid,requested:a.requested,pending:pending>0,rows:a.rows.map(s=>({code:s.code,billed:effectiveBill(s),paid:num(s.paidAmount),due:money(Math.max(0,effectiveBill(s)-num(s.paidAmount)))})),payMethods:await payMethodsFor(link.supplier.code)}})
 })
 .post('/:token/receipt-image/upload',async c=>{
  const link=await resolve(c.req.param('token'))
  return c.json(await reserveReceiptScreenshot(link.tokenHash,'statement',await c.req.json()),201)
 })
 .post('/:token/receipt',async c=>{
  if(!await rateLimit(`statement-receipt:${tokenHash(c.req.param('token'))}`,10))throw new HttpError(429,'Too many requests')
  const link=await resolve(c.req.param('token'))
  const b=z.object({methodId:z.string(),amount:z.number().positive().multipleOf(0.01).max(9999999999),txnRef:z.string().trim().min(3).max(100),imageReference:z.string().uuid().optional()}).parse(moneyBody(await c.req.json(), ['amount']))
  const method=(await prisma.payMethod.findMany({where:{enabled:true},include:{account:true}})).find(m=>m.publicReference===b.methodId)
  if(!method)throw badRequest('Unknown payment method')
  if(sourceFields(0).sourceCurrency !== (method.account?.currency ?? 'BDT'))throw badRequest('Enter the amount in the selected account currency')
  const name=await receivingFundName(method),a=await amounts(link)
  if(b.amount>a.requested)throw badRequest('Amount exceeds the current payment request')
  if(await prisma.statementReceipt.count({where:{status:'pending',link:{supplierId:link.supplierId,month:link.month}}}))throw badRequest('A receipt is already awaiting review')
  if(await prisma.statementReceipt.count({where:{method:name,txnRef:b.txnRef,status:{in:['pending','approved']}}})||await prisma.receipt.count({where:{method:name,txnRef:b.txnRef,status:{in:['pending','approved']}}})||await prisma.payment.count({where:{method:name,reference:{endsWith:`/ ${b.txnRef}`}}}))throw badRequest('This transaction reference was already submitted')
  const screenshotReference=await acceptReceiptScreenshot(b.imageReference,link.tokenHash,'statement')
  const receipt=await prisma.statementReceipt.create({data:{...sourceFields(b.amount),linkId:link.id,amount:b.amount,method:name,txnRef:b.txnRef,screenshotReference}})
  await prisma.todo.create({data:{role:'admin',auto:true,statementReceiptId:receipt.id,text:`Review monthly receipt — ${link.supplier.code} / ${link.month}`}})
  return c.json({ok:true},201)
 })
