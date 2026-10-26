import { assertFlightCapacity } from '../shared/flightCapacity'
import { currentActor, writeShipmentLog } from '../shared/actor'
import { latestReceipt } from '../shared/receiptHistory'
import { sealLinkToken, savedLink } from '../shared/savedLinks'
import { draftBillLines, invoiceBillLines } from '../shared/invoiceLines'
import { screenshotSelect } from '../shared/receiptScreenshots'
import { moneyBody, sourceFields, sourceAt, withSavedMoney } from '../shared/money'
import { invoicePdf } from '../shared/invoicePdf'
import { addShipmentBillCharge, ensureShipmentInvoice, refreshShipmentInvoice, invoiceSuggestion, calculatedInvoice, pricingFingerprint } from '../shared/shipmentBilling'
import { snapshotInvoice, releaseExcessPaid } from '../shared/customerCredit'
import { randomBytes } from 'node:crypto'
import { Hono } from 'hono'
import { Prisma, type PayStatus, type ShipmentStatus } from '@prisma/client'
import { z } from 'zod'
import { prisma } from '../core/db'
import { cacheInvalidate } from '../core/redis'
import { badRequest, forbidden, notFound } from '../core/errors'
import { requireRole, type AppEnv, type SessionUser } from './auth'
import { STATUS_LABEL, STATUS_ORDER, statusIndex } from '../shared/status'
import { billAmount, computeCharge, pcsTotal, weightDelta, type PcsItem } from '../shared/compute'
import { effectiveBill, paymentStatus, num, shipmentDetail, shipmentRow, type ShipmentWithRelations } from '../shared/serialize'
import { getSettings } from '../shared/settings'
import { creditPayment, debitCash } from '../shared/ledger'
import { config } from '../core/config'
import { newPublicToken, tokenHash } from '../shared/publicLinks'

const INCLUDE = { supplier: true, flight: true, receipts: true, expenses: true, costs: true, invoice: true } as const
const INCLUDE_FULL = {
  ...INCLUDE,
  receipts: { include: { screenshot: { select: screenshotSelect }, payments:true }, orderBy:{uploadedAt:'desc' as const} },
  flyer: true,
  logs: { orderBy: { at: 'desc' as const } },
  payments: { orderBy: { createdAt: 'asc' as const } },
} as const

const actorOf = (user: SessionUser): string => user.name

async function invalidateReads(): Promise<void> {
  await cacheInvalidate('dashboard')
  await cacheInvalidate('track')
}

async function findByCode(code: string) {
  const shipment = await prisma.shipment.findUnique({ where: { code }, include: INCLUDE_FULL })
  if (!shipment) throw notFound(`Shipment ${code} not found`)
  return shipment
}

async function log(shipmentId: string, actor: string, message: string): Promise<void> {
  await writeShipmentLog(shipmentId, message, actor)
}

/**
 * Record money received against one shipment: appends to the payment ledger,
 * credits the matching account, bumps paidAmount and derives the pay status
 * (partial until the effective bill is covered). Also used by supplier-level
 * payments, which allocate one amount across many shipments.
 */
export async function recordShipmentPayment(
  shipment: ShipmentWithRelations & { invoice?: { total: Prisma.Decimal; state: string; needsReview: boolean } | null },
  amount: number,
  method: string,
  actor: string,
  transactionReference?: string,
  links: {receiptId?:string;statementReceiptId?:string} = {},
): Promise<{ newPaid: number; fullyPaid: boolean; bill: number }> {
  if (shipment.invoice?.state !== "issued" || shipment.invoice.needsReview) throw badRequest("Review and issue the invoice before applying payment. Record an advance from the customer account if needed.")
  const bill = effectiveBill(shipment)
  if (!Number.isFinite(amount) || amount <= 0 || Math.abs(amount * 100 - Math.round(amount * 100)) > 0.00001) throw badRequest('Enter a positive amount with at most two decimals')
  if (amount > bill - num(shipment.paidAmount) + 0.005) throw badRequest('Payment exceeds outstanding balance')
  const newPaid = Math.round((num(shipment.paidAmount) + amount) * 100) / 100
  const fullyPaid = newPaid >= bill - 0.005
  await prisma.shipment.update({
    where: { id: shipment.id },
    data: { paidAmount: new Prisma.Decimal(newPaid), payStatus: fullyPaid ? 'paid' : 'partial', payMethod: method },
  })
  await creditPayment(method, amount, transactionReference ? `${shipment.code} / ${transactionReference}` : shipment.code, shipment.id, 'customer', undefined, {...links,supplierId:shipment.supplierId})
  await log(
    shipment.id,
    actor,
    `Payment ৳${amount.toLocaleString('en-IN')} via ${method} — ৳${newPaid.toLocaleString('en-IN')} of ৳${bill.toLocaleString('en-IN')} paid${fullyPaid ? ' ✓' : ''}`,
  )
  await invalidateReads()
  return { newPaid, fullyPaid, bill }
}

/** SH-101 → 101; next code continues from the highest existing number. */
async function nextShipmentCode(): Promise<string> {
  const rows = await prisma.shipment.findMany({ select: { code: true } })
  const max = rows.reduce((a, r) => Math.max(a, Number(r.code.replace(/\D/g, '')) || 0), 100)
  return `SH-${max + 1}`
}

const makeTrackToken = (code: string): string => randomBytes(32).toString('base64url')

const pcsItemsSchema = z
  .array(
    z.object({
      category: z.string().min(1).max(60),
      count: z.number().int().min(1),
      rate: z.number().min(0),
      currency: z.enum(['BDT', 'CNY']).default('BDT'),
      units: z.array(z.object({
        model: z.string().max(120).default(''),
        serial: z.string().max(120).default(''),
        serialPhotoRef: z.string().uuid().nullable().optional(),
      })).max(20).default([]),
    }),
  )
  .max(20)

/** Serial column stays a flat copy of the per-unit serials for display/search. */
const flattenSerials = (items: { units?: { serial: string }[] }[]): string[] =>
  items.flatMap((i) => (i.units ?? []).map((u) => u.serial.trim()).filter(Boolean))

