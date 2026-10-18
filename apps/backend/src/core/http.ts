import { withActor } from '../shared/actor'
import { auditBefore, auditLabel, auditValue } from '../shared/audit'
import { correctionRoutes, costCorrectionRoutes } from '../modules/corrections'
import { withMoneyInput } from '../shared/money'
import { financeLedgerRoutes } from '../modules/financeLedger'
import { Hono, type MiddlewareHandler } from 'hono'
import { bodyLimit } from 'hono/body-limit'
import { atomicMutation, prisma } from './db'
import type { Prisma } from '@prisma/client'
import { createHash } from 'node:crypto'
import { cacheInvalidate, redis } from './redis'
import { cors } from 'hono/cors'
import { config } from './config'
import { handleError, HttpError } from './errors'
import { authRoutes, requireAuth, requireRole, type SessionUser, type AppEnv } from '../modules/auth'
import { dashboardRoutes } from '../modules/dashboard'
import { shipmentRoutes } from '../modules/shipments'
import { flightRoutes } from '../modules/flights'
import { flyerRoutes } from '../modules/flyers'
import { flyerDocumentRoutes } from '../modules/flyerDocuments'
import { supplierRoutes } from '../modules/suppliers'
import { financeRoutes } from '../modules/finance'
import { reviewRoutes } from '../modules/review'
import { todoRoutes } from '../modules/todos'
import { settingsRoutes } from '../modules/settings'
import { categoryRoutes } from '../modules/categories'
import { reconciliationRoutes } from '../modules/reconciliation'
import { statementAdminRoutes,publicStatementRoutes } from '../modules/statements'
import { customerAccountRoutes, invoiceHistoryRoutes } from '../modules/customerAccounts'
import { mediaRoutes, publicMediaRoutes } from '../modules/media'
import { trackRoutes } from '../modules/track'

export function createApp(): Hono {
  const app = new Hono()

  app.onError(handleError)
  app.use('*', bodyLimit({ maxSize: 1024 * 1024 }))
  app.use('*', async (c, next) => {
    c.header('Cache-Control', 'no-store')
    c.header('Referrer-Policy', 'no-referrer')
    c.header('X-Robots-Tag', 'noindex, nofollow, noarchive')
    c.header('X-Content-Type-Options', 'nosniff')
    await next()
  })
  const writes: MiddlewareHandler = async (c, next) => {
    if (['GET', 'HEAD', 'OPTIONS'].includes(c.req.method)) return next()
    const financial = !c.req.path.startsWith('/api/track/') && /\/(payments|incomes|expenses|transfers|refunds|apply-credit|mark-paid|after-sales|receipt\/approve|statement-receipts\/[^/]+\/approve|settlements|reverse|void)$/.test(c.req.path)
    const key = financial ? c.req.header('Idempotency-Key') : undefined
    if (key && !/^[0-9a-f-]{36}$/i.test(key)) throw new HttpError(400, 'Invalid request key')
    const actorId = key ? (c.get('user') as {id:string}).id : ''
    const requestHash = key ? createHash('sha256').update(c.req.method + c.req.path + await c.req.text()).digest('hex') : ''
    await atomicMutation(async () => {
      if (key) {
        const previous = await prisma.financialRequest.findUnique({where:{key}})
        if (previous) {
          if (previous.actorId !== actorId || previous.requestHash !== requestHash) throw new HttpError(409,'Request key already used for different details')
          c.res = c.json(previous.response, previous.status as 200)
          return
        }
      }
      const raw = await c.req.json().catch(() => null)
      const user=c.get('user') as SessionUser|undefined
      const before=user?await auditBefore(c.req.path):undefined
      const run=()=>withMoneyInput(c.req.path,raw,async()=>{await next()})
      if(user)await withActor(user,run);else await run()
      // Hono catches route errors: rethrow so the transaction rolls back.
      if (c.error) throw c.error
      if (c.res.status >= 400) throw new HttpError(c.res.status, 'Request not available')
      if(user)await prisma.auditEvent.create({data:{actorId:user.id,actorName:user.name,...auditLabel(c.req.method,c.req.path),details:auditValue(raw??{}),...(before?{before:auditValue(before)}:{})}})
      if (key) await prisma.financialRequest.create({data:{key,actorId,requestHash,response:await c.res.clone().json() as Prisma.InputJsonValue,status:c.res.status}})
    })
    await cacheInvalidate('dashboard')
    await cacheInvalidate('track')
  }
  app.use('/api/track/*', writes)
  app.use('/api/statements/*',writes)
  app.use(
    '*',
    cors({
      origin: config.allowedOrigins.length ? config.allowedOrigins : '*',
      allowHeaders: ['Authorization', 'Content-Type', 'Idempotency-Key'],
    }),
  )

  app.get('/api/health', async (c) => {
    try {
      await Promise.all([prisma.$queryRaw`SELECT 1`, redis.ping()])
      return c.json({ ok: true, app: config.appName })
    } catch { return c.json({ ok: false }, 503) }
  })

  // Unauthenticated surfaces.
  app.route('/api/auth', authRoutes)
  app.route('/api/statements',publicStatementRoutes)
  app.route('/api/track', publicMediaRoutes)
  app.route('/api/track', trackRoutes)

  // Everything else requires a session.
  const authed = new Hono<AppEnv>()
  authed.use('*', requireAuth)
  authed.use('*', writes)
  authed.get('/me', (c) => c.json({ user: c.get('user') }))
  authed.route('/dashboard', dashboardRoutes)
  authed.route('/shipments',costCorrectionRoutes)
  authed.route('/shipments', invoiceHistoryRoutes)
  authed.route('/shipments', mediaRoutes)
  authed.route('/shipments', shipmentRoutes)
  authed.route('/flights', flightRoutes)
  authed.route('/flyers', flyerDocumentRoutes)
  authed.route('/flyers', flyerRoutes)
  authed.route('/suppliers',statementAdminRoutes)
  authed.route('/suppliers', customerAccountRoutes)
  authed.route('/suppliers', supplierRoutes)
  authed.route('/finance',correctionRoutes)
  authed.route('/finance', financeLedgerRoutes)
  authed.route('/finance', reconciliationRoutes)
  authed.route('/finance', financeRoutes)
  authed.route('/review', reviewRoutes)
  authed.route('/todos', todoRoutes)
  authed.get('/settings/activity',requireRole('admin'),async c=>{const page=Math.max(1,Math.floor(Number(c.req.query('page'))||1));const [events,total]=await Promise.all([prisma.auditEvent.findMany({orderBy:[{createdAt:'desc'},{id:'desc'}],skip:(page-1)*25,take:25}),prisma.auditEvent.count()]);return c.json({events,total,page,limit:25})})
  authed.route('/settings', settingsRoutes)
  authed.route('/categories', categoryRoutes)
  app.route('/api', authed)

  return app
}
