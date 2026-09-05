import { invoicePdf } from '../shared/invoicePdf'
import { draftBillLines } from '../shared/shipmentBilling'
import { receivingFundName } from '../shared/bankAccounts'
/** Public bearer-capability pages. Tokens are random, hashed at rest,
 * scoped to one shipment, expiring and revocable. Authorization is never cached. */

import { Hono } from 'hono'
import { z } from 'zod'
import { prisma } from '../core/db'
import { rateLimit } from '../core/redis'
import { resolvePublicLink, publicMethodKey } from '../shared/publicLinks'
import { notFound, HttpError } from '../core/errors'
import { STATUS_LABEL, statusIndex } from '../shared/status'
import { effectiveBill, num, numOrNull, isoDate } from '../shared/serialize'
import { uploadReceipt } from './shipments'

/** Tab label: provider for wallets, bank name for accounts. */
export const payMethodName = (m: { kind: string; provider: string; bankName: string }): string =>
  m.kind === 'mobile_banking' ? m.provider : m.bankName

/** Enabled payment rails from settings, "{code}" in notes substituted. */
export async function payMethodsFor(shipmentCode: string) {
  const methods = await prisma.payMethod.findMany({ where: { enabled: true }, orderBy: { order: 'asc' } })
  return methods.map((m) => ({
    id: publicMethodKey(m.id),
    kind: m.kind,
    name: payMethodName(m),
    provider: m.provider,
    label: m.label,
    number: m.number,
    note: m.note.replaceAll('{code}', shipmentCode),
    qrImage: m.qrImage,
    bankName: m.bankName,
    accountNumber: m.accountNumber,
    accountName: m.accountName,
    branch: m.branch,
    district: m.district,
  }))
}

function trackNote(index: number, lastMile: { courier: string; ref: string } | null): string {
  if (index >= 8) return `Delivered${lastMile ? ` via ${lastMile.courier} (${lastMile.ref})` : ''}.`
  if (index >= 5) return 'At our Bashundhara hub — out for delivery soon.'
  if (index >= 3) return 'In the air, Chengdu → Dhaka.'
  return 'Being prepared at our Chengdu hub.'
}

async function findByToken(token: string) {
  const link = await resolvePublicLink(token)
  const shipment = await prisma.shipment.findUnique({
    where: { id: link.shipmentId },
    include: {
      supplier: true,
      flight: { include: { legs: { orderBy: { order: 'asc' } } } },
      receipt: true,
      expenses: true,
      invoice: true,
      logs: { orderBy: { at: 'desc' }, take: 1 },
    },
  })
  if (!shipment) throw notFound('Unknown tracking link')
  return { shipment, link }
}

const clientIp = (headers: Headers): string =>
  'public' // Shared bucket cannot be bypassed with forged proxy headers

