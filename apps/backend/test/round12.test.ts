import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono } from 'hono'
import { Prisma } from '@prisma/client'
import type { AppEnv } from '../src/modules/auth'

vi.hoisted(() => {
  process.env.DATABASE_URL ??= 'postgresql://unit:unit@localhost:5432/unit'
  process.env.REDIS_URL ??= 'redis://localhost:6379'
  process.env.LINK_ENCRYPTION_KEY ??= 'ab'.repeat(32)
})

const writeShipmentLog = vi.hoisted(() => vi.fn())
const refreshShipmentInvoice = vi.hoisted(() => vi.fn())
const redis = vi.hoisted(() => ({ get: vi.fn(), incr: vi.fn(), expire: vi.fn(), set: vi.fn(), eval: vi.fn() }))
const cache = vi.hoisted(() => ({ get: vi.fn(async () => null as unknown), set: vi.fn() }))
const db = vi.hoisted(() => ({
  flight: { findUnique: vi.fn(), findMany: vi.fn() },
  shipment: { findMany: vi.fn(), update: vi.fn() },
  shipmentMedia: { findMany: vi.fn(async () => []) },
  setting: { findMany: vi.fn(async () => []) },
  notification: { findUnique: vi.fn(), findFirst: vi.fn(), findMany: vi.fn(), count: vi.fn(), create: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
}))

vi.mock('../src/core/db', () => ({ prisma: db, atomicMutation: async (work: () => Promise<unknown>) => work() }))
vi.mock('../src/core/redis', () => ({
  redis,
  rateLimit: vi.fn(async () => true),
  cacheInvalidate: vi.fn(),
  cacheGetJson: cache.get,
  cacheSetJson: cache.set,
}))
vi.mock('../src/shared/actor', () => ({ writeShipmentLog, currentActor: () => undefined, withActor: (_: unknown, work: () => unknown) => work() }))
vi.mock('../src/shared/shipmentBilling', () => ({ refreshShipmentInvoice }))
vi.mock('@node-rs/argon2', () => ({ verify: vi.fn(), hash: vi.fn() }))

const { config } = await import('../src/core/config')
const notes = await import('../src/shared/notifications')
const { dueReminders, landingInstant, flightFacts } = await import('../src/shared/flightNotices')
const { orderSortState, groupState, sortGroups } = await import('../src/shared/hubSorting')
const { flightPosition, samplePosition, currentLeg, progressOf } = await import('../src/shared/flightPosition')
const { cleanPartners } = await import('../src/shared/settings')
const { devicePhotoMap } = await import('../src/shared/hubFlights')
const { openHubTodo } = await import('../src/shared/hubTodos')
const { sortingRoutes } = await import('../src/modules/sorting')
const { notificationRoutes } = await import('../src/modules/notifications')
const { handleError } = await import('../src/core/errors')

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Any = any

const D = (n: number) => new Prisma.Decimal(n)
const ADMIN = { id: 'admin-1', name: 'Rafiq Ahmed', email: 'admin@example.invalid', role: 'admin' as const, roleLabel: 'admin' }
const HUB = { id: 'hub-1', name: 'Mina Akter', email: 'hub@example.invalid', role: 'hub' as const, roleLabel: 'hub' }

function app(user: typeof ADMIN | typeof HUB) {
  const a = new Hono<AppEnv>()
  a.onError(handleError)
  a.use('*', async (c, next) => {
    c.set('user', user)
    await next()
  })
  a.route('/sorting', sortingRoutes)
  a.route('/notifications', notificationRoutes)
  return a
}

const post = (user: typeof ADMIN | typeof HUB, path: string, body: unknown = {}) =>
  app(user).request(path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })

