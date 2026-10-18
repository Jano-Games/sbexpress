import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { ShipmentStatus } from '@prisma/client'

const db = vi.hoisted(() => ({
  shipment: { findMany: vi.fn() },
  todo: { upsert: vi.fn(), updateMany: vi.fn() },
}))
vi.mock('../src/core/db', () => ({ prisma: db }))

const { openHubTodo, syncHubTodos } = await import('../src/shared/hubTodos')

const base = {
  code: 'SH-1',
  weighedKg: null as number | null,
  packedAt: null as Date | null,
  lastMileRef: null as string | null,
  deliveryMode: 'courier',
  exception: null as string | null,
}

function step(status: ShipmentStatus, extra: Partial<typeof base> = {}) {
  return openHubTodo({ ...base, status, ...extra })
}

beforeEach(() => {
  vi.clearAllMocks()
  db.todo.upsert.mockResolvedValue({})
  db.todo.updateMany.mockResolvedValue({ count: 0 })
})

describe('current hub step', () => {
  it('creates no task before the shipment reaches the Dhaka leg', () => {
    expect(step('pending')).toBeNull()
    expect(step('received_cn_hub')).toBeNull()
    expect(step('ready_for_shipment')).toBeNull()
    expect(step('delivered', { weighedKg: 1, packedAt: new Date(), lastMileRef: 'C1' })).toBeNull()
    expect(step('in_transit', { exception: 'cancelled' })).toBeNull()
    expect(step('received_bd_hub', { exception: 'lost' })).toBeNull()
    expect(step('out_for_delivery', { exception: 'returned' })).toBeNull()
  })

  it('follows receive, weigh, pack, book, dispatch and handover without skipping', () => {
    expect(step('in_transit')).toMatchObject({ triggerKey: 'hub:SH-1:receive', text: 'Receive SH-1 at the Dhaka hub' })
    expect(step('customs_cleared')?.triggerKey).toBe('hub:SH-1:receive')
    expect(step('received_bd_hub')?.triggerKey).toBe('hub:SH-1:weigh')
    expect(step('received_bd_hub', { weighedKg: 3 })?.triggerKey).toBe('hub:SH-1:pack')
    expect(step('received_bd_hub', { weighedKg: 3, packedAt: new Date() })).toBeNull()
    expect(step('ready_for_last_mile', { weighedKg: 3 })?.triggerKey).toBe('hub:SH-1:pack')
    expect(step('ready_for_last_mile', { weighedKg: 3, packedAt: new Date() })?.triggerKey).toBe('hub:SH-1:book')
    expect(step('ready_for_last_mile', { weighedKg: 3, packedAt: new Date(), lastMileRef: 'DHL1' })?.triggerKey).toBe('hub:SH-1:dispatch')
    expect(step('ready_for_last_mile', { weighedKg: 3, packedAt: new Date(), lastMileRef: 'PU1', deliveryMode: 'pickup' })?.triggerKey).toBe('hub:SH-1:handover')
    expect(step('out_for_delivery', { weighedKg: 3, packedAt: new Date(), lastMileRef: 'DHL1' })?.triggerKey).toBe('hub:SH-1:handover')
  })
})

describe('hub task sync', () => {
  it('upserts the current weigh task and closes other automatic hub tasks', async () => {
    db.shipment.findMany.mockResolvedValue([
      { code: 'SH-1', status: 'received_bd_hub', weighedKg: null, packedAt: null, lastMileRef: null, deliveryMode: 'courier', exception: null },
      { code: 'SH-2', status: 'pending', weighedKg: null, packedAt: null, lastMileRef: null, deliveryMode: 'courier', exception: null },
    ])
    await syncHubTodos()
    expect(db.todo.upsert).toHaveBeenCalledOnce()
    expect(db.todo.upsert).toHaveBeenCalledWith({
      where: { triggerKey: 'hub:SH-1:weigh' },
      create: {
        role: 'hub',
        auto: true,
        done: false,
        text: 'Weigh SH-1',
        triggerKey: 'hub:SH-1:weigh',
        shipmentCode: 'SH-1',
      },
      update: { text: 'Weigh SH-1', done: false, shipmentCode: 'SH-1' },
    })
    expect(db.todo.updateMany).toHaveBeenCalledWith({
      where: { role: 'hub', auto: true, done: false, triggerKey: { notIn: ['hub:SH-1:weigh'] } },
      data: { done: true },
    })
  })
})
