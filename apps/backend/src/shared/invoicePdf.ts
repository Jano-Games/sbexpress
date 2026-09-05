import PDFDocument from 'pdfkit'
import { existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import type { Prisma } from '@prisma/client'
import { draftBillLines } from './shipmentBilling'
import { effectiveBill, num } from './serialize'

type InvoiceShipment = Prisma.ShipmentGetPayload<{include:{invoice:true,flight:true}}>
export const cleanFlightCode=(code:string)=>code.replace(/-\d{8}-[a-z0-9]+$/i,'').replace(/\+/g,'-')

export async function invoicePdf(s:InvoiceShipment):Promise<Buffer> {
  const candidates=[new URL('./assets/fonts/NotoSansBengali.ttf',import.meta.url),new URL('../../assets/fonts/NotoSansBengali.ttf',import.meta.url)]
  const font=candidates.find(url=>existsSync(url))
  if(!font) throw new Error('Invoice font asset is missing')
  const doc=new PDFDocument({size:'A4',margin:48,bufferPages:true,font:fileURLToPath(font),info:{Title:`Invoice ${s.invoice?.number ?? s.code}`,Author:'Sichuan Bangla Express'}})
  const chunks:Buffer[]=[]
  const output=new Promise<Buffer>((resolve,reject)=>{doc.on('data',chunk=>chunks.push(chunk));doc.on('end',()=>resolve(Buffer.concat(chunks)));doc.on('error',reject)})
  const right=547, width=499
  const money=(amount:number)=>`BDT ${amount.toLocaleString('en-IN',{minimumFractionDigits:2,maximumFractionDigits:2})}`
  const date=(value:Date)=>value.toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric',timeZone:'UTC'})
  const heading=()=>{
    doc.rect(0,0,596,108).fill('#0f766e')
    doc.fillColor('white').fontSize(21).text('Sichuan Bangla Express',48,31,{width})
    doc.fontSize(10).text(s.invoice?'INVOICE':'BILL SUMMARY · DRAFT',48,69,{width})
    doc.fillColor('#182322').fontSize(10)
    doc.text(s.invoice?.number ?? s.code,48,131,{width})
    doc.text(`Shipment: ${s.code}`,48,155,{width})
    doc.text(`Issued: ${date(s.invoice?.issuedAt ?? s.createdAt)}`,48,176,{width})
    if(s.flight)doc.text(`Flight: ${cleanFlightCode(s.flight.code)}  |  ${date(s.flight.date)}`,48,197,{width})
    doc.fillColor('#53615e').fontSize(9).text('DESCRIPTION',48,233,{width:350}).text('AMOUNT (BDT)',398,233,{width:149,align:'right'})
    doc.moveTo(48,254).lineTo(right,254).strokeColor('#dce4e1').stroke()
    return 266
  }
  let y=heading()
  const ensure=(height:number)=>{if(y+height>760){doc.addPage();y=heading()}}
  const lines=s.invoice ? s.invoice.lines as {label:string;amount:number}[] : draftBillLines(s)
  for(const line of lines){
    doc.fontSize(10)
    const height=Math.max(22,doc.heightOfString(line.label,{width:340})+14)
    ensure(height)
    doc.fillColor('#24312e').text(line.label,48,y,{width:340})
    doc.fillColor(line.amount<0?'#0f766e':'#24312e').text(money(line.amount),398,y,{width:149,align:'right'})
    y+=height;doc.moveTo(48,y-6).lineTo(right,y-6).strokeColor('#edf0ee').stroke()
  }
  ensure(182);y+=12
  const total=effectiveBill(s),discount=num(s.invoice?.discount),paid=num(s.paidAmount)
  const row=(label:string,amount:number,color='#24312e')=>{doc.fontSize(11).fillColor(color).text(label,48,y,{width:330}).text(money(amount),378,y,{width:169,align:'right'});y+=27}
  row('Subtotal',total+discount)
  if(discount)row('Discount / credit',-discount,'#0f766e')
  row('Total bill',total)
  row('Verified payments',-paid,'#0f766e')
  doc.rect(48,y-3,width,42).fill('#e5f2ef');y+=8
  row('AMOUNT DUE',Math.max(0,total-paid),'#0f766e');y+=20
  if(s.invoice?.note){const height=doc.fontSize(9).heightOfString(s.invoice.note,{width});ensure(height+18);doc.fillColor('#53615e').text(s.invoice.note,48,y,{width})}
  const pages=doc.bufferedPageRange()
  for(let page=0;page<pages.count;page++){doc.switchToPage(page);doc.fontSize(8).fillColor('#64716e').text(`Sichuan Bangla Express | All amounts in BDT | Page ${page+1} of ${pages.count}`,48,790,{width,align:'center'})}
  doc.end()
  return output
}