let seq = 0
/** An order on BG298 for Nila Store (C-14), received at the hub. */
function ship(extra: Record<string, unknown> = {}): Any {
  seq++
  return {
    id: `s-${seq}`,
    code: `SH-4${seq}`,
    status: 'received_bd_hub',
    exception: null,
    sortedAt: null,
    sortedBy: null,
    approvedAt: null,
    approvedBy: null,
    sentBackAt: null,
    sentBackBy: null,
    sentBackNote: '',
    deliveryMode: 'courier',
    lastMileCourier: null,
    lastMileRef: null,
    packedAt: null,
    packageCount: 0,
    arrivedNote: '',
    hubNote: '',
    description: 'garments',
    categories: ['Garments'],
    bookedKg: D(7),
    weighedKg: null,
    chargeRate: D(1200),
    chargeCurrency: 'BDT',
    charge: D(8400),
    customsTax: D(0),
    afterSalesFee: D(0),
    paidAmount: D(0),
    pricingRates: { BDT: 1, CNY: 17 },
    pcsItems: [],
    invoice: null,
    receipts: [],
    expenses: [],
    costs: [],
    flight: null,
    flyer: { name: 'Arif Rahman' },
    supplier: { code: 'C-14', name: 'Nila Store', phone: '01700000000', address: 'Mirpur 10, Dhaka' },
    ...extra,
  }
}

function flightWith(shipments: Any[]) {
  return { id: 'fl-298', code: 'BG298-20261113-ab12cd', date: new Date('2026-11-13T00:00:00Z'), status: 'completed', arrTime: '16:30', shipments }
}

beforeEach(() => {
  vi.clearAllMocks()
  seq = 0
  db.setting.findMany.mockResolvedValue([])
  db.shipmentMedia.findMany.mockResolvedValue([])
  db.shipment.update.mockResolvedValue({})
  db.notification.findUnique.mockResolvedValue(null)
  db.notification.create.mockResolvedValue({})
  cache.get.mockResolvedValue(null)
})

// --------------------------------------------------------------- words

describe('Notification words', () => {
  const now = new Date('2026-11-09T06:00:00Z')
  const facts = { code: 'MU2039-20261114-ab12cd', arrDate: '2026-11-14', arrTime: '15:25', depTime: '10:40', from: 'Chengdu', orders: 6, flyers: ['Arif Rahman'] }

  it('says when a new flight lands, how many days are left and who carries it', () => {
    const n = notes.flightNewNote(facts, now)
    expect(n.roles).toEqual(['hub'])
    expect(n.body).toBe('New flight MU2039. Lands in Dhaka Sat 14 Nov at 15:25, in 5 days. 6 orders, flyer Arif Rahman.')
    expect(notes.flightNewNote({ ...facts, orders: 0 }, now).body).toBe('New flight MU2039. Lands in Dhaka Sat 14 Nov at 15:25, in 5 days. Flyer Arif Rahman.')
  })

  it('writes the flight steps in plain words with no dashes', () => {
    const all = [
      notes.flightTomorrowNote(facts, 'k1', new Date('2026-11-13T12:00:00Z')),
      notes.flightTomorrowNote(facts, 'k1', new Date('2026-11-14T01:00:00Z')),
      notes.flightDepartedNote({ ...facts, arrTime: '15:40', depTime: '10:52' }, 6, 'k2'),
      notes.flightSoonNote({ ...facts, arrTime: '15:40' }, 'k3'),
      notes.flightLandedNote({ ...facts, arrTime: '16:58', orders: 7 }, 'k4'),
      notes.flightCancelledNote(facts, '2026-11-14', 'k5'),
      notes.flightDatePassedNote(facts.code, '2026-11-13', 'k6'),
      notes.ordersReceivedNote('BG298-20261113-ab12cd', 7, 'Mina Akter'),
    ].map((n) => n.body)
    expect(all).toEqual([
      'MU2039 lands tomorrow at 15:25. 6 orders.',
      'MU2039 lands today at 15:25. 6 orders.',
      'MU2039 left Chengdu at 10:52. Lands in Dhaka at 15:40. 6 orders are In transit.',
      'MU2039 lands in about 1 hour at 15:40.',
      'MU2039 landed in Dhaka at 16:58. 7 orders to receive.',
      'The airline cancelled MU2039 on Sat 14 Nov. Nothing was changed here.',
      'MU2039 was due on Fri 13 Nov. The airline has no update. Confirm what happened.',
      'Mina Akter received 7 orders from BG298 at the Dhaka hub.',
    ])
    for (const body of all) expect(body).not.toMatch(/[—–]/)
  })

  it('names the customer for the admin, only the code for the hub', () => {
    const facts = { flightCode: 'BG298-20261113-ab12cd', customerCode: 'C-14', customerName: 'Nila Store', orders: 2, kg: 14.6, by: 'Mina Akter' }
    expect(notes.sortWaitingNote(facts)).toMatchObject({ roles: ['admin'], body: 'Mina Akter sorted Nila Store from BG298: 2 orders, 14.6 kg. Waiting for approval.' })
    const back = notes.sortSentBackNote({ ...facts, by: 'Rafiq Ahmed', note: 'SH-42 needs a photo with the carton open.' })
    expect(back.roles).toEqual(['hub'])
    expect(back.body).not.toContain('Nila')
    expect(notes.sortApprovedNote({ ...facts, partner: 'Steadfast', by: 'Rafiq Ahmed' }).body).toBe('C-14 from BG298 approved. 2 orders In delivery with Steadfast.')
    expect(notes.sortApprovedNote({ ...facts, partner: 'Hub pickup', by: 'Rafiq Ahmed' }).body).toBe('C-14 from BG298 approved. 2 orders ready for pickup at the hub.')
    expect(notes.problemNote('SH-41', 'on_hold', 'Box is wet', 'Mina Akter', 'hub')).toMatchObject({ roles: ['admin'], body: 'SH-41 is on hold: Box is wet (Mina Akter)' })
  })

  it('skips a repeat of the same event and never throws', async () => {
    db.notification.findUnique.mockResolvedValueOnce({ id: 'n1' })
    expect(await notes.notify(notes.flightSoonNote(facts, 'flight:x:soon'))).toBe(false)
    expect(db.notification.create).not.toHaveBeenCalled()
    db.notification.create.mockRejectedValueOnce(new Error('down'))
    const error = vi.spyOn(console, 'error').mockImplementation(() => {})
    expect(await notes.notify(notes.flightSoonNote(facts, 'flight:y:soon'))).toBe(false)
    error.mockRestore()
  })
})

