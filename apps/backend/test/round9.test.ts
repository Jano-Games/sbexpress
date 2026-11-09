import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono } from 'hono'
import type { AppEnv } from '../src/modules/auth'

vi.hoisted(() => {
  process.env.DATABASE_URL ??= 'postgresql://unit:unit@localhost:5432/unit'
  process.env.REDIS_URL ??= 'redis://localhost:6379'
  process.env.LINK_ENCRYPTION_KEY ??= 'ab'.repeat(32)
})

const db = vi.hoisted(() => ({
  flight: { findUnique: vi.fn(), findFirst: vi.fn(), update: vi.fn() },
  flightFlyer: { findMany: vi.fn(), update: vi.fn() },
}))

vi.mock('../src/core/db', () => ({ prisma: db, atomicMutation: async (work: () => Promise<unknown>) => work() }))
vi.mock('../src/core/redis', () => ({ redis: {}, rateLimit: vi.fn(async () => true), cacheInvalidate: vi.fn(), cacheGetJson: vi.fn(async () => null), cacheSetJson: vi.fn() }))
vi.mock('@node-rs/argon2', () => ({ verify: vi.fn(), hash: vi.fn() }))

const { flightRoutes, flightNumberOf } = await import('../src/modules/flights')
const { handleError } = await import('../src/core/errors')
const { config } = await import('../src/core/config')
const { providerPacing } = await import('../src/shared/flightLookup')
const realPacing = { ...providerPacing }

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Any = any

function flights() {
  const app = new Hono<AppEnv>()
  app.onError(handleError)
  app.use('*', async (c, next) => {
    c.set('user', { id: 'admin-1', name: 'Unit admin', email: 'admin@example.invalid', role: 'admin', roleLabel: 'admin' })
    await next()
  })
  return app.route('/flights', flightRoutes)
}

const patch = (code: string, body: unknown) =>
  flights().request(`/flights/${code}`, { method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })

/** AeroDataBox answers keyed by "NUMBER/DATE"; anything else is a 404. */
function schedule(rows: Record<string, unknown>) {
  const fetchMock = vi.fn(async (url: string) => {
    const key = /flights\/number\/([^?]+)\?/.exec(url)?.[1] ?? ''
    const row = rows[key]
    return row ? new Response(JSON.stringify([row]), { status: 200 }) : new Response('', { status: 404 })
  })
  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}

const movement = (iata: string, city: string, local: string) => ({
  airport: { iata, municipalityName: city },
  scheduledTime: { local },
})

const mu5842 = {
  number: 'MU 5842',
  status: 'Expected',
  airline: { name: 'China Eastern' },
  departure: movement('PEK', 'Beijing', '2026-11-20 09:40+08:00'),
  arrival: movement('PVG', 'Shanghai', '2026-11-20 11:55+08:00'),
}
const mu2035 = {
  number: 'MU 2035',
  status: 'Expected',
  airline: { name: 'China Eastern' },
  departure: movement('PVG', 'Shanghai', '2026-11-21 08:10+08:00'),
  arrival: movement('DAC', 'Dhaka', '2026-11-21 11:25+06:00'),
}

