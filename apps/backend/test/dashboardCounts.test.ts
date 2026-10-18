import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono, type Context, type Next } from 'hono'
import type { AppEnv, Role } from '../src/modules/auth'

const db = vi.hoisted(() => ({
  receipt: { count: vi.fn() },
  statementReceipt: { count: vi.fn() },
  todo: { count: vi.fn() },
}))
vi.mock('../src/core/db', () => ({ prisma: db }))
vi.mock('../src/shared/financialSummary', () => ({ financialSummary: vi.fn() }))
vi.mock('../src/core/redis', () => ({ cacheGetJson: vi.fn(), cacheSetJson: vi.fn() }))
vi.mock('../src/modules/flights', () => ({ autoCompletePastFlights: vi.fn() }))
vi.mock('../src/shared/hubTodos', () => ({ syncHubTodos: vi.fn() }))
vi.mock('../src/modules/auth', () => ({ requireRole: (...roles: Role[]) => async (c: Context<AppEnv>, next: Next) => {
  if (!roles.includes(c.get('user').role)) return c.json({ error: 'Forbidden' }, 403)
  await next()
} }))
const { dashboardRoutes } = await import('../src/modules/dashboard')
const { syncHubTodos } = await import('../src/shared/hubTodos')

function appFor(role: Role) {
  const app = new Hono<AppEnv>()
  app.use('*', async (c, next) => {
    c.set('user', { id: 'unit-test', name: 'Unit test', email: 'unit@example.invalid', role, roleLabel: role })
    await next()
  })
  return app.route('/', dashboardRoutes)
}

beforeEach(() => {
  vi.clearAllMocks()
  db.receipt.count.mockResolvedValue(2)
  db.statementReceipt.count.mockResolvedValue(3)
  db.todo.count.mockResolvedValue(4)
})

describe('Lightweight role-scoped dashboard counts', () => {
  it('combines pending shipment and statement receipts with admin tasks', async () => {
    const response = await appFor('admin').request('/counts')
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ reviewCount: 5, openTodoCount: 4 })
    expect(db.receipt.count).toHaveBeenCalledWith({ where: { status: 'pending' } })
    expect(db.statementReceipt.count).toHaveBeenCalledWith({ where: { status: 'pending' } })
    expect(db.todo.count).toHaveBeenCalledWith({ where: { role: 'admin', done: false } })
    expect(syncHubTodos).not.toHaveBeenCalled()
  })

  it('returns only hub task counts without querying financial review data', async () => {
    const response = await appFor('hub').request('/counts')
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ reviewCount: 0, openTodoCount: 4 })
    expect(db.todo.count).toHaveBeenCalledWith({ where: { role: 'hub', done: false } })
    expect(db.receipt.count).not.toHaveBeenCalled()
    expect(db.statementReceipt.count).not.toHaveBeenCalled()
    expect(syncHubTodos).toHaveBeenCalledOnce()
  })
})
