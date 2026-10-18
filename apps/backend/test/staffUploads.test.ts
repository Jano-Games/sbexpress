import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono, type Context, type Next } from 'hono'
import type { AppEnv, Role } from '../src/modules/auth'
import { handleError } from '../src/core/errors'

const rateLimit = vi.hoisted(() => vi.fn())
const signUpload = vi.hoisted(() => vi.fn())
const db = vi.hoisted(() => ({
  shipment: { findUnique: vi.fn(), update: vi.fn() },
  shipmentMedia: { count: vi.fn(), create: vi.fn(), findMany: vi.fn(), findFirst: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
  flyer: { findUnique: vi.fn() },
  flyerDocument: { count: vi.fn(), create: vi.fn(), findMany: vi.fn() },
}))
vi.mock('../src/core/db', () => ({ prisma: db }))
vi.mock('../src/core/redis', () => ({ rateLimit }))
vi.mock('../src/shared/r2', () => ({
  r2Configured: () => true,
  signUpload,
  finalizeUpload: vi.fn(),
  signDownload: vi.fn(),
}))
vi.mock('../src/shared/actor', () => ({ writeShipmentLog: vi.fn() }))
vi.mock('../src/shared/publicLinks', () => ({ resolvePublicLink: vi.fn(), tokenHash: () => 'hash' }))
vi.mock('../src/modules/auth', () => ({ requireRole: (...roles: Role[]) => async (c: Context<AppEnv>, next: Next) => {
  if (!roles.includes(c.get('user').role)) return c.json({ error: 'Forbidden' }, 403)
  await next()
} }))

const { mediaRoutes } = await import('../src/modules/media')
const { flyerDocumentRoutes } = await import('../src/modules/flyerDocuments')

function appFor(role: Role, routes: Hono<AppEnv>) {
  const app = new Hono<AppEnv>()
  app.onError(handleError)
  app.use('*', async (c, next) => {
    c.set('user', { id: 'staff-1', name: 'Staff', email: 'staff@example.invalid', role, roleLabel: role })
    await next()
  })
  return app.route('/', routes)
}

const reference = '11111111-1111-4111-8111-111111111111'

beforeEach(() => {
  vi.clearAllMocks()
  rateLimit.mockResolvedValue(true)
  signUpload.mockResolvedValue('https://storage.example/put')
  db.shipment.findUnique.mockResolvedValue({
    id: 'ship-1',
    code: 'SH-1',
    pcsItems: [{ units: [{ serial: 'IMEI1' }] }],
  })
  db.shipmentMedia.count.mockResolvedValue(0)
  db.shipmentMedia.create.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => ({
    reference,
    expiresAt: new Date('2026-10-18T00:15:00.000Z'),
    ...data,
  }))
  db.flyer.findUnique.mockResolvedValue({ id: 'flyer-1', name: 'Karim' })
  db.flyerDocument.count.mockResolvedValue(0)
  db.flyerDocument.create.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => ({
    reference,
    expiresAt: new Date('2026-10-18T00:15:00.000Z'),
    ...data,
  }))
})

describe('staff upload reservations', () => {
  it('stops a user who is over the per-user reservation budget', async () => {
    rateLimit.mockResolvedValue(false)
    const response = await appFor('hub', mediaRoutes).request('/SH-1/media/upload', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'photo.jpg', contentType: 'image/jpeg', size: 1000 }),
    })
    expect(response.status).toBe(429)
    expect(rateLimit).toHaveBeenCalledWith('staff-upload:staff-1', 30)
    expect(db.shipmentMedia.create).not.toHaveBeenCalled()
  })

  it('reserves an IMEI photo as a private image and rejects other file types', async () => {
    const ok = await appFor('hub', mediaRoutes).request('/SH-1/device-photo', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ itemIndex: 0, unitIndex: 0, name: 'imei.jpg', contentType: 'image/jpeg', size: 2000 }),
    })
    expect(ok.status).toBe(201)
    expect(db.shipmentMedia.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        purpose: 'device_serial',
        deviceKey: '0:0',
        shared: false,
        contentType: 'image/jpeg',
      }),
    })
    expect(signUpload).toHaveBeenCalledWith(expect.any(String), 'image/jpeg', 2000, 900)

    const svg = await appFor('hub', mediaRoutes).request('/SH-1/device-photo', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ itemIndex: 0, unitIndex: 0, name: 'imei.svg', contentType: 'image/svg+xml', size: 2000 }),
    })
    expect(svg.status).toBe(400)
  })

  it('keeps ticket and NID uploads on the admin flyer router', async () => {
    const hub = await appFor('hub', flyerDocumentRoutes).request('/Karim/documents/upload', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ kind: 'nid', name: 'nid.jpg', contentType: 'image/jpeg', size: 1000 }),
    })
    expect(hub.status).toBe(403)
    expect(db.flyer.findUnique).not.toHaveBeenCalled()

    for (const kind of ['nid', 'ticket'] as const) {
      const response = await appFor('admin', flyerDocumentRoutes).request('/Karim/documents/upload', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          kind,
          name: kind === 'ticket' ? 'ticket.pdf' : 'nid.jpg',
          contentType: kind === 'ticket' ? 'application/pdf' : 'image/jpeg',
          size: 1000,
        }),
      })
      expect(response.status, kind).toBe(201)
    }
    expect(signUpload).toHaveBeenCalledWith(expect.any(String), 'image/jpeg', 1000, 900)
    expect(signUpload).toHaveBeenCalledWith(expect.any(String), 'application/pdf', 1000, 300)
  })
})