// --------------------------------------------------------------- reminders

describe('Flight reminders', () => {
  const leg = (tracking: unknown = null) => ({
    id: 'leg-1', code: 'MU2039', date: new Date('2026-11-14T00:00:00Z'), fromIata: 'KMG', fromCity: 'Kunming', toIata: 'DAC', depTime: '13:30', arrTime: '15:25', tracking,
  })
  const flight = (extra: Record<string, unknown> = {}): Any => ({
    id: 'fl-1', code: 'MU2039-20261114-ab12cd', date: new Date('2026-11-14T00:00:00Z'), depTime: '13:30', arrTime: '15:25', status: 'upcoming', airlineStatus: null,
    legs: [leg()], flyers: [], _count: { shipments: 6 }, ...extra,
  })
  // 15:25 in Dhaka is 09:25 UTC.
  const land = Date.parse('2026-11-14T09:25:00Z')

  it('lands from the plan, or from the airline once it has a newer time', () => {
    expect(landingInstant(flight())).toBe(land)
    const late = flight({ legs: [leg({ status: 'EnRoute', arr: '2026-11-14T09:40:00.000Z', arrLocal: '15:40' })] })
    expect(landingInstant(late)).toBe(Date.parse('2026-11-14T09:40:00Z'))
    expect(flightFacts(late)).toMatchObject({ arrDate: '2026-11-14', arrTime: '15:40', orders: 6 })
  })

  it('reminds a day before, an hour before, and the day after a date with no update', () => {
    expect(dueReminders(flight(), land - 25 * 3600_000)).toEqual([])
    expect(dueReminders(flight(), land - 20 * 3600_000)).toEqual(['tomorrow'])
    expect(dueReminders(flight({ status: 'departed' }), land - 30 * 60_000)).toEqual(['soon'])
    expect(dueReminders(flight(), land + 30 * 60_000)).toEqual([])
    expect(dueReminders(flight(), Date.parse('2026-11-15T03:00:00Z'))).toEqual(['passed'])
    expect(dueReminders(flight({ airlineStatus: 'cancelled' }), land - 30 * 60_000)).toEqual([])
    expect(dueReminders(flight({ status: 'completed' }), land - 30 * 60_000)).toEqual([])
  })
})

// --------------------------------------------------------------- sorting rules

