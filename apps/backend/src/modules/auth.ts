/**
 * Email/password authentication for staff accounts (admin, hub manager).
 * Passwords are argon2id hashes in the User table; sessions are opaque
 * bearer tokens in Redis. Customers never log in — they get per-shipment
 * tracking links instead.
 *
 * "Remember me" keeps a 30-day sliding session instead of 12 hours. A phone
 * with fingerprint sign-in holds a device key: 32 random bytes the server
 * only knows as a SHA-256 digest in Redis, tied to the user's session and
 * password versions so a password change or deactivation turns it off.
 */

import { randomUUID, randomBytes, createHash } from 'node:crypto'
import { verify } from '@node-rs/argon2'
import { Hono } from 'hono'
import type { Context, Next } from 'hono'
import type { User } from '@prisma/client'
import { z } from 'zod'
import { prisma } from '../core/db'
import { redis, rateLimit } from '../core/redis'
import { unauthorized, forbidden, HttpError } from '../core/errors'

/**
 * Hub Manager is one fully trusted Dhaka role. There is no hubId scope yet:
 * every hub user sees the same operational shipments. Do not treat hub as a
 * separate tenant boundary.
 */
export type Role = 'admin' | 'hub'

export interface SessionUser {
  id: string
  name: string
  email: string
  role: Role
  roleLabel: string
}

export const ROLE_LABEL: Record<Role, string> = {
  admin: 'Admin',
  hub: 'Hub Manager · Dhaka',
}

export type AppEnv = { Variables: { user: SessionUser } }

export const SESSION_TTL_SECONDS = 60 * 60 * 12
/** "Remember me" and fingerprint sign-in: 30 days, refreshed on every request. */
export const REMEMBER_TTL_SECONDS = 60 * 60 * 24 * 30
/** A fingerprint device key lives 180 days after its last use. */
export const DEVICE_TTL_SECONDS = 60 * 60 * 24 * 180
const MAX_DEVICES_PER_USER = 5
const DEVICE_TOKEN = /^[A-Za-z0-9_-]{43}$/
const DEVICE_OFF = 'Fingerprint sign-in was turned off. Sign in with your password.'

const sessionKey = (token: string) => `session:${token}`
const deviceKey = (digest: string) => `device:${digest}`
const userDevicesKey = (userId: string) => `devices:${userId}`

const sha256 = (value: string) => createHash('sha256').update(value).digest('hex')
const passwordVersion = (hash: string) => sha256(hash)

type StoredSession = SessionUser & { passwordVersion?: string; sessionVersion?: number; ttl?: number }
interface DeviceRecord {
  userId: string
  sessionVersion: number
  passwordVersion: string
  label: string
  createdAt: string
}

/** Each session keeps the lifetime it was created with; anything odd falls back to 12 hours. */
const sessionTtl = (ttl: unknown): number =>
  typeof ttl === 'number' && Number.isInteger(ttl) && ttl > 0 && ttl <= REMEMBER_TTL_SECONDS ? ttl : SESSION_TTL_SECONDS

const toSessionUser = (user: Pick<User, 'id' | 'name' | 'email' | 'role'>): SessionUser => ({
  id: user.id,
  name: user.name,
  email: user.email,
  role: user.role,
  roleLabel: ROLE_LABEL[user.role],
})

async function startSession(user: User, ttl: number): Promise<{ token: string; user: SessionUser }> {
  const session = toSessionUser(user)
  const token = randomUUID()
  const stored: StoredSession = { ...session, sessionVersion: user.sessionVersion, passwordVersion: passwordVersion(user.passwordHash), ttl }
  await redis.set(sessionKey(token), JSON.stringify(stored), 'EX', ttl)
  return { token, user: session }
}

function readDevice(raw: string | null): DeviceRecord | null {
  if (!raw) return null
  try {
    const record = JSON.parse(raw) as Partial<DeviceRecord>
    return typeof record.userId === 'string' && typeof record.passwordVersion === 'string' ? (record as DeviceRecord) : null
  } catch {
    return null
  }
}

async function forgetDevice(digest: string, userId?: string): Promise<void> {
  await redis.del(deviceKey(digest))
  if (userId) await redis.zrem(userDevicesKey(userId), digest)
}

/** Drops expired keys from the user's index, then the oldest beyond the limit. */
async function pruneDevices(userId: string): Promise<void> {
  const index = userDevicesKey(userId)
  const digests = await redis.zrange(index, 0, -1)
  const live: string[] = []
  for (const digest of digests) {
    if (await redis.exists(deviceKey(digest))) live.push(digest)
    else await redis.zrem(index, digest)
  }
  for (const digest of live.slice(0, Math.max(0, live.length - MAX_DEVICES_PER_USER))) await forgetDevice(digest, userId)
}

