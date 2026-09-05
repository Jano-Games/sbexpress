/** Server bootstrap. */

import { serve } from '@hono/node-server'
import { createApp } from './core/http'
import { config } from './core/config'
import { prisma, closeDb } from './core/db'
import { connectRedis, closeRedis } from './core/redis'

async function main() {
  // Fail fast on a bad connection string rather than surfacing it as a 500 on
  // the first real request.
  await prisma.$queryRaw`SELECT 1`
  console.log('[db] connected')

  await connectRedis()

  const app = createApp()

  const server = serve({ fetch: app.fetch, port: config.port }, (info) => {
    console.log(`[api] listening on http://localhost:${info.port} (${config.nodeEnv})`)
  })

  let shuttingDown = false
  const shutdown = async (signal: string) => {
    if (shuttingDown) return
    shuttingDown = true
    console.log(`[api] ${signal} received, shutting down`)
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