export const shipmentRoutes = new Hono<AppEnv>()
  .get('/', async (c) => {
    const user = c.get('user')
    const { status, supplier, from, to } = c.req.query()
    const settings = await getSettings()

    const where: Prisma.ShipmentWhereInput = {}
    if (status && status !== 'all') where.status = status as ShipmentStatus
    if (supplier && supplier !== 'all') where.supplier = { code: supplier }
    if (from) where.createdAt = { ...(where.createdAt as object), gte: new Date(from) }
    if (to) where.createdAt = { ...(where.createdAt as object), lte: new Date(`${to}T23:59:59Z`) }

    const rows = await prisma.shipment.findMany({ where, include: INCLUDE, orderBy: { code: 'asc' } })
    return c.json({ shipments: rows.map((s) => shipmentRow(s, user.role, settings.threshold)) })
  })

  .post('/', requireRole('admin'), async (c) => {
    const user = c.get('user')
    const body = z
      .object({
        supplierCode: z.string().min(1),
        flightCode: z.string().min(1).optional(),
        flyerName: z.string().min(1).optional(),
        categories: z.array(z.string().min(1)).min(1, 'Pick at least one category'),
        serials: z.array(z.string()).default([]),
        bookedKg: z.number().min(0).default(0),
        chargeRate: z.number().min(0).default(0),
        chargeCurrency: z.enum(['BDT', 'CNY']).default('BDT'),
        pcsItems: pcsItemsSchema.default([]),
        description: z.string().default(''),
        payStatus: z.enum(['unpaid', 'cod', 'monthly']).optional(),
        paymentTerms:z.enum(['invoice','cod','monthly']).optional(),
      })
      .parse(await c.req.json())

    const supplier = await prisma.supplier.findUnique({ where: { code: body.supplierCode } })
    if (!supplier) throw badRequest(`Unknown customer ${body.supplierCode}`)
    if (supplier.archivedAt) throw badRequest(`${supplier.code} is archived — restore the customer first`)
    const flight = body.flightCode ? await prisma.flight.findUnique({ where: { code: body.flightCode }, include: {flyers:{include:{flyer:true}}} }) : null
    if (body.flightCode && !flight) throw badRequest(`Unknown flight ${body.flightCode}`)
    if(flight && flight.status!=='upcoming')throw badRequest('Choose an upcoming flight')
    const flyer = body.flyerName ? flight?.flyers.find(f => f.flyer.name === body.flyerName) : flight?.flyers.length === 1 ? flight.flyers[0] : undefined
    if ((body.flyerName && !flyer) || flyer?.flyer.archivedAt) throw badRequest('Choose an active flyer assigned to this flight')

    if (flight) await assertFlightCapacity(flight.id, body.bookedKg)
    const code = await nextShipmentCode()
    const flatSerials = flattenSerials(body.pcsItems)
    const serials = flatSerials.length ? flatSerials : body.serials.map((s) => s.trim()).filter(Boolean)
    const totalPcs = body.pcsItems.reduce((a, i) => a + i.count, 0)
    const description = body.description || (totalPcs > 0 ? `${totalPcs} device(s)` : '—')
    const settings = await getSettings()
    const charge =
      Math.round(
        (computeCharge(body.chargeRate, body.bookedKg, body.chargeCurrency, settings.rate) +
          pcsTotal(body.pcsItems, settings.rate)) *
          100,
      ) / 100

    const shipment = await prisma.shipment.create({
      data: {
        code,
        supplierId: supplier.id,
        flightId: flight?.id,
        flyerId: flyer?.flyerId,
        bookedKg: new Prisma.Decimal(body.bookedKg),
        charge: new Prisma.Decimal(charge),
        chargeRate: new Prisma.Decimal(body.chargeRate),
        chargeCurrency: body.chargeCurrency,
        pricingRates: settings.exchangeRates,
        pcsItems: body.pcsItems,
        description,
        categories: body.categories,
        serials,
        paymentTerms:body.paymentTerms ?? (body.payStatus==='cod'?'cod':body.payStatus==='monthly'?'monthly':body.payStatus==='unpaid'?'invoice':supplier.terms==='monthly'?'monthly':'invoice'),
        payStatus:'unpaid',
        trackToken: makeTrackToken(code),
      },
    })
    await log(shipment.id, actorOf(user), `Created, booked${body.bookedKg ? ` ${body.bookedKg} kg` : ''} on ${flight?.code ?? 'an unassigned flight'}`)
    if (serials.length) await log(shipment.id, actorOf(user), `Device serials recorded: ${serials.join(', ')}`)
    await invalidateReads()
    return c.json({ code }, 201)
  })

  .get('/:code', async (c) => {
    const user = c.get('user')
    const shipment = await findByCode(c.req.param('code')!)
    const settings = await getSettings()
    return c.json({ shipment: shipmentDetail(shipment, user.role, settings.threshold) })
  })

  .patch('/:code', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    const body = z
      .object({
        supplierCode: z.string().min(1).optional(),
        paymentTerms:z.enum(['invoice','cod','monthly']).optional(),
        flightCode: z.string().min(1).nullable().optional(),
        flyerName: z.string().min(1).nullable().optional(),
        categories: z.array(z.string().min(1)).min(1, 'Pick at least one category').optional(),
        serials: z.array(z.string()).optional(),
        bookedKg: z.number().min(0).optional(),
        chargeRate: z.number().min(0).optional(),
        chargeCurrency: z.enum(['BDT', 'CNY']).optional(),
        pcsItems: pcsItemsSchema.optional(),
        description: z.string().optional(),
        payStatus: z.enum(['paid', 'unpaid', 'cod', 'monthly', 'partial']).optional(),
        cnFare: z.number().min(0).optional(),
        customsTax: z.number().min(0).optional(),
      })
      .parse(moneyBody(await c.req.json(), ['cnFare', 'customsTax']))

    if (body.payStatus && ['paid', 'partial'].includes(body.payStatus) && body.payStatus !== shipment.payStatus) throw badRequest('Record a payment to change paid status')
    if (body.payStatus && num(shipment.paidAmount) > 0 && body.payStatus !== shipment.payStatus) throw badRequest('Payment status is derived from the ledger')
    if (body.supplierCode && body.supplierCode !== shipment.supplier.code && (shipment.invoice || num(shipment.paidAmount) > 0)) throw badRequest('Cannot reassign an invoiced or paid shipment')
    const data: Prisma.ShipmentUncheckedUpdateInput = {}
    const changed: string[] = []
    if(body.paymentTerms !== undefined && body.paymentTerms !== shipment.paymentTerms){data.paymentTerms=body.paymentTerms;changed.push(`payment terms → ${body.paymentTerms}`)}

    if (body.supplierCode !== undefined && body.supplierCode !== shipment.supplier.code) {
      const supplier = await prisma.supplier.findUnique({ where: { code: body.supplierCode } })
      if (!supplier) throw badRequest(`Unknown customer ${body.supplierCode}`)
      if (supplier.archivedAt) throw badRequest(`${supplier.code} is archived — restore the customer first`)
      data.supplierId = supplier.id
      changed.push(`supplier → ${supplier.code}`)
    }
    const flightChanged=body.flightCode!==undefined && body.flightCode!==(shipment.flight?.code??null)
    const flyerChanged=body.flyerName!==undefined && body.flyerName!==(shipment.flyer?.name??null)
    if((flightChanged||flyerChanged) && statusIndex(shipment.status)>=3)throw badRequest('Use Correct flight assignment with a reason after dispatch')
    if(flightChanged){
      const flight=body.flightCode?await prisma.flight.findUnique({where:{code:body.flightCode}}):null
      if(body.flightCode&&!flight)throw badRequest('Unknown flight')
      if(flight&&flight.status!=='upcoming')throw badRequest('Choose an upcoming flight before dispatch')
      data.flightId=flight?.id??null;data.flyerId=null;changed.push(`flight: ${shipment.flight?.code??'unassigned'} → ${flight?.code??'unassigned'}`)
    }
    if(body.flyerName!==undefined||flightChanged){
      const flightId=flightChanged?data.flightId as string|null:shipment.flightId
      const assigned=flightId?await prisma.flightFlyer.findMany({where:{flightId},include:{flyer:true}}):[]
      const member=body.flyerName?assigned.find(f=>f.flyer.name===body.flyerName):body.flyerName===null?undefined:assigned.length===1?assigned[0]:undefined
      if((body.flyerName&&!member)||((flightChanged||flyerChanged)&&member?.flyer.archivedAt))throw badRequest('Choose an active flyer assigned to this flight')
      data.flyerId=member?.flyerId??null;changed.push('carrying flyer')
    }
    const capacityFlightId = flightChanged ? data.flightId as string | null : shipment.flightId
    if (capacityFlightId && (flightChanged || (body.bookedKg !== undefined && body.bookedKg > num(shipment.bookedKg)))) {
      await assertFlightCapacity(capacityFlightId, body.bookedKg ?? num(shipment.bookedKg), shipment.id)
    }
    if (body.categories !== undefined) {
      data.categories = body.categories
      changed.push('categories')
    }
    if (body.serials !== undefined) {
      data.serials = body.serials.map((s) => s.trim()).filter(Boolean)
      changed.push('serials')
    }
    if (body.bookedKg !== undefined && body.bookedKg !== num(shipment.bookedKg)) {
      data.bookedKg = new Prisma.Decimal(body.bookedKg)
      changed.push(`booked ${body.bookedKg} kg`)
    }
    // Rate, currency, weight or device pieces moving means the total charge
    // moves with them.
    const existingPcs = (shipment.pcsItems as unknown as PcsItem[]) ?? []
    const rateChanged = body.chargeRate !== undefined && body.chargeRate !== num(shipment.chargeRate)
    const currencyChanged = body.chargeCurrency !== undefined && body.chargeCurrency !== shipment.chargeCurrency
    const pcsChanged = body.pcsItems !== undefined && JSON.stringify(body.pcsItems) !== JSON.stringify(existingPcs)
    if (rateChanged || currencyChanged || pcsChanged || data.bookedKg !== undefined) {
      const settings = await getSettings()
      const rate = body.chargeRate ?? num(shipment.chargeRate)
      const currency = body.chargeCurrency ?? shipment.chargeCurrency
      const kg = shipment.weighedKg !== null ? num(shipment.weighedKg) : body.bookedKg ?? num(shipment.bookedKg)
      const pcs = body.pcsItems ?? existingPcs
      const pricing = shipment.pricingRates as Record<string,number>
      const lockedRate = pricing.CNY || settings.rate
      if (!pricing.CNY) data.pricingRates = settings.exchangeRates
      const total = Math.round((computeCharge(rate, kg, currency, lockedRate) + pcsTotal(pcs, lockedRate)) * 100) / 100
      data.chargeRate = new Prisma.Decimal(rate)
      data.chargeCurrency = currency
      if (pcsChanged) {
        data.pcsItems = body.pcsItems
        data.serials = flattenSerials(body.pcsItems ?? [])
        changed.push(
          `devices ${pcs.map((i) => `${i.count}× ${i.category} @${i.currency === 'CNY' ? '¥' : '৳'}${i.rate}`).join(', ') || 'none'}`,
        )
      }
      if (total !== num(shipment.charge)) {
        data.charge = new Prisma.Decimal(total)
        changed.push(`charge ৳${total} (${currency === 'CNY' ? '¥' : '৳'}${rate}/kg)`)
      } else if (rateChanged || currencyChanged) {
        changed.push(`rate ${currency === 'CNY' ? '¥' : '৳'}${rate}/kg`)
      }
    }
    if (body.description !== undefined && body.description !== shipment.description) {
      data.description = body.description || '—'
      changed.push('description')
    }
    if (body.payStatus !== undefined && body.payStatus !== shipment.payStatus) {
      if(['cod','monthly','unpaid'].includes(body.payStatus)){data.paymentTerms=body.payStatus==='unpaid'?'invoice':body.payStatus;changed.push(`payment terms → ${data.paymentTerms}`)}
    }
    if (body.cnFare !== undefined && body.cnFare !== num(shipment.cnFare)) {
      data.cnFare = new Prisma.Decimal(body.cnFare)
      changed.push(`CN fare ৳${body.cnFare}`)
    }
    if (body.customsTax !== undefined && body.customsTax !== num(shipment.customsTax)) {
      data.customsTax = new Prisma.Decimal(body.customsTax)
      changed.push(`customs tax ৳${body.customsTax}`)
    }

    for (const field of ['cnFare','customsTax'] as const) {
      const paid = shipment.expenses.filter(e=>e.costField === field).reduce((a,e)=>a+num(e.amount),0)
      if (body[field] !== undefined && body[field]! < paid) throw badRequest('Recorded cost cannot be lower than its cash payments')
    }
    const newBill = shipment.invoice ? num(shipment.invoice.total) : Number(data.charge ?? shipment.charge) + Number(data.customsTax ?? shipment.customsTax) - num(shipment.afterSalesFee)
    if (newBill < num(shipment.paidAmount)) throw badRequest('Edited charges cannot be less than received payments')
    if (body.cnFare !== undefined || body.customsTax !== undefined) data.costSources = { ...(shipment.costSources as Record<string,Prisma.InputJsonValue>), ...(body.cnFare !== undefined ? {cnFare:sourceFields(body.cnFare)} : {}), ...(body.customsTax !== undefined ? {customsTax:sourceFields(body.customsTax)} : {}) }
    if (changed.length) {
      await prisma.shipment.update({ where: { id: shipment.id }, data })
      await log(shipment.id, 'Admin', `Details edited: ${changed.join(', ')}`)
      if(data.charge!==undefined || data.customsTax!==undefined)await refreshShipmentInvoice(shipment.id,'Shipment pricing changed')
    await invalidateReads()
    }
    return c.json({ ok: true, changed })
  })

  .delete('/:code', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    // Logs and receipt cascade; linked expenses stay in the books (unlinked) —
    // the money was still spent.
    if (shipment.invoice || num(shipment.paidAmount) > 0 || shipment.payments.length || shipment.expenses.length || latestReceipt(shipment.receipts) || await prisma.customerCredit.count({ where: { shipmentCode: shipment.code } })) throw badRequest('Financial history exists; this shipment cannot be deleted')
    await prisma.shipment.delete({ where: { id: shipment.id } })
    await invalidateReads()
    return c.json({ ok: true })
  })

  .post('/:code/advance', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const shipment = await findByCode(c.req.param('code')!)
    const index = statusIndex(shipment.status)
    if (index >= STATUS_ORDER.length - 1) throw badRequest('Already delivered')
    // The hub team only handles the Dhaka side of the pipeline.
    if (user.role === 'hub' && index < 4) throw forbidden('Hub can advance only after customs clearance')
    if(shipment.exception)throw badRequest('Resolve the shipment exception before continuing')
    const next = STATUS_ORDER[index + 1] as ShipmentStatus
    if(next==='out_for_delivery'||next==='delivered')throw badRequest('Use the dispatch or handover confirmation in Handling & delivery')
    if (next === 'in_transit' && (!shipment.flightId || !shipment.flyerId)) throw badRequest('Assign a flight and carrying flyer before dispatch')
    if (next === 'ready_for_last_mile' && !shipment.packedAt) throw badRequest('Weigh and confirm packing first')
    await prisma.shipment.update({ where: { id: shipment.id }, data: { status: next } })
    await log(shipment.id, actorOf(user), `Status → ${STATUS_LABEL[next]}`)
    await invalidateReads()
    return c.json({ status: next })
  })

  .post('/:code/weigh', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const { kg } = z.object({ kg: z.number().min(0) }).parse(await c.req.json())
    const shipment = await findByCode(c.req.param('code')!)
    const settings = await getSettings()
    if(shipment.exception)throw badRequest('Resolve the shipment exception before handling')
    if (statusIndex(shipment.status) < 5 || statusIndex(shipment.status) >= 7) throw badRequest('Weigh at the BD hub before courier dispatch')
    const pricing = shipment.pricingRates as Record<string,number>
    const lockedRate = pricing.CNY || settings.rate
    const charge = Math.round((computeCharge(num(shipment.chargeRate), kg, shipment.chargeCurrency, lockedRate) + pcsTotal(shipment.pcsItems as unknown as PcsItem[], lockedRate))*100)/100
    if (!shipment.invoice && charge + num(shipment.customsTax) - num(shipment.afterSalesFee) < num(shipment.paidAmount)) throw badRequest('New bill is below receipts; adjust the invoice before reweighing')
    await prisma.shipment.update({ where: { id: shipment.id }, data: { pricingRates: {BDT:1,CNY:lockedRate}, weighedKg: new Prisma.Decimal(kg), charge, packedAt:null, packageCount:0, ...(shipment.status === 'ready_for_last_mile' ? {status:'received_bd_hub' as const}: {}) } })
    await refreshShipmentInvoice(shipment.id,'Measured weight updated')
    const delta = weightDelta(num(shipment.bookedKg), kg, settings.threshold)
    await log(shipment.id, actorOf(user), `Weighed ${kg} kg${delta !== null ? ' — DISCREPANCY' : ''}`)
    await invalidateReads()
    return c.json({ ok: true })
  })

  .post('/:code/pack', requireRole('admin', 'hub'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    const { count } = z.object({ count:z.number().int().min(1).max(10000) }).parse(await c.req.json())
    if(shipment.exception)throw badRequest('Resolve the shipment exception before handling')
    if (!['received_bd_hub','ready_for_last_mile'].includes(shipment.status)) throw badRequest('Packing is available at the BD hub before dispatch')
    if (shipment.weighedKg === null) throw badRequest('Record the measured weight before packing (0 for devices only)')
    await prisma.shipment.update({where:{id:shipment.id},data:{packageCount:count,packedAt:new Date(),status:'ready_for_last_mile'}})
    await log(shipment.id,actorOf(c.get('user')),`Packed ${count} package(s); ready for courier`)
    return c.json({ok:true})
  })

  .post('/:code/bd-fare', requireRole('admin'), async (c) => {
    const user = c.get('user')
    const { amount } = z.object({ amount: z.number().min(0) }).parse(moneyBody(await c.req.json(), ['amount']))
    const shipment = await findByCode(c.req.param('code')!)
    const paid = shipment.expenses.filter(e=>e.costField === 'bdFare').reduce((a,e)=>a+num(e.amount),0)
    if (amount < paid) throw badRequest('Recorded cost cannot be lower than its cash payments')
    await prisma.shipment.update({ where: { id: shipment.id }, data: { bdFare: new Prisma.Decimal(amount), costSources: {...(shipment.costSources as Record<string,Prisma.InputJsonValue>), bdFare:sourceFields(amount)} } })
    await log(shipment.id, actorOf(user), `BD transport fare ৳${amount}`)
    await invalidateReads()
    return c.json({ ok: true })
  })

  .post('/:code/last-mile', requireRole('admin','hub'), async c=>{
    const b=z.object({courier:z.string().trim().min(1).max(100),ref:z.string().trim().min(1).max(200),mode:z.enum(['courier','pickup']).optional(),reason:z.string().trim().min(3).max(300).optional()}).parse(await c.req.json())
    const s=await findByCode(c.req.param('code')!)
    if(s.exception)throw badRequest('Resolve the exception before booking delivery')
    if(!['ready_for_last_mile','out_for_delivery'].includes(s.status)||!s.packedAt)throw badRequest('Confirm packing before booking delivery')
    if(s.lastMileRef&&!b.reason)throw badRequest('Enter a reason for correcting the delivery booking')
    const mode=b.mode??(b.courier==='Hub pickup'?'pickup':'courier')
    if(s.status==='out_for_delivery'&&mode!==s.deliveryMode)throw badRequest('Return the shipment to Ready for last mile before changing the delivery type')
    await prisma.shipment.update({where:{id:s.id},data:{lastMileCourier:mode==='pickup'?'Hub pickup':b.courier,lastMileRef:b.ref,deliveryMode:mode,deliveryBookedAt:new Date()}})
    await log(s.id,c.get('user').name,`Delivery ${s.lastMileRef?'booking corrected':'booked'}: ${mode} ${b.courier} ${b.ref}${s.lastMileRef?` (previous: ${s.lastMileCourier} ${s.lastMileRef}; ${b.reason})`:''}`)
    return c.json({ok:true})
  })
  .post('/:code/dispatch',requireRole('admin','hub'),async c=>{
    const s=await findByCode(c.req.param('code')!)
    if(s.exception||s.status!=='ready_for_last_mile'||!s.packedAt||!s.lastMileRef||s.deliveryMode==='pickup')throw badRequest('A packed courier booking is required before dispatch')
    await prisma.shipment.update({where:{id:s.id},data:{status:'out_for_delivery',dispatchedAt:new Date()}})
    await log(s.id,c.get('user').name,`Delivery dispatched via ${s.lastMileCourier}: ${s.lastMileRef}`)
    return c.json({ok:true})
  })
  .post('/:code/handover',requireRole('admin','hub'),async c=>{
    const {confirmation}=z.object({confirmation:z.string().trim().min(3,'Enter the recipient or delivery confirmation').max(300)}).parse(await c.req.json())
    const s=await findByCode(c.req.param('code')!)
    if(s.exception||!s.lastMileRef||!s.packedAt||!(s.status==='out_for_delivery'||s.status==='ready_for_last_mile'&&s.deliveryMode==='pickup'))throw badRequest('A dispatched courier delivery or booked pickup is required')
    await prisma.shipment.update({where:{id:s.id},data:{status:'delivered',handedOverAt:new Date()}})
    await log(s.id,c.get('user').name,`Delivery confirmed${s.deliveryMode==='pickup'?' (hub collection)':''}: ${confirmation}`)
    return c.json({ok:true})
  })
  .post('/:code/exception',requireRole('admin','hub'),async c=>{
    const b=z.object({type:z.enum(['on_hold','cancelled','delivery_failed','returned','lost','resume']),reason:z.string().trim().min(3).max(500)}).parse(await c.req.json())
    const s=await findByCode(c.req.param('code')!),u=c.get('user')
    if(u.role==='hub'&&!['on_hold','delivery_failed','resume'].includes(b.type))throw forbidden('An administrator must record this exception')
    if(u.role==='hub'&&b.type==='resume'&&s.exception&&!['on_hold','delivery_failed'].includes(s.exception))throw forbidden('An administrator must resume this shipment')
    if(b.type==='resume'&&!s.exception)throw badRequest('This shipment has no exception to resolve')
    await prisma.shipment.update({where:{id:s.id},data:{exception:b.type==='resume'?null:b.type,exceptionReason:b.type==='resume'?'':b.reason,exceptionAt:b.type==='resume'?null:new Date()}})
    await log(s.id,u.name,`${b.type==='resume'?'Shipment resumed':'Exception: '+b.type.replaceAll('_',' ')} — ${b.reason}`)
    return c.json({ok:true})
  })
  .post('/:code/correct-stage',requireRole('admin'),async c=>{
    const b=z.object({status:z.enum(STATUS_ORDER as [ShipmentStatus,...ShipmentStatus[]]),reason:z.string().trim().min(3).max(500)}).parse(await c.req.json())
    const s=await findByCode(c.req.param('code')!)
    if(statusIndex(b.status)>=statusIndex(s.status))throw badRequest('Corrections move to an earlier checkpoint; use normal confirmations to advance')
    await prisma.shipment.update({where:{id:s.id},data:{status:b.status,exception:null,exceptionReason:'',exceptionAt:null,...(statusIndex(b.status)<6?{packedAt:null,packageCount:0}:{}),...(statusIndex(b.status)<7?{dispatchedAt:null,handedOverAt:null,lastMileCourier:null,lastMileRef:null,deliveryBookedAt:null}:{handedOverAt:null})}})
    await log(s.id,c.get('user').name,`Checkpoint corrected: ${STATUS_LABEL[s.status]} → ${STATUS_LABEL[b.status]} — ${b.reason}`)
    return c.json({ok:true})
  })
  .post('/:code/assignment-correction',requireRole('admin'),async c=>{
    const b=z.object({flightCode:z.string().min(1),flyerName:z.string().min(1),reason:z.string().trim().min(3).max(500)}).parse(await c.req.json())
    const s=await findByCode(c.req.param('code')!),f=await prisma.flight.findUnique({where:{code:b.flightCode},include:{flyers:{include:{flyer:true}}}})
    const member=f?.flyers.find(m=>m.flyer.name===b.flyerName)
    if(!f||!member)throw badRequest('Choose a flight and one of its assigned flyers')
    if (f.id !== s.flightId) await assertFlightCapacity(f.id, num(s.bookedKg), s.id)
    await prisma.shipment.update({where:{id:s.id},data:{flightId:f.id,flyerId:member.flyerId}})
    await log(s.id,c.get('user').name,`Flight assignment corrected: ${s.flight?.code??'unassigned'} / ${s.flyer?.name??'unassigned'} → ${f.code} / ${member.flyer.name} — ${b.reason}`)
    return c.json({ok:true})
  })

  .post('/:code/mark-paid', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    const remaining = Math.round((effectiveBill(shipment) - num(shipment.paidAmount)) * 100) / 100
    if (remaining <= 0) throw badRequest('Already paid')
    await recordShipmentPayment(shipment, remaining, 'Cash', 'Admin')
    return c.json({ ok: true })
  })

  .post('/:code/payments', requireRole('admin'), async (c) => {
    const { amount, method } = z
      .object({ amount: z.number().positive('Amount required'), method: z.string().min(1).max(200).default('Cash') })
      .parse(moneyBody(await c.req.json(), ['amount']))
    const shipment = await findByCode(c.req.param('code')!)
    const remaining = Math.round((effectiveBill(shipment) - num(shipment.paidAmount)) * 100) / 100
    if (remaining <= 0) throw badRequest('Nothing left to pay on this shipment')
    if (amount > remaining + 0.005) throw badRequest(`Amount exceeds the remaining ৳${remaining.toLocaleString('en-IN')}`)
    const result = await recordShipmentPayment(shipment, amount, method, 'Admin')
    return c.json({ ok: true, ...result }, 201)
  })

  .post('/:code/after-sales', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    const { amount, reason } = z.object({amount:z.number().positive().multipleOf(0.01),reason:z.string().trim().min(1).max(200)}).parse(moneyBody(await c.req.json(), ['amount']))
    const total = effectiveBill(shipment) - amount
    if (total < 0) throw badRequest('Credit cannot exceed the bill total')
    await prisma.creditNote.create({data:{...sourceFields(amount),shipmentId:shipment.id,amount,reason,previousTotal:effectiveBill(shipment),revisedTotal:total}})
    await releaseExcessPaid(shipment,total,reason)
    await prisma.shipment.update({where:{id:shipment.id},data:{afterSalesFee:{increment:amount},freeOfCharge:total===0 && shipment.invoice?.state==='issued',payStatus:total > 0 && total <= num(shipment.paidAmount) && shipment.invoice?.state==='issued' ? 'paid' : num(shipment.paidAmount) > 0 ? 'partial' : 'unpaid'}})
    if (shipment.invoice) {
      const updated=await prisma.invoice.update({where:{shipmentId:shipment.id},data:{...sourceAt(total,shipment.invoice),discount:{increment:amount},total}})
      await snapshotInvoice(updated,`Credit note: ${reason}`)
    }
    await log(shipment.id,'Admin',`Credit BDT ${amount}: ${reason}`)
    return c.json({ok:true})
  })

  .post('/:code/expenses', requireRole('admin'), async (c) => {
    const body=z.object({category:z.enum(['ticket','packaging','courier','salary','transport','customs','others']),amount:z.number().positive(),reason:z.string().trim().min(1).max(500),label:z.string().trim().min(1).max(120).optional(),accountName:z.string().trim().min(1).optional(),paymentTiming:z.enum(['now','later']).default('now'),costId:z.string().optional(),costField:z.enum(['cnFare','bdFare','customsTax']).optional()}).parse(moneyBody(await c.req.json(),['amount']))
    const shipment=await findByCode(c.req.param('code')!)
    let costId=body.costId
    if(body.costField){const paid=shipment.expenses.filter(e=>e.costField===body.costField).reduce((n,e)=>n+num(e.amount),0);if(body.amount>num(shipment[body.costField])-paid+0.005)throw badRequest('Amount exceeds the unpaid recorded cost')}
    else if(costId){const cost=shipment.costs.find(c=>c.id===costId&&!c.voidedAt);if(!cost)throw notFound('Cost not found');const paid=shipment.expenses.filter(e=>e.costId===costId).reduce((n,e)=>n+num(e.amount),0);if(body.amount>num(cost.amount)-paid+0.005)throw badRequest('Amount exceeds the remaining cost')}
    else {const cost=await prisma.shipmentCost.create({data:{shipmentId:shipment.id,name:body.label??({courier:"Courier charge",packaging:"Packaging charge",customs:"Customs charge",transport:"Transport charge",others:"Additional charge",salary:"Service charge",ticket:"Ticket charge"}[body.category]),category:body.category,amount:body.amount,...sourceFields(body.amount)}});costId=cost.id;await addShipmentBillCharge(shipment.id,body.category,body.amount,body.label)}
    if(body.paymentTiming==='later'&&(body.costId||body.costField))throw badRequest('Choose a paying account to settle this cost')
    if(body.paymentTiming==='now'){
      if(!body.accountName)throw badRequest('Choose the paying account')
      const posted=await debitCash(body.amount,body.accountName)
      await prisma.expense.create({data:{...posted,...sourceFields(body.amount),costId,costField:body.costField,date:new Date(),category:body.category,amount:body.amount,reason:body.reason,shipmentId:shipment.id}})
    }
    await log(shipment.id,c.get('user').name,`${body.costId||body.costField?'Cost payment':'Cost recorded'}: ${body.reason} — BDT ${body.amount}${body.paymentTiming==='later'?' (unpaid)':''}`)
    return c.json({ok:true,costId})
  })

  .get('/:code/invoice.pdf', requireRole('admin'), async c=>{
    const shipment=await findByCode(c.req.param('code')!)
    const pdf=await invoicePdf(shipment)
    c.header('Content-Type','application/pdf')
    c.header('Content-Disposition',`attachment; filename="invoice-${shipment.code.replace(/[^A-Za-z0-9_-]/g,'')}.pdf"`)
    return c.body(new Uint8Array(pdf))
  })

  .get('/:code/invoice', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    const to = `${shipment.supplier.name} (${shipment.supplier.code})`

    if (shipment.invoice) {
      const inv = shipment.invoice
      return c.json({
        saved: true,
        invoice: {
          sourceCurrency:inv.sourceCurrency, sourceFxRate:num(inv.sourceFxRate), sourceAmount:num(inv.sourceAmount),
          state:inv.state,needsReview:inv.needsReview,pricingMode:inv.pricingMode,suggestedLines:await invoiceSuggestion(shipment.id),calculatedLines:(await calculatedInvoice(shipment.id)).lines,
          number: inv.number,
          to,
          shipmentCode: shipment.code,
          lines: invoiceBillLines(shipment),
          paidAmount: num(shipment.paidAmount), dueAmount: Math.max(0, Math.round((num(inv.total)-num(shipment.paidAmount))*100)/100),
          discount: num(inv.discount),
          note: inv.note,
          total: num(inv.total),
          issuedAt: inv.issuedAt.toISOString(),
          updatedAt: inv.updatedAt.toISOString(),
        },
      })
    }

    // Draft and saved documents share the same line-item calculation.
    const lines = draftBillLines(shipment)
    const yymm = new Date().toISOString().slice(2, 7).replace('-', '')
    return c.json({
      saved: false,
      invoice: {
        state:"draft",needsReview:false,pricingMode:"automatic",suggestedLines:lines,calculatedLines:lines,
        number: `INV-${yymm}-${shipment.code}`,
        paidAmount: num(shipment.paidAmount), dueAmount: Math.max(0, Math.round((effectiveBill(shipment)-num(shipment.paidAmount))*100)/100),
        to,
        shipmentCode: shipment.code,
        lines,
        discount: 0,
        note: '',
        total: billAmount({
          charge: num(shipment.charge),
          customsTax: num(shipment.customsTax),
          afterSalesFee: num(shipment.afterSalesFee),
        }),
        issuedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    })
  })

  .post('/:code/invoice', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    const body = z
      .object({
        lines: z
          .array(z.object({ label: z.string().min(1, 'Line label required').max(160), amount: z.number(),costId:z.string().optional() }))
          .min(1, 'At least one line')
          .max(30),
        discount: z.number().min(0).default(0),
        note: z.string().max(300).default(''),
        state:z.enum(['draft','issued']).default('issued'),pricingMode:z.enum(['automatic','manual']).default('manual'),revisionReason:z.string().trim().max(500).optional(),confirmFree:z.boolean().default(false),
      })
      .parse(moneyBody(await c.req.json(), ['lines', 'discount']))

    const total = Math.round((body.lines.reduce((a, l) => a + l.amount, 0) - body.discount) * 100) / 100
    if (total < 0) throw badRequest('Invoice cannot be negative')
    if(body.state==='issued' && total===0 && !body.confirmFree && !shipment.freeOfCharge)throw badRequest('Confirm that this shipment is free of charge before issuing a zero-value invoice')
    if(shipment.invoice?.state==='issued' && body.state==='draft')throw badRequest('An issued invoice cannot be unpublished; revise it with a reason')
    if(shipment.invoice?.state==='issued' && (shipment.invoice.needsReview || total!==num(shipment.invoice.total)) && !body.revisionReason)throw badRequest('Enter a reason for revising the issued invoice')
    if(body.lines.some(l=>l.costId&&!shipment.costs.some(c=>c.id===l.costId)))throw badRequest('Invoice cost belongs to a different shipment')
    if(shipment.invoice?.state==='issued' && total<num(shipment.invoice.total))await prisma.creditNote.create({data:{...sourceFields(num(shipment.invoice.total)-total),shipmentId:shipment.id,amount:num(shipment.invoice.total)-total,reason:body.revisionReason!,previousTotal:shipment.invoice.total,revisedTotal:total}})
    const lifecycle={state:body.state,pricingMode:body.pricingMode,pricingFingerprint:pricingFingerprint(shipment),needsReview:false}

    const yymm = new Date().toISOString().slice(2, 7).replace('-', '')
    const existed = shipment.invoice !== null
    const invoice = await prisma.invoice.upsert({
      where: { shipmentId: shipment.id },
      update: { ...lifecycle,...(body.state==='issued' && shipment.invoice?.state!=='issued'?{issuedAt:new Date()}:{}),...sourceFields(total), lines: body.lines, discount: new Prisma.Decimal(body.discount), note: body.note, total: new Prisma.Decimal(total) },
      create: {
        ...lifecycle,...sourceFields(total),
        number: `INV-${yymm}-${shipment.code}`,
        shipmentId: shipment.id,
        supplierId: shipment.supplierId,
        lines: body.lines,
        discount: new Prisma.Decimal(body.discount),
        note: body.note,
        total: new Prisma.Decimal(total),
      },
    })
    await snapshotInvoice(invoice,body.revisionReason || (body.state==='draft'?'Draft saved':existed ? 'Invoice issued / revised' : 'Invoice issued'))
    await releaseExcessPaid(shipment,total,'Invoice finalized below received amount')
    await log(shipment.id, 'Admin', `Invoice ${invoice.number} ${existed ? 'updated' : 'finalized'} — total ৳${total.toLocaleString('en-IN')}`)
    await prisma.shipment.update({ where: { id: shipment.id }, data: { freeOfCharge:total===0 && body.state==='issued' && (body.confirmFree||shipment.freeOfCharge),payStatus: num(shipment.paidAmount) >= total && body.state==='issued' ? 'paid' : num(shipment.paidAmount) > 0 ? 'partial' : 'unpaid' } })
    // The invoice total is now the amount due everywhere.
    await invalidateReads()
    return c.json({ ok: true, number: invoice.number }, existed ? 200 : 201)
  })

  .get('/:code/track-links', requireRole('admin'), async c => {
    const shipment = await findByCode(c.req.param('code')!)
    const rows = await prisma.publicLink.findMany({where:{shipmentId:shipment.id},orderBy:{createdAt:'desc'}})
    return c.json({links:rows.map(row=>savedLink(row,'t'))})
  })

  .post('/:code/track-link', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    const body = z.object({ scope: z.enum(['tracking', 'invoice', 'tracking_only']).default('tracking_only'),
      days: z.number().int().min(1).max(90).default(7),
      amount: z.number().positive().multipleOf(0.01).optional(),
    }).parse(moneyBody(await c.req.json(), ['amount']))
    if (body.scope !== 'tracking_only') await ensureShipmentInvoice(shipment.id)
    const due = Math.max(0, effectiveBill(shipment) - num(shipment.paidAmount))
    if (body.amount !== undefined && body.amount > due) throw badRequest('Requested amount exceeds balance')
    const token = newPublicToken()
    const expiresAt = new Date(Date.now() + body.days * 86400000)
    await prisma.publicLink.create({ data: { shipmentId: shipment.id, tokenHash: tokenHash(token), tokenCiphertext: sealLinkToken(token),
      scope: body.scope, expiresAt, requestedAmount: body.amount, paidAtIssue: shipment.paidAmount } })
    await log(shipment.id, 'Admin', `${body.scope} link issued; expires ${expiresAt.toISOString()}`)
    return c.json({ token, url: `${config.publicTrackBaseUrl}/t/${token}`, expiresAt: expiresAt.toISOString() }, 201)
  })
  .delete('/:code/track-link', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    await prisma.publicLink.updateMany({ where: { shipmentId: shipment.id, revokedAt: null }, data: { revokedAt: new Date() } })
    await log(shipment.id, 'Admin', 'All public links revoked')
    return c.json({ ok: true })
  })

  .post('/:code/receipt/approve', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    const receipt = shipment.receipts.find(r=>r.status==='pending')
    if (!receipt) throw badRequest('No pending receipt')
    const user=c.get('user')
    await withSavedMoney(receipt, () => recordShipmentPayment(shipment, num(receipt.amount), receipt.method, user.name, receipt.txnRef, {receiptId:receipt.id}))
    await prisma.receipt.update({where:{id:receipt.id},data:{status:'approved',reviewedAt:new Date(),reviewedById:user.id,reviewedByName:user.name,reviewReason:''}})
    await prisma.todo.updateMany({where:{receiptId:receipt.id},data:{done:true}})
    await log(shipment.id,user.name,`Receipt approved: ${receipt.txnRef}`)
    return c.json({ok:true})
  })
  .post('/:code/receipt/reject', requireRole('admin'), async (c) => {
    const {reason}=z.object({reason:z.string().trim().min(3,'Explain why the receipt could not be verified').max(500)}).parse(await c.req.json())
    const shipment=await findByCode(c.req.param('code')!),receipt=shipment.receipts.find(r=>r.status==='pending'),user=c.get('user')
    if(!receipt)throw badRequest('No pending receipt')
    await prisma.receipt.update({where:{id:receipt.id},data:{status:'rejected',reviewedAt:new Date(),reviewedById:user.id,reviewedByName:user.name,reviewReason:reason}})
    await prisma.todo.updateMany({where:{receiptId:receipt.id},data:{done:true}})
    await log(shipment.id,user.name,`Receipt rejected: ${receipt.txnRef} — ${reason}`)
    return c.json({ok:true})
  })

