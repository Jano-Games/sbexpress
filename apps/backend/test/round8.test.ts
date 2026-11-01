import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono } from 'hono'
import { Prisma } from '@prisma/client'
import type { AppEnv, Role } from '../src/modules/auth'

vi.hoisted(() => {
  process.env.DATABASE_URL ??= 'postgresql://unit:unit@localhost:5432/unit'
  process.env.REDIS_URL ??= 'redis://localhost:6379'
  process.env.LINK_ENCRYPTION_KEY ??= 'ab'.repeat(32)
})

const db = vi.hoisted(() => ({
  setting: { findMany: vi.fn(), upsert: vi.fn() },
  flight: { findUnique: vi.fn(), findMany: vi.fn(), update: vi.fn() },
  shipment: { findUnique: vi.fn(), findMany: vi.fn(), update: vi.fn() },
  invoice: { upsert: vi.fn(), update: vi.fn() },
  invoiceRevision: { count: vi.fn(), create: vi.fn() },
  creditNote: { create: vi.fn() },
  shipmentLog: { create: vi.fn() },
}))

vi.mock('../src/core/db', () => ({ prisma: db, atomicMutation: async (work: () => Promise<unknown>) => work() }))
vi.mock('../src/core/redis', () => ({ redis: {}, rateLimit: vi.fn(async () => true), cacheInvalidate: vi.fn(), cacheGetJson: vi.fn(async () => null), cacheSetJson: vi.fn() }))
vi.mock('@node-rs/argon2', () => ({ verify: vi.fn(), hash: vi.fn() }))

const { flightRoutes } = await import('../src/modules/flights')
const { settingsRoutes } = await import('../src/modules/settings')
const { handleError } = await import('../src/core/errors')
const { cacheInvalidate } = await import('../src/core/redis')

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Any = any

const send = (method: string, body?: unknown) => ({
  method,
  headers: { 'content-type': 'application/json' },
  body: body === undefined ? undefined : JSON.stringify(body),
})

function appFor(role: Role, path: string, routes: Hono<AppEnv>) {
  const app = new Hono<AppEnv>()
  app.onError(handleError)
  app.use('*', async (c, next) => {
    c.set('user', { id: `${role}-1`, name: `Unit ${role}`, email: `${role}@example.invalid`, role, roleLabel: role })
    await next()
  })
  return app.route(path, routes)
}
const admin = () => appFor('admin', '/flights', flightRoutes)
const hub = () => appFor('hub', '/flights', flightRoutes)

/** Settings rows held in memory, read and written the way getSettings/putRaw do. */
const settingRows = new Map<string, string>()
function useSettings(values: Record<string, string>) {
  settingRows.clear()
  for (const [key, value] of Object.entries(values)) settingRows.set(key, value)
}

beforeEach(() => {
  vi.clearAllMocks()
  settingRows.clear()
  db.setting.findMany.mockImplementation(async () => [...settingRows].map(([key, value]) => ({ key, value })))
  db.setting.upsert.mockImplementation(async ({ where, update }: Any) => settingRows.set(where.key, update.value))
})

// ─────────────────────────────────────────────────────────────────────────
// Default rates in settings
// ─────────────────────────────────────────────────────────────────────────

