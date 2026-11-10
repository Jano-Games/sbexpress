/**
 * Who received a flight's orders at the BD hub: read from each order's
 * "Status → Received at BD Hub" history entry, newest one per order, grouped
 * by the staff member who pressed it.
 */

import type { ShipmentStatus } from '@prisma/client'
import { prisma } from '../core/db'
import { staffPeople } from './personPhotos'
import { STATUS_LABEL, statusIndex } from './status'

export const RECEIVED_MESSAGE = `Status → ${STATUS_LABEL.received_bd_hub}`

export interface ReceivedGroup {
  /** The staff member's id, so an admin can add their photo; null for older history. */
  userId: string | null
  name: string
  role: 'admin' | 'hub' | null
  photoRef: string | null
  count: number
  /** When this person last received one of these orders. */
  at: string
}

export async function receivedBy(shipments: readonly { id: string; status: ShipmentStatus }[]): Promise<ReceivedGroup[]> {
  const ids = shipments.filter((s) => statusIndex(s.status) >= statusIndex('received_bd_hub')).map((s) => s.id)
  if (!ids.length) return []
  const logs = await prisma.shipmentLog.findMany({
    where: { shipmentId: { in: ids }, message: RECEIVED_MESSAGE },
    orderBy: { at: 'desc' },
    select: { shipmentId: true, actor: true, actorId: true, at: true },
  })
  const latest = new Map<string, (typeof logs)[number]>()
  for (const log of logs) if (!latest.has(log.shipmentId)) latest.set(log.shipmentId, log)
  const groups = new Map<string, { actor: string; actorId: string | null; count: number; at: Date }>()
  for (const log of latest.values()) {
    const key = log.actorId ?? `name:${log.actor}`
    const group = groups.get(key)
    if (group) {
      group.count++
      if (log.at > group.at) group.at = log.at
    } else groups.set(key, { actor: log.actor, actorId: log.actorId, count: 1, at: log.at })
  }
  const people = await staffPeople([...groups.values()].map((g) => g.actorId))
  return [...groups.values()]
    .sort((a, b) => b.at.getTime() - a.at.getTime())
    .map((g) => {
      const person = g.actorId ? people.get(g.actorId) : undefined
      return {
        userId: person ? g.actorId : null,
        name: person?.name ?? g.actor,
        role: person?.role ?? null,
        photoRef: person?.photoRef ?? null,
        count: g.count,
        at: g.at.toISOString(),
      }
    })
}
