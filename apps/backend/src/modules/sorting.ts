import { Hono } from 'hono'
import { z } from 'zod'
import { prisma } from '../core/db'
import { badRequest, notFound } from '../core/errors'
import { requireRole, type AppEnv } from './auth'
import { writeShipmentLog } from '../shared/actor'
import { getSettings, HUB_PICKUP } from '../shared/settings'
import { isoDate, numOrNull } from '../shared/serialize'
import { FLIGHT_LABEL } from '../shared/status'
import {
  SORT_INCLUDE,
  applyMeasuredWeight,
  loadSortMedia,
  orderSortState,
  sortGroups,
  sortable,
  type SortShipment,
  type SortState,
} from '../shared/hubSorting'
import {
  deliveredNote,
  flightNumber,
  notify,
  sortApprovedNote,
  sortSentBackNote,
  sortWaitingNote,
} from '../shared/notifications'

const customerParam = z.string().trim().min(1).max(60)

async function flightOrders(code: string) {
  const flight = await prisma.flight.findUnique({
    where: { code },
    select: { id: true, code: true, date: true, status: true, arrTime: true, shipments: { include: SORT_INCLUDE, orderBy: { code: 'asc' } } },
  })
  if (!flight) throw notFound('Flight not found')
  return flight
}

/** One customer's orders on the flight; refuses a customer with none there. */
async function customerOrders(flightCode: string, customer: string) {
  const flight = await flightOrders(flightCode)
  const orders = flight.shipments.filter((s) => s.supplier.code === customer)
  if (!orders.length) throw notFound('No orders for this customer on this flight')
  return { flight, orders }
}

const ofState = (orders: SortShipment[], ...states: SortState[]) => orders.filter((s) => states.includes(orderSortState(s)))

async function partnerList(): Promise<string[]> {
  return [...(await getSettings()).deliveryPartners, HUB_PICKUP]
}

const flightDto = (f: { code: string; date: Date; status: keyof typeof FLIGHT_LABEL; arrTime: string }) => ({
  code: f.code,
  number: flightNumber(f.code),
  date: isoDate(f.date),
  arrTime: f.arrTime,
  status: f.status,
})

const sortBody = z
  .object({
    orders: z
      .array(
        z.object({
          code: z.string().min(1).max(40),
          kg: z.number().min(0).max(10000),
          arrived: z.string().trim().min(2, 'Write what arrived').max(300),
        }),
      )
      .min(1)
      .max(200),
    packages: z.number().int().min(1, 'At least 1 package').max(1000),
    partner: z.string().trim().min(1).max(60),
    courierRef: z.string().trim().max(200).optional(),
    note: z.string().trim().max(500).optional(),
  })
  .strict()

