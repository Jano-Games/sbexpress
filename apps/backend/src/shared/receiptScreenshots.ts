import { randomUUID } from 'node:crypto'
import { z } from 'zod'
import { prisma } from '../core/db'
import { badRequest, HttpError } from '../core/errors'
import { rateLimit } from '../core/redis'
import { signUpload, finalizeUpload } from './r2'

export const screenshotSelect = { reference: true, name: true, contentType: true, size: true } as const
export const screenshotSchema = z.object({
  name: z.string().trim().min(1).max(180),
  contentType: z.enum(['image/jpeg', 'image/png', 'image/webp']),
  size: z.number().int().positive().max(5 * 1024 * 1024, 'Screenshot must be 5 MB or smaller'),
})
export type ReceiptKind = 'shipment' | 'statement'

export async function reserveReceiptScreenshot(linkHash: string, kind: ReceiptKind, input: unknown) {
  const body = screenshotSchema.parse(input)
  if (!await rateLimit(`receipt-screenshot:${linkHash}`, 10)) throw new HttpError(429, 'Too many screenshot uploads; try again later')
  const pending = await prisma.receiptUpload.count({ where: { linkHash, status: 'pending', expiresAt: { gt: new Date() } } })
  if (pending >= 4) throw badRequest('Finish the selected upload or wait five minutes before trying again')
  const stagingKey = `staging/${randomUUID()}`, objectKey = `media/${randomUUID()}`
  const uploadUrl = await signUpload(stagingKey, body.contentType, body.size)
  const upload = await prisma.receiptUpload.create({ data: {
    ...body, linkHash, kind, stagingKey, objectKey, expiresAt: new Date(Date.now() + 300000),
  } })
  return { reference: upload.reference, uploadUrl, expiresAt: upload.expiresAt.toISOString() }
}

/** Verify immutable evidence before accepting it on the receipt in the same transaction. */
export async function acceptReceiptScreenshot(reference: string | undefined, linkHash: string, kind: ReceiptKind) {
  if (!reference) return null
  const upload = await prisma.receiptUpload.findFirst({ where: { reference, linkHash, kind, status: 'pending' } })
  if (!upload) throw badRequest('Screenshot does not belong to this payment link or has already been used')
  if (upload.expiresAt <= new Date()) throw badRequest('Screenshot upload expired; select the image again and retry')
  await finalizeUpload(upload)
  await prisma.receiptUpload.update({ where: { id: upload.id }, data: { status: 'attached' } })
  return upload.reference
}
