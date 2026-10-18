import type { ShipmentStatus } from '@prisma/client'
import { prisma } from '../core/db'
import { statusIndex } from './status'

export interface HubTodoShipment {
  code: string
  status: ShipmentStatus
  weighedKg: number | null
  packedAt: Date | null
  lastMileRef: string | null
  deliveryMode: string | null
  exception: string | null
}

export interface HubTodoStep {
  triggerKey: string
  shipmentCode: string
  text: string
}

const CLOSED_EXCEPTIONS = new Set(['cancelled', 'lost', 'returned'])

/**
 * The single current Dhaka-hub step for a shipment.
 * The weigh → pack → courier → dispatch → handover order is unchanged;
 * this only describes the step that is already required.
 */
export function openHubTodo(shipment: HubTodoShipment): HubTodoStep | null {
  if (shipment.status === 'delivered') return null
  if (shipment.exception && CLOSED_EXCEPTIONS.has(shipment.exception)) return null
  if (statusIndex(shipment.status) < 0) return null
  const step = (action: string, text: string): HubTodoStep => ({
    triggerKey: `hub:${shipment.code}:${action}`,
    shipmentCode: shipment.code,
    text,
  })
  switch (shipment.status) {
    case 'in_transit':
    case 'customs_cleared':
      return step('receive', `Receive ${shipment.code} at the Dhaka hub`)
    case 'received_bd_hub':
      if (shipment.weighedKg === null) return step('weigh', `Weigh ${shipment.code}`)
      if (!shipment.packedAt) return step('pack', `Pack ${shipment.code} and confirm the package count`)
      return null
    case 'ready_for_last_mile':
      if (!shipment.packedAt || shipment.weighedKg === null) return step('pack', `Pack ${shipment.code} and confirm the package count`)
      if (!shipment.lastMileRef) return step('book', `Book courier or pickup for ${shipment.code}`)
      if (shipment.deliveryMode === 'pickup') return step('handover', `Confirm handover for ${shipment.code}`)
      return step('dispatch', `Dispatch ${shipment.code}`)
    case 'out_for_delivery':
      return step('handover', `Confirm handover for ${shipment.code}`)
    case 'pending':
    case 'received_cn_hub':
    case 'ready_for_shipment':
      return null
    default: {
      const unreachable: never = shipment.status
      return unreachable
    }
  }
}

/** Create or refresh automatic hub tasks from current shipment status, and close finished steps. */
export async function syncHubTodos(): Promise<void> {
  const rows = await prisma.shipment.findMany({
    select: {
      code: true,
      status: true,
      weighedKg: true,
      packedAt: true,
      lastMileRef: true,
      deliveryMode: true,
      exception: true,
    },
  })
  const desired = rows.flatMap((row) => {
    const step = openHubTodo({
      code: row.code,
      status: row.status,
      weighedKg: row.weighedKg === null ? null : Number(row.weighedKg),
      packedAt: row.packedAt,
      lastMileRef: row.lastMileRef,
      deliveryMode: row.deliveryMode,
      exception: row.exception,
    })
    return step ? [step] : []
  })
  await Promise.all(desired.map((step) => prisma.todo.upsert({
    where: { triggerKey: step.triggerKey },
    create: { role: 'hub', auto: true, done: false, text: step.text, triggerKey: step.triggerKey, shipmentCode: step.shipmentCode },
    update: { text: step.text, done: false, shipmentCode: step.shipmentCode },
  })))
  const keys = desired.map((step) => step.triggerKey)
  await prisma.todo.updateMany({
    where: {
      role: 'hub',
      auto: true,
      done: false,
      triggerKey: keys.length ? { notIn: keys } : { not: null },
    },
    data: { done: true },
  })
}