describe('Sorting states', () => {
  it('reads where each order is', () => {
    expect(orderSortState(ship({ status: 'customs_cleared' }))).toBe('not_received')
    expect(orderSortState(ship())).toBe('to_sort')
    expect(orderSortState(ship({ sentBackAt: new Date() }))).toBe('sent_back')
    expect(orderSortState(ship({ status: 'ready_for_last_mile', sortedAt: new Date() }))).toBe('waiting_admin')
    expect(orderSortState(ship({ status: 'ready_for_last_mile', sortedAt: new Date(), approvedAt: new Date(), deliveryMode: 'pickup' }))).toBe('ready_pickup')
    expect(orderSortState(ship({ status: 'out_for_delivery' }))).toBe('in_delivery')
    expect(orderSortState(ship({ status: 'delivered' }))).toBe('delivered')
    expect(orderSortState(ship({ exception: 'on_hold' }))).toBe('problem')
    // Booked the older way: the admin approves what the hub booked.
    expect(orderSortState(ship({ status: 'ready_for_last_mile', packedAt: new Date(), lastMileCourier: 'Pathao' }))).toBe('waiting_admin')
  })

  it('shows a customer by its most urgent order', () => {
    expect(groupState(['waiting_admin', 'sent_back'])).toBe('sent_back')
    expect(groupState(['not_received', 'to_sort'])).toBe('to_sort')
    expect(groupState(['not_received'])).toBe('not_received')
    expect(groupState(['delivered', 'in_delivery'])).toBe('in_delivery')
  })

  it('keeps names, phones and money away from the hub', () => {
    const list = [ship({ weighedKg: D(7.4) }), ship({ supplier: { code: 'C-20', name: 'Sky Mobile', phone: '01800000000', address: 'Dhaka' } })]
    const media = [{ shipmentId: 's-1', reference: 'r-goods', purpose: 'goods', deviceKey: null }, { shipmentId: 's-1', reference: 'r-pack', purpose: 'packing', deviceKey: null }]
    const hub = sortGroups(list, media, 'hub', { rate: 17, threshold: 1 })
    const text = JSON.stringify(hub)
    for (const secret of ['Nila', 'Sky Mobile', '01700000000', 'Mirpur', 'bill', 'money']) expect(text).not.toContain(secret)
    expect(hub[0]).toMatchObject({ customerCode: 'C-14', state: 'to_sort', packingPhotos: [{ reference: 'r-pack', order: expect.any(String) }], orders: [{ goodsPhotos: ['r-goods'], flyerName: 'Arif Rahman' }] })
    const admin = sortGroups(list, media, 'admin', { rate: 17, threshold: 1 })
    expect(admin[0]).toMatchObject({ customerName: 'Nila Store', customerPhone: '01700000000', money: { bill: 8400, bookedBill: 8400 } })
  })

  it('asks the admin to look when an order weighs more than booked by the threshold', () => {
    const [g] = sortGroups([ship({ bookedKg: D(4), weighedKg: D(5.1) })], [], 'admin', { rate: 17, threshold: 1 })
    expect(g).toMatchObject({ needsLook: true, bookedKg: 4, measuredKg: 5.1, orders: [{ weightDelta: 1.1 }] })
  })

  it('hub to-dos follow sorting', () => {
    const base = { code: 'SH-1', weighedKg: 7, packedAt: new Date(), lastMileRef: null, deliveryMode: 'courier', exception: null }
    expect(openHubTodo({ ...base, status: 'received_bd_hub' })?.triggerKey).toBe('hub:SH-1:sort')
    expect(openHubTodo({ ...base, status: 'ready_for_last_mile', sortedAt: new Date() })).toBeNull()
  })
})

// --------------------------------------------------------------- sorting routes

