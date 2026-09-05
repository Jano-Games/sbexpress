import { Hono } from 'hono'
import type { TodoRole } from '@prisma/client'
import { z } from 'zod'
import { prisma } from '../core/db'
import { notFound } from '../core/errors'
import { requireRole, type AppEnv } from './auth'

/** Customers have no to-do list; admin and hub each see their own. */
const roleOf = (role: string): TodoRole => (role === 'hub' ? 'hub' : 'admin')

export const todoRoutes = new Hono<AppEnv>()
  .get('/', requireRole('admin', 'hub'), async (c) => {
    const todos = await prisma.todo.findMany({
      where: { role: roleOf(c.get('user').role) },
      orderBy: { createdAt: 'asc' },
    })
    return c.json({
      todos: todos.map((t) => ({ id: t.id, text: t.text, auto: t.auto, done: t.done })),
    })
  })

  .post('/', requireRole('admin', 'hub'), async (c) => {
    const { text } = z.object({ text: z.string().min(1, 'Task text required') }).parse(await c.req.json())
    await prisma.todo.create({ data: { role: roleOf(c.get('user').role), text } })
    return c.json({ ok: true }, 201)
  })

  .post('/:id/toggle', requireRole('admin', 'hub'), async (c) => {
    const todo = await prisma.todo.findUnique({ where: { id: c.req.param('id') } })
    if (!todo || todo.role !== roleOf(c.get('user').role)) throw notFound('Task not found')
    await prisma.todo.update({ where: { id: todo.id }, data: { done: !todo.done } })
    return c.json({ done: !todo.done })
  })