describe('Default rate per kg in settings', () => {
  const app = () => appFor('admin', '/settings', settingsRoutes)

  it('starts unset in taka and keeps what is saved', async () => {
    const first = ((await (await app().request('/settings')).json()) as Any).settings
    expect(first).toMatchObject({ kgRate: 0, kgRateCurrency: 'BDT' })

    const saved = await app().request('/settings', send('PATCH', { kgRate: 1250, kgRateCurrency: 'CNY', pcsRates: { Mobile: 1400 } }))
    expect(saved.status).toBe(200)
    expect(((await saved.json()) as Any).settings).toMatchObject({ kgRate: 1250, kgRateCurrency: 'CNY', pcsRates: { Mobile: 1400 } })
    expect(settingRows.get('kgRate')).toBe('1250')
    expect(settingRows.get('kgRateCurrency')).toBe('CNY')

    const again = ((await (await app().request('/settings')).json()) as Any).settings
    expect(again).toMatchObject({ kgRate: 1250, kgRateCurrency: 'CNY' })

    // Changing one leaves the other alone.
    await app().request('/settings', send('PATCH', { kgRate: 0 }))
    expect(((await (await app().request('/settings')).json()) as Any).settings).toMatchObject({ kgRate: 0, kgRateCurrency: 'CNY' })
  })

  it('refuses a negative, huge or unknown-currency rate', async () => {
    for (const body of [{ kgRate: -1 }, { kgRate: 1_000_001 }, { kgRateCurrency: 'USD' }, { kgRate: '1200' }]) {
      expect((await app().request('/settings', send('PATCH', body))).status, JSON.stringify(body)).toBe(400)
    }
    expect(db.setting.upsert).not.toHaveBeenCalled()
  })

  it('reads damaged stored values as unset', async () => {
    useSettings({ kgRate: 'abc', kgRateCurrency: 'USD' })
    expect(((await (await app().request('/settings')).json()) as Any).settings).toMatchObject({ kgRate: 0, kgRateCurrency: 'BDT' })
    useSettings({ kgRate: '-50', kgRateCurrency: 'BDT' })
    expect(((await (await app().request('/settings')).json()) as Any).settings).toMatchObject({ kgRate: 0, kgRateCurrency: 'BDT' })
  })
})

// ─────────────────────────────────────────────────────────────────────────
// A flight's own rates
// ─────────────────────────────────────────────────────────────────────────

const FLIGHT_CODE = 'BG305-20261024-abc123'
const supplier = { id: 'sup-1', code: 'SUP-004', name: 'Nila Store', phone: '01700000000', terms: 'instant', archivedAt: null }

function shipmentFixture(over: Record<string, unknown> = {}): Any {
  return {
    id: 'sh-1', code: 'SH-1', supplierId: supplier.id, supplier,
    flightId: 'fl-1', flight: { code: FLIGHT_CODE, date: new Date('2026-10-24'), spaceKg: 44, agencyShare: 0 }, flyerId: null, flyer: null,
    bookedKg: 4, weighedKg: null, charge: 0, chargeRate: 0, chargeCurrency: 'BDT', pricingRates: { BDT: 1, CNY: 17 }, pcsItems: [],
    customsTax: 0, afterSalesFee: 0, paidAmount: 0, freeOfCharge: false, paymentTerms: 'invoice', payStatus: 'unpaid', payMethod: null,
    status: 'booked', createdAt: new Date('2026-10-20'), handedOverAt: null, description: '—', categories: ['Mobile'], serials: [],
    exception: null, exceptionReason: '', deliveryMode: 'courier', lastMileRef: null, lastMileCourier: null, deliveryBookedAt: null,
    dispatchedAt: null, packedAt: null, packageCount: 0, photosCount: 0, hasVideo: false,
    cnFare: 0, bdFare: null, costSources: {}, trackToken: 'token',
    invoice: null, costs: [], receipts: [], expenses: [], logs: [], payments: [],
    ...over,
  }
}

const autoInvoice = (shipmentId: string, total: number, over: Record<string, unknown> = {}) => ({
  id: `inv-${shipmentId}`, number: `INV-2610-${shipmentId}`, shipmentId, supplierId: supplier.id, state: 'issued', pricingMode: 'automatic', needsReview: false,
  lines: [{ label: 'Shipment charges', amount: total }], discount: 0, total, note: '', issuedAt: new Date('2026-10-20'), updatedAt: new Date('2026-10-20'),
  sourceCurrency: 'BDT', sourceFxRate: 1, sourceAmount: total, pricingFingerprint: null,
  ...over,
})

interface FlightStore {
  flight: Any
  shipments: Any[]
  logs: { shipmentId: string; message: string }[]
}