describe('Hub sorts a customer and sends it to the admin', () => {
  const body = (orders: { code: string; kg: number; arrived: string }[], extra: Record<string, unknown> = {}) => ({ orders, packages: 2, partner: 'steadfast', ...extra })

  it('records weight, what arrived, packing and partner, and tells the admin', async () => {
    const a = ship()
    const b = ship({ bookedKg: D(7.2), weighedKg: D(7.2), description: 'cosmetics' })
    const pending = ship({ status: 'customs_cleared' })
    db.flight.findUnique.mockResolvedValue(flightWith([a, b, pending]))
    const res = await post(HUB, '/sorting/flights/BG298-20261113-ab12cd/customers/C-14/sort', body([
      { code: a.code, kg: 7.4, arrived: '3 cartons of ladies kurtis' },
      { code: b.code, kg: 7.2, arrived: '1 carton of creams and lotions, sealed' },
    ], { note: 'Customer asked for delivery after 5 pm.' }))
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ sorted: [a.code, b.code] })
    // Only the order whose weight changed is priced again.
    expect(refreshShipmentInvoice).toHaveBeenCalledTimes(1)
    expect(db.shipment.update).toHaveBeenCalledWith(expect.objectContaining({ where: { id: a.id }, data: expect.objectContaining({ weighedKg: D(7.4), charge: 8880 }) }))
    const sorted = db.shipment.update.mock.calls.map((call: Any[]) => call[0]).filter((u: Any) => u.data.sortedBy)
    expect(sorted).toHaveLength(2)
    expect(sorted[0].data).toMatchObject({
      status: 'ready_for_last_mile', arrivedNote: '3 cartons of ladies kurtis', hubNote: 'Customer asked for delivery after 5 pm.', packageCount: 2,
      lastMileCourier: 'Steadfast', lastMileRef: null, deliveryMode: 'courier', sortedBy: 'Mina Akter', sentBackAt: null,
    })
    expect(db.notification.create).toHaveBeenCalledWith({ data: expect.objectContaining({ event: 'sort_waiting', roles: ['admin'], customerCode: 'C-14' }) })
  })

  it('needs every received order, a partner from the list and what arrived', async () => {
    const a = ship()
    const b = ship()
    db.flight.findUnique.mockResolvedValue(flightWith([a, b]))
    const one = await post(HUB, '/sorting/flights/F/customers/C-14/sort', body([{ code: a.code, kg: 7, arrived: 'shoes' }]))
    expect(one.status).toBe(400)
    expect(((await one.json()) as Any).error).toContain(b.code)
    const wrong = await post(HUB, '/sorting/flights/F/customers/C-14/sort', body([{ code: a.code, kg: 7, arrived: 'shoes' }, { code: b.code, kg: 7, arrived: 'bags' }], { partner: 'DHL' }))
    expect(wrong.status).toBe(400)
    const blank = await post(HUB, '/sorting/flights/F/customers/C-14/sort', body([{ code: a.code, kg: 7, arrived: '' }, { code: b.code, kg: 7, arrived: 'bags' }]))
    expect(blank.status).toBe(400)
    expect(db.shipment.update).not.toHaveBeenCalled()
  })

  it('books Hub pickup as a pickup', async () => {
    const a = ship()
    db.flight.findUnique.mockResolvedValue(flightWith([a]))
    const res = await post(HUB, '/sorting/flights/F/customers/C-14/sort', body([{ code: a.code, kg: 0, arrived: '2 phones in their boxes' }], { partner: 'Hub pickup', courierRef: '' }))
    expect(res.status).toBe(200)
    const sorted = db.shipment.update.mock.calls.map((call: Any[]) => call[0]).find((u: Any) => u.data.sortedBy)
    expect(sorted.data).toMatchObject({ deliveryMode: 'pickup', lastMileCourier: 'Hub pickup' })
  })
})

