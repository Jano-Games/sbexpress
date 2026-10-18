import { Hono } from 'hono'
import { z } from 'zod'
import { prisma } from '../core/db'
import { notFound } from '../core/errors'
import { requireRole, type AppEnv } from './auth'
import { num } from '../shared/serialize'
import { screenshotSelect } from '../shared/receiptScreenshots'
import { signDownload } from '../shared/r2'

export const reviewRoutes = new Hono<AppEnv>()
  .get('/screenshots/:reference/url', requireRole('admin'), async c => {
    const reference = z.string().uuid().parse(c.req.param('reference'))
    const upload = await prisma.receiptUpload.findFirst({ where: { reference, status: 'attached' } })
    if (!upload) throw notFound('Receipt screenshot not available')
    return c.json({ url: await signDownload(upload.objectKey) })
  })
  .get('/', requireRole('admin'), async c => {
    const [ships, statements] = await Promise.all([
      prisma.shipment.findMany({
        where: { receipts: { some: { status: 'pending' } } },
        include: { supplier: true, receipts: { where:{status:'pending'}, include: { screenshot: { select: screenshotSelect } } } },
        orderBy: { code: 'asc' },
      }),
      prisma.statementReceipt.findMany({
        where: { status: 'pending' },
        include: { link: { include: { supplier: true } }, screenshot: { select: screenshotSelect } },
        orderBy: { createdAt: 'asc' },
      }),
    ])
    return c.json({
      statements: statements.map(r => ({
        sourceCurrency: r.sourceCurrency, sourceAmount: num(r.sourceAmount), sourceFxRate: num(r.sourceFxRate),
        reference: r.reference, supplierCode: r.link.supplier.code, supplierName: r.link.supplier.name,
        month: r.link.month, amount: num(r.amount), method: r.method, txnRef: r.txnRef,
        date: r.createdAt.toISOString(), screenshot: r.screenshot,
      })),
      queue: ships.map(s => ({
        code: s.code, supplierCode: s.supplier.code, supplierName: s.supplier.name,
        method: s.receipts[0]!.method, sourceCurrency: s.receipts[0]!.sourceCurrency,
        sourceAmount: num(s.receipts[0]!.sourceAmount), sourceFxRate: num(s.receipts[0]!.sourceFxRate),
        amount: num(s.receipts[0]!.amount), txnRef: s.receipts[0]!.txnRef,
        date: s.receipts[0]!.uploadedAt.toISOString(), screenshot: s.receipts[0]!.screenshot,
      })),
    })
  })
