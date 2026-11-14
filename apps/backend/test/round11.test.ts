import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono } from 'hono'
import type { AppEnv } from '../src/modules/auth'

vi.hoisted(() => {
  process.env.DATABASE_URL ??= 'postgresql://unit:unit@localhost:5432/unit'
  process.env.REDIS_URL ??= 'redis://localhost:6379'
  process.env.LINK_ENCRYPTION_KEY ??= 'ab'.repeat(32)
})

const writeShipmentLog = vi.hoisted(() => vi.fn())
const redis = vi.hoisted(() => ({ incr: vi.fn(), expire: vi.fn(), set: vi.fn(), eval: vi.fn() }))
const db = vi.hoisted(() => ({
  flight: { findUnique: vi.fn(), findFirst: vi.fn(), findMany: vi.fn(), update: vi.fn() },
  flightFlyer: { findMany: vi.fn(), update: vi.fn() },
  flightLeg: { findMany: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
  shipment: { findMany: vi.fn(), update: vi.fn() },
}))

vi.mock('../src/core/db', () => ({ prisma: db, atomicMutation: async (work: () => Promise<unknown>) => work() }))
vi.mock('../src/core/redis', () => ({ redis, rateLimit: vi.fn(async () => true), cacheInvalidate: vi.fn(), cacheGetJson: vi.fn(async () => null), cacheSetJson: vi.fn() }))
vi.mock('../src/shared/actor', () => ({ writeShipmentLog, currentActor: () => undefined, withActor: (_: unknown, work: () => unknown) => work() }))
vi.mock('@node-rs/argon2', () => ({ verify: vi.fn(), hash: vi.fn() }))

const { config } = await import('../src/core/config')
const { providerPacing } = await import('../src/shared/flightLookup')
const tracking = await import('../src/shared/flightTracking')
const view = await import('../src/shared/flightTrackingView')
const { flightRoutes } = await import('../src/modules/flights')
const { handleError } = await import('../src/core/errors')

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Any = any

const realPacing = { ...providerPacing }

/** An AeroDataBox movement: planned, and optionally the latest (actual or expected) time. */
const move = (plan: [string, string], latest?: [string, string]) => ({
  scheduledTime: { utc: plan[0], local: plan[1] },
  ...(latest ? { revisedTime: { utc: latest[0], local: latest[1] } } : {}),
})

/** BG305 Chengdu 13:40 (UTC+8) to Dhaka 17:15 (UTC+6) on Fri 13 Nov. */
const bg305Leg = (extra: Record<string, unknown> = {}) => ({
  id: 'leg-1',
  code: 'BG305',
  date: new Date('2026-11-13T00:00:00Z'),
  fromIata: 'CTU',
  fromCity: 'Chengdu',
  toIata: 'DAC',
  toCity: 'Dhaka',
  depTime: '13:40',
  arrTime: '17:15',
  tracking: null,
  ...extra,
})

const bg305 = (extra: Record<string, unknown> = {}) => ({
  id: 'fl-bg',
  code: 'BG305-20261113-ab12cd',
  date: new Date('2026-11-13T00:00:00Z'),
  status: 'upcoming',
  airlineStatus: null,
  trackedAt: null,
  trackChecks: 0,
  legs: [bg305Leg()],
  ...extra,
})

const at = (iso: string) => new Date(iso)

function airline(rows: Record<string, unknown>) {
  const fetchMock = vi.fn(async (url: string) => {
    const key = /flights\/number\/([^?]+)\?/.exec(url)?.[1] ?? ''
    const row = rows[key]
    return row ? new Response(JSON.stringify([row]), { status: 200 }) : new Response('', { status: 404 })
  })
  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}

beforeEach(() => {
  vi.clearAllMocks()
  Object.assign(providerPacing, { gapMs: 0, retryMs: 0 })
  ;(config as Any).aerodataboxKey = 'unit-key'
  redis.incr.mockResolvedValue(1)
  db.flightLeg.findMany.mockResolvedValue([])
  db.flightFlyer.findMany.mockResolvedValue([{ flyerId: 'f-sumon', paidAmount: 0 }])
  db.shipment.findMany.mockResolvedValue([])
  db.flight.update.mockImplementation(async ({ data }: Any) => data)
})

afterEach(() => {
  vi.unstubAllGlobals()
  ;(config as Any).aerodataboxKey = ''
  Object.assign(providerPacing, realPacing)
})

describe('Reading what the airline says', () => {
  it('keeps the planned and actual times, local clock and minutes late', () => {
    const leg = tracking.legTracking(
      {
        status: 'EnRoute',
        departure: move(['2026-11-20 05:10Z', '2026-11-20 13:10+08:00'], ['2026-11-20 05:34Z', '2026-11-20 13:34+08:00']),
        arrival: move(['2026-11-20 11:25Z', '2026-11-20 17:25+06:00'], ['2026-11-20 11:48Z', '2026-11-20 17:48+06:00']),
      },
      at('2026-11-20T08:10:00Z'),
    )
    expect(leg).toEqual({
      status: 'EnRoute',
      checkedAt: '2026-11-20T08:10:00.000Z',
      planDep: '2026-11-20T05:10:00.000Z',
      planArr: '2026-11-20T11:25:00.000Z',
      dep: '2026-11-20T05:34:00.000Z',
      arr: '2026-11-20T11:48:00.000Z',
      depLocal: '13:34',
      arrLocal: '17:48',
      depLateMin: 24,
      arrLateMin: 23,
    })
  })

  it('stores a day with no flight as not found', () => {
    expect(tracking.legTracking(null, at('2026-11-13T06:30:00Z'))).toMatchObject({ status: 'NotFound', dep: null, depLateMin: null })
  })

  it('reads the whole trip from its legs', () => {
    const t = (status: string) => tracking.legTracking({ status }, at('2026-11-20T08:00:00Z'))
    expect(view.airlineState([null])).toBeNull()
    expect(view.airlineState([t('Expected'), null])).toBe('scheduled')
    expect(view.airlineState([t('Arrived'), t('EnRoute')])).toBe('on_the_way')
    expect(view.airlineState([t('Arrived'), t('Arrived')])).toBe('landed')
    expect(view.airlineState([t('Canceled')])).toBe('cancelled')
    expect(view.airlineState([t('NotFound')])).toBe('none')
  })
})

describe('When the server asks the airline', () => {
  it('asks soon after take-off and soon after landing, by each airport\'s clock', () => {
    const flight = bg305() as Any
    // 13:40 in Chengdu is 05:40 UTC; 17:15 in Dhaka is 11:15 UTC.
    expect(tracking.checkPoints(flight).map((p) => new Date(p).toISOString())).toEqual(['2026-11-13T06:20:00.000Z', '2026-11-13T11:45:00.000Z'])
    expect(tracking.isDue(flight, Date.parse('2026-11-13T06:10:00Z'))).toBe(false)
    expect(tracking.isDue(flight, Date.parse('2026-11-13T06:25:00Z'))).toBe(true)
    expect(tracking.isDue({ ...flight, trackedAt: at('2026-11-13T06:25:00Z') }, Date.parse('2026-11-13T09:00:00Z'))).toBe(false)
    expect(tracking.isDue({ ...flight, trackedAt: at('2026-11-13T06:25:00Z') }, Date.parse('2026-11-13T11:50:00Z'))).toBe(true)
  })

  it('waits for a later take-off the airline gives', () => {
    const late = tracking.legTracking(
      { status: 'Delayed', departure: move(['2026-11-13 05:40Z', '2026-11-13 13:40+08:00'], ['2026-11-13 08:00Z', '2026-11-13 16:00+08:00']) },
      at('2026-11-13T06:25:00Z'),
    )
    const flight = bg305({ airlineStatus: 'scheduled', trackedAt: at('2026-11-13T06:25:00Z'), trackChecks: 1, legs: [bg305Leg({ tracking: late })] }) as Any
    expect(tracking.isDue(flight, Date.parse('2026-11-13T08:30:00Z'))).toBe(false)
    expect(tracking.isDue(flight, Date.parse('2026-11-13T08:41:00Z'))).toBe(true)
  })

  it('stops asking after a cancellation, a landing or too many checks', () => {
    const now = Date.parse('2026-11-13T12:00:00Z')
    expect(tracking.isDue(bg305({ airlineStatus: 'cancelled' }) as Any, now)).toBe(false)
    expect(tracking.isDue(bg305({ airlineStatus: 'landed' }) as Any, now)).toBe(false)
    expect(tracking.isDue(bg305({ status: 'completed' }) as Any, now)).toBe(false)
    expect(tracking.isDue(bg305({ trackChecks: tracking.TRACKING.maxChecks }) as Any, now)).toBe(false)
  })

  it('puts a connection\'s later leg after the one before it', () => {
    const flight = {
      date: new Date('2026-11-20T00:00:00Z'),
      legs: [
        { ...bg305Leg(), date: new Date('2026-11-20T00:00:00Z'), code: 'MU5842', fromIata: 'PEK', toIata: 'PVG', depTime: '22:10', arrTime: '00:25' },
        { ...bg305Leg(), id: 'leg-2', date: null, code: 'MU2035', fromIata: 'PVG', toIata: 'DAC', depTime: '08:10', arrTime: '11:25' },
      ],
    } as Any
    const [first, second] = tracking.plannedTimes(flight)
    expect(new Date(first!.dep).toISOString()).toBe('2026-11-20T14:10:00.000Z')
    expect(new Date(first!.arr).toISOString()).toBe('2026-11-20T16:25:00.000Z')
    expect(new Date(second!.dep).toISOString()).toBe('2026-11-21T00:10:00.000Z')
    expect(new Date(second!.arr).toISOString()).toBe('2026-11-21T05:25:00.000Z')
  })
})

describe('Checking a flight with the airline', () => {
  const enRoute = {
    status: 'EnRoute',
    departure: move(['2026-11-13 05:40Z', '2026-11-13 13:40+08:00'], ['2026-11-13 05:52Z', '2026-11-13 13:52+08:00']),
    arrival: move(['2026-11-13 11:15Z', '2026-11-13 17:15+06:00'], ['2026-11-13 11:20Z', '2026-11-13 17:20+06:00']),
  }

  it('makes the flight Departed and moves the orders ready for shipment', async () => {
    const flight = bg305()
    db.flight.findUnique.mockResolvedValue(flight)
    db.shipment.findMany.mockResolvedValue([
      { id: 's-41', code: 'SH-41', flyerId: 'f-sumon' },
      { id: 's-42', code: 'SH-42', flyerId: null },
    ])
    const fetchMock = airline({ 'BG305/2026-11-13': enRoute })
    const result = await tracking.checkFlight(flight as Any, at('2026-11-13T06:25:00Z'))

    expect(result).toEqual({ calls: 1, status: 'departed' })
    expect(fetchMock.mock.calls[0]![0]).toContain('/flights/number/BG305/2026-11-13?dateLocalRole=Departure')
    expect(db.flightLeg.update.mock.calls[0]![0]).toMatchObject({ where: { id: 'leg-1' }, data: { tracking: { status: 'EnRoute', depLocal: '13:52' } } })
    expect(db.flight.update.mock.calls[0]![0].data).toMatchObject({ airlineStatus: 'on_the_way', trackedAt: at('2026-11-13T06:25:00Z'), trackChecks: { increment: 1 } })
    // Only orders ready for shipment and free of problems are asked for.
    expect(db.shipment.findMany.mock.calls[0]![0].where).toEqual({ flightId: 'fl-bg', status: 'ready_for_shipment', exception: null })
    // The flight's only flyer carries the order that had none.
    expect(db.shipment.update.mock.calls.map((c: Any) => c[0])).toEqual([
      { where: { id: 's-41' }, data: { status: 'in_transit', flyerId: 'f-sumon' } },
      { where: { id: 's-42' }, data: { status: 'in_transit', flyerId: 'f-sumon' } },
    ])
    expect(writeShipmentLog).toHaveBeenCalledWith('s-41', 'Status → In Transit', 'Flight tracking')
    expect(db.flight.update.mock.calls[1]![0].data).toMatchObject({
      status: 'departed',
      statusSetBy: 'airline',
      movedOrders: { by: 'airline', codes: ['SH-41', 'SH-42'] },
    })
  })

  it('leaves an order with no flyer when the flight has several', async () => {
    const flight = bg305()
    db.flight.findUnique.mockResolvedValue(flight)
    db.flightFlyer.findMany.mockResolvedValue([{ flyerId: 'f-sumon' }, { flyerId: 'f-arif' }])
    db.shipment.findMany.mockResolvedValue([{ id: 's-42', code: 'SH-42', flyerId: null }])
    airline({ 'BG305/2026-11-13': enRoute })
    await tracking.checkFlight(flight as Any, at('2026-11-13T06:25:00Z'))
    expect(db.shipment.update).not.toHaveBeenCalled()
    expect(db.flight.update.mock.calls[1]![0].data.movedOrders).toMatchObject({ codes: [] })
  })

  it('lands an upcoming flight and still moves its ready orders', async () => {
    const flight = bg305()
    db.flight.findUnique.mockResolvedValue(flight)
    db.shipment.findMany.mockResolvedValue([{ id: 's-41', code: 'SH-41', flyerId: 'f-sumon' }])
    airline({ 'BG305/2026-11-13': { ...enRoute, status: 'Arrived' } })
    const result = await tracking.checkFlight(flight as Any, at('2026-11-13T11:50:00Z'))
    expect(result?.status).toBe('completed')
    expect(db.flight.update.mock.calls[1]![0].data).toMatchObject({ status: 'completed', statusSetBy: 'airline' })
    expect(db.shipment.update).toHaveBeenCalledTimes(1)
  })

  it('changes nothing when the airline cancels', async () => {
    const flight = bg305()
    db.flight.findUnique.mockResolvedValue(flight)
    airline({ 'BG305/2026-11-13': { status: 'Canceled', departure: move(['2026-11-13 05:40Z', '2026-11-13 13:40+08:00']) } })
    const result = await tracking.checkFlight(flight as Any, at('2026-11-13T06:25:00Z'))
    expect(result).toEqual({ calls: 1, status: 'upcoming' })
    expect(db.flight.update).toHaveBeenCalledTimes(1)
    expect(db.flight.update.mock.calls[0]![0].data.airlineStatus).toBe('cancelled')
    expect(db.shipment.findMany).not.toHaveBeenCalled()
  })

  it('never moves a flight back', async () => {
    const flight = bg305({ status: 'departed' })
    db.flight.findUnique.mockResolvedValue(flight)
    airline({ 'BG305/2026-11-13': { status: 'Expected' } })
    const result = await tracking.checkFlight(flight as Any, at('2026-11-13T06:25:00Z'))
    expect(result?.status).toBe('departed')
    expect(db.flight.update).toHaveBeenCalledTimes(1)
  })

  it('remembers a day the airline has nothing for', async () => {
    const flight = bg305()
    db.flight.findUnique.mockResolvedValue(flight)
    airline({})
    await tracking.checkFlight(flight as Any, at('2026-11-13T06:25:00Z'))
    expect(db.flight.update.mock.calls[0]![0].data.airlineStatus).toBe('none')
  })

  it('stops for the day once the allowance is used', async () => {
    const flight = bg305()
    redis.incr.mockResolvedValue(tracking.TRACKING.dailyCalls + 1)
    const fetchMock = airline({ 'BG305/2026-11-13': enRoute })
    expect(await tracking.checkFlight(flight as Any, at('2026-11-13T06:25:00Z'))).toBeNull()
    expect(fetchMock).not.toHaveBeenCalled()
    expect(db.flight.update).not.toHaveBeenCalled()
  })

  it('drops the answer when someone moved the flight meanwhile', async () => {
    const flight = bg305()
    db.flight.findUnique.mockResolvedValue({ ...flight, date: new Date('2026-11-15T00:00:00Z') })
    airline({ 'BG305/2026-11-13': enRoute })
    expect(await tracking.checkFlight(flight as Any, at('2026-11-13T06:25:00Z'))).toBeNull()
    expect(db.flight.update).not.toHaveBeenCalled()
  })

  it('checks only the flights that are due', async () => {
    db.flight.findMany.mockResolvedValue([bg305(), bg305({ id: 'fl-later', code: 'BG305-20261114-cd34ef', date: new Date('2026-11-14T00:00:00Z'), legs: [bg305Leg({ id: 'leg-9', date: new Date('2026-11-14T00:00:00Z') })] })])
    db.flight.findUnique.mockResolvedValue(bg305())
    const fetchMock = airline({ 'BG305/2026-11-13': enRoute })
    expect(await tracking.trackDueFlights(at('2026-11-13T06:25:00Z'))).toBe(1)
    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(db.flight.findMany.mock.calls[0]![0].where).toMatchObject({
      status: { in: ['upcoming', 'departed'] },
      date: { gte: at('2026-11-10T00:00:00Z'), lte: at('2026-11-14T00:00:00Z') },
    })
  })
})

describe('What the app is told', () => {
  const t = (raw: Any, checked = '2026-11-20T08:10:00Z') => tracking.legTracking(raw, at(checked))

  it('shows a connection on its second leg', () => {
    const shown = view.trackingView({
      airlineStatus: 'on_the_way',
      trackedAt: at('2026-11-20T08:10:00Z'),
      legs: [
        { code: 'MU5842', fromIata: 'PEK', fromCity: 'Beijing', toIata: 'PVG', toCity: 'Shanghai', depTime: '09:40', arrTime: '11:55',
          tracking: t({ status: 'EnRoute', departure: move(['2026-11-20 01:40Z', '2026-11-20 09:40+08:00'], ['2026-11-20 01:52Z', '2026-11-20 09:52+08:00']), arrival: move(['2026-11-20 03:55Z', '2026-11-20 11:55+08:00'], ['2026-11-20 04:01Z', '2026-11-20 12:01+08:00']) }, '2026-11-20T02:30:00Z') as Any },
        { code: 'MU2035', fromIata: 'PVG', fromCity: 'Shanghai', toIata: 'DAC', toCity: 'Dhaka', depTime: '13:10', arrTime: '17:25',
          tracking: t({ status: 'EnRoute', departure: move(['2026-11-20 05:10Z', '2026-11-20 13:10+08:00'], ['2026-11-20 05:34Z', '2026-11-20 13:34+08:00']), arrival: move(['2026-11-20 11:25Z', '2026-11-20 17:25+06:00'], ['2026-11-20 11:48Z', '2026-11-20 17:48+06:00']) }) as Any },
      ],
    })
    expect(shown).toMatchObject({
      state: 'on_the_way',
      checkedAt: '2026-11-20T08:10:00.000Z',
      left: true,
      leftAt: '09:52',
      leftLateMin: 12,
      lastLeft: { code: 'MU2035', iata: 'PVG', city: 'Shanghai', at: '13:34' },
      landed: false,
      landsAt: '17:48',
      landsLateMin: 23,
      plannedArr: '17:25',
      nextCheck: 'after_landing',
    })
    // The first leg landed: the second one left after it.
    expect(shown!.legs.map((leg) => leg.state)).toEqual(['landed', 'in_air'])
  })

  it('says nothing before the airline was asked', () => {
    expect(view.trackingView({ airlineStatus: null, trackedAt: null, legs: [bg305Leg() as Any] })).toBeNull()
  })

  it('names the orders that did not move when the flight left', () => {
    const order = (code: string, status: string, extra: Record<string, unknown> = {}) => ({ code, status, exception: null, flyerId: 'f-1', supplier: { name: 'Sky Mobile' }, ...extra }) as Any
    const orders = [
      order('SH-31', 'in_transit'),
      order('SH-36', 'received_cn_hub'),
      order('SH-37', 'ready_for_shipment', { flyerId: null }),
      order('SH-38', 'ready_for_shipment', { exception: 'damaged' }),
      order('SH-39', 'ready_for_shipment'),
    ]
    expect(view.notMovedOrders({ status: 'upcoming', flyerCount: 2 }, orders)).toEqual([])
    expect(view.notMovedOrders({ status: 'departed', flyerCount: 2 }, orders).map((o) => [o.code, o.reason])).toEqual([
      ['SH-36', 'not_ready'],
      ['SH-37', 'no_flyer'],
      ['SH-38', 'exception'],
      ['SH-39', 'ready'],
    ])
  })
})

describe('Setting the status by hand', () => {
  const flight = {
    id: 'fl-bg',
    code: 'BG305-20261113-ab12cd',
    date: new Date('2026-11-13T00:00:00Z'),
    status: 'upcoming',
    actualCost: 0,
    agencyShare: 0,
    flyerPaidAmount: 0,
    spaceKg: 44,
  }

  function flights() {
    const app = new Hono<AppEnv>()
    app.onError(handleError)
    app.use('*', async (c, next) => {
      c.set('user', { id: 'admin-1', name: 'Mamun Hossain', email: 'admin@example.invalid', role: 'admin', roleLabel: 'admin' })
      await next()
    })
    return app.route('/flights', flightRoutes)
  }
  const patch = (body: unknown) =>
    flights().request(`/flights/${flight.code}`, { method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })

  beforeEach(() => {
    db.flight.findUnique.mockImplementation(async ({ where }: Any) => (where.code === flight.code ? flight : null))
    db.flight.findFirst.mockResolvedValue(null)
    db.flight.update.mockImplementation(async ({ data }: Any) => ({ ...flight, ...data }))
  })

  it('moves the ready orders when it is set to Departed, under the person\'s name', async () => {
    db.shipment.findMany.mockResolvedValue([{ id: 's-41', code: 'SH-41', flyerId: 'f-sumon' }])
    const res = await patch({ status: 'departed' })
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ code: flight.code, moved: ['SH-41'] })
    expect(writeShipmentLog).toHaveBeenCalledWith('s-41', 'Status → In Transit', 'Mamun Hossain')
    const statusUpdate = db.flight.update.mock.calls.find((c: Any) => c[0].data.status)![0].data
    expect(statusUpdate).toMatchObject({ status: 'departed', statusSetBy: 'Mamun Hossain', movedOrders: { by: 'Mamun Hossain', codes: ['SH-41'] } })
  })

  it('moves no orders back when it is set to Upcoming again', async () => {
    db.flight.findUnique.mockResolvedValue({ ...flight, status: 'departed' })
    const res = await patch({ status: 'upcoming' })
    expect(await res.json()).toMatchObject({ moved: [] })
    expect(db.shipment.findMany).not.toHaveBeenCalled()
  })

  it('asks the airline afresh on a new date and moves the legs with it', async () => {
    db.flightLeg.findMany.mockResolvedValue([{ id: 'leg-1', code: 'BG305', date: new Date('2026-11-13T00:00:00Z'), tracking: { status: 'NotFound' } }])
    const res = await patch({ date: '2026-11-15' })
    expect(await res.json()).toEqual({ code: 'BG305-20261115-ab12cd', moved: [] })
    expect(db.flightLeg.update).toHaveBeenCalledWith({ where: { id: 'leg-1' }, data: { date: new Date('2026-11-15T00:00:00Z'), tracking: expect.anything() } })
    expect(db.flight.update.mock.calls[0]![0].data).toMatchObject({ airlineStatus: null, trackedAt: null, trackChecks: 0 })
  })

  it('keeps what the airline said when the same legs come back', async () => {
    const said = { status: 'EnRoute', depLocal: '13:52' }
    db.flightLeg.findMany.mockResolvedValue([{ code: 'BG305', date: new Date('2026-11-13T00:00:00Z'), tracking: said }])
    await patch({ legs: [{ source: 'manual', code: 'bg305', date: '2026-11-13', depTime: '13:40', arrTime: '17:15' }], mobiles: 3 })
    const data = db.flight.update.mock.calls[0]![0].data
    expect(data.airlineStatus).toBeUndefined()
    expect(data.legs.create[0]).toMatchObject({ code: 'BG305', tracking: said })
  })
})
