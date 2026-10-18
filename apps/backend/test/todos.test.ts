import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono, type Context, type Next } from 'hono'
import type { AppEnv, Role } from '../src/modules/auth'
import { handleError } from '../src/core/errors'

const db = vi.hoisted(() => ({
  todo: {
    findMany: vi.fn(),
    create: vi.fn(),
    findUnique: vi.fn(),
    update: vi.fn(),
  },
}))
const syncHubTodos = vi.hoisted(() => vi.fn())
vi.mock('../src/core/db', () => ({ prisma: db }))
vi.mock('../src/shared/hubTodos', () => ({ syncHubTodos }))
vi.mock('../src/modules/auth', () => ({ requireRole: (...roles: Role[]) => async (c: Context<AppEnv>, next: Next) => {
  if (!roles.includes(c.get('user').role)) return c.json({ error: 'Forbidden' }, 403)
  await next()
} }))

const { todoRoutes } = await import('../src/modules/todos')

function appFor(role: Role) {
  const app = new Hono<AppEnv>()
  app.onError(handleError)
  app.use('*', async (c, next) => {
    c.set('user', { id: 'user-1', name: 'Unit', email: 'unit@example.invalid', role, roleLabel: role })
    await next()
  })
  return app.route('/', todoRoutes)
}

beforeEach(() => {
  vi.clearAllMocks()
  syncHubTodos.mockResolvedValue(undefined)
  db.todo.findMany.mockResolvedValue([])
  db.todo.create.mockResolvedValue({ id: 'todo-1' })
  db.todo.update.mockResolvedValue({})
})

describe('task assignment', () => {
  it('syncs hub steps for hub staff and lets an admin assign a hub task', async () => {
    const hub = await appFor('hub').request('/')
    expect(hub.status).toBe(200)
    expect(syncHubTodos).toHaveBeenCalledOnce()

    const assigned = await appFor('admin').request('/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: 'Recount bag 4', assignTo: 'hub' }),
    })
    expect(assigned.status).toBe(201)
    expect(await assigned.json()).toEqual({ ok: true, role: 'hub' })
    expect(db.todo.create).toHaveBeenCalledWith({ data: { role: 'hub', text: 'Recount bag 4' } })
  })

  it('refuses a hub user assigning work to an admin', async () => {
    const response = await appFor('hub').request('/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: 'Change the rate', assignTo: 'admin' }),
    })
    expect(response.status).toBe(403)
    expect(db.todo.create).not.toHaveBeenCalled()
  })

  it('does not let staff tick off an automatic hub step', async () => {
    db.todo.findUnique.mockResolvedValue({
      id: 'auto-1',
      role: 'hub',
      triggerKey: 'hub:SH-1:weigh',
      receiptId: null,
      statementReceiptId: null,
      done: false,
    })
    const response = await appFor('hub').request('/auto-1/toggle', { method: 'POST' })
    expect(response.status).toBe(400)
    expect(await response.json()).toEqual({ error: 'This task completes when the hub step is done' })
    expect(db.todo.update).not.toHaveBeenCalled()
  })

  it('lets an admin read hub tasks', async () => {
    db.todo.findMany.mockResolvedValue([{
      id: 'auto-1',
      text: 'Weigh SH-1',
      auto: true,
      done: false,
      receiptId: null,
      statementReceiptId: null,
      shipmentCode: 'SH-1',
      role: 'hub',
    }])
    const response = await appFor('admin').request('/?scope=hub')
    expect(response.status).toBe(200)
    expect(syncHubTodos).toHaveBeenCalledOnce()
    expect(await response.json()).toEqual({
      todos: [{
        id: 'auto-1',
        text: 'Weigh SH-1',
        auto: true,
        done: false,
        role: 'hub',
        href: '/shipments/SH-1?section=handling',
      }],
    })
  })
})
