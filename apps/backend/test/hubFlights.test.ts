import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono, type Context, type Next } from 'hono'
import type { AppEnv, Role } from '../src/modules/auth'

const db = vi.hoisted(() => ({ flight: { findMany: vi.fn(), findUnique: vi.fn() } }))
vi.mock('../src/core/db', () => ({ prisma: db }))
vi.mock('../src/core/redis', () => ({ cacheInvalidate: vi.fn(), cacheGetJson: vi.fn(), cacheSetJson: vi.fn() }))
vi.mock('../src/shared/settings', () => ({ getSettings: vi.fn(async () => ({ threshold: 0.5 })) }))
vi.mock('../src/shared/flightLookup', () => ({ lookupFlight: vi.fn() }))
vi.mock('../src/shared/ledger', () => ({ creditPayment: vi.fn(), debitCash: vi.fn() }))
vi.mock('../src/modules/auth', () => ({ requireRole: (...roles: Role[]) => async (c: Context<AppEnv>, next: Next) => {
  if (!roles.includes(c.get('user').role)) return c.json({ error: 'Forbidden' }, 403)
  await next()
} }))
const { flightRoutes } = await import('../src/modules/flights')
const { hubFlightRow } = await import('../src/shared/hubFlights')

/** Ticket and booking money that must never reach the hub role. */
const MONEY_KEYS = [
  'fare',
  'actualCost',
  'agencyShare',
  'flyerPaidAmount',
  'flyerDue',
  'contribution',
  'paidAmount',
  'settlements',
  'ticketPaid',
  'ticketDue',
  'revenue',
  'margin',
  'sourceAmount',
  'charge',
  'billAmount',
  'dueAmount',
  'payStatus',
  'paymentTerms',
] as const

function assertNoMoney(payload: unknown) {
  const json = JSON.stringify(payload)
  for (const key of MONEY_KEYS) expect(json.includes(`"${key}":`), key).toBe(false)
  expect(json).not.toContain('Secret Supplier')
}

function appFor(role: Role) {
  const app = new Hono<AppEnv>()
  app.use('*', async (c, next) => {
    c.set('user', { id: 'unit-test', name: 'Unit test', email: 'unit@example.invalid', role, roleLabel: role })
    await next()
  })
  return app.route('/', flightRoutes)
}

const legs = [
  { fromIata: 'CTU', fromCity: 'Chengdu', toIata: 'KMG', toCity: 'Kunming' },
  { fromIata: 'KMG', fromCity: 'Kunming', toIata: 'DAC', toCity: '' },
]

const money = { fare: 9000, actualCost: 12000, agencyShare: 3000, flyerPaidAmount: 500, sourceAmount: 12000 }

const upcoming = {
  ...money,
  code: 'BG147-20261020-ab12cd',
  date: new Date('2026-10-20T00:00:00.000Z'),
  depTime: '10:40',
  arrTime: '15:25',
  via: 'Via KMG Kunming',
  status: 'upcoming',
  flyers: [{ contribution: 9000, paidAmount: 500, flyer: { name: 'Arif Rahman' } }],
  shipments: [
    { bookedKg: 8.2, weighedKg: null, status: 'ready_for_shipment', charge: 4000 },
    { bookedKg: 10, weighedKg: 10.2, status: 'received_bd_hub', charge: 5000 },
  ],
  legs,
}

const manifestShipment = {
  code: 'SH-2051',
  supplier: { code: 'C-14', name: 'Secret Supplier' },
  flight: { code: upcoming.code, date: upcoming.date, spaceKg: 44, agencyShare: 3000 },
  bookedKg: 8.2,
  weighedKg: null,
  description: 'phones',
  categories: ['Mobile'],
  status: 'ready_for_shipment',
  exception: null,
  exceptionReason: '',
  paymentTerms: 'invoice',
  freeOfCharge: false,
  deliveryMode: 'courier',
  lastMileRef: null,
  receipts: [],
  expenses: [],
  costs: [],
  createdAt: new Date('2026-10-15T00:00:00.000Z'),
  charge: 4000,
  customsTax: 0,
  afterSalesFee: 0,
  paidAmount: 1000,
  payMethod: 'bkash',
  invoice: null,
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.useFakeTimers({ toFake: ['Date'] })
  vi.setSystemTime(new Date('2026-10-18T06:00:00.000Z'))
})

afterEach(() => {
  vi.useRealTimers()
})

describe('hub flight schedule', () => {
  it('lists upcoming and arrived flights for the hub without ticket or booking money', async () => {
    db.flight.findMany.mockResolvedValueOnce([upcoming]).mockResolvedValueOnce([])
    const response = await appFor('hub').request('/hub')
    expect(response.status).toBe(200)
    const body = await response.json() as { upcoming: unknown[]; arrived: unknown[] }
    assertNoMoney(body)
    expect(body.arrived).toEqual([])
    expect(body.upcoming).toEqual([
      {
        code: upcoming.code,
        date: '2026-10-20',
        depTime: '10:40',
        arrTime: '15:25',
        via: 'Via KMG Kunming',
        from: 'Chengdu',
        to: 'DAC',
        status: 'upcoming',
        statusLabel: 'Upcoming',
        scheduleNeedsConfirmation: false,
        flyers: ['Arif Rahman'],
        shipmentCount: 2,
        kg: 18.4,
        receivedCount: 1,
      },
    ])
    expect(db.flight.findMany.mock.calls[0]![0]).toMatchObject({ where: { status: { in: ['upcoming', 'departed'] } }, orderBy: { date: 'asc' } })
    expect(db.flight.findMany.mock.calls[1]![0]).toMatchObject({ where: { status: 'completed' }, orderBy: { date: 'desc' }, take: 10 })
  })

  it('returns the manifest and flyer contact for one flight, still without money', async () => {
    db.flight.findUnique.mockResolvedValue({
      ...upcoming,
      flyers: [{ contribution: 9000, paidAmount: 500, flyer: { name: 'Arif Rahman', bdPhone: '01800000000' } }],
      shipments: [manifestShipment],
    })
    const response = await appFor('hub').request(`/hub/${upcoming.code}`)
    expect(response.status).toBe(200)
    const { flight } = await response.json() as { flight: { flyerDetails: unknown[]; shipments: unknown[] } }
    assertNoMoney(flight)
    expect(flight.flyerDetails).toEqual([{ name: 'Arif Rahman', initial: 'A', bdPhone: '01800000000' }])
    expect(flight.shipments).toHaveLength(1)
    expect(flight.shipments[0]).toMatchObject({ code: 'SH-2051', supplierCode: 'C-14', supplierName: null, bookedKg: 8.2 })
    expect(db.flight.findUnique.mock.calls[0]![0]).toMatchObject({ where: { code: upcoming.code } })
  })

  it('keeps the full flight list and detail admin-only', async () => {
    expect((await appFor('hub').request('/')).status).toBe(403)
    expect((await appFor('hub').request(`/${upcoming.code}`)).status).toBe(403)
    expect(db.flight.findMany).not.toHaveBeenCalled()
    expect(db.flight.findUnique).not.toHaveBeenCalled()
  })

  it('flags an upcoming flight whose date has already passed', () => {
    const row = hubFlightRow(upcoming as unknown as Parameters<typeof hubFlightRow>[0], new Date('2026-10-22T08:00:00.000Z'))
    expect(row.scheduleNeedsConfirmation).toBe(true)
  })
})