/** One flight and its orders held in memory, read the way the flight and billing code reads them. */
function flightStore(flight: Record<string, unknown>, shipments: Any[]): FlightStore {
  const store: FlightStore = {
    flight: {
      id: 'fl-1', code: FLIGHT_CODE, date: new Date('2026-10-24'), depTime: '10:00', arrTime: '14:00', via: 'Direct', status: 'upcoming',
      fare: 0, actualCost: 0, agencyShare: 0, flyerPaidAmount: 0, spaceKg: 44, mobiles: 2, laptops: 1,
      sourceCurrency: 'BDT', sourceFxRate: 1, sourceAmount: 0, kgRate: null, kgRateCurrency: null, pcsRates: null,
      legs: [], flyers: [], expenses: [],
      ...flight,
    },
    shipments,
    logs: [],
  }
  const view = () => ({ ...store.flight, shipments: store.shipments })
  const find = (where: Any) => store.shipments.find((s) => s.id === where.id || s.code === where.code) ?? null
  db.flight.findUnique.mockImplementation(async ({ where }: Any) => (where.code === FLIGHT_CODE || where.id === 'fl-1' ? view() : null))
  db.flight.findMany.mockImplementation(async () => [view()])
  db.flight.update.mockImplementation(async ({ data }: Any) => {
    Object.assign(store.flight, { ...data, pcsRates: data.pcsRates === Prisma.DbNull ? null : data.pcsRates })
    return store.flight
  })
  db.shipment.findMany.mockImplementation(async ({ where }: Any) => store.shipments.filter((s) => s.flightId === where.flightId))
  db.shipment.findUnique.mockImplementation(async ({ where }: Any) => find(where))
  db.shipment.update.mockImplementation(async ({ where, data }: Any) => Object.assign(find(where), data))
  db.invoice.upsert.mockImplementation(async ({ where, create, update }: Any) => {
    const shipment = find({ id: where.shipmentId })
    shipment.invoice = shipment.invoice ? { ...shipment.invoice, ...update } : { id: `inv-${shipment.id}`, note: '', issuedAt: new Date(), updatedAt: new Date(), ...create }
    return shipment.invoice
  })
  db.invoiceRevision.count.mockResolvedValue(1)
  db.shipmentLog.create.mockImplementation(async ({ data }: Any) => store.logs.push({ shipmentId: data.shipmentId, message: data.message }))
  return store
}

const RATE_KEYS = ['ownRates', 'kgRate', 'kgRateCurrency', 'pcsRates', 'rateFollowers'] as const

describe('Saving a flight’s own rates', () => {
  beforeEach(() => useSettings({ rate: '17', kgRate: '1200', kgRateCurrency: 'BDT', pcsRates: JSON.stringify({ Mobile: 1400, Laptop: 2800 }) }))

  it('stores the flight’s rates and shows them on the flight', async () => {
    const store = flightStore({}, [])
    const response = await admin().request(`/flights/${FLIGHT_CODE}/rates`, send('PUT', { own: true, kgRate: 1300, pcsRates: { Mobile: 1500, ' Laptop ': 3000 } }))
    expect(response.status).toBe(200)
    const body = (await response.json()) as Any
    expect(body.updated).toBe(0)
    expect(body.flight).toMatchObject({ code: FLIGHT_CODE, ownRates: true, kgRate: 1300, kgRateCurrency: 'BDT', pcsRates: { Mobile: 1500, Laptop: 3000 } })
    expect(db.flight.update).toHaveBeenCalledWith({ where: { id: 'fl-1' }, data: { kgRate: 1300, kgRateCurrency: 'BDT', pcsRates: { Mobile: 1500, Laptop: 3000 } } })
    expect(store.flight).toMatchObject({ kgRate: 1300, kgRateCurrency: 'BDT' })
    // Without applyToOrders no order is read or touched.
    expect(db.shipment.findMany).not.toHaveBeenCalled()
    expect(db.shipment.update).not.toHaveBeenCalled()
    expect(cacheInvalidate).toHaveBeenCalledWith('dashboard')
    expect(cacheInvalidate).toHaveBeenCalledWith('track')

    const list = (await (await admin().request('/flights')).json()) as Any
    expect(list.flights[0]).toMatchObject({ ownRates: true, kgRate: 1300, kgRateCurrency: 'BDT', pcsRates: { Mobile: 1500, Laptop: 3000 } })

    const yuan = await admin().request(`/flights/${FLIGHT_CODE}/rates`, send('PUT', { own: true, kgRate: 75.456, kgRateCurrency: 'CNY' }))
    expect(((await yuan.json()) as Any).flight).toMatchObject({ ownRates: true, kgRate: 75.46, kgRateCurrency: 'CNY', pcsRates: {} })
  })

  it('clears the flight back to the defaults', async () => {
    const store = flightStore({ kgRate: 1300, kgRateCurrency: 'CNY', pcsRates: { Mobile: 1500 } }, [])
    const response = await admin().request(`/flights/${FLIGHT_CODE}/rates`, send('PUT', { own: false, kgRate: 999, pcsRates: { Mobile: 1 } }))
    expect(response.status).toBe(200)
    expect(((await response.json()) as Any).flight).toMatchObject({ ownRates: false, kgRate: null, kgRateCurrency: null, pcsRates: null })
    expect(db.flight.update).toHaveBeenCalledWith({ where: { id: 'fl-1' }, data: { kgRate: null, kgRateCurrency: null, pcsRates: Prisma.DbNull } })
    expect(store.flight).toMatchObject({ kgRate: null, kgRateCurrency: null, pcsRates: null })
  })

  it('needs a rate per kg, an admin and a known flight', async () => {
    flightStore({}, [])
    const missing = await admin().request(`/flights/${FLIGHT_CODE}/rates`, send('PUT', { own: true, pcsRates: { Mobile: 1500 } }))
    expect(missing.status).toBe(400)
    expect(((await missing.json()) as Any).error).toBe('Enter the rate per kg for this flight')
    for (const body of [{ own: true, kgRate: -5 }, { own: true, kgRate: 1300, pcsRates: { Mobile: -1 } }, { kgRate: 1300 }, { own: true, kgRate: 1300, kgRateCurrency: 'USD' }]) {
      expect((await admin().request(`/flights/${FLIGHT_CODE}/rates`, send('PUT', body))).status, JSON.stringify(body)).toBe(400)
    }
    expect((await admin().request('/flights/NOPE/rates', send('PUT', { own: true, kgRate: 1300 }))).status).toBe(404)
    expect((await hub().request(`/flights/${FLIGHT_CODE}/rates`, send('PUT', { own: true, kgRate: 1300 }))).status).toBe(403)
    expect(db.flight.update).not.toHaveBeenCalled()
  })
})

