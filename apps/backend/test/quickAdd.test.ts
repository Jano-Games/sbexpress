import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono, type Context, type Next } from 'hono'
import type { AppEnv, Role } from '../src/modules/auth'

vi.hoisted(() => {
  process.env.DATABASE_URL ??= 'postgresql://unit:unit@localhost:5432/unit'
  process.env.REDIS_URL ??= 'redis://localhost:6379'
})
const db = vi.hoisted(() => ({
  supplier: { findMany: vi.fn() },
  shipment: { findUnique: vi.fn() },
  shipmentMedia: { count: vi.fn(), create: vi.fn(), findMany: vi.fn() },
}))
vi.mock('../src/core/db', () => ({ prisma: db }))
vi.mock('../src/core/redis', () => ({ rateLimit: vi.fn(), cacheInvalidate: vi.fn(), cacheGetJson: vi.fn(), cacheSetJson: vi.fn() }))
vi.mock('../src/shared/r2', () => ({
  r2Configured: () => true,
  signUpload: vi.fn(async () => 'https://upload.example.invalid/put'),
  finalizeUpload: vi.fn(),
  signDownload: vi.fn(),
}))
vi.mock('../src/shared/uploadPolicy', () => ({ assertStaffUploadBudget: vi.fn(), reservationSeconds: () => 600 }))
vi.mock('../src/modules/auth', () => ({ requireRole: (...roles: Role[]) => async (c: Context<AppEnv>, next: Next) => {
  if (!roles.includes(c.get('user').role)) return c.json({ error: 'Forbidden' }, 403)
  await next()
} }))
const { supplierRoutes } = await import('../src/modules/suppliers')
const { mediaRoutes } = await import('../src/modules/media')

function appFor(role: Role, routes: Hono<AppEnv>) {
  const app = new Hono<AppEnv>()
  app.use('*', async (c, next) => {
    c.set('user', { id: 'unit-test', name: 'Unit test', email: 'unit@example.invalid', role, roleLabel: role })
    await next()
  })
  return app.route('/', routes)
}

beforeEach(() => vi.clearAllMocks())

describe('Next customer code', () => {
  it('suggests the code a new customer would get', async () => {
    db.supplier.findMany.mockResolvedValue([{ code: 'SUP-009' }, { code: 'SUP-015' }, { code: 'C-99' }])
    const response = await appFor('admin', supplierRoutes).request('/next-code')
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ code: 'SUP-016' })
  })

  it('is admin only', async () => {
    const response = await appFor('hub', supplierRoutes).request('/next-code')
    expect(response.status).toBe(403)
  })
})

describe('Device photos', () => {
  beforeEach(() => {
    db.shipment.findUnique.mockResolvedValue({ id: 'ship-1', code: 'SH-54' })
    db.shipmentMedia.count.mockResolvedValue(0)
    db.shipmentMedia.create.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => ({
      ...data,
      reference: '0b6a7f5e-2d36-4bb6-9c2e-6f0a2f1c9d11',
      expiresAt: new Date(Date.now() + 600_000),
    }))
  })

  it('stores a device category on the upload and returns it in the list', async () => {
    const app = appFor('admin', mediaRoutes)
    const upload = await app.request('/SH-54/media/upload', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ name: 'iphone.jpg', contentType: 'image/jpeg', size: 1000, deviceCategory: 'Mobile' }),
    })
    expect(upload.status).toBe(201)
    expect(db.shipmentMedia.create.mock.calls[0]![0].data).toMatchObject({ purpose: 'device_category', deviceKey: 'Mobile' })

    db.shipmentMedia.findMany.mockResolvedValue([
      { reference: 'a', name: 'iphone.jpg', contentType: 'image/jpeg', size: 1000, shared: false, purpose: 'device_category', deviceKey: 'Mobile' },
      { reference: 'b', name: 'box.jpg', contentType: 'image/jpeg', size: 900, shared: false, purpose: 'general', deviceKey: null },
    ])
    const list = await app.request('/SH-54/media')
    const body = (await list.json()) as { media: { reference: string; deviceCategory: string | null }[] }
    expect(body.media.map((m) => [m.reference, m.deviceCategory])).toEqual([['a', 'Mobile'], ['b', null]])
  })

  it('keeps plain uploads as parcel photos', async () => {
    const response = await appFor('admin', mediaRoutes).request('/SH-54/media/upload', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ name: 'box.jpg', contentType: 'image/jpeg', size: 1000 }),
    })
    expect(response.status).toBe(201)
    expect(db.shipmentMedia.create.mock.calls[0]![0].data).toMatchObject({ purpose: 'general', deviceKey: null })
  })
})
