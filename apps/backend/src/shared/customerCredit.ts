import { sourceFields } from './money'
import type { Invoice } from '@prisma/client'
import { prisma } from '../core/db'
import { badRequest } from '../core/errors'
export const money=(n:number)=>Math.round(n*100)/100
export async function changeCredit(supplierId:string,amount:number,kind:string,reason:string,shipmentCode?:string){
 const supplier=await prisma.supplier.findUniqueOrThrow({where:{id:supplierId}})
 if(money(Number(supplier.creditBalance)+amount)<0)throw badRequest('Insufficient customer credit')
 await prisma.supplier.update({where:{id:supplierId},data:{creditBalance:{increment:amount}}})
 return prisma.customerCredit.create({data:{...sourceFields(amount),supplierId,amount,kind,reason,shipmentCode}})
}
export async function snapshotInvoice(inv:Invoice,reason:string){
 const version=await prisma.invoiceRevision.count({where:{invoiceId:inv.id}})+1
 await prisma.invoiceRevision.create({data:{invoiceId:inv.id,version,reason,snapshot:{state:inv.state,pricingMode:inv.pricingMode,needsReview:inv.needsReview,issuedAt:inv.issuedAt.toISOString(),sourceCurrency:inv.sourceCurrency,sourceFxRate:Number(inv.sourceFxRate),sourceAmount:Number(inv.sourceAmount),number:inv.number,lines:inv.lines,discount:Number(inv.discount),total:Number(inv.total),note:inv.note}}})
}
export async function releaseExcessPaid(s:{id:string;supplierId:string;code:string;paidAmount:unknown},total:number,reason:string){
 const excess=money(Math.max(0,Number(s.paidAmount)-total))
 if(excess){await changeCredit(s.supplierId,excess,'bill-reduction',reason,s.code);await prisma.shipment.update({where:{id:s.id},data:{paidAmount:total}})}
 return excess
}
