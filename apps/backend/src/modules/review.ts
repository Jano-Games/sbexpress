import { Hono } from 'hono'
import { prisma } from '../core/db'
import { requireRole, type AppEnv } from './auth'
import { num, isoDate } from '../shared/serialize'

export const reviewRoutes = new Hono<AppEnv>().get('/', requireRole('admin'), async (c) => {
  const ships = await prisma.shipment.findMany({
    where: { receipt: { status: 'pending' } },
    include: { supplier: true, receipt: true },
    orderBy: { code: 'asc' },
  })
  const statements=await prisma.statementReceipt.findMany({where:{status:'pending'},include:{link:{include:{supplier:true}}},orderBy:{createdAt:'asc'}})
  return c.json({
    statements:statements.map(r=>({reference:r.reference,supplierCode:r.link.supplier.code,supplierName:r.link.supplier.name,month:r.link.month,amount:num(r.amount),method:r.method,txnRef:r.txnRef})),
    queue: ships.map((s) => ({
      code: s.code,
      supplierCode: s.supplier.code,
      supplierName: s.supplier.name,
      method: s.receipt!.method,
      amount: num(s.receipt!.amount),
      txnRef: s.receipt!.txnRef,
      date: isoDate(s.receipt!.uploadedAt),
    })),
  })
})