describe('Applying a flight’s rates to its orders', () => {
  beforeEach(() => useSettings({ rate: '17', kgRate: '1200', kgRateCurrency: 'BDT', pcsRates: JSON.stringify({ Mobile: 1400, Laptop: 2800 }) }))

  /** Orders on the flight while it is on the defaults: ৳1200/kg, Mobile ৳1400, Laptop ৳2800. */
  const orders = () => [
    // Follows: on the default kg rate.
    shipmentFixture({ id: 'sh-1', code: 'SH-1', bookedKg: 5, chargeRate: 1200, charge: 6000, invoice: autoInvoice('sh-1', 6000) }),
    // Follows: a custom kg rate but a device on the default piece price (category in any case).
    shipmentFixture({ id: 'sh-2', code: 'SH-2', bookedKg: 3, chargeRate: 1000, charge: 5800, pcsItems: [{ category: 'mobile', count: 2, rate: 1400, currency: 'BDT', units: [] }], invoice: autoInvoice('sh-2', 5800) }),
    // Something is paid.
    shipmentFixture({ id: 'sh-3', code: 'SH-3', bookedKg: 2, chargeRate: 1200, charge: 2400, paidAmount: 500, payStatus: 'partial', invoice: autoInvoice('sh-3', 2400) }),
    // A payment exists even though nothing is counted as paid yet.
    shipmentFixture({ id: 'sh-4', code: 'SH-4', bookedKg: 2, chargeRate: 1200, charge: 2400, payments: [{ id: 'pay-1' }], invoice: autoInvoice('sh-4', 2400) }),
    // Hand-edited invoice.
    shipmentFixture({ id: 'sh-5', code: 'SH-5', bookedKg: 2, chargeRate: 1200, charge: 2400, invoice: autoInvoice('sh-5', 2300, { pricingMode: 'manual' }) }),
    // A different kg rate and a different piece price.
    shipmentFixture({ id: 'sh-6', code: 'SH-6', bookedKg: 2, chargeRate: 1100, charge: 3650, pcsItems: [{ category: 'Mobile', count: 1, rate: 1450, currency: 'BDT', units: [] }] }),
    // The same number in yuan is a different rate.
    shipmentFixture({ id: 'sh-7', code: 'SH-7', bookedKg: 1, chargeRate: 1200, chargeCurrency: 'CNY', charge: 20400 }),
    // A device priced in yuan never follows the taka piece price.
    shipmentFixture({ id: 'sh-8', code: 'SH-8', bookedKg: 1, chargeRate: 1000, charge: 24800, pcsItems: [{ category: 'Mobile', count: 1, rate: 1400, currency: 'CNY', units: [] }] }),
  ]

  it('reprices only the unpaid orders still on the old rates', async () => {
    const store = flightStore({}, orders())
    const untouched = JSON.parse(JSON.stringify(store.shipments.slice(2)))
    const detail = async () => ((await (await admin().request(`/flights/${FLIGHT_CODE}`)).json()) as Any).flight
    expect((await detail()).rateFollowers).toBe(2)

    const response = await admin().request(`/flights/${FLIGHT_CODE}/rates`, send('PUT', {
      own: true, kgRate: 1300, kgRateCurrency: 'BDT', pcsRates: { Mobile: 1500 }, applyToOrders: true,
    }))
    expect(response.status).toBe(200)
    const body = (await response.json()) as Any
    expect(body.updated).toBe(2)
    expect(body.flight).toMatchObject({ ownRates: true, kgRate: 1300, revenue: expect.any(Number) })

    const [sh1, sh2] = store.shipments
    expect(Number(sh1.chargeRate)).toBe(1300)
    expect(Number(sh1.charge)).toBe(6500)
    expect(sh1.invoice).toMatchObject({ state: 'issued', pricingMode: 'automatic', total: 6500 })
    expect(Number(sh2.chargeRate)).toBe(1000)
    expect(sh2.pcsItems).toEqual([{ category: 'mobile', count: 2, rate: 1500, currency: 'BDT', units: [] }])
    expect(Number(sh2.charge)).toBe(6000)
    expect(sh2.invoice).toMatchObject({ total: 6000 })
    expect(JSON.parse(JSON.stringify(store.shipments.slice(2)))).toEqual(untouched)

    expect(store.logs.filter((l) => l.message.startsWith('Rates from flight'))).toEqual([
      { shipmentId: 'sh-1', message: 'Rates from flight BG305: ৳1300/kg (charge ৳6500)' },
      { shipmentId: 'sh-2', message: 'Rates from flight BG305: mobile ৳1500 each (charge ৳6000)' },
    ])
    expect(store.logs.map((l) => l.shipmentId).every((id) => id === 'sh-1' || id === 'sh-2')).toBe(true)

    // Against the flight's new rates the same two orders follow.
    expect((await detail()).rateFollowers).toBe(2)
  })

  it('moves orders back to the defaults when the flight’s own rates are cleared', async () => {
    const store = flightStore({ kgRate: 1300, kgRateCurrency: 'BDT', pcsRates: { Mobile: 1500 } }, [
      shipmentFixture({ id: 'sh-1', code: 'SH-1', bookedKg: 5, chargeRate: 1300, charge: 6500, invoice: autoInvoice('sh-1', 6500) }),
      // Laptop has no flight price, so it sat on the default and stays there.
      shipmentFixture({ id: 'sh-2', code: 'SH-2', bookedKg: 0, chargeRate: 0, charge: 2800, pcsItems: [{ category: 'Laptop', count: 1, rate: 2800, currency: 'BDT', units: [] }] }),
    ])
    const response = await admin().request(`/flights/${FLIGHT_CODE}/rates`, send('PUT', { own: false, applyToOrders: true }))
    expect(((await response.json()) as Any).updated).toBe(1)
    expect(Number(store.shipments[0].chargeRate)).toBe(1200)
    expect(Number(store.shipments[0].charge)).toBe(6000)
    expect(store.shipments[1].charge).toBe(2800)
    expect(store.logs.find((l) => l.message.startsWith('Rates'))?.message).toBe('Rates from flight BG305: ৳1200/kg (charge ৳6000)')
  })

  it('leaves the kg part alone when the default rate per kg is not set', async () => {
    useSettings({ rate: '17', pcsRates: JSON.stringify({ Mobile: 1400 }) })
    const store = flightStore({ kgRate: 1300, kgRateCurrency: 'BDT', pcsRates: { Mobile: 1500 } }, [
      shipmentFixture({ id: 'sh-1', code: 'SH-1', bookedKg: 2, chargeRate: 1300, charge: 4100, pcsItems: [{ category: 'Mobile', count: 1, rate: 1500, currency: 'BDT', units: [] }] }),
    ])
    const response = await admin().request(`/flights/${FLIGHT_CODE}/rates`, send('PUT', { own: false, applyToOrders: true }))
    expect(((await response.json()) as Any).updated).toBe(1)
    expect(Number(store.shipments[0].chargeRate)).toBe(1300)
    expect(store.shipments[0].pcsItems[0].rate).toBe(1400)
    expect(Number(store.shipments[0].charge)).toBe(4000)
  })

  it('counts followers against the flight’s own rates, falling back to the default piece price', async () => {
    flightStore({ kgRate: 1300, kgRateCurrency: 'BDT', pcsRates: { Mobile: 1500 } }, [
      // Laptop has no flight price: the default ৳2800 is the flight's rate.
      shipmentFixture({ id: 'a', code: 'SH-A', bookedKg: 0, chargeRate: 0, charge: 2800, pcsItems: [{ category: 'LAPTOP', count: 1, rate: 2800, currency: 'BDT', units: [] }] }),
      // The flight overrides Mobile, so the default ৳1400 is not its rate.
      shipmentFixture({ id: 'b', code: 'SH-B', bookedKg: 1, chargeRate: 1000, charge: 2400, pcsItems: [{ category: 'Mobile', count: 1, rate: 1400, currency: 'BDT', units: [] }] }),
      // The default kg rate is not the flight's either.
      shipmentFixture({ id: 'c', code: 'SH-C', bookedKg: 1, chargeRate: 1200, charge: 1200 }),
      shipmentFixture({ id: 'd', code: 'SH-D', bookedKg: 1, chargeRate: 1300, charge: 1300 }),
    ])
    const flight = ((await (await admin().request(`/flights/${FLIGHT_CODE}`)).json()) as Any).flight
    expect(flight).toMatchObject({ ownRates: true, kgRate: 1300, kgRateCurrency: 'BDT', pcsRates: { Mobile: 1500 }, rateFollowers: 2 })
  })

  it('never counts an order on a ৳0 rate as a follower', async () => {
    useSettings({ rate: '17' })
    flightStore({}, [shipmentFixture({ bookedKg: 2, chargeRate: 0, charge: 0 })])
    const flight = ((await (await admin().request(`/flights/${FLIGHT_CODE}`)).json()) as Any).flight
    expect(flight).toMatchObject({ ownRates: false, kgRate: null, kgRateCurrency: null, pcsRates: null, rateFollowers: 0 })
  })
})

