import { atomicMutation, prisma } from '../core/db'
import { removeStoredObject } from './r2'

export async function cleanupMedia(execute = false) {
  const cutoff = new Date(Date.now() - 7 * 86400_000)
  const report = { mode: execute ? 'executed' : 'dry-run', stagingObjects: 0, removedRecords: 0 }
  // Each record is re-read inside the same mutation lock as upload completion.
  // Ready files and accepted payment evidence are never deleted.
  // These delegates share precisely the fields read below. Do not use model-specific fields here.
  for (const kind of ['shipmentMedia', 'receiptUpload', 'flyerDocument'] as const) {
    const store = prisma[kind] as typeof prisma.shipmentMedia
    let cursor: string | undefined
    while (true) {
      const rows: { id: string }[] = await store.findMany({
        where: { expiresAt: { lt: cutoff }, ...(cursor ? { id: { gt: cursor } } : {}) }, select: { id: true }, orderBy: { id: 'asc' }, take: 100,
      })
      if (!rows.length) break
      for (const { id } of rows) {
        const clean = async () => {
          const row = await store.findUnique({ where: { id } })
          if (!row || row.expiresAt >= cutoff) return
          if (execute) await removeStoredObject(row.stagingKey)
          report.stagingObjects++
          if (row.status === 'pending' || row.status === 'deleted') {
            if (execute) {
              await removeStoredObject(row.objectKey)
              await store.delete({ where: { id } })
            }
            report.removedRecords++
          }
        }
        if (execute) await atomicMutation(clean); else await clean()
      }
      // Use an ID range, rather than a cursor pointing at a just-deleted row.
      cursor = rows.at(-1)!.id
    }
  }
  return report
}