export const sortingRoutes = new Hono<AppEnv>()
  /** The flight's customers to sort, waiting for the admin, and in delivery. */
  .get('/flights/:code', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const [flight, settings] = await Promise.all([flightOrders(c.req.param('code')!), getSettings()])
    const media = await loadSortMedia(flight.shipments.map((s) => s.id))
    const groups = sortGroups(flight.shipments, media, user.role, settings)
    return c.json({
      flight: flightDto(flight),
      partners: [...settings.deliveryPartners, HUB_PICKUP],
      groups,
    })
  })

  /** The hub sends one customer's sorted orders to the admin. */
  .post('/flights/:code/customers/:customer/sort', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const body = sortBody.parse(await c.req.json())
    const customer = customerParam.parse(c.req.param('customer'))
    const [{ flight, orders }, settings] = await Promise.all([customerOrders(c.req.param('code')!, customer), getSettings()])
    const partners = [...settings.deliveryPartners, HUB_PICKUP]
    const partner = partners.find((p) => p.toLowerCase() === body.partner.toLowerCase())
    if (!partner) throw badRequest('Pick a delivery partner from the list')
    const open = orders.filter(sortable)
    if (!open.length) throw badRequest('Nothing to sort for this customer')
    const sent = new Set(body.orders.map((o) => o.code))
    const missing = open.filter((s) => !sent.has(s.code)).map((s) => s.code)
    if (missing.length) throw badRequest(`Sort every received order: ${missing.join(', ')}`)
    const extra = body.orders.filter((o) => !open.some((s) => s.code === o.code)).map((o) => o.code)
    if (extra.length) throw badRequest(`Not ready to sort: ${extra.join(', ')}`)

    const now = new Date()
    const pickup = partner === HUB_PICKUP
    const ref = body.courierRef ? body.courierRef : null
    for (const s of open) {
      const line = body.orders.find((o) => o.code === s.code)!
      if (numOrNull(s.weighedKg) !== line.kg) await applyMeasuredWeight(s, line.kg, settings, user.name)
      await prisma.shipment.update({
        where: { id: s.id },
        data: {
          status: 'ready_for_last_mile',
          arrivedNote: line.arrived,
          hubNote: body.note ?? '',
          packageCount: body.packages,
          packedAt: now,
          lastMileCourier: partner,
          lastMileRef: ref,
          deliveryMode: pickup ? 'pickup' : 'courier',
          deliveryBookedAt: now,
          sortedAt: now,
          sortedBy: user.name,
          approvedAt: null,
          approvedBy: null,
          sentBackNote: '',
          sentBackAt: null,
          sentBackBy: null,
        },
      })
      await writeShipmentLog(s.id, `Sorted: ${line.arrived}; ${body.packages} package(s); ${partner}${ref ? ` ${ref}` : ''}. Waiting for admin`, user.name)
    }
    const kg = Math.round(open.reduce((t, s) => t + body.orders.find((o) => o.code === s.code)!.kg, 0) * 10) / 10
    await notify(
      sortWaitingNote({ flightCode: flight.code, customerCode: customer, customerName: open[0]!.supplier.name, orders: open.length, kg, by: user.name }),
    )
    return c.json({ sorted: open.map((s) => s.code) })
  })

  /** Approve: courier orders go In delivery; Hub pickup orders are ready for pickup. */
  .post('/flights/:code/customers/:customer/approve', requireRole('admin'), async (c) => {
    const user = c.get('user')
    const customer = customerParam.parse(c.req.param('customer'))
    const { flight, orders } = await customerOrders(c.req.param('code')!, customer)
    const approved = await approveOrders(flight.code, customer, orders, user.name)
    if (!approved.length) throw badRequest('Nothing is waiting for approval for this customer')
    return c.json({ approved })
  })

  /** Approves every customer on the flight that needs no look; the others stay for a person. */
  .post('/flights/:code/approve-all', requireRole('admin'), async (c) => {
    const user = c.get('user')
    const [flight, settings] = await Promise.all([flightOrders(c.req.param('code')!), getSettings()])
    const groups = sortGroups(flight.shipments, [], 'admin', settings).filter((g) => g.state === 'waiting_admin')
    if (!groups.length) throw badRequest('Nothing is waiting for approval on this flight')
    const approved: string[] = []
    const skipped: string[] = []
    for (const g of groups) {
      if (g.needsLook) {
        skipped.push(g.customerCode)
        continue
      }
      const orders = flight.shipments.filter((s) => s.supplier.code === g.customerCode)
      approved.push(...(await approveOrders(flight.code, g.customerCode, orders, user.name)))
    }
    return c.json({ approved, skipped })
  })

  /** Sends one customer back to the hub with a note; the orders wait at the hub. */
  .post('/flights/:code/customers/:customer/send-back', requireRole('admin'), async (c) => {
    const user = c.get('user')
    const { note } = z.object({ note: z.string().trim().min(3, 'Write what needs fixing').max(500) }).strict().parse(await c.req.json())
    const customer = customerParam.parse(c.req.param('customer'))
    const { flight, orders } = await customerOrders(c.req.param('code')!, customer)
    const waiting = ofState(orders, 'waiting_admin')
    if (!waiting.length) throw badRequest('Nothing is waiting for approval for this customer')
    const now = new Date()
    for (const s of waiting) {
      await prisma.shipment.update({
        where: { id: s.id },
        data: { status: 'received_bd_hub', packedAt: null, sortedAt: null, sortedBy: null, sentBackNote: note, sentBackAt: now, sentBackBy: user.name },
      })
      await writeShipmentLog(s.id, `Sent back to the hub: ${note}`, user.name)
    }
    await notify(sortSentBackNote({ flightCode: flight.code, customerCode: customer, orders: waiting.length, by: user.name, note }))
    return c.json({ sentBack: waiting.map((s) => s.code) })
  })

  /** Adds or corrects the courier ID while the orders are not delivered yet. */
  .post('/flights/:code/customers/:customer/courier-ref', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const { ref } = z.object({ ref: z.string().trim().min(1, 'Enter the courier ID').max(200) }).strict().parse(await c.req.json())
    const customer = customerParam.parse(c.req.param('customer'))
    const { orders } = await customerOrders(c.req.param('code')!, customer)
    const open = ofState(orders, 'waiting_admin', 'in_delivery', 'ready_pickup')
    if (!open.length) throw badRequest('No booked delivery for this customer')
    for (const s of open) {
      await prisma.shipment.update({ where: { id: s.id }, data: { lastMileRef: ref } })
      await writeShipmentLog(s.id, `Courier ID ${s.lastMileRef ? `changed from ${s.lastMileRef} to` : 'added:'} ${ref}`, user.name)
    }
    return c.json({ updated: open.map((s) => s.code) })
  })

  /** The customer has the orders: courier delivered or collected at the hub. */
  .post('/flights/:code/customers/:customer/delivered', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const { confirmation } = z
      .object({ confirmation: z.string().trim().min(3, 'Write who received it').max(300) })
      .strict()
      .parse(await c.req.json())
    const customer = customerParam.parse(c.req.param('customer'))
    const { flight, orders } = await customerOrders(c.req.param('code')!, customer)
    const open = ofState(orders, 'in_delivery', 'ready_pickup')
    if (!open.length) throw badRequest('Nothing is out for delivery for this customer')
    const now = new Date()
    for (const s of open) {
      await prisma.shipment.update({ where: { id: s.id }, data: { status: 'delivered', handedOverAt: now } })
      await writeShipmentLog(s.id, `Delivery confirmed${s.deliveryMode === 'pickup' ? ' (hub collection)' : ''}: ${confirmation}`, user.name)
    }
    await notify(
      deliveredNote({ flightCode: flight.code, customerCode: customer, customerName: open[0]!.supplier.name, orders: open.length, by: user.name }),
    )
    return c.json({ delivered: open.map((s) => s.code) })
  })

  /** Everything waiting for the admin, by flight, newest flight first. */
  .get('/approvals', requireRole('admin'), async (c) => {
    const settings = await getSettings()
    const waiting = await prisma.shipment.findMany({
      where: { status: 'ready_for_last_mile', approvedAt: null, exception: null, flightId: { not: null } },
      select: { flightId: true },
      distinct: ['flightId'],
    })
    const flights = await prisma.flight.findMany({
      where: { id: { in: waiting.map((w) => w.flightId!) } },
      select: { id: true, code: true, date: true, status: true, arrTime: true, shipments: { include: SORT_INCLUDE, orderBy: { code: 'asc' } } },
      orderBy: { date: 'desc' },
    })
    const media = await loadSortMedia(flights.flatMap((f) => f.shipments.map((s) => s.id)))
    const out = flights
      .map((f) => ({ flight: flightDto(f), groups: sortGroups(f.shipments, media, 'admin', settings).filter((g) => g.state === 'waiting_admin') }))
      .filter((f) => f.groups.length)
    return c.json({ flights: out, count: out.reduce((t, f) => t + f.groups.length, 0) })
  })

  /** The hub's day: customers to sort or fix, waiting for the admin, and in delivery. */
  .get('/hub-summary', requireRole('admin', 'hub'), async (c) => {
    const rows = await prisma.shipment.findMany({
      where: { status: { in: ['received_bd_hub', 'ready_for_last_mile', 'out_for_delivery'] }, flightId: { not: null } },
      select: {
        status: true,
        exception: true,
        sortedAt: true,
        approvedAt: true,
        sentBackAt: true,
        deliveryMode: true,
        lastMileCourier: true,
        packedAt: true,
        supplier: { select: { code: true } },
        flight: { select: { code: true, date: true } },
      },
    })
    type Bucket = { flightCode: string; number: string; date: string; customers: Set<string>; orders: number }
    type Kind = 'to_sort' | 'sent_back' | 'waiting' | 'delivery'
    const buckets: Record<Kind, Map<string, Bucket>> = { to_sort: new Map(), sent_back: new Map(), waiting: new Map(), delivery: new Map() }
    for (const r of rows) {
      const state = orderSortState(r)
      const kind: Kind | null =
        state === 'to_sort' || state === 'sent_back'
          ? state
          : state === 'waiting_admin'
            ? 'waiting'
            : state === 'in_delivery' || state === 'ready_pickup'
              ? 'delivery'
              : null
      if (!kind) continue
      const map = buckets[kind]
      const b = map.get(r.flight!.code) ?? { flightCode: r.flight!.code, number: flightNumber(r.flight!.code), date: isoDate(r.flight!.date), customers: new Set(), orders: 0 }
      b.customers.add(r.supplier.code)
      b.orders++
      map.set(r.flight!.code, b)
    }
    const list = (map: Map<string, Bucket>) =>
      [...map.values()]
        .sort((a, b) => a.date.localeCompare(b.date))
        .map((b) => ({ flightCode: b.flightCode, number: b.number, date: b.date, customers: [...b.customers].sort(), orders: b.orders }))
    const customers = (map: Map<string, Bucket>) => [...map.values()].reduce((n, b) => n + b.customers.size, 0)
    return c.json({
      toSort: list(buckets.to_sort),
      sentBack: list(buckets.sent_back),
      waiting: list(buckets.waiting),
      delivery: list(buckets.delivery),
      waitingAdmin: customers(buckets.waiting),
      inDelivery: customers(buckets.delivery),
    })
  })

async function approveOrders(flightCode: string, customer: string, orders: SortShipment[], by: string): Promise<string[]> {
  const waiting = ofState(orders, 'waiting_admin')
  if (!waiting.length) return []
  const now = new Date()
  for (const s of waiting) {
    const pickup = s.deliveryMode === 'pickup'
    await prisma.shipment.update({
      where: { id: s.id },
      data: {
        approvedAt: now,
        approvedBy: by,
        ...(s.sortedAt ? {} : { sortedAt: s.packedAt ?? now, sortedBy: by }),
        ...(pickup ? {} : { status: 'out_for_delivery' as const, dispatchedAt: now }),
      },
    })
    await writeShipmentLog(s.id, pickup ? 'Approved: ready for pickup at the hub' : `Approved: In delivery with ${s.lastMileCourier ?? 'the courier'}`, by)
  }
  await notify(sortApprovedNote({ flightCode, customerCode: customer, orders: waiting.length, partner: waiting[0]!.lastMileCourier, by }))
  return waiting.map((s) => s.code)
}