describe('Admin approves or sends back', () => {
  const waiting = (extra: Record<string, unknown> = {}) =>
    ship({ status: 'ready_for_last_mile', sortedAt: new Date(), sortedBy: 'Mina Akter', packedAt: new Date(), lastMileCourier: 'Steadfast', weighedKg: D(7.4), ...extra })

  it('moves courier orders to In delivery and tells the hub', async () => {
    const a = waiting()
    db.flight.findUnique.mockResolvedValue(flightWith([a]))
    const res = await post(ADMIN, '/sorting/flights/F/customers/C-14/approve')
    expect(await res.json()).toEqual({ approved: [a.code] })
    expect(db.shipment.update).toHaveBeenCalledWith({ where: { id: a.id }, data: expect.objectContaining({ status: 'out_for_delivery', approvedBy: 'Rafiq Ahmed' }) })
    expect(db.notification.create).toHaveBeenCalledWith({ data: expect.objectContaining({ event: 'sort_approved', roles: ['hub'] }) })
  })

  it('keeps an approved Hub pickup at the hub, ready for pickup', async () => {
    const a = waiting({ deliveryMode: 'pickup', lastMileCourier: 'Hub pickup' })
    db.flight.findUnique.mockResolvedValue(flightWith([a]))
    await post(ADMIN, '/sorting/flights/F/customers/C-14/approve')
    const data = (db.shipment.update.mock.calls as Any)[0][0].data
    expect(data.status).toBeUndefined()
    expect(data.approvedBy).toBe('Rafiq Ahmed')
  })

  it('only the admin approves', async () => {
    db.flight.findUnique.mockResolvedValue(flightWith([waiting()]))
    expect((await post(HUB, '/sorting/flights/F/customers/C-14/approve')).status).toBe(403)
  })

  it('sends back with a note: the orders wait at the hub again', async () => {
    const a = waiting()
    db.flight.findUnique.mockResolvedValue(flightWith([a]))
    expect((await post(ADMIN, '/sorting/flights/F/customers/C-14/send-back', { note: 'no' })).status).toBe(400)
    const res = await post(ADMIN, '/sorting/flights/F/customers/C-14/send-back', { note: 'SH-42 needs a photo with the carton open.' })
    expect(res.status).toBe(200)
    expect(db.shipment.update).toHaveBeenCalledWith({
      where: { id: a.id },
      data: expect.objectContaining({ status: 'received_bd_hub', sortedAt: null, sentBackNote: 'SH-42 needs a photo with the carton open.', sentBackBy: 'Rafiq Ahmed' }),
    })
    expect(db.notification.create).toHaveBeenCalledWith({ data: expect.objectContaining({ event: 'sort_sent_back', roles: ['hub'] }) })
  })

  it('Approve all leaves the customers that need a look', async () => {
    const fine = waiting()
    const heavy = waiting({ supplier: { code: 'C-30', name: 'Karim Electronics', phone: '—', address: '—' }, bookedKg: D(4), weighedKg: D(5.1) })
    db.flight.findUnique.mockResolvedValue(flightWith([fine, heavy]))
    const res = await post(ADMIN, '/sorting/flights/F/approve-all')
    expect(await res.json()).toEqual({ approved: [fine.code], skipped: ['C-30'] })
  })

  it('adds the courier ID later and confirms delivery for the customer', async () => {
    const a = ship({ status: 'out_for_delivery', sortedAt: new Date(), approvedAt: new Date(), packedAt: new Date(), lastMileCourier: 'Steadfast' })
    db.flight.findUnique.mockResolvedValue(flightWith([a]))
    expect((await post(HUB, '/sorting/flights/F/customers/C-14/courier-ref', { ref: 'SF-88231' })).status).toBe(200)
    expect(db.shipment.update).toHaveBeenCalledWith({ where: { id: a.id }, data: { lastMileRef: 'SF-88231' } })
    const res = await post(HUB, '/sorting/flights/F/customers/C-14/delivered', { confirmation: 'Received by the shop manager' })
    expect(await res.json()).toEqual({ delivered: [a.code] })
    expect(db.notification.create).toHaveBeenCalledWith({ data: expect.objectContaining({ event: 'delivered', roles: ['admin'] }) })
  })
})

// --------------------------------------------------------------- the bell

describe('Notifications list', () => {
  it('shows the role its own notifications with read marks, and marks all read', async () => {
    db.notification.findMany.mockResolvedValue([
      { id: 'n1', event: 'flight_soon', title: 't', body: 'b', params: { flight: 'MU2039' }, flightCode: 'MU2039-20261114-ab12cd', shipmentCode: null, customerCode: null, readBy: [], createdAt: new Date('2026-11-14T08:40:00Z') },
      { id: 'n2', event: 'flight_departed', title: 't', body: 'b', params: {}, flightCode: null, shipmentCode: null, customerCode: null, readBy: ['hub-1'], createdAt: new Date('2026-11-14T05:32:00Z') },
    ])
    db.notification.count.mockResolvedValue(1)
    const res = await app(HUB).request('/notifications')
    const json = (await res.json()) as Any
    expect(json.unread).toBe(1)
    expect(json.notifications.map((n: Any) => n.read)).toEqual([false, true])
    expect((db.notification.findMany.mock.calls as Any)[0][0].where).toEqual({ roles: { has: 'hub' } })
    db.notification.updateMany.mockResolvedValue({ count: 1 })
    await post(HUB, '/notifications/read-all')
    expect(db.notification.updateMany).toHaveBeenCalledWith({ where: { roles: { has: 'hub' }, NOT: { readBy: { has: 'hub-1' } } }, data: { readBy: { push: 'hub-1' } } })
  })
})

