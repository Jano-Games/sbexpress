import { AsyncLocalStorage } from 'node:async_hooks'
import { prisma } from '../core/db'
import type { SessionUser } from '../modules/auth'
const context = new AsyncLocalStorage<SessionUser>()
export const withActor = <T>(user: SessionUser, work: () => Promise<T>) =>
  context.run(user, work)
export const currentActor = () => context.getStore()
export async function writeShipmentLog(
  shipmentId: string,
  message: string,
  fallback = 'System',
) {
  const actor = currentActor()
  await prisma.shipmentLog.create({
    data: {
      shipmentId,
      actorId: actor?.id,
      actor: actor?.name ?? fallback,
      message,
    },
  })
}
