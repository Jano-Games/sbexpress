import { randomUUID } from 'node:crypto'
import { Hono } from 'hono'
import { z } from 'zod'
import { prisma } from '../core/db'
import { badRequest, notFound } from '../core/errors'
import { requireRole, type AppEnv } from './auth'
import { finalizeUpload, signDownload, signUpload } from '../shared/r2'
import { assertStaffUploadBudget, reservationSeconds } from '../shared/uploadPolicy'
import type { PhotoOwner } from '../shared/personPhotos'

/**
 * Face photos of flyers and staff. Admins add, replace and remove them; the
 * hub can view them, since that is how it recognises the flyers at the
 * airport and sees who received an order. Images are re-encoded on finish,
 * so camera location data does not stay in the stored file.
 */

const ownerType = z.enum(['flyer', 'user'])
const reference = z.string().uuid()

/** The owner's id: a flyer is named by its unique name, a staff member by id. */
async function ownerId(type: PhotoOwner, owner: string): Promise<string> {
  if (type === 'flyer') {
    const flyer = await prisma.flyer.findUnique({ where: { name: owner }, select: { id: true } })
    if (!flyer) throw notFound('Flyer not found')
    return flyer.id
  }
  const user = await prisma.user.findUnique({ where: { id: owner }, select: { id: true } })
  if (!user) throw notFound('User not found')
  return user.id
}

async function photo(ref: string) {
  const row = await prisma.personPhoto.findUnique({ where: { reference: reference.parse(ref) } })
  if (!row || row.status === 'deleted') throw notFound('Photo not found')
  return row
}

/** Marks every ready photo of the owner, except [keep], as removed. */
async function retireOthers(type: string, id: string, keep?: string) {
  await prisma.personPhoto.updateMany({
    where: { ownerType: type, ownerId: id, status: 'ready', ...(keep ? { reference: { not: keep } } : {}) },
    // Short-lived preview links run out before the cleanup job removes the file.
    data: { status: 'deleted', expiresAt: new Date(Date.now() + 120_000) },
  })
}

export const photoRoutes = new Hono<AppEnv>()
  .post('/upload', requireRole('admin'), async (c) => {
    await assertStaffUploadBudget(c.get('user').id)
    const body = z
      .object({
        ownerType,
        owner: z.string().trim().min(1).max(200),
        contentType: z.enum(['image/jpeg', 'image/png', 'image/webp']),
        size: z.number().int().positive().max(10 * 1024 * 1024, 'Photos must be 10 MB or smaller'),
      })
      .strict()
      .parse(await c.req.json())
    const id = await ownerId(body.ownerType, body.owner)
    const pending = await prisma.personPhoto.count({
      where: { ownerType: body.ownerType, ownerId: id, status: 'pending', expiresAt: { gt: new Date() } },
    })
    if (pending >= 5) throw badRequest('Too many unfinished photo uploads. Wait a few minutes and try again.')
    const seconds = reservationSeconds(body.contentType)
    const stagingKey = `staging/${randomUUID()}`
    const objectKey = `media/${randomUUID()}`
    const uploadUrl = await signUpload(stagingKey, body.contentType, body.size, seconds)
    const row = await prisma.personPhoto.create({
      data: {
        ownerType: body.ownerType,
        ownerId: id,
        contentType: body.contentType,
        size: body.size,
        stagingKey,
        objectKey,
        uploadedById: c.get('user').id,
        expiresAt: new Date(Date.now() + seconds * 1000),
      },
    })
    return c.json({ reference: row.reference, uploadUrl, expiresAt: row.expiresAt.toISOString() }, 201)
  })

  .post('/:reference/complete', requireRole('admin'), async (c) => {
    const row = await photo(c.req.param('reference') ?? '')
    if (row.status !== 'ready') {
      if (row.expiresAt <= new Date()) throw badRequest('Upload expired; choose the photo and upload again')
      const stored = await finalizeUpload(row)
      await prisma.personPhoto.update({
        where: { id: row.id },
        data: { status: 'ready', size: stored.size, contentType: stored.contentType },
      })
    }
    // The newest photo replaces the one before.
    await retireOthers(row.ownerType, row.ownerId, row.reference)
    return c.json({ reference: row.reference })
  })

  .get('/:reference/url', requireRole('admin', 'hub'), async (c) => {
    const row = await photo(c.req.param('reference') ?? '')
    if (row.status !== 'ready') throw notFound('Photo is not ready')
    return c.json({ url: await signDownload(row.objectKey) })
  })

  .delete('/:ownerType/:owner', requireRole('admin'), async (c) => {
    const type = ownerType.parse(c.req.param('ownerType'))
    await retireOthers(type, await ownerId(type, c.req.param('owner') ?? ''))
    return c.json({ ok: true })
  })
