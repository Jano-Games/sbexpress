import { createHash, randomBytes } from 'node:crypto'
import { prisma } from '../core/db'
import { notFound } from '../core/errors'
export const newPublicToken = () => randomBytes(32).toString('base64url')
export const tokenHash = (token: string) => createHash('sha256').update(token).digest('hex')
export const validToken = (token: string) => /^[A-Za-z0-9_-]{43}$/.test(token)
export const isLive = (link: { expiresAt: Date; revokedAt: Date | null }, now = new Date()) => !link.revokedAt && link.expiresAt > now
export const publicMethodKey = (id: string) => tokenHash(`payment-method:${id}`)
export async function resolvePublicLink(token: string) {
  if (!validToken(token)) throw notFound('Link unavailable or expired')
  const link = await prisma.publicLink.findUnique({ where: { tokenHash: tokenHash(token) } })
  if (!link || !isLive(link)) throw notFound('Link unavailable or expired')
  return link
}