export const authRoutes = new Hono<AppEnv>()
  .post('/login', async (c) => {
    const { email, password, remember } = z
      .object({
        email: z.string().email('Enter a valid email'),
        password: z.string().min(1, 'Password required'),
        remember: z.boolean().optional(),
      })
      .parse(await c.req.json())

    if (!(await rateLimit(`login:${sha256(email.toLowerCase())}`, 20))) throw new HttpError(429, 'Too many attempts for this account — try again in a minute')
    const user = await prisma.user.findUnique({ where: { email: email.toLowerCase() } })
    const ok = user ? await verify(user.passwordHash, password).catch(() => false) : false
    if (!user || !user.active || !ok) throw unauthorized('Invalid email or password')

    return c.json(await startSession(user, remember ? REMEMBER_TTL_SECONDS : SESSION_TTL_SECONDS))
  })
  .post('/logout', async (c) => {
    // Signing out ends this session only; a fingerprint device key stays.
    const token = bearerToken(c)
    if (token) await redis.del(sessionKey(token)).catch(() => undefined)
    return c.json({ ok: true })
  })
  .post('/device', requireAuth, async (c) => {
    const { label } = z
      .object({ label: z.string().trim().max(60, 'Keep the phone name under 60 characters').optional() })
      .parse(await c.req.json().catch(() => ({})))
    const current = await prisma.user.findUnique({ where: { id: c.get('user').id } })
    if (!current || !current.active) throw unauthorized('Account changed — sign in again')

    const deviceToken = randomBytes(32).toString('base64url')
    const digest = sha256(deviceToken)
    const record: DeviceRecord = {
      userId: current.id,
      sessionVersion: current.sessionVersion,
      passwordVersion: passwordVersion(current.passwordHash),
      label: label || 'Phone',
      createdAt: new Date().toISOString(),
    }
    await redis.set(deviceKey(digest), JSON.stringify(record), 'EX', DEVICE_TTL_SECONDS)
    await redis.zadd(userDevicesKey(current.id), Date.now(), digest)
    await redis.expire(userDevicesKey(current.id), DEVICE_TTL_SECONDS)
    await pruneDevices(current.id)
    // The only time the key leaves the server; Redis keeps just its digest.
    return c.json({ deviceToken }, 201)
  })
  .post('/device-login', async (c) => {
    const { deviceToken } = z.object({ deviceToken: z.string().min(1).max(200) }).parse(await c.req.json())
    const digest = sha256(deviceToken)
    if (!(await rateLimit(`login:device:${digest}`, 20))) throw new HttpError(429, 'Too many attempts — try again in a minute')
    if (!DEVICE_TOKEN.test(deviceToken)) throw unauthorized(DEVICE_OFF)
    const record = readDevice(await redis.get(deviceKey(digest)))
    if (!record) {
      await redis.del(deviceKey(digest))
      throw unauthorized(DEVICE_OFF)
    }
    const user = await prisma.user.findUnique({ where: { id: record.userId } })
    if (!user || !user.active || user.sessionVersion !== record.sessionVersion || passwordVersion(user.passwordHash) !== record.passwordVersion) {
      await forgetDevice(digest, record.userId)
      throw unauthorized(DEVICE_OFF)
    }
    await redis.expire(deviceKey(digest), DEVICE_TTL_SECONDS)
    await redis.expire(userDevicesKey(user.id), DEVICE_TTL_SECONDS)
    return c.json(await startSession(user, REMEMBER_TTL_SECONDS))
  })
  .post('/device/revoke', async (c) => {
    const { deviceToken } = z.object({ deviceToken: z.string().min(1).max(200) }).parse(await c.req.json())
    const digest = sha256(deviceToken)
    const record = readDevice(await redis.get(deviceKey(digest)))
    await forgetDevice(digest, record?.userId)
    return c.json({ ok: true })
  })

function bearerToken(c: Context): string | null {
  const header = c.req.header('authorization')
  if (!header?.startsWith('Bearer ')) return null
  return header.slice('Bearer '.length)
}

/** Attaches the session user or rejects with 401. */
export async function requireAuth(c: Context<AppEnv>, next: Next): Promise<void> {
  const token = bearerToken(c)
  if (!token) throw unauthorized()
  const raw = await redis.get(sessionKey(token))
  if (!raw) throw unauthorized('Session expired — sign in again')
  const session = JSON.parse(raw) as StoredSession
  const current = await prisma.user.findUnique({ where: { id: session.id } })
  if (!current || !current.active || (session.sessionVersion ?? 0) !== current.sessionVersion || current.role !== session.role || session.passwordVersion !== passwordVersion(current.passwordHash)) {
    await redis.del(sessionKey(token))
    throw unauthorized('Account changed — sign in again')
  }
  // Sliding expiry with the lifetime the session was created with.
  await redis.expire(sessionKey(token), sessionTtl(session.ttl)).catch(() => undefined)
  c.set('user', toSessionUser(current))
  await next()
}

export function requireRole(...roles: Role[]) {
  return async (c: Context<AppEnv>, next: Next): Promise<void> => {
    const user = c.get('user')
    if (!roles.includes(user.role)) throw forbidden()
    await next()
  }
}