// --------------------------------------------------------------- Track

describe('Track', () => {
  const legs = [
    { code: 'MU2039', date: new Date('2026-11-14T00:00:00Z'), fromIata: 'TFU', fromCity: 'Chengdu', toIata: 'KMG', toCity: 'Kunming', tracking: { status: 'Arrived' } },
    { code: 'MU2039', date: new Date('2026-11-14T00:00:00Z'), fromIata: 'KMG', fromCity: 'Kunming', toIata: 'DAC', toCity: 'Dhaka', tracking: { status: 'EnRoute' } },
  ]
  const flight = { id: 'fl-1', date: new Date('2026-11-14T00:00:00Z'), status: 'departed', airlineStatus: 'on_the_way', legs } as Any

  it('picks the leg in the air and draws the whole route', () => {
    expect(currentLeg(legs as Any)?.fromIata).toBe('KMG')
    const sample = samplePosition(legs[1] as Any, legs as Any, new Date('2026-11-14T08:22:00Z'))
    expect(sample.sample).toBe(true)
    expect(sample.route.map((r) => r.iata)).toEqual(['TFU', 'KMG', 'DAC'])
    expect(sample.progress).toBeGreaterThan(50)
    expect(progressOf(sample.from, sample.to, { lat: sample.to.lat!, lon: sample.to.lon! })).toBe(100)
  })

  it('answers only for flights in the air', async () => {
    const answer = await flightPosition({ ...flight, status: 'upcoming', airlineStatus: 'scheduled' }, false)
    expect(answer).toEqual({ inAir: false, track: null, nextRefreshAt: null, refreshesLeft: 0, note: null })
  })

  it('keeps one answer for 15 minutes and stops after 6 refreshes a day', async () => {
    const original = config.aerodataboxKey
    ;(config as Any).aerodataboxKey = 'test-key'
    try {
      const now = new Date('2026-11-14T08:30:00Z')
      const kept = { ...samplePosition(legs[1] as Any, legs as Any, new Date('2026-11-14T08:22:00Z')), sample: false }
      cache.get.mockResolvedValue(kept)
      redis.get.mockResolvedValue('2')
      const early = await flightPosition(flight, true, now)
      expect(early).toMatchObject({ inAir: true, refreshesLeft: 4, nextRefreshAt: '2026-11-14T08:37:00.000Z' })
      expect(redis.incr).not.toHaveBeenCalled()
      redis.get.mockResolvedValue('6')
      redis.incr.mockResolvedValue(7)
      const used = await flightPosition(flight, true, new Date('2026-11-14T09:00:00Z'))
      expect(used).toMatchObject({ note: 'limit', refreshesLeft: 0 })
    } finally {
      ;(config as Any).aerodataboxKey = original
    }
  })
})

// --------------------------------------------------------------- small parts

describe('Partners and device photos', () => {
  it('cleans the partner list and keeps Hub pickup out of it', () => {
    expect(cleanPartners([' Steadfast ', 'steadfast', '', 'Hub pickup', 'e  Courier'])).toEqual(['Steadfast', 'e Courier'])
  })

  it('names each device photo after its device', () => {
    const map = devicePhotoMap(
      [
        { shipmentId: 's1', reference: 'r1', purpose: 'device_photo', deviceKey: '0:1' },
        { shipmentId: 's1', reference: 'r2', purpose: 'device_photo', deviceKey: '1:0' },
        { shipmentId: 's1', reference: 'r3', purpose: 'device_category', deviceKey: 'Laptop' },
      ],
      new Map([['s1', [{ category: 'Mobile', count: 2 }, { category: 'Laptop', count: 1 }]]]),
    )
    expect(map.get('s1')).toEqual([{ reference: 'r1', label: 'Mobile 2' }, { reference: 'r2', label: 'Laptop' }, { reference: 'r3', label: 'Laptop' }])
  })
})
