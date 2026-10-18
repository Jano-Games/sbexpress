/**
 * Email/password authentication for staff accounts (admin, hub manager).
 * Passwords are argon2id hashes in the User table; sessions are opaque
 * bearer tokens in Redis. Customers never log in — they get per-shipment
 * tracking links instead.
 */

import { randomUUID, createHash } from 'node:crypto'
import { verify } from '@node-rs/argon2'
import { Hono } from 'hono'
import type { Context, Next } from 'hono'
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

const SESSION_TTL_SECONDS = 60 * 60 * 12

const sessionKey = (token: string) => `session:${token}`

const passwordVersion = (hash: string) => createHash('sha256').update(hash).digest('hex')

export const authRoutes = new Hono()
  .post('/login', async (c) => {
    const { email, password } = z
      .object({ email: z.string().email('Enter a valid email'), password: z.string().min(1, 'Password required') })
      .parse(await c.req.json())

    if (!(await rateLimit(`login:${createHash('sha256').update(email.toLowerCase()).digest('hex')}`, 20))) throw new HttpError(429, 'Too many attempts for this account — try again in a minute')
    const user = await prisma.user.findUnique({ where: { email: email.toLowerCase() } })
    const ok = user ? await verify(user.passwordHash, password).catch(() => false) : false
    if (!user || !user.active || !ok) throw unauthorized('Invalid email or password')

    const session: SessionUser = {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      roleLabel: ROLE_LABEL[user.role],
    }
    const token = randomUUID()
    await redis.set(sessionKey(token), JSON.stringify({ ...session, sessionVersion:user.sessionVersion, passwordVersion: passwordVersion(user.passwordHash) }), 'EX', SESSION_TTL_SECONDS)
    return c.json({ token, user: session })
  })
  .post('/logout', async (c) => {
    const token = bearerToken(c)
    if (token) await redis.del(sessionKey(token)).catch(() => undefined)
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
  const session = JSON.parse(raw) as SessionUser & { passwordVersion?: string; sessionVersion?: number }
  const current = await prisma.user.findUnique({ where: { id: session.id } })
  if (!current || !current.active || (session.sessionVersion ?? 0) !== current.sessionVersion || current.role !== session.role || session.passwordVersion !== passwordVersion(current.passwordHash)) {
    await redis.del(sessionKey(token))
    throw unauthorized('Account changed — sign in again')
  }
  await redis.expire(sessionKey(token), SESSION_TTL_SECONDS).catch(() => undefined)
  c.set('user', { id: current.id, name: current.name, email: current.email, role: current.role, roleLabel: ROLE_LABEL[current.role] })
  await next()
}

export function requireRole(...roles: Role[]) {
  return async (c: Context<AppEnv>, next: Next): Promise<void> => {
    const user = c.get('user')
    if (!roles.includes(user.role)) throw forbidden()
    await next()
  }
}
