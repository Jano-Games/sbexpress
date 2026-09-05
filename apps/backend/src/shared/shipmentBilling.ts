import { Prisma } from '@prisma/client'
import { prisma } from '../core/db'
import { notFound } from '../core/errors'
import { num } from './serialize'
import { snapshotInvoice } from './customerCredit'

export const draftBillLines = (s: {charge:Prisma.Decimal;customsTax:Prisma.Decimal;afterSalesFee:Prisma.Decimal}) => [
  {label:'Shipment charges',amount:num(s.charge)},
  ...(num(s.customsTax) ? [{label:'Customs tax',amount:num(s.customsTax)}] : []),
  ...(num(s.afterSalesFee) ? [{label:'After-sales credit',amount:-num(s.afterSalesFee)}] : []),
]

/** Called inside the expense transaction: the new cost is also a customer charge. */
export async function addShipmentBillCharge(shipmentId:string, category:string, amount:number) {
  const s=await prisma.shipment.findUnique({where:{id:shipmentId},include:{invoice:true,supplier:true}})
  if(!s) throw notFound('Shipment not found')
  const label=({courier:'Courier charge',packaging:'Packaging charge',transport:'Transport charge',customs:'Additional customs charge',ticket:'Ticket charge',salary:'Service charge',others:'Other shipment charge'} as Record<string,string>)[category] ?? 'Additional shipment charge'
  const lines=[...(s.invoice ? s.invoice.lines as {label:string;amount:number}[] : draftBillLines(s)),{label,amount}]
  const discount=num(s.invoice?.discount)
  const total=Math.round((lines.reduce((sum,line)=>sum+line.amount,0)-discount)*100)/100
  const invoice=await prisma.invoice.upsert({where:{shipmentId},
    create:{shipmentId,supplierId:s.supplierId,number:`INV-${new Date().toISOString().slice(2,7).replace('-','')}-${s.code}`,lines,total},
    update:{lines,total},
  })
  await snapshotInvoice(invoice,`Shipment expense billed: ${label}`)
  await prisma.shipment.update({where:{id:shipmentId},data:{payStatus:num(s.paidAmount)>=total?'paid':num(s.paidAmount)>0?'partial':s.supplier.terms==='monthly'?'monthly':'unpaid'}})
}
