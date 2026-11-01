import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono } from 'hono'
import type { AppEnv, Role } from '../src/modules/auth'

vi.hoisted(() => {
  process.env.DATABASE_URL ??= 'postgresql://unit:unit@localhost:5432/unit'
  process.env.REDIS_URL ??= 'redis://localhost:6379'
  process.env.LINK_ENCRYPTION_KEY ??= 'ab'.repeat(32)
})

const db = vi.hoisted(() => ({
  setting: { findMany: vi.fn(), upsert: vi.fn() },
  flyer: { findMany: vi.fn() },
  flight: { findUnique: vi.fn(), findFirst: vi.fn(), create: vi.fn() },
  shipment: { aggregate: vi.fn() },
}))

vi.mock('../src/core/db', () => ({ prisma: db, atomicMutation: async (work: () => Promise<unknown>) => work() }))
vi.mock('../src/core/redis', () => ({ redis: {}, rateLimit: vi.fn(async () => true), cacheInvalidate: vi.fn(), cacheGetJson: vi.fn(async () => null), cacheSetJson: vi.fn() }))
vi.mock('@node-rs/argon2', () => ({ verify: vi.fn(), hash: vi.fn() }))

const { flightRoutes } = await import('../src/modules/flights')
const { settingsRoutes } = await import('../src/modules/settings')
const { handleError } = await import('../src/core/errors')

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
const settings = () => appFor('admin', '/settings', settingsRoutes)
const flights = () => appFor('admin', '/flights', flightRoutes)

/** Settings rows held in memory, read and written the way getSettings/putRaw do. */
const settingRows = new Map<string, string>()

beforeEach(() => {
  vi.clearAllMocks()
  settingRows.clear()
  db.setting.findMany.mockImplementation(async () => [...settingRows].map(([key, value]) => ({ key, value })))
  db.setting.upsert.mockImplementation(async ({ where, update }: Any) => settingRows.set(where.key, update.value))
})

describe('Default flight capacity in settings', () => {
  it('starts at 44 kg and keeps what is saved', async () => {
    expect(((await (await settings().request('/settings')).json()) as Any).settings.defaultSpaceKg).toBe(44)
    const saved = await settings().request('/settings', send('PATCH', { defaultSpaceKg: 52 }))
    expect(saved.status).toBe(200)
    expect(((await saved.json()) as Any).settings.defaultSpaceKg).toBe(52)
    expect(settingRows.get('defaultSpaceKg')).toBe('52')
  })

  it('refuses 0, a fraction or a huge capacity', async () => {
    for (const defaultSpaceKg of [0, 44.5, 5000]) {
      expect((await settings().request('/settings', send('PATCH', { defaultSpaceKg }))).status).toBe(400)
    }
    expect(settingRows.has('defaultSpaceKg')).toBe(false)
  })

  it('reads a damaged stored value as 44 kg', async () => {
    for (const value of ['abc', '0', '-3']) {
      settingRows.set('defaultSpaceKg', value)
      expect(((await (await settings().request('/settings')).json()) as Any).settings.defaultSpaceKg).toBe(44)
    }
  })
})

describe('A new flight’s capacity', () => {
  beforeEach(() => {
    db.flyer.findMany.mockResolvedValue([{ id: 'fy-1', name: 'Arif Rahman' }])
    db.flight.findFirst.mockResolvedValue(null)
    db.flight.create.mockImplementation(async ({ data }: Any) => ({ id: 'fl-1', ...data }))
  })
  const create = (extra: Record<string, unknown> = {}) =>
    flights().request('/flights', send('POST', { code: 'BG305', flyerNames: ['Arif Rahman'], date: '2026-11-20', ...extra }))

  it('starts with the default from settings', async () => {
    settingRows.set('defaultSpaceKg', '52')
    expect((await create()).status).toBe(201)
    expect(db.flight.create.mock.calls[0]![0].data.spaceKg).toBe(52)
  })

  it('keeps a capacity typed for the flight', async () => {
    settingRows.set('defaultSpaceKg', '52')
    expect((await create({ spaceKg: 30 })).status).toBe(201)
    expect(db.flight.create.mock.calls[0]![0].data.spaceKg).toBe(30)
  })

  it('uses 44 kg when no default was ever saved', async () => {
    expect((await create()).status).toBe(201)
    expect(db.flight.create.mock.calls[0]![0].data.spaceKg).toBe(44)
  })
})

describe('Lowering a flight’s capacity', () => {
  it('says how much is already booked', async () => {
    db.flight.findUnique.mockResolvedValue({ id: 'fl-1', code: 'BG305-20261120-ab12cd', spaceKg: 44 })
    db.shipment.aggregate.mockResolvedValue({ _sum: { bookedKg: 31.5 } })
    const res = await flights().request('/flights/BG305-20261120-ab12cd', send('PATCH', { spaceKg: 30 }))
    expect(res.status).toBe(400)
    expect(((await res.json()) as Any).error).toBe('31.5 kg is already booked on this flight. The capacity cannot be less than that.')
  })
})