describe('Looking up a whole itinerary', () => {
  beforeEach(() => {
    Object.assign(providerPacing, { gapMs: 0, retryMs: 0 })
  })
  afterEach(() => {
    vi.unstubAllGlobals()
    ;(config as Any).aerodataboxKey = ''
    Object.assign(providerPacing, realPacing)
  })

  it('looks nothing up without a flight data key', async () => {
    ;(config as Any).aerodataboxKey = ''
    const fetchMock = schedule({})
    const res = await flights().request('/flights/lookup-route?code=MU5842%2BMU2035&date=2026-11-20')
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ configured: false, found: false, legs: [], missing: [], depTime: null, arrTime: null, via: null })
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('finds a connection whose second flight leaves the next day', async () => {
    ;(config as Any).aerodataboxKey = 'unit-key'
    schedule({ 'MU5842/2026-11-20': mu5842, 'MU2035/2026-11-21': mu2035 })
    const res = await flights().request('/flights/lookup-route?code=mu5842%20%2B%20MU2035&date=2026-11-20')
    const body = (await res.json()) as Any
    expect(body).toMatchObject({ configured: true, found: true, missing: [], depTime: '09:40', arrTime: '11:25', via: 'Via PVG Shanghai' })
    expect(body.legs.map((leg: Any) => [leg.code, leg.date, leg.fromIata, leg.toIata])).toEqual([
      ['MU5842', '2026-11-20', 'PEK', 'PVG'],
      ['MU2035', '2026-11-21', 'PVG', 'DAC'],
    ])
  })

  it('names the flight it could not find', async () => {
    ;(config as Any).aerodataboxKey = 'unit-key'
    schedule({ 'MU5842/2026-11-20': mu5842 })
    const body = (await (await flights().request('/flights/lookup-route?code=MU5842%2BMU2035&date=2026-11-20')).json()) as Any
    expect(body).toMatchObject({ configured: true, found: false, missing: ['MU2035'], depTime: '09:40', arrTime: null })
    expect(body.legs[1]).toMatchObject({ code: 'MU2035', found: false })
  })

  it('refuses something that is not a flight number', async () => {
    ;(config as Any).aerodataboxKey = 'unit-key'
    const fetchMock = schedule({})
    const res = await flights().request('/flights/lookup-route?code=MU5842%2B12&date=2026-11-20')
    expect(res.status).toBe(400)
    expect(((await res.json()) as Any).error ?? '').toContain('"12" is not a valid flight number')
    expect(fetchMock).not.toHaveBeenCalled()
  })
})

describe('Staying inside the flight data plan', () => {
  const refused = () => new Response('Too many requests', { status: 429 })

  beforeEach(() => {
    ;(config as Any).aerodataboxKey = 'unit-key'
    Object.assign(providerPacing, { gapMs: 0, retryMs: 0 })
  })
  afterEach(() => {
    vi.unstubAllGlobals()
    ;(config as Any).aerodataboxKey = ''
    Object.assign(providerPacing, realPacing)
  })

  it('spaces the calls for a connection apart', async () => {
    providerPacing.gapMs = 60
    const calledAt: number[] = []
    const fetchMock = schedule({ 'MU5842/2026-11-20': mu5842, 'MU2035/2026-11-21': mu2035 })
    const answer = fetchMock.getMockImplementation()!
    fetchMock.mockImplementation(async (url: string) => {
      calledAt.push(Date.now())
      return answer(url)
    })
    const res = await flights().request('/flights/lookup-route?code=MU5842%2BMU2035&date=2026-11-20')
    expect(((await res.json()) as Any).found).toBe(true)
    // MU5842, MU2035 on the same day (a miss), then MU2035 the next day.
    expect(calledAt).toHaveLength(3)
    for (let i = 1; i < calledAt.length; i++) expect(calledAt[i]! - calledAt[i - 1]!).toBeGreaterThanOrEqual(50)
  })

  it('waits and tries again when the provider refuses a call', async () => {
    const fetchMock = schedule({ 'MU5842/2026-11-20': mu5842 })
    const answer = fetchMock.getMockImplementation()!
    fetchMock.mockImplementationOnce(async () => refused()).mockImplementation(answer)
    const res = await flights().request('/flights/lookup-route?code=MU5842&date=2026-11-20')
    expect(res.status).toBe(200)
    expect(await res.json()).toMatchObject({ found: true, depTime: '09:40', arrTime: '11:55' })
    expect(fetchMock).toHaveBeenCalledTimes(2)
  })

  it('says the service is busy when it keeps refusing', async () => {
    const fetchMock = vi.fn(async () => refused())
    vi.stubGlobal('fetch', fetchMock)
    const res = await flights().request('/flights/lookup-route?code=MU5842&date=2026-11-20')
    expect(res.status).toBe(503)
    expect(((await res.json()) as Any).error).toBe('The flight schedule service is busy. Try again in a few seconds.')
    expect(fetchMock).toHaveBeenCalledTimes(providerPacing.retries + 1)
  })
})

