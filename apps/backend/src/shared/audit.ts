import type { Prisma } from '@prisma/client'
import { prisma } from '../core/db'
const hidden = /password|token|secret|qrimage|objectkey|stagingkey/i
export function auditValue(value: unknown): Prisma.InputJsonValue {
  return JSON.parse(
    JSON.stringify(value, (key, item) =>
      hidden.test(key) ? '[redacted]' : item,
    ),
  ) as Prisma.InputJsonValue
}
export async function auditBefore(path: string) {
  const p = path.split('/').filter(Boolean),
    kind = p[1],
    id = p[2]
  if (!id) return undefined
  if (kind === 'shipments')
    return prisma.shipment.findUnique({
      where: { code: id },
      include: { invoice: true },
    })
  if (kind === 'flights')
    return prisma.flight.findUnique({ where: { code: id } })
  if (kind === 'flyers')
    return prisma.flyer.findUnique({ where: { name: decodeURIComponent(id) } })
  if (kind === 'suppliers')
    return prisma.supplier.findUnique({ where: { code: id } })
  if (kind === 'settings' && id === 'users' && p[3])
    return prisma.user.findUnique({
      where: { id: p[3] },
      select: { id: true, name: true, email: true, role: true, active: true },
    })
  return undefined
}
export function auditLabel(method: string, path: string) {
  const p = path.split('/').filter(Boolean),
    last = p.at(-1) ?? '',
    entity = p[2] ?? p[1] ?? 'Workspace'
  const labels: Record<string, string> = {
    payments: 'Recorded payment',
    expenses: 'Recorded cost/payment',
    incomes: 'Recorded business income',
    transfers: 'Transferred funds',
    refunds: 'Recorded refund',
    'apply-credit': 'Applied customer credit',
    reverse: 'Reversed financial entry',
    void: 'Cancelled cost',
    approve: 'Approved receipt',
    reject: 'Rejected receipt',
    invoice: 'Saved invoice',
    weigh: 'Recorded weight',
    pack: 'Confirmed packing',
    'last-mile': 'Saved delivery booking',
    dispatch: 'Confirmed dispatch',
    handover: 'Confirmed handover',
    exception: 'Updated shipment exception',
    'correct-stage': 'Corrected checkpoint',
    'assignment-correction': 'Corrected flight assignment',
    archive: 'Updated flyer archive status',
    password: 'Changed staff password',
  }
  return {
    action:
      labels[last] ??
      `${method === 'DELETE' ? 'Removed' : method === 'PATCH' ? 'Updated' : 'Created'} ${p[1] === 'settings' && p[2] === 'users' ? 'staff account' : (p[1] === 'suppliers' ? 'customer' : (p[1] ?? 'record').replace(/s$/, ''))}`,
    entity: decodeURIComponent(entity),
  }
}
