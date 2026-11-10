/**
 * Face photos of flyers and staff (PersonPhoto). Lists and detail payloads
 * carry only the photo's reference; the picture itself is fetched through a
 * short-lived signed link from GET /api/photos/:reference/url.
 */

import { prisma } from '../core/db'

export type PhotoOwner = 'flyer' | 'user'

/** The newest ready photo of each owner, keyed by owner id. */
export async function photoRefs(ownerType: PhotoOwner, ownerIds: readonly string[]): Promise<Map<string, string>> {
  const ids = [...new Set(ownerIds.filter(Boolean))]
  if (!ids.length) return new Map()
  const rows = await prisma.personPhoto.findMany({
    where: { ownerType, ownerId: { in: ids }, status: 'ready' },
    orderBy: { createdAt: 'desc' },
    select: { ownerId: true, reference: true },
  })
  const refs = new Map<string, string>()
  for (const row of rows) if (!refs.has(row.ownerId)) refs.set(row.ownerId, row.reference)
  return refs
}

export async function photoRef(ownerType: PhotoOwner, ownerId: string): Promise<string | null> {
  return (await photoRefs(ownerType, [ownerId])).get(ownerId) ?? null
}

/** Staff names, roles and photos for the people who wrote an order's history. */
export async function staffPeople(userIds: readonly (string | null | undefined)[]) {
  const ids = [...new Set(userIds.filter((id): id is string => Boolean(id)))]
  if (!ids.length) return new Map<string, StaffPerson>()
  const [users, refs] = await Promise.all([
    prisma.user.findMany({ where: { id: { in: ids } }, select: { id: true, name: true, role: true } }),
    photoRefs('user', ids),
  ])
  return new Map(users.map((user) => [user.id, { name: user.name, role: user.role, photoRef: refs.get(user.id) ?? null }]))
}

export interface StaffPerson {
  name: string
  role: 'admin' | 'hub'
  photoRef: string | null
}