/** Called from the public tracking page's receipt upload. */
export async function uploadReceipt(
  shipment: ShipmentWithRelations & { invoice?: { total: Prisma.Decimal; state: string; needsReview: boolean } | null },
  method: string,
  actor: string,
  amount: number,
  txnRef: string,
  screenshotReference: string | null = null,
): Promise<{ amount: number; txnRef: string }> {
  if (latestReceipt(shipment.receipts)?.status === 'pending') throw badRequest('A receipt is already under review')
  // The customer pays what's left, not the original bill.
  const remaining = Math.round((effectiveBill(shipment) - num(shipment.paidAmount)) * 100) / 100
  if (amount <= 0 || amount > remaining) throw badRequest('Invalid payment amount')
  const duplicate = await prisma.receipt.findFirst({ where: { method, txnRef, status: { in: ['pending', 'approved'] } } })
  if (duplicate || await prisma.statementReceipt.count({where:{method,txnRef,status:{in:['pending','approved']}}})) throw badRequest('This transaction reference has already been submitted')
  const processed = await prisma.payment.findFirst({ where: { method, reference: { endsWith: ` / ${txnRef}` } } })
  if (processed) throw badRequest('This transaction has already been credited')
  const receipt = await prisma.receipt.create({
    data: { ...sourceFields(amount), shipmentId: shipment.id, method, amount: new Prisma.Decimal(amount), txnRef, screenshotReference },
  })
  await log(shipment.id, actor, `${method} receipt submitted: ${txnRef}`)
  await prisma.todo.create({data:{role:'admin',text:`Review ${method} receipt — ${shipment.code}`,auto:true,receiptId:receipt.id}})
  await invalidateReads()
  return { amount, txnRef }
}
