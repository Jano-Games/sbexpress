/** Server bootstrap. */

import { serveFrontend } from './core/frontend'
import { startMaintenance } from './shared/maintenance'
import { serve } from '@hono/node-server'
import { createApp } from './core/http'
import { config } from './core/config'
import { prisma, closeDb } from './core/db'
import { connectRedis, closeRedis } from './core/redis'
import { startInvoiceCatchUp } from './shared/shipmentBilling'

async function main() {
  // Fail fast on a bad connection string rather than surfacing it as a 500 on
  // the first real request.
  await prisma.$queryRaw`SELECT 1`
  const database = new URL(config.databaseUrl)
  console.log(`[db] connected to ${database.hostname}:${database.port || '5432'}${database.pathname}`)

  await connectRedis()

  const app = createApp()
  if (process.env.SERVE_FRONTEND === 'true') serveFrontend(app, process.env.FRONTEND_DIST ?? '../frontend/dist')

  const server = serve({ fetch: app.fetch, port: config.port, hostname: config.isProduction ? '0.0.0.0' : '127.0.0.1' }, (info) => {
    console.log(`[api] listening on http://localhost:${info.port} (${config.nodeEnv})`)
  })

  // Older shipments get their automatic bill without waiting for an admin to open them.
  // Background only: it logs the count and never blocks or fails the boot.
  void startInvoiceCatchUp()

  const stopMaintenance = startMaintenance()
  let shuttingDown = false
  const shutdown = async (signal: string) => {
    if (shuttingDown) return
    shuttingDown = true
    console.log(`[api] ${signal} received, shutting down`)
    stopMaintenance()
    server.close()
    await Promise.allSettled([closeDb(), closeRedis()])
    process.exit(0)
  }

  process.on('SIGTERM', () => void shutdown('SIGTERM'))
  process.on('SIGINT', () => void shutdown('SIGINT'))
}

main().catch((error: unknown) => {
  console.error('[api] failed to start:', error)
  process.exit(1)
})
