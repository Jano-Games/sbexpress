import { addShipmentBillCharge } from '../shared/shipmentBilling'
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
import { effectiveBill, num, shipmentDetail, shipmentRow, type ShipmentWithRelations } from '../shared/serialize'
import { getSettings } from '../shared/settings'
import { creditPayment, debitCash } from '../shared/ledger'
import { config } from '../core/config'
import { newPublicToken, tokenHash } from '../shared/publicLinks'

const INCLUDE = { supplier: true, flight: true, receipt: true, expenses: true, invoice: true } as const
const INCLUDE_FULL = {
  ...INCLUDE,
  flyer: true,
  logs: { orderBy: { at: 'desc' as const } },
  payments: { orderBy: { createdAt: 'asc' as const } },
} as const

const actorOf = (user: SessionUser): string => (user.role === 'admin' ? 'Admin' : 'Hub')

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
  await prisma.shipmentLog.create({ data: { shipmentId, actor, message } })
}

/**
 * Record money received against one shipment: appends to the payment ledger,
 * credits the matching account, bumps paidAmount and derives the pay status
 * (partial until the effective bill is covered). Also used by supplier-level
 * payments, which allocate one amount across many shipments.
 */
export async function recordShipmentPayment(
  shipment: ShipmentWithRelations & { invoice?: { total: Prisma.Decimal } | null },
  amount: number,
  method: string,
  actor: string,
  transactionReference?: string,
): Promise<{ newPaid: number; fullyPaid: boolean; bill: number }> {
  const bill = effectiveBill(shipment)
  if (!Number.isFinite(amount) || amount <= 0 || Math.abs(amount * 100 - Math.round(amount * 100)) > 0.00001) throw badRequest('Enter a positive amount with at most two decimals')
  if (amount > bill - num(shipment.paidAmount) + 0.005) throw badRequest('Payment exceeds outstanding balance')
  const newPaid = Math.round((num(shipment.paidAmount) + amount) * 100) / 100
  const fullyPaid = newPaid >= bill - 0.005
  await prisma.shipment.update({
    where: { id: shipment.id },
    data: { paidAmount: new Prisma.Decimal(newPaid), payStatus: fullyPaid ? 'paid' : 'partial', payMethod: method },
  })
  await creditPayment(method, amount, transactionReference ? `${shipment.code} / ${transactionReference}` : shipment.code, shipment.id)
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
      units: z.array(z.object({ model: z.string().max(120).default(''), serial: z.string().max(120).default('') })).max(20).default([]),
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
        payStatus: z.enum(['unpaid', 'cod', 'monthly']).default('unpaid'),
      })
      .parse(await c.req.json())

    const supplier = await prisma.supplier.findUnique({ where: { code: body.supplierCode } })
    if (!supplier) throw badRequest(`Unknown supplier ${body.supplierCode}`)
    const flight = body.flightCode ? await prisma.flight.findUnique({ where: { code: body.flightCode }, include: {flyers:{include:{flyer:true}}} }) : null
    if (body.flightCode && !flight) throw badRequest(`Unknown flight ${body.flightCode}`)
    const flyer = body.flyerName ? flight?.flyers.find(f => f.flyer.name === body.flyerName) : flight?.flyers.length === 1 ? flight.flyers[0] : undefined
    if (body.flyerName && !flyer) throw badRequest('Flyer must be assigned to this flight')

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
        pcsItems: body.pcsItems,
        description,
        categories: body.categories,
        serials,
        payStatus: supplier.terms === 'monthly' ? 'monthly' : body.payStatus === 'cod' ? 'cod' : 'unpaid',
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
        flightCode: z.string().min(1).optional(),
        flyerName: z.string().min(1).optional(),
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
      .parse(await c.req.json())

    if (body.payStatus && ['paid', 'partial'].includes(body.payStatus) && body.payStatus !== shipment.payStatus) throw badRequest('Record a payment to change paid status')
    if (body.payStatus && num(shipment.paidAmount) > 0 && body.payStatus !== shipment.payStatus) throw badRequest('Payment status is derived from the ledger')
    if (body.supplierCode && body.supplierCode !== shipment.supplier.code && (shipment.invoice || num(shipment.paidAmount) > 0)) throw badRequest('Cannot reassign an invoiced or paid shipment')
    const data: Prisma.ShipmentUncheckedUpdateInput = {}
    const changed: string[] = []

    if (body.supplierCode !== undefined && body.supplierCode !== shipment.supplier.code) {
      const supplier = await prisma.supplier.findUnique({ where: { code: body.supplierCode } })
      if (!supplier) throw badRequest(`Unknown supplier ${body.supplierCode}`)
      data.supplierId = supplier.id
      changed.push(`supplier → ${supplier.code}`)
    }
    if (body.flightCode !== undefined && body.flightCode !== shipment.flight?.code) {
      const flight = await prisma.flight.findUnique({ where: { code: body.flightCode } })
      if (!flight) throw badRequest(`Unknown flight ${body.flightCode}`)
      data.flightId = flight.id
      changed.push(`flight → ${flight.code}`)
    }
    if (body.flyerName !== undefined || data.flightId !== undefined) {
      const assigned = await prisma.flightFlyer.findMany({ where:{flightId: (data.flightId as string | undefined) ?? shipment.flightId ?? ''}, include:{flyer:true} })
      const flyer = body.flyerName ? assigned.find(f => f.flyer.name === body.flyerName) : assigned.length === 1 ? assigned[0] : undefined
      if (body.flyerName && !flyer) throw badRequest('Flyer must be assigned to this flight')
      data.flyerId = flyer?.flyerId ?? null
      changed.push('carrying flyer')
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
      const total = Math.round((computeCharge(rate, kg, currency, settings.rate) + pcsTotal(pcs, settings.rate)) * 100) / 100
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
      data.payStatus = body.payStatus as PayStatus
      changed.push(`payment → ${body.payStatus}`)
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
    if (changed.length) {
      await prisma.shipment.update({ where: { id: shipment.id }, data })
      await log(shipment.id, 'Admin', `Details edited: ${changed.join(', ')}`)
      await invalidateReads()
    }
    return c.json({ ok: true, changed })
  })

  .delete('/:code', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    // Logs and receipt cascade; linked expenses stay in the books (unlinked) —
    // the money was still spent.
    if (shipment.invoice || shipment.payments.length || shipment.expenses.length) throw badRequest('Financial history exists; this shipment cannot be deleted')
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
    const next = STATUS_ORDER[index + 1] as ShipmentStatus
    if (next === 'in_transit' && (!shipment.flightId || !shipment.flyerId)) throw badRequest('Assign a flight and carrying flyer before dispatch')
    if (next === 'ready_for_last_mile' && !shipment.packedAt) throw badRequest('Weigh and confirm packing first')
    if ((next === 'out_for_delivery' || next === 'delivered') && !shipment.lastMileRef) throw badRequest('Record the real courier or pickup reference first')
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
    if (statusIndex(shipment.status) < 5 || statusIndex(shipment.status) >= 7) throw badRequest('Weigh at the BD hub before courier dispatch')
    const charge = Math.round((computeCharge(num(shipment.chargeRate), kg, shipment.chargeCurrency, settings.rate) + pcsTotal(shipment.pcsItems as unknown as PcsItem[], settings.rate))*100)/100
    if (!shipment.invoice && charge + num(shipment.customsTax) - num(shipment.afterSalesFee) < num(shipment.paidAmount)) throw badRequest('New bill is below receipts; adjust the invoice before reweighing')
    await prisma.shipment.update({ where: { id: shipment.id }, data: { weighedKg: new Prisma.Decimal(kg), charge, packedAt:null, packageCount:0, ...(shipment.status === 'ready_for_last_mile' ? {status:'received_bd_hub' as const}: {}) } })
    const delta = weightDelta(num(shipment.bookedKg), kg, settings.threshold)
    await log(shipment.id, actorOf(user), `Weighed ${kg} kg${delta !== null ? ' — DISCREPANCY' : ''}`)
    await invalidateReads()
    return c.json({ ok: true })
  })

  .post('/:code/pack', requireRole('admin', 'hub'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    const { count } = z.object({ count:z.number().int().min(1).max(10000) }).parse(await c.req.json())
    if (!['received_bd_hub','ready_for_last_mile'].includes(shipment.status)) throw badRequest('Packing is available at the BD hub before dispatch')
    if (shipment.weighedKg === null) throw badRequest('Record the measured weight before packing (0 for devices only)')
    await prisma.shipment.update({where:{id:shipment.id},data:{packageCount:count,packedAt:new Date(),status:'ready_for_last_mile'}})
    await log(shipment.id,actorOf(c.get('user')),`Packed ${count} package(s); ready for courier`)
    return c.json({ok:true})
  })

  .post('/:code/bd-fare', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const { amount } = z.object({ amount: z.number().min(0) }).parse(await c.req.json())
    const shipment = await findByCode(c.req.param('code')!)
    const paid = shipment.expenses.filter(e=>e.costField === 'bdFare').reduce((a,e)=>a+num(e.amount),0)
    if (amount < paid) throw badRequest('Recorded cost cannot be lower than its cash payments')
    await prisma.shipment.update({ where: { id: shipment.id }, data: { bdFare: new Prisma.Decimal(amount) } })
    await log(shipment.id, actorOf(user), `BD transport fare ৳${amount}`)
    await invalidateReads()
    return c.json({ ok: true })
  })

  .post('/:code/last-mile', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const { courier, ref } = z
      .object({ courier: z.string().trim().min(1), ref: z.string().trim().min(1, 'Real courier or pickup reference required') })
      .parse(await c.req.json())
    const shipment = await findByCode(c.req.param('code')!)
    if (shipment.status !== 'ready_for_last_mile' || !shipment.packedAt) throw badRequest('Confirm packing before booking the courier')
    const bookingRef = ref
    // Booking the courier moves a ready shipment straight to Out for Delivery.
    const bump = shipment.status === 'ready_for_last_mile'
    await prisma.shipment.update({
      where: { id: shipment.id },
      data: { lastMileCourier: courier, lastMileRef: bookingRef, ...(bump ? { status: 'out_for_delivery' } : {}) },
    })
    if (bump) await log(shipment.id, actorOf(user), 'Status → Out for Delivery')
    await log(shipment.id, actorOf(user), `Last mile booked: ${courier} ${bookingRef}`)
    await invalidateReads()
    return c.json({ ok: true })
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
      .parse(await c.req.json())
    const shipment = await findByCode(c.req.param('code')!)
    const remaining = Math.round((effectiveBill(shipment) - num(shipment.paidAmount)) * 100) / 100
    if (remaining <= 0) throw badRequest('Nothing left to pay on this shipment')
    if (amount > remaining + 0.005) throw badRequest(`Amount exceeds the remaining ৳${remaining.toLocaleString('en-IN')}`)
    const result = await recordShipmentPayment(shipment, amount, method, 'Admin')
    return c.json({ ok: true, ...result }, 201)
  })

  .post('/:code/after-sales', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    const { amount, reason } = z.object({amount:z.number().positive().multipleOf(0.01),reason:z.string().trim().min(1).max(200)}).parse(await c.req.json())
    const total = effectiveBill(shipment) - amount
    if (total < 0) throw badRequest('Credit cannot exceed the bill total')
    await prisma.creditNote.create({data:{shipmentId:shipment.id,amount,reason,previousTotal:effectiveBill(shipment),revisedTotal:total}})
    await releaseExcessPaid(shipment,total,reason)
    await prisma.shipment.update({where:{id:shipment.id},data:{afterSalesFee:{increment:amount},payStatus:total <= num(shipment.paidAmount) ? 'paid' : num(shipment.paidAmount) > 0 ? 'partial' : shipment.supplier.terms === 'monthly' ? 'monthly' : 'unpaid'}})
    if (shipment.invoice) {
      const updated=await prisma.invoice.update({where:{shipmentId:shipment.id},data:{discount:{increment:amount},total}})
      await snapshotInvoice(updated,`Credit note: ${reason}`)
    }
    await log(shipment.id,'Admin',`Credit BDT ${amount}: ${reason}`)
    return c.json({ok:true})
  })

  .post('/:code/expenses', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const body = z
      .object({
        category: z.enum(['ticket', 'packaging', 'courier', 'salary', 'transport', 'customs', 'others']),
        amount: z.number().positive('Amount is required'),
        reason: z.string().min(1, 'Reason is required'),
        accountName: z.string().trim().min(1).default('Cash'),
        costField: z.enum(['cnFare','bdFare','customsTax']).optional(),
      })
      .parse(await c.req.json())
    const shipment = await findByCode(c.req.param('code')!)
    if (body.costField) {
      const paid = shipment.expenses.filter(e => e.costField === body.costField).reduce((a,e)=>a+num(e.amount),0)
      if (body.amount > num(shipment[body.costField]) - paid + 0.005) throw badRequest('Amount exceeds the unpaid recorded cost')
    }
    const paidFrom = await debitCash(body.amount, body.accountName)
    await prisma.expense.create({
      data: {
        ...paidFrom,
        costField:body.costField,
        date: new Date(),
        category: body.category,
        amount: new Prisma.Decimal(body.amount),
        reason: body.reason,
        shipmentId: shipment.id,
      },
    })
    if (!body.costField) await addShipmentBillCharge(shipment.id, body.category, body.amount)
    await log(shipment.id, actorOf(user), `Expense: ${body.category} ৳${body.amount} — ${body.reason}`)
    await invalidateReads()
    return c.json({ ok: true })
  })

  .get('/:code/invoice', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    const to = `${shipment.supplier.name} (${shipment.supplier.code})`

    if (shipment.invoice) {
      const inv = shipment.invoice
      return c.json({
        saved: true,
        invoice: {
          number: inv.number,
          to,
          shipmentCode: shipment.code,
          lines: (inv.lines as { label: string; amount: number }[] | null) ?? [],
          discount: num(inv.discount),
          note: inv.note,
          total: num(inv.total),
          issuedAt: inv.issuedAt.toISOString(),
          updatedAt: inv.updatedAt.toISOString(),
        },
      })
    }

    // No invoice yet — a draft built from the shipment, not persisted.
    const lines = [
      { label: `Shipment charge — ${shipment.categories.join(', ')} · ${shipment.description}`, amount: num(shipment.charge) },
    ]
    if (num(shipment.customsTax) > 0) lines.push({ label: 'Customs tax', amount: num(shipment.customsTax) })
    if (num(shipment.afterSalesFee) > 0)
      lines.push({ label: 'After-sales credit (damage/lost)', amount: -num(shipment.afterSalesFee) })
    const yymm = new Date().toISOString().slice(2, 7).replace('-', '')
    return c.json({
      saved: false,
      invoice: {
        number: `INV-${yymm}-${shipment.code}`,
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
          .array(z.object({ label: z.string().min(1, 'Line label required').max(160), amount: z.number() }))
          .min(1, 'At least one line')
          .max(30),
        discount: z.number().min(0).default(0),
        note: z.string().max(300).default(''),
      })
      .parse(await c.req.json())

    const total = Math.round((body.lines.reduce((a, l) => a + l.amount, 0) - body.discount) * 100) / 100
    if (total < 0) throw badRequest('Invoice cannot be negative')
    if (shipment.invoice && total < num(shipment.invoice.total)) throw badRequest('Use a credit note to reduce a finalized invoice')
    const yymm = new Date().toISOString().slice(2, 7).replace('-', '')
    const existed = shipment.invoice !== null
    const invoice = await prisma.invoice.upsert({
      where: { shipmentId: shipment.id },
      update: { lines: body.lines, discount: new Prisma.Decimal(body.discount), note: body.note, total: new Prisma.Decimal(total) },
      create: {
        number: `INV-${yymm}-${shipment.code}`,
        shipmentId: shipment.id,
        supplierId: shipment.supplierId,
        lines: body.lines,
        discount: new Prisma.Decimal(body.discount),
        note: body.note,
        total: new Prisma.Decimal(total),
      },
    })
    await snapshotInvoice(invoice,existed ? 'Invoice revised' : 'Invoice finalized')
    await releaseExcessPaid(shipment,total,'Invoice finalized below received amount')
    await log(shipment.id, 'Admin', `Invoice ${invoice.number} ${existed ? 'updated' : 'finalized'} — total ৳${total.toLocaleString('en-IN')}`)
    await prisma.shipment.update({ where: { id: shipment.id }, data: { payStatus: num(shipment.paidAmount) >= total ? 'paid' : num(shipment.paidAmount) > 0 ? 'partial' : shipment.supplier.terms === 'monthly' ? 'monthly' : 'unpaid' } })
    // The invoice total is now the amount due everywhere.
    await invalidateReads()
    return c.json({ ok: true, number: invoice.number }, existed ? 200 : 201)
  })

  .post('/:code/track-link', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    const body = z.object({ scope: z.enum(['tracking', 'invoice']).default('tracking'),
      days: z.number().int().min(1).max(90).default(7),
      amount: z.number().positive().multipleOf(0.01).optional(),
    }).parse(await c.req.json())
    if (body.scope === 'invoice' && !shipment.invoice) throw badRequest('Finalize the invoice before sharing')
    const due = Math.max(0, effectiveBill(shipment) - num(shipment.paidAmount))
    if (body.amount !== undefined && body.amount > due) throw badRequest('Requested amount exceeds balance')
    const token = newPublicToken()
    const expiresAt = new Date(Date.now() + body.days * 86400000)
    await prisma.publicLink.create({ data: { shipmentId: shipment.id, tokenHash: tokenHash(token),
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
    if (!shipment.receipt || shipment.receipt.status !== 'pending') throw badRequest('No pending receipt')
    await prisma.receipt.update({ where: { id: shipment.receipt.id }, data: { status: 'approved' } })
    await log(shipment.id, 'Admin', 'Receipt approved ✓')
    // The receipt's amount counts toward the bill — a smaller receipt leaves
    // the shipment partially paid rather than settling it.
    await recordShipmentPayment(shipment, num(shipment.receipt.amount), shipment.receipt.method, 'Admin', shipment.receipt.txnRef)
    return c.json({ ok: true })
  })

  .post('/:code/receipt/reject', requireRole('admin'), async (c) => {
    const shipment = await findByCode(c.req.param('code')!)
    if (!shipment.receipt || shipment.receipt.status !== 'pending') throw badRequest('No pending receipt')
    await prisma.receipt.update({ where: { id: shipment.receipt.id }, data: { status: 'rejected' } })
    await log(shipment.id, 'Admin', 'Receipt rejected — payment not found')
    await invalidateReads()
    return c.json({ ok: true })
  })

/** Called from the public tracking page's receipt upload. */
export async function uploadReceipt(
  shipment: ShipmentWithRelations & { invoice?: { total: Prisma.Decimal } | null },
  method: string,
  actor: string,
  amount: number,
  txnRef: string,
): Promise<{ amount: number; txnRef: string }> {
  if (shipment.receipt?.status === 'pending') throw badRequest('A receipt is already under review')
  // The customer pays what's left, not the original bill.
  const remaining = Math.round((effectiveBill(shipment) - num(shipment.paidAmount)) * 100) / 100
  if (amount <= 0 || amount > remaining) throw badRequest('Invalid payment amount')
  const duplicate = await prisma.receipt.findFirst({ where: { method, txnRef, status: { in: ['pending', 'approved'] } } })
  if (duplicate || await prisma.statementReceipt.count({where:{method,txnRef,status:{in:['pending','approved']}}})) throw badRequest('This transaction reference has already been submitted')
  const processed = await prisma.payment.findFirst({ where: { method, reference: { endsWith: ` / ${txnRef}` } } })
  if (processed) throw badRequest('This transaction has already been credited')
  await prisma.receipt.upsert({
    where: { shipmentId: shipment.id },
    update: { method, amount: new Prisma.Decimal(amount), status: 'pending', txnRef, uploadedAt: new Date() },
    create: { shipmentId: shipment.id, method, amount: new Prisma.Decimal(amount), txnRef },
  })
  await log(shipment.id, actor, `${method} receipt uploaded`)
  await prisma.todo.create({
    data: { role: 'admin', text: `Review ${method} receipt — ${shipment.code} (৳${amount.toLocaleString('en-IN')})`, auto: true },
  })
  await invalidateReads()
  return { amount, txnRef }
}
