import { Hono } from 'hono'
import type { Prisma } from '@prisma/client'
import { z } from 'zod'
import { prisma } from '../core/db'
import { notFound } from '../core/errors'
import { requireRole, type AppEnv } from './auth'

const LIMIT = 100

const dto = (
  n: {
    id: string
    event: string
    title: string
    body: string
    params: Prisma.JsonValue
    flightCode: string | null
    shipmentCode: string | null
    customerCode: string | null
    readBy: string[]
    createdAt: Date
  },
  userId: string,
) => ({
  id: n.id,
  event: n.event,
  title: n.title,
  body: n.body,
  params: n.params && typeof n.params === 'object' && !Array.isArray(n.params) ? n.params : {},
  flightCode: n.flightCode,
  shipmentCode: n.shipmentCode,
  customerCode: n.customerCode,
  read: n.readBy.includes(userId),
  createdAt: n.createdAt.toISOString(),
})

/** The bell: each staff member sees the notifications for their role, newest first. */
export const notificationRoutes = new Hono<AppEnv>()
  .get('/', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const mine = { roles: { has: user.role } }
    const [rows, unread] = await Promise.all([
      prisma.notification.findMany({ where: mine, orderBy: { createdAt: 'desc' }, take: LIMIT }),
      prisma.notification.count({ where: { ...mine, NOT: { readBy: { has: user.id } } } }),
    ])
    return c.json({ notifications: rows.map((n) => dto(n, user.id)), unread })
  })

  .get('/unread', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const unread = await prisma.notification.count({ where: { roles: { has: user.role }, NOT: { readBy: { has: user.id } } } })
    return c.json({ unread })
  })

  .post('/read-all', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const { count } = await prisma.notification.updateMany({
      where: { roles: { has: user.role }, NOT: { readBy: { has: user.id } } },
      data: { readBy: { push: user.id } },
    })
    return c.json({ read: count })
  })

  .post('/:id/read', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const id = z.string().min(1).max(64).parse(c.req.param('id'))
    const row = await prisma.notification.findFirst({ where: { id, roles: { has: user.role } }, select: { id: true, readBy: true } })
    if (!row) throw notFound('Notification not found')
    if (!row.readBy.includes(user.id)) await prisma.notification.update({ where: { id }, data: { readBy: { push: user.id } } })
    return c.json({ ok: true })
  })
