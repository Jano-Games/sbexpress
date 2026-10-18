import PDFDocument from 'pdfkit'
import { existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import type { Prisma } from '@prisma/client'
import { invoiceBillLines } from './invoiceLines'
import { effectiveBill, num } from './serialize'

type InvoiceShipment = Prisma.ShipmentGetPayload<{ include: { invoice: true; flight: true } }>
export const cleanFlightCode = (code: string) => code.replace(/-\d{8}-[a-z0-9]+$/i, '').replace(/\+/g, '-')

export async function invoicePdf(s: InvoiceShipment): Promise<Buffer> {
  const candidates = [new URL('./assets/fonts/NotoSansBengali.ttf', import.meta.url), new URL('../../assets/fonts/NotoSansBengali.ttf', import.meta.url)]
  const font = candidates.find(url => existsSync(url))
  if (!font) throw new Error('Invoice font asset is missing')
  const doc = new PDFDocument({ size: 'A4', margin: 48, bufferPages: true, font: fileURLToPath(font), info: { Title: `Invoice ${s.invoice?.number ?? s.code}`, Author: 'Sichuan Bangla Express' } })
  const chunks: Buffer[] = []
  const output = new Promise<Buffer>((resolve, reject) => { doc.on('data', chunk => chunks.push(chunk)); doc.on('end', () => resolve(Buffer.concat(chunks))); doc.on('error', reject) })
  const right = 547, width = 499
  const colors = { text: '#202937', muted: '#647080', border: '#d9dee6', brand: '#2459b8' }
  const currency = s.invoice?.sourceCurrency ?? 'BDT', fx = Number(s.invoice?.sourceFxRate ?? 1)
  const money = (amount: number) => `${currency} ${(amount === 0 ? 0 : amount / fx).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  const date = (value: Date) => value.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' })
  const rule = (at: number) => doc.moveTo(48, at).lineTo(right, at).strokeColor(colors.border).lineWidth(0.6).stroke()

  const heading = () => {
    doc.fillColor(colors.brand).fontSize(16).text('Sichuan Bangla Express', 48, 36, { width: 300 })
    doc.fillColor(colors.text).fontSize(21).text(s.invoice?.state==='issued' ? 'Invoice' : 'Draft estimate', 350, 30, { width: 197, align: 'right' })
    doc.fillColor(colors.muted).fontSize(10).text(s.invoice?.number ?? s.code, 300, 68, { width: 247, align: 'right' })
    if (s.invoice?.state!=='issued' || s.invoice?.needsReview) doc.fontSize(9).text(s.invoice?.needsReview?'PRICING REVIEW — DO NOT PAY':'DRAFT — DO NOT PAY', 48, 68, { width: 245 })
    rule(96)

    doc.fillColor(colors.muted).fontSize(9).text('Shipment', 48, 114, { width: 230 }).text(s.invoice?.state==='issued'?'Issue date':'Prepared date', 316, 114, { width: 231 })
    doc.fillColor(colors.text).fontSize(11).text(s.code, 48, 132, { width: 230 }).text(date(s.invoice?.issuedAt ?? s.createdAt), 316, 132, { width: 231 })
    if (s.flight) {
      doc.fillColor(colors.muted).fontSize(9).text('Flight', 48, 164, { width: 230 })
      doc.fillColor(colors.text).fontSize(10).text(`${cleanFlightCode(s.flight.code)} | ${date(s.flight.date)}`, 48, 182, { width: 230 })
    }
    doc.fillColor(colors.muted).fontSize(9).text('Invoice currency', 316, 164, { width: 231 })
    doc.fillColor(colors.text).fontSize(10).text(`${currency} | BDT rate ${fx}`, 316, 182, { width: 231 })
    doc.fillColor(colors.muted).fontSize(10).text('Description', 48, 225, { width: 340 }).text(`Amount (${currency})`, 398, 225, { width: 149, align: 'right' })
    rule(249)
    return 264
  }

  let y = heading()
  const ensure = (height: number) => { if (y + height > 760) { doc.addPage(); y = heading() } }
  const lines = invoiceBillLines(s)
  for (const line of lines) {
    doc.fontSize(10)
    const height = Math.max(26, doc.heightOfString(line.label, { width: 340 }) + 14)
    ensure(height)
    doc.fillColor(colors.text).text(line.label, 48, y, { width: 340 })
    doc.text(money(line.amount), 398, y, { width: 149, align: 'right' })
    y += height
    rule(y - 6)
  }

  ensure(190)
  y += 14
  const total = effectiveBill(s), discount = num(s.invoice?.discount), paid = num(s.paidAmount)
  const row = (label: string, amount: number) => {
    doc.fontSize(10).fillColor(colors.muted).text(label, 48, y, { width: 330 })
    doc.fillColor(colors.text).text(money(amount), 378, y, { width: 169, align: 'right' })
    y += 27
  }
  row('Subtotal', total + discount)
  if (discount) row('Discount / credit', -discount)
  row('Total bill', total)
  row('Verified payments', -paid)
  rule(y + 2)
  y += 17
  doc.fillColor(colors.text).fontSize(12).text(s.invoice?.state==='issued'&&!s.invoice.needsReview?'Amount due':'Estimate — not payable', 48, y, { width: 260 })
  doc.fontSize(14).text(money(Math.max(0, total - paid)), 308, y - 2, { width: 239, align: 'right' })
  y += 43
  if (s.invoice?.note) {
    const height = doc.fontSize(9).heightOfString(s.invoice.note, { width })
    ensure(height + 18)
    doc.fillColor(colors.muted).text(s.invoice.note, 48, y, { width })
  }

  const pages = doc.bufferedPageRange()
  for (let page = 0; page < pages.count; page++) {
    doc.switchToPage(page)
    rule(767)
    doc.fontSize(8).fillColor(colors.muted).text(`Sichuan Bangla Express | ${currency} | BDT rate ${fx} | Page ${page + 1} of ${pages.count}`, 48, 778, { width, lineBreak: false, align: 'center' })
  }
  doc.end()
  return output
}
