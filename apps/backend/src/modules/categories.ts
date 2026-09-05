import { Hono } from 'hono'
import { z } from 'zod'
import { prisma } from '../core/db'
import { requireRole, type AppEnv } from './auth'

export const categoryRoutes = new Hono<AppEnv>()
  .get('/', requireRole('admin', 'hub'), async (c) => {
    const categories = await prisma.category.findMany({ orderBy: { name: 'asc' } })
    return c.json({ categories: categories.map((x) => x.name) })
  })

  .post('/', requireRole('admin'), async (c) => {
    const { name } = z.object({ name: z.string().min(1).trim() }).parse(await c.req.json())
    await prisma.category.upsert({ where: { name }, update: {}, create: { name } })
    return c.json({ ok: true }, 201)
  })
