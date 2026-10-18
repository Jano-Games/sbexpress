import { randomUUID } from 'node:crypto'
import { Hono } from 'hono'
import { z } from 'zod'
import { prisma } from '../core/db'
import { badRequest, notFound } from '../core/errors'
import { requireRole, type AppEnv } from './auth'
import {
  finalizeUpload,
  r2Configured,
  signDownload,
  signUpload,
} from '../shared/r2'
import { assertStaffUploadBudget, reservationSeconds } from '../shared/uploadPolicy'

const referenceSchema = z.string().uuid()
const uploadSchema = z
  .object({
    // Ticket and NID stay on this admin-only router. Hub staff cannot upload identity documents.
    kind: z.enum(['passport', 'nid', 'visa', 'student_id', 'admission', 'ticket', 'other']),
    name: z.string().trim().min(1).max(180),
    contentType: z.enum([
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf',
    ]),
    size: z
      .number()
      .int()
      .positive()
      .max(10 * 1024 * 1024, 'Documents must be 10 MB or smaller'),
  })
  .strict()
async function flyer(name: string) {
  const row = await prisma.flyer.findUnique({ where: { name } })
  if (!row) throw notFound('Flyer not found')
  return row
}
async function document(name: string, reference: string) {
  const owner = await flyer(name)
  const row = await prisma.flyerDocument.findFirst({
    where: {
      flyerId: owner.id,
      reference: referenceSchema.parse(reference),
      status: { not: 'deleted' },
    },
  })
  if (!row) throw notFound('Document not found')
  return row
}
// Keep compatibility flags based on reviewed, stored evidence, never a profile checkbox.
async function syncVerification(flyerId: string) {
  const rows = await prisma.flyerDocument.findMany({
    where: { flyerId, status: 'ready', verifiedAt: { not: null } },
    select: { kind: true },
  })
  const kinds = new Set(rows.map((row) => row.kind))
  await prisma.flyer.update({
    where: { id: flyerId },
    data: {
      docStudentId: kinds.has('student_id'),
      docVisa: kinds.has('visa'),
      docAdmission: kinds.has('admission'),
    },
  })
}
export const flyerDocumentRoutes = new Hono<AppEnv>()
  .use('*', requireRole('admin'))
  .get('/:name/documents', async (c) => {
    const owner = await flyer(c.req.param('name'))
    const rows = await prisma.flyerDocument.findMany({
      where: { flyerId: owner.id, status: 'ready' },
      orderBy: { createdAt: 'desc' },
      select: {
        reference: true,
        kind: true,
        name: true,
        contentType: true,
        size: true,
        createdAt: true,
        uploadedByName: true,
        verifiedAt: true,
        verifiedByName: true,
      },
    })
    return c.json({ configured: r2Configured(), documents: rows })
  })
  .post('/:name/documents/upload', async (c) => {
    await assertStaffUploadBudget(c.get('user').id)
    const owner = await flyer(c.req.param('name'))
    const body = uploadSchema.parse(await c.req.json())
    if (
      (await prisma.flyerDocument.count({
        where: {
          flyerId: owner.id,
          OR: [
            { status: 'ready' },
            { status: 'pending', expiresAt: { gt: new Date() } },
          ],
        },
      })) >= 30
    )
      throw badRequest(
        'Maximum 30 documents per flyer. Remove an old file or let unfinished uploads expire.',
      )
    const seconds = reservationSeconds(body.contentType)
    const stagingKey = `staging/${randomUUID()}`,
      objectKey = `media/${randomUUID()}`
    const uploadUrl = await signUpload(stagingKey, body.contentType, body.size, seconds)
    const user = c.get('user')
    const row = await prisma.flyerDocument.create({
      data: {
        ...body,
        flyerId: owner.id,
        stagingKey,
        objectKey,
        uploadedById: user.id,
        uploadedByName: user.name,
        expiresAt: new Date(Date.now() + seconds * 1000),
      },
    })
    return c.json(
      {
        reference: row.reference,
        uploadUrl,
        expiresAt: row.expiresAt.toISOString(),
      },
      201,
    )
  })
  .post('/:name/documents/:reference/complete', async (c) => {
    const row = await document(c.req.param('name'), c.req.param('reference'))
    if (row.status === 'ready') return c.json({ ok: true })
    if (row.expiresAt <= new Date())
      throw badRequest('Upload expired; select the file and upload again')
    const stored = await finalizeUpload(row, { allowPdf: true })
    await prisma.flyerDocument.update({
      where: { id: row.id },
      data: { status: 'ready', size: stored.size, contentType: stored.contentType },
    })
    return c.json({ ok: true })
  })
  .get('/:name/documents/:reference/url', async (c) => {
    const row = await document(c.req.param('name'), c.req.param('reference'))
    if (row.status !== 'ready') throw notFound('Document is not ready')
    return c.json({ url: await signDownload(row.objectKey) })
  })
  .patch('/:name/documents/:reference/verification', async (c) => {
    const row = await document(c.req.param('name'), c.req.param('reference'))
    const { verified } = z
      .object({ verified: z.boolean() })
      .strict()
      .parse(await c.req.json())
    if (row.status !== 'ready')
      throw badRequest('Finish uploading before verifying this document')
    if (verified && row.verifiedAt) return c.json({ ok: true })
    const user = c.get('user')
    await prisma.flyerDocument.update({
      where: { id: row.id },
      data: {
        verifiedAt: verified ? new Date() : null,
        verifiedById: verified ? user.id : null,
        verifiedByName: verified ? user.name : null,
      },
    })
    await syncVerification(row.flyerId)
    return c.json({ ok: true })
  })
  .delete('/:name/documents/:reference', async (c) => {
    const row = await document(c.req.param('name'), c.req.param('reference'))
    // Short-lived preview URLs expire before the cleanup job removes stored content.
    await prisma.flyerDocument.update({
      where: { id: row.id },
      data: { status: 'deleted', expiresAt: new Date(Date.now() + 120000) },
    })
    await syncVerification(row.flyerId)
    return c.json({ ok: true })
  })
