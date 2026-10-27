import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono, type Context, type Next } from 'hono'
import type { AppEnv, Role } from '../src/modules/auth'

const db = vi.hoisted(() => ({
  flight: { findFirst: vi.fn(), findUnique: vi.fn(), create: vi.fn() },
  flyer: { findMany: vi.fn(), findUnique: vi.fn() },
  flightFlyer: { findUnique: vi.fn(), upsert: vi.fn() },
}))
vi.mock('../src/core/db', () => ({ prisma: db }))
vi.mock('../src/core/redis', () => ({ cacheInvalidate: vi.fn(), cacheGetJson: vi.fn(), cacheSetJson: vi.fn() }))
vi.mock('../src/shared/settings', () => ({ getSettings: vi.fn(async () => ({ threshold: 0.5 })) }))
vi.mock('../src/shared/flightLookup', () => ({ lookupFlight: vi.fn() }))
vi.mock('../src/shared/ledger', () => ({ creditPayment: vi.fn(), debitCash: vi.fn() }))
vi.mock('../src/modules/auth', () => ({ requireRole: (...roles: Role[]) => async (c: Context<AppEnv>, next: Next) => {
  if (!roles.includes(c.get('user').role)) return c.json({ error: 'Forbidden' }, 403)
  await next()
} }))
const { flightRoutes, sameFlightPrefix } = await import('../src/modules/flights')
const { handleError } = await import('../src/core/errors')

function app() {
  const hono = new Hono<AppEnv>()
  hono.onError(handleError)
  hono.use('*', async (c, next) => {
    c.set('user', { id: 'u', name: 'Admin', email: 'a@example.invalid', role: 'admin', roleLabel: 'Admin' })
    await next()
  })
  return hono.route('/', flightRoutes)
}

const arif = { id: 'f-arif', name: 'Arif Rahman', archivedAt: null }
const rakib = { id: 'f-rakib', name: 'Rakib Hasan', archivedAt: null }
const post = (path: string, body: unknown) =>
  app().request(path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })

describe('the same flight cannot be added twice for one flyer', () => {
  beforeEach(() => vi.clearAllMocks())

  it('reads the number and day from a made flight code', () => {
    expect(sameFlightPrefix('BG305-20261024-ab12cd')).toBe('BG305-20261024-')
    expect(sameFlightPrefix('MU5842-MU2035-20261030-0f0f0f')).toBe('MU5842-MU2035-20261030-')
    expect(sameFlightPrefix('CA945')).toBeNull()
  })

  it('refuses a new flight with the same number, day and flyer', async () => {
    db.flyer.findMany.mockResolvedValue([arif])
    db.flight.findFirst.mockResolvedValue({
      id: 'old', code: 'BG305-20261024-ab12cd', flyers: [{ flyerId: 'f-arif', flyer: arif }],
    })
    const res = await post('/', { code: 'bg305', date: '2026-10-24', flyerNames: ['Arif Rahman'] })
    expect(res.status).toBe(409)
    expect(((await res.json()) as { error: string }).error).toBe(
      'BG305 on 24 Oct 2026 is already added with Arif Rahman. Open that flight instead of adding it again.')
    expect(db.flight.findFirst.mock.calls[0]![0].where).toMatchObject({
      code: { startsWith: 'BG305-20261024-' },
      flyers: { some: { flyerId: { in: ['f-arif'] } } },
    })
    expect(db.flight.create).not.toHaveBeenCalled()
  })

  it('refuses a flyer who is already on this flight', async () => {
    db.flight.findUnique.mockResolvedValue({ id: 'fl', code: 'BG305-20261024-ab12cd' })
    db.flyer.findUnique.mockResolvedValue(arif)
    db.flightFlyer.findUnique.mockResolvedValue({ flightId: 'fl', flyerId: 'f-arif' })
    const res = await post('/BG305-20261024-ab12cd/flyers', { name: 'Arif Rahman' })
    expect(res.status).toBe(409)
    expect(((await res.json()) as { error: string }).error).toBe('Arif Rahman is already on this flight')
    expect(db.flightFlyer.upsert).not.toHaveBeenCalled()
  })

  it('refuses a flyer who is on another booking of the same flight and day', async () => {
    db.flight.findUnique.mockResolvedValue({ id: 'fl', code: 'BG305-20261024-ab12cd' })
    db.flyer.findUnique.mockResolvedValue(rakib)
    db.flightFlyer.findUnique.mockResolvedValue(null)
    db.flight.findFirst.mockResolvedValue({
      id: 'other', code: 'BG305-20261024-99aa00', flyers: [{ flyerId: 'f-rakib', flyer: rakib }],
    })
    const res = await post('/BG305-20261024-ab12cd/flyers', { name: 'Rakib Hasan' })
    expect(res.status).toBe(409)
    expect(db.flight.findFirst.mock.calls[0]![0].where.id).toEqual({ not: 'fl' })
    expect(db.flightFlyer.upsert).not.toHaveBeenCalled()
  })

  it('still adds a new flyer to the flight', async () => {
    db.flight.findUnique.mockResolvedValue({ id: 'fl', code: 'BG305-20261024-ab12cd' })
    db.flyer.findUnique.mockResolvedValue(rakib)
    db.flightFlyer.findUnique.mockResolvedValue(null)
    db.flight.findFirst.mockResolvedValue(null)
    const res = await post('/BG305-20261024-ab12cd/flyers', { name: 'Rakib Hasan' })
    expect(res.status).toBe(200)
    expect(db.flightFlyer.upsert).toHaveBeenCalledOnce()
  })
})
