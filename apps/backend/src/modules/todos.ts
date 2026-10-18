import { Hono } from 'hono'
import type { TodoRole } from '@prisma/client'
import { z } from 'zod'
import { prisma } from '../core/db'
import { forbidden, notFound } from '../core/errors'
import { syncHubTodos } from '../shared/hubTodos'
import { requireRole, type AppEnv } from './auth'

/** Customers have no to-do list; admin and hub each see their own. */
const roleOf = (role: string): TodoRole => (role === 'hub' ? 'hub' : 'admin')

const todoDto = (todo: {
  id: string
  text: string
  auto: boolean
  done: boolean
  receiptId: string | null
  statementReceiptId: string | null
  shipmentCode: string | null
  role: TodoRole
}) => ({
  id: todo.id,
  text: todo.text,
  auto: todo.auto,
  done: todo.done,
  role: todo.role,
  href: todo.receiptId || todo.statementReceiptId
    ? '/review'
    : todo.shipmentCode
      ? `/shipments/${encodeURIComponent(todo.shipmentCode)}?section=handling`
      : null,
})

export const todoRoutes = new Hono<AppEnv>()
  .get('/', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const scope = c.req.query('scope')
    const role = scope === 'hub' ? 'hub' : roleOf(user.role)
    if (role === 'hub' && user.role !== 'admin' && user.role !== 'hub') throw forbidden()
    if (scope === 'hub' && user.role !== 'admin') throw forbidden('Only an administrator can view another role’s tasks')
    if (role === 'hub') await syncHubTodos()
    const todos = await prisma.todo.findMany({
      where: { role },
      orderBy: { createdAt: 'asc' },
    })
    return c.json({ todos: todos.map(todoDto) })
  })

  .post('/', requireRole('admin', 'hub'), async (c) => {
    const user = c.get('user')
    const body = z.object({
      text: z.string().trim().min(1, 'Task text required').max(500),
      assignTo: z.enum(['admin', 'hub']).optional(),
    }).parse(await c.req.json())
    if (body.assignTo && body.assignTo !== roleOf(user.role) && user.role !== 'admin') {
      throw forbidden('Only an administrator can assign tasks to hub staff')
    }
    const role = user.role === 'admin' && body.assignTo ? body.assignTo : roleOf(user.role)
    await prisma.todo.create({ data: { role, text: body.text } })
    return c.json({ ok: true, role }, 201)
  })

  .post('/:id/toggle', requireRole('admin', 'hub'), async (c) => {
    const todo = await prisma.todo.findUnique({ where: { id: c.req.param('id') } })
    if (!todo || todo.role !== roleOf(c.get('user').role)) throw notFound('Task not found')
    if (todo.receiptId || todo.statementReceiptId) return c.json({ error: 'Complete this task in Payment review' }, 400)
    if (todo.triggerKey) return c.json({ error: 'This task completes when the hub step is done' }, 400)
    await prisma.todo.update({ where: { id: todo.id }, data: { done: !todo.done } })
    return c.json({ done: !todo.done })
  })