describe('The hub never sees flight rates', () => {
  it('keeps rate fields out of the hub schedule and manifest', async () => {
    useSettings({ rate: '17', kgRate: '1200', pcsRates: JSON.stringify({ Mobile: 1400 }) })
    flightStore({ kgRate: 1300, kgRateCurrency: 'CNY', pcsRates: { Mobile: 1500 } }, [
      shipmentFixture({ chargeRate: 1300, charge: 2600, bookedKg: 2, pcsItems: [{ category: 'Mobile', count: 1, rate: 1500, currency: 'BDT', units: [] }] }),
    ])
    db.flight.findMany.mockResolvedValueOnce([{ ...(await db.flight.findUnique({ where: { id: 'fl-1' } })) }]).mockResolvedValueOnce([])
    const schedule = await hub().request('/flights/hub')
    const detail = await hub().request(`/flights/hub/${FLIGHT_CODE}`)
    expect(schedule.status).toBe(200)
    expect(detail.status).toBe(200)
    for (const payload of [await schedule.text(), await detail.text()]) {
      expect(payload).toContain(FLIGHT_CODE)
      for (const key of RATE_KEYS) expect(payload.includes(`"${key}":`), key).toBe(false)
      expect(payload).not.toContain('"rate":')
      expect(payload).not.toContain('"chargeRate":')
    }
    expect((await hub().request(`/flights/${FLIGHT_CODE}`)).status).toBe(403)
  })
})