export const trackRoutes = new Hono()
  .get('/:token', async (c) => {
    if (!(await rateLimit(`track:${clientIp(c.req.raw.headers)}`, 120))) {
      throw new HttpError(429, 'Too many requests — slow down')
    }
    const token = c.req.param('token')
    const { shipment: s, link } = await findByToken(token)
    const index = statusIndex(s.status)
    const totalBill = effectiveBill(s)
    const paidSoFar = num(s.paidAmount)
    const due = Math.max(0, Math.round((totalBill - paidSoFar) * 100) / 100)
    const pending = s.receipt?.status === 'pending'
    const kg = numOrNull(s.weighedKg) ?? num(s.bookedKg)

    const legs = s.flight?.legs ?? []
    const routeLabel = legs.length
      ? [legs[0]!.fromIata || legs[0]!.fromCity || '?', ...legs.map((l) => l.toIata || l.toCity || '?')].join(' → ')
      : 'CTU → DAC'

    const requestRemaining = link.requestedAmount === null ? due : Math.max(0, Math.min(due, num(link.requestedAmount) - Math.max(0, paidSoFar - num(link.paidAtIssue))))
    const payload = {
      shipment: {
        code: s.code,
        expiresAt: link.expiresAt.toISOString(),
        requestedAmount: requestRemaining,
        invoice: link.scope === 'invoice' && s.invoice ? {
          number: s.invoice.number, lines: s.invoice.lines, discount: num(s.invoice.discount),
          total: num(s.invoice.total), note: s.invoice.note, issuedAt: s.invoice.issuedAt.toISOString(),
        } : null,
        statusLabel: STATUS_LABEL[s.status],
        statusIndex: index,
        contents: `${s.categories.join(', ')} · ${s.description}`,
        kgLabel: kg > 0 ? `${kg} kg` : 'devices',
        flightCode: s.flight?.code ?? '—',
        flightDate: s.flight ? isoDate(s.flight.date) : null,
        depTime: s.flight && s.flight.depTime !== '—' ? s.flight.depTime : null,
        arrTime: s.flight && s.flight.arrTime !== '—' ? s.flight.arrTime : null,
        via: s.flight && s.flight.via !== 'Direct' ? s.flight.via : null,
        routeLabel,
        updatedAt: (s.logs[0]?.at ?? s.createdAt).toISOString(),
        note: trackNote(index, s.lastMileCourier ? { courier: s.lastMileCourier, ref: s.lastMileRef ?? '' } : null),
        due,
        totalBill,
        billLines: (s.invoice ? s.invoice.lines as {label:string;amount:number}[] : draftBillLines(s)).map(line=>({label:line.label,amount:line.amount})),
        billSubtotal: Math.round((totalBill + num(s.invoice?.discount))*100)/100,
        invoiceNumber: s.invoice?.number ?? null,

        paidSoFar,
        discount: num(s.invoice?.discount ?? null),
        showPay: requestRemaining > 0 && !pending,
        showPaid: due <= 0,
        showPending: pending,
        payMethods: await payMethodsFor(s.code),
      },
    }
    return c.json(payload)
  })

  .get('/:token/invoice.pdf', async c=>{
    if(!(await rateLimit('track-pdf:public',60))) throw new HttpError(429,'Too many downloads — try again shortly')
    const {shipment}=await findByToken(c.req.param('token'))
    const pdf=await invoicePdf(shipment)
    c.header('Content-Type','application/pdf')
    c.header('Content-Disposition',`${c.req.query('download')==='1'?'attachment':'inline'}; filename="invoice-${shipment.code.replace(/[^A-Za-z0-9_-]/g,'')}.pdf"`)
    return c.body(new Uint8Array(pdf))
  })

  .post('/:token/receipt', async (c) => {
    if (!(await rateLimit(`track-upload:${clientIp(c.req.raw.headers)}`, 10))) {
      throw new HttpError(429, 'Too many uploads — slow down')
    }
    const { methodId, amount, txnRef } = z.object({
      methodId: z.string().min(1), amount: z.number().positive().max(9999999999).multipleOf(0.01),
      txnRef: z.string().trim().min(3).max(100),
    }).parse(await c.req.json())
    const { shipment, link } = await findByToken(c.req.param('token'))
    const known = (await prisma.payMethod.findMany({ where: { enabled: true } })).find(m => publicMethodKey(m.id) === methodId)
    if (!known) throw notFound('Unknown payment method')
    const due = Math.max(0, effectiveBill(shipment) - num(shipment.paidAmount))
    const limit = link.requestedAmount === null ? due : Math.max(0, Math.min(due, num(link.requestedAmount) - Math.max(0, num(shipment.paidAmount) - num(link.paidAtIssue))))
    if (amount > limit) throw new HttpError(400, 'Amount exceeds this payment request')
    const result = await uploadReceipt(shipment, await receivingFundName(known), 'Customer', amount, txnRef)
    return c.json({ ok: true, ...result }, 201)
  })