describe('Editing a flight', () => {
  const flight = {
    id: 'fl',
    code: 'MU5842-20261120-ab12cd',
    date: new Date('2026-11-20T00:00:00Z'),
    actualCost: 0,
    agencyShare: 0,
    flyerPaidAmount: 0,
    spaceKg: 44,
  }

  beforeEach(() => {
    vi.clearAllMocks()
    db.flight.findUnique.mockImplementation(async ({ where }: Any) => (where.code === flight.code ? flight : null))
    db.flight.findFirst.mockResolvedValue(null)
    db.flightFlyer.findMany.mockResolvedValue([{ flightId: 'fl', flyerId: 'f-arif', paidAmount: 0 }])
    db.flight.update.mockImplementation(async ({ data }: Any) => ({ ...flight, ...data }))
  })

  const manualLegs = (stop: string) => [
    { source: 'manual', code: 'MU5842', date: '2026-11-20', toCity: stop, depTime: '09:40' },
    { source: 'manual', code: 'MU2036', date: '2026-11-20', fromCity: stop, arrTime: '17:25' },
  ]

  it('moves the reference to a new number and keeps its tail', async () => {
    const res = await patch(flight.code, { legs: manualLegs('PVG Shanghai'), date: '2026-11-20' })
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ code: 'MU5842+MU2036-20261120-ab12cd' })
    expect(db.flight.update.mock.calls[0]![0].data).toMatchObject({
      code: 'MU5842+MU2036-20261120-ab12cd',
      depTime: '09:40',
      arrTime: '17:25',
      via: 'Via PVG Shanghai',
    })
  })

  it('moves the reference to a new date', async () => {
    const res = await patch(flight.code, { date: '2026-11-21', depTime: '09:40', arrTime: '17:25' })
    expect(await res.json()).toEqual({ code: 'MU5842-20261121-ab12cd' })
  })

  it('keeps the reference when the full reference comes back as the number', async () => {
    const res = await patch(flight.code, { code: flight.code, date: '2026-11-20', mobiles: 3 })
    expect(await res.json()).toEqual({ code: flight.code })
    expect(db.flight.findFirst).not.toHaveBeenCalled()
  })

  it('calls a connection without a named stop a connection', async () => {
    await patch(flight.code, { legs: manualLegs('') })
    expect(db.flight.update.mock.calls[0]![0].data.via).toBe('Connection')
  })

  it('refuses a move onto a flight a flyer is already on', async () => {
    db.flight.findFirst.mockResolvedValue({
      id: 'other',
      code: 'MU5842-20261121-99aa00',
      flyers: [{ flyerId: 'f-arif', flyer: { name: 'Arif Rahman' } }],
    })
    const res = await patch(flight.code, { date: '2026-11-21' })
    expect(res.status).toBe(409)
    expect(((await res.json()) as Any).error).toContain('MU5842 on 21 Nov 2026 is already added with Arif Rahman')
    expect(db.flight.update).not.toHaveBeenCalled()
  })

  it('picks a fresh tail when the new reference is taken', async () => {
    db.flight.findUnique.mockImplementation(async ({ where }: Any) =>
      where.code === flight.code ? flight : where.code === 'MU5842-20261121-ab12cd' ? { id: 'other' } : null,
    )
    const body = (await (await patch(flight.code, { date: '2026-11-21' })).json()) as Any
    expect(body.code).toMatch(/^MU5842-20261121-[0-9a-f]{6}$/)
    expect(body.code).not.toBe('MU5842-20261121-ab12cd')
  })

  it('reads the airline number out of a reference', () => {
    expect(flightNumberOf('BG305-20261024-ab12cd')).toBe('BG305')
    expect(flightNumberOf('MU5842+MU2035-20261120-0f0f0f')).toBe('MU5842+MU2035')
    expect(flightNumberOf('BG305')).toBe('BG305')
  })
})
