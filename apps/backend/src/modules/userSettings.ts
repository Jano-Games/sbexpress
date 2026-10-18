import { hash, verify } from '@node-rs/argon2'
import { Prisma } from '@prisma/client'
import { Hono } from 'hono'
import { z } from 'zod'
import { prisma } from '../core/db'
import { badRequest, notFound, HttpError } from '../core/errors'
import { rateLimit } from '../core/redis'
import { requireRole, type AppEnv } from './auth'

// Explicit selection keeps password hashes out of every account response.
const userFields = { id: true, name: true, email: true, role: true, active:true, createdAt: true } as const
const profile = z.object({
  name: z.string().trim().min(1, 'Name required').max(100),
  email: z.string().trim().toLowerCase().email('Enter a valid email').max(254),
  role: z.enum(['admin', 'hub']),
})
const password = z.string().min(8, 'Use at least 8 characters').max(128, 'Use no more than 128 characters')

async function availableEmail(email: string, exceptId?: string) {
  const existing = await prisma.user.findFirst({
    where: { email: { equals: email, mode: 'insensitive' }, ...(exceptId ? { id: { not: exceptId } } : {}) },
    select: { id: true },
  })
  if (existing) throw badRequest('A user with this email already exists')
}
function accountError(error: unknown): never {
  if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002')
    throw badRequest('A user with this email already exists')
  throw error
}

export const userSettingsRoutes = new Hono<AppEnv>()
  .use('*', requireRole('admin'))
  .get('/', async c => c.json({ users: await prisma.user.findMany({ select: userFields, orderBy: [{ createdAt: 'asc' }, { id: 'asc' }] }) }))
  .post('/', async c => {
    const body = profile.extend({ password }).strict().parse(await c.req.json())
    await availableEmail(body.email)
    try {
      const user = await prisma.user.create({
        data: { name: body.name, email: body.email, role: body.role, passwordHash: await hash(body.password) },
        select: userFields,
      })
      return c.json({ user }, 201)
    } catch (error) { return accountError(error) }
  })
  .patch('/:id', async c => {
    const body = profile.partial().extend({active:z.boolean().optional()}).strict().refine(value => Object.keys(value).length > 0, 'Choose a field to update').parse(await c.req.json())
    const existing = await prisma.user.findUnique({ where: { id: c.req.param('id') }, select: userFields })
    if (!existing) throw notFound('User not found')
    if(body.active===false && existing.id===c.get('user').id)throw badRequest('Another administrator must deactivate your account')
    if(existing.active && existing.role==='admin' && (body.active===false||body.role==='hub') && await prisma.user.count({where:{role:'admin',active:true}})<=1)throw badRequest('Keep at least one active administrator')
    if (body.role && body.role !== existing.role) {
      if (existing.id === c.get('user').id) throw badRequest('Another administrator must change your own role')
      if (existing.role === 'admin' && await prisma.user.count({ where: { role: 'admin',active:true } }) <= 1)
        throw badRequest('Keep at least one administrator')
    }
    if (body.email) await availableEmail(body.email, existing.id)
    try {
      return c.json({ user: await prisma.user.update({ where: { id: existing.id }, data: {...body,...(body.active===false?{sessionVersion:{increment:1}}:{})}, select: userFields }) })
    } catch (error) { return accountError(error) }
  })
  .post('/:id/password', async c => {
    const body = z.object({ password, currentPassword: z.string().max(128).optional() }).strict().parse(await c.req.json())
    const existing = await prisma.user.findUnique({ where: { id: c.req.param('id') } })
    if (!existing) throw notFound('User not found')
    if (!await rateLimit(`user-password:${c.get('user').id}`, 10)) throw new HttpError(429, 'Too many password changes. Try again in a minute.')
    if (existing.id === c.get('user').id && (!body.currentPassword || !await verify(existing.passwordHash, body.currentPassword).catch(() => false)))
      throw badRequest('Enter your correct current password')
    await prisma.user.update({ where: { id: existing.id }, data: { passwordHash: await hash(body.password) } })
    // requireAuth checks the password hash version, invalidating all old sessions.
    return c.json({ ok: true })
  })
