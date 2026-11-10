import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono, type Context, type Next } from 'hono'
import type { AppEnv, Role } from '../src/modules/auth'

vi.hoisted(() => {
  process.env.DATABASE_URL ??= 'postgresql://unit:unit@localhost:5432/unit'
  process.env.REDIS_URL ??= 'redis://localhost:6379'
  process.env.LINK_ENCRYPTION_KEY ??= 'ab'.repeat(32)
})

const signUpload = vi.hoisted(() => vi.fn())
const finalizeUpload = vi.hoisted(() => vi.fn())
const writeShipmentLog = vi.hoisted(() => vi.fn())
const db = vi.hoisted(() => ({
  flyer: { findUnique: vi.fn() },
  user: { findUnique: vi.fn(), findMany: vi.fn() },
  personPhoto: { count: vi.fn(), create: vi.fn(), findUnique: vi.fn(), findMany: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
  shipment: { findUnique: vi.fn(), update: vi.fn() },
  shipmentMedia: { count: vi.fn(), create: vi.fn(), findMany: vi.fn(), findFirst: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
  shipmentLog: { findMany: vi.fn(), create: vi.fn() },
  supplier: { findUnique: vi.fn(), findMany: vi.fn() },
  flight: { findUnique: vi.fn() },
}))
vi.mock('../src/core/db', () => ({ prisma: db, atomicMutation: async (work: () => Promise<unknown>) => work() }))
vi.mock('../src/core/redis', () => ({ redis: {}, rateLimit: vi.fn(async () => true), cacheInvalidate: vi.fn(), cacheGetJson: vi.fn(async () => null), cacheSetJson: vi.fn() }))
vi.mock('@node-rs/argon2', () => ({ verify: vi.fn(), hash: vi.fn() }))
vi.mock('../src/shared/r2', () => ({
  r2Configured: () => true,
  signUpload,
  finalizeUpload,
  signDownload: vi.fn(async (key: string) => `https://storage.example/${key}`),
  removeStoredObject: vi.fn(),
}))
vi.mock('../src/shared/actor', () => ({ writeShipmentLog, currentActor: () => undefined, withActor: (_: unknown, work: () => unknown) => work() }))
vi.mock('../src/shared/settings', () => ({ getSettings: vi.fn(async () => ({ threshold: 0.5, rate: 17, exchangeRates: { BDT: 1, CNY: 17 } })) }))
vi.mock('../src/modules/auth', () => ({ requireRole: (...roles: Role[]) => async (c: Context<AppEnv>, next: Next) => {
  if (!roles.includes(c.get('user').role)) return c.json({ error: 'Forbidden' }, 403)
  await next()
} }))

const { handleError } = await import('../src/core/errors')
const { photoRoutes } = await import('../src/modules/photos')
const { mediaRoutes } = await import('../src/modules/media')
const { shipmentRoutes } = await import('../src/modules/shipments')
const { flightRoutes } = await import('../src/modules/flights')
const { receivedBy, RECEIVED_MESSAGE } = await import('../src/shared/receivedBy')

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Any = any

function appFor(role: Role, routes: Hono<AppEnv>) {
  const app = new Hono<AppEnv>()
  app.onError(handleError)
  app.use('*', async (c, next) => {
    c.set('user', { id: `${role}-1`, name: `Unit ${role}`, email: `${role}@example.invalid`, role, roleLabel: role })
    await next()
  })
  return app.route('/', routes)
}

const send = (role: Role, routes: Hono<AppEnv>, path: string, method: string, body?: unknown) =>
  appFor(role, routes).request(path, {
    method,
    headers: { 'Content-Type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  })

const REF = '11111111-1111-4111-8111-111111111111'
const OLD_REF = '22222222-2222-4222-8222-222222222222'

beforeEach(() => {
  vi.clearAllMocks()
  signUpload.mockResolvedValue('https://storage.example/put')
  finalizeUpload.mockResolvedValue({ size: 900, contentType: 'image/jpeg' })
  db.personPhoto.count.mockResolvedValue(0)
  db.personPhoto.findMany.mockResolvedValue([])
  db.personPhoto.create.mockImplementation(async ({ data }: Any) => ({ reference: REF, ...data }))
  db.user.findMany.mockResolvedValue([])
  db.shipmentLog.findMany.mockResolvedValue([])
  db.shipmentMedia.count.mockResolvedValue(0)
  db.shipmentMedia.findMany.mockResolvedValue([])
})

describe('Face photos of flyers and staff', () => {
  it('reserves a flyer photo against the flyer id, for admins only', async () => {
    db.flyer.findUnique.mockResolvedValue({ id: 'flyer-1' })
    const body = { ownerType: 'flyer', owner: 'Arif Rahman', contentType: 'image/jpeg', size: 4000 }

    const hub = await send('hub', photoRoutes, '/upload', 'POST', body)
    expect(hub.status).toBe(403)

    const ok = await send('admin', photoRoutes, '/upload', 'POST', body)
    expect(ok.status).toBe(201)
    expect(await ok.json()).toMatchObject({ reference: REF, uploadUrl: 'https://storage.example/put' })
    expect(db.flyer.findUnique).toHaveBeenCalledWith({ where: { name: 'Arif Rahman' }, select: { id: true } })
    expect(db.personPhoto.create.mock.calls[0]![0].data).toMatchObject({ ownerType: 'flyer', ownerId: 'flyer-1', uploadedById: 'admin-1', contentType: 'image/jpeg' })
  })

  it('refuses files that are not photos and unknown staff', async () => {
    const pdf = await send('admin', photoRoutes, '/upload', 'POST', { ownerType: 'user', owner: 'u-1', contentType: 'application/pdf', size: 10 })
    expect(pdf.status).toBe(400)
    db.user.findUnique.mockResolvedValue(null)
    const missing = await send('admin', photoRoutes, '/upload', 'POST', { ownerType: 'user', owner: 'nobody', contentType: 'image/png', size: 10 })
    expect(missing.status).toBe(404)
  })

  it('finishing a photo replaces the one before', async () => {
    db.personPhoto.findUnique.mockResolvedValue({ id: 'p-1', reference: REF, ownerType: 'user', ownerId: 'hub-7', status: 'pending', expiresAt: new Date(Date.now() + 60_000), stagingKey: 's', objectKey: 'o', contentType: 'image/jpeg', size: 4000 })
    const done = await send('admin', photoRoutes, `/${REF}/complete`, 'POST', {})
    expect(done.status).toBe(200)
    expect(db.personPhoto.update).toHaveBeenCalledWith({ where: { id: 'p-1' }, data: { status: 'ready', size: 900, contentType: 'image/jpeg' } })
    expect(db.personPhoto.updateMany.mock.calls[0]![0].where).toEqual({ ownerType: 'user', ownerId: 'hub-7', status: 'ready', reference: { not: REF } })
    expect(db.personPhoto.updateMany.mock.calls[0]![0].data.status).toBe('deleted')
  })

  it('lets the hub open a photo, and admins remove one', async () => {
    db.personPhoto.findUnique.mockResolvedValue({ reference: REF, status: 'ready', objectKey: 'media/face' })
    const url = await send('hub', photoRoutes, `/${REF}/url`, 'GET')
    expect(await url.json()).toEqual({ url: 'https://storage.example/media/face' })

    db.flyer.findUnique.mockResolvedValue({ id: 'flyer-1' })
    expect((await send('hub', photoRoutes, '/flyer/Arif%20Rahman', 'DELETE')).status).toBe(403)
    expect((await send('admin', photoRoutes, '/flyer/Arif%20Rahman', 'DELETE')).status).toBe(200)
    expect(db.personPhoto.updateMany.mock.calls[0]![0].where).toEqual({ ownerType: 'flyer', ownerId: 'flyer-1', status: 'ready' })
  })
})

describe('A photo of each device piece', () => {
  const laptop = () => ({
    id: 'ship-1',
    code: 'SH-1',
    pcsItems: [{ category: 'Laptop', count: 1, rate: 0, units: [{ model: 'MacBook Air', serial: '', photoRef: OLD_REF }] }],
  })

  it('reserves a piece photo as private, apart from the IMEI photo', async () => {
    db.shipment.findUnique.mockResolvedValue(laptop())
    db.shipmentMedia.create.mockImplementation(async ({ data }: Any) => ({ reference: REF, expiresAt: new Date(), ...data }))
    const response = await send('admin', mediaRoutes, '/SH-1/device-photo', 'POST', { itemIndex: 0, unitIndex: 0, kind: 'device', name: 'laptop.jpg', contentType: 'image/jpeg', size: 3000 })
    expect(response.status).toBe(201)
    expect(db.shipmentMedia.create.mock.calls[0]![0].data).toMatchObject({ purpose: 'device_photo', deviceKey: '0:0', shared: false })
  })

  it('attaches the finished photo to the piece and retires the old one', async () => {
    db.shipment.findUnique.mockResolvedValue(laptop())
    db.shipmentMedia.findFirst.mockResolvedValue({ id: 'm-1', reference: REF, purpose: 'device_photo', deviceKey: '0:0', contentType: 'image/jpeg', status: 'pending', expiresAt: new Date(Date.now() + 60_000), shared: false })
    const response = await send('hub', mediaRoutes, `/SH-1/device-photo/${REF}/complete`, 'POST', {})
    expect(response.status).toBe(200)
    const saved = db.shipment.update.mock.calls.find((call: Any) => call[0].data.pcsItems)![0].data.pcsItems
    expect(saved[0].units[0]).toEqual({ model: 'MacBook Air', serial: '', photoRef: REF })
    expect(db.shipmentMedia.updateMany.mock.calls[0]![0].where).toEqual({ shipmentId: 'ship-1', reference: OLD_REF, purpose: 'device_photo' })
    expect(writeShipmentLog).toHaveBeenCalledWith('ship-1', 'Device photo attached')
  })

  it('keeps piece photos out of the order photo list and off share links', async () => {
    db.shipment.findUnique.mockResolvedValue(laptop())
    await send('admin', mediaRoutes, '/SH-1/media', 'GET')
    expect(db.shipmentMedia.findMany.mock.calls[0]![0].where.purpose).toEqual({ notIn: ['device_serial', 'device_photo'] })

    db.shipmentMedia.findFirst.mockResolvedValue({ id: 'm-1', reference: REF, purpose: 'device_photo', status: 'ready' })
    const share = await send('admin', mediaRoutes, `/SH-1/media/${REF}`, 'PATCH', { shared: true })
    expect(share.status).toBe(400)
    expect(db.shipmentMedia.update).not.toHaveBeenCalled()
  })
})

describe('Who ordered each device', () => {
  const order = () => ({
    id: 'ship-1',
    code: 'SH-1',
    supplier: { code: 'C-1', name: 'Order customer' },
    pcsItems: [{ category: 'Mobile', count: 2, rate: 0, units: [{ model: 'iPhone 15', serial: '' }, { model: '', serial: '' }] }],
    logs: [],
  })

  it('a new order refuses an unknown customer on a piece', async () => {
    db.supplier.findUnique.mockResolvedValue({ id: 'sup-1', code: 'C-1', archivedAt: null })
    db.supplier.findMany.mockResolvedValue([])
    const response = await send('admin', shipmentRoutes, '/', 'POST', {
      supplierCode: 'C-1',
      categories: ['Mobile'],
      pcsItems: [{ category: 'Mobile', count: 1, rate: 0, units: [{ model: 'iPhone 15', customerCode: 'C-9' }] }],
    })
    expect(response.status).toBe(400)
    expect(((await response.json()) as Any).error).toContain('Unknown customer C-9')
  })

  it('sets the customer on one piece and notes it in the history', async () => {
    db.shipment.findUnique.mockResolvedValue(order())
    db.supplier.findUnique.mockResolvedValue({ archivedAt: null })
    const response = await send('admin', shipmentRoutes, '/SH-1/devices/0/1', 'PATCH', { customerCode: 'C-5' })
    expect(response.status).toBe(200)
    const items = db.shipment.update.mock.calls[0]![0].data.pcsItems
    expect(items[0].units[1]).toEqual({ model: '', serial: '', customerCode: 'C-5' })
    expect(items[0].units[0]).toEqual({ model: 'iPhone 15', serial: '' })
    expect(writeShipmentLog).toHaveBeenCalledWith('ship-1', 'Ordered by C-5 for Mobile 2', 'Unit admin')
  })

  it('choosing the order customer clears the piece back to the default', async () => {
    const stored = order()
    ;(stored.pcsItems[0]!.units[0] as Any).customerCode = 'C-5'
    db.shipment.findUnique.mockResolvedValue(stored)
    const response = await send('admin', shipmentRoutes, '/SH-1/devices/0/0', 'PATCH', { customerCode: 'C-1' })
    expect(response.status).toBe(200)
    expect(db.supplier.findUnique).not.toHaveBeenCalled()
    expect(db.shipment.update.mock.calls[0]![0].data.pcsItems[0].units[0]).toEqual({ model: 'iPhone 15', serial: '' })
    expect(writeShipmentLog).toHaveBeenCalledWith('ship-1', 'Ordered by C-1 for iPhone 15', 'Unit admin')
  })

  it('refuses archived customers, missing pieces and the hub', async () => {
    db.shipment.findUnique.mockResolvedValue(order())
    db.supplier.findUnique.mockResolvedValue({ archivedAt: new Date() })
    expect((await send('admin', shipmentRoutes, '/SH-1/devices/0/0', 'PATCH', { customerCode: 'C-8' })).status).toBe(400)
    expect((await send('admin', shipmentRoutes, '/SH-1/devices/0/5', 'PATCH', { customerCode: null })).status).toBe(400)
    expect((await send('hub', shipmentRoutes, '/SH-1/devices/0/0', 'PATCH', { customerCode: null })).status).toBe(403)
    expect(db.shipment.update).not.toHaveBeenCalled()
  })
})

describe('Received at the BD hub', () => {
  it('groups each order by the person who last received it, with their photo', async () => {
    const at = (h: number) => new Date(`2026-11-10T${String(h).padStart(2, '0')}:00:00.000Z`)
    db.shipmentLog.findMany.mockResolvedValue([
      { shipmentId: 's1', actor: 'Rafi', actorId: 'hub-1', at: at(9) },
      { shipmentId: 's2', actor: 'Rafi', actorId: 'hub-1', at: at(8) },
      { shipmentId: 's1', actor: 'Old name', actorId: 'hub-2', at: at(7) },
      { shipmentId: 's3', actor: 'Admin', actorId: null, at: at(6) },
    ])
    db.user.findMany.mockResolvedValue([{ id: 'hub-1', name: 'Rafi Hasan', role: 'hub' }])
    db.personPhoto.findMany.mockResolvedValue([{ ownerId: 'hub-1', reference: REF }])
    const groups = await receivedBy([
      { id: 's1', status: 'received_bd_hub' },
      { id: 's2', status: 'delivered' },
      { id: 's3', status: 'ready_for_last_mile' },
      { id: 's4', status: 'in_transit' },
    ])
    expect(db.shipmentLog.findMany.mock.calls[0]![0].where).toEqual({ shipmentId: { in: ['s1', 's2', 's3'] }, message: RECEIVED_MESSAGE })
    expect(groups).toEqual([
      { userId: 'hub-1', name: 'Rafi Hasan', role: 'hub', photoRef: REF, count: 2, at: at(9).toISOString() },
      { userId: null, name: 'Admin', role: null, photoRef: null, count: 1, at: at(6).toISOString() },
    ])
  })

  it('receives every order through customs on the flight in one tap', async () => {
    db.flight.findUnique.mockResolvedValue({
      id: 'f-1',
      shipments: [
        { id: 's1', code: 'SH-1', status: 'customs_cleared', exception: null },
        { id: 's2', code: 'SH-2', status: 'in_transit', exception: null },
        { id: 's3', code: 'SH-3', status: 'customs_cleared', exception: 'Box damaged' },
        { id: 's4', code: 'SH-4', status: 'customs_cleared', exception: null },
      ],
    })
    const response = await send('hub', flightRoutes, '/hub/MU2035/receive', 'POST', {})
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ received: ['SH-1', 'SH-4'] })
    expect(db.shipment.update.mock.calls.map((call: Any) => call[0])).toEqual([
      { where: { id: 's1' }, data: { status: 'received_bd_hub' } },
      { where: { id: 's4' }, data: { status: 'received_bd_hub' } },
    ])
    expect(writeShipmentLog.mock.calls).toEqual([['s1', 'Status → Received at BD Hub'], ['s4', 'Status → Received at BD Hub']])
  })

  it('receives only the named orders, and says when none are waiting', async () => {
    db.flight.findUnique.mockResolvedValue({
      id: 'f-1',
      shipments: [
        { id: 's1', code: 'SH-1', status: 'customs_cleared', exception: null },
        { id: 's2', code: 'SH-2', status: 'received_bd_hub', exception: null },
      ],
    })
    expect((await send('hub', flightRoutes, '/hub/MU2035/receive', 'POST', { codes: ['SH-9'] })).status).toBe(400)
    expect((await send('hub', flightRoutes, '/hub/MU2035/receive', 'POST', { codes: ['SH-2'] })).status).toBe(400)
    const one = await send('hub', flightRoutes, '/hub/MU2035/receive', 'POST', { codes: ['SH-1'] })
    expect(await one.json()).toEqual({ received: ['SH-1'] })
  })
})
