import {Hono} from 'hono'
import {prisma} from '../core/db'
import {requireRole,type AppEnv} from './auth'
import {money} from '../shared/customerCredit'
import {isUnpaidFlightCost} from '../shared/flightCosts'
export const reconciliationRoutes=new Hono<AppEnv>().get('/reconciliation',requireRole('admin'),async c=>{
 const [accounts,payments,expenses,refunds,transfers,shipments,credits]=await Promise.all([prisma.account.findMany(),prisma.payment.findMany(),prisma.expense.findMany(),prisma.customerRefund.findMany(),prisma.fundTransfer.findMany(),prisma.shipment.findMany(),prisma.customerCredit.findMany()])
 const missingPostings=[...payments.filter(x=>x.accountAmount===null).map(x=>({kind:'payment',reference:x.reference,amount:Number(x.amount)})),...expenses.filter(x=>x.accountAmount===null&&!isUnpaidFlightCost(x)).map(x=>({kind:'expense',reference:x.reason,amount:Number(x.amount)}))]
 const shipmentDifferences=shipments.map(s=>{const recorded=money(payments.filter(p=>p.shipmentId===s.id&&p.kind==='customer').reduce((a,p)=>a+Number(p.amount),0)-credits.filter(x=>x.shipmentCode===s.code).reduce((a,x)=>a+Number(x.amount),0));return{code:s.code,allocatedPaid:Number(s.paidAmount),ledgerPaid:recorded,difference:money(Number(s.paidAmount)-recorded)}}).filter(x=>x.difference!==0)
 const rows=accounts.map(a=>{
 const net=money(payments.filter(p=>p.accountName===a.name).reduce((v,p)=>v+Number(p.accountAmount??0),0)-expenses.filter(p=>p.accountName===a.name).reduce((v,p)=>v+Number(p.accountAmount??0),0)-refunds.filter(p=>p.accountName===a.name).reduce((v,p)=>v+Number(p.accountAmount),0)+transfers.filter(t=>t.toName===a.name).reduce((v,t)=>v+Number(t.receivedAmount),0)-transfers.filter(t=>t.fromName===a.name).reduce((v,t)=>v+Number(t.amount),0))
 return{name:a.name,currency:a.currency,balance:Number(a.balance),recordedNetMovement:net,impliedOpeningBalance:money(Number(a.balance)-net)}
 })
 return c.json({accounts:rows,missingPostings,shipmentDifferences,note:'Implied opening balances are derived from current balances and recorded movements. Verify these against bank/cash records; missing historical postings are not reconstructed automatically.'})
})
