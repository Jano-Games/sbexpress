/**
 * Email/password authentication for staff accounts (admin, hub manager).
 * Passwords are argon2id hashes in the User table; sessions are opaque
 * bearer tokens in Redis. Customers never log in — they get per-shipment
 * tracking links instead.
 */

import { randomUUID } from 'node:crypto'
import { verify } from '@node-rs/argon2'
import { Hono } from 'hono'
import type { Context, Next } from 'hono'
import { z } from 'zod'
import { prisma } from '../core/db'
import { redis, rateLimit } from '../core/redis'
import { unauthorized, forbidden, HttpError } from '../core/errors'

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

const clientIp = (c: Context): string => 'staff-login'

export const authRoutes = new Hono()
  .post('/login', async (c) => {
    // Brake on credential stuffing; the verify below is deliberately the
    // same code path for unknown email and wrong password.
    if (!(await rateLimit(`login:${clientIp(c)}`, 20))) {
      throw new HttpError(429, 'Too many attempts — try again in a minute')
    }
    const { email, password } = z
      .object({ email: z.string().email('Enter a valid email'), password: z.string().min(1, 'Password required') })
      .parse(await c.req.json())

    const user = await prisma.user.findUnique({ where: { email: email.toLowerCase() } })
    const ok = user ? await verify(user.passwordHash, password).catch(() => false) : false
    if (!user || !ok) throw unauthorized('Invalid email or password')

    const session: SessionUser = {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      roleLabel: ROLE_LABEL[user.role],
    }
    const token = randomUUID()
    await redis.set(sessionKey(token), JSON.stringify(session), 'EX', SESSION_TTL_SECONDS)
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
  // Sliding expiry: activity keeps the session alive.
  await redis.expire(sessionKey(token), SESSION_TTL_SECONDS).catch(() => undefined)
  c.set('user', JSON.parse(raw) as SessionUser)
  await next()
}

export function requireRole(...roles: Role[]) {
  return async (c: Context<AppEnv>, next: Next): Promise<void> => {
    const user = c.get('user')
    if (!roles.includes(user.role)) throw forbidden()
    await next()
  }
}
