import type { Hono } from 'hono'
import { serveStatic } from '@hono/node-server/serve-static'
import { existsSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'

/** Serve only the built frontend, never the workspace or environment files. */
export function serveFrontend(app: Hono, directory: string) {
  const root = resolve(directory), index = resolve(root, 'index.html')
  if (!existsSync(index)) throw new Error('Built frontend is missing; run pnpm build first')
  const html = readFileSync(index, 'utf8')
  app.get('/assets/*', async (c, next) => {
    c.header('Cache-Control', 'public, max-age=31536000, immutable')
    await next()
  }, serveStatic({ root }))
  app.get('/assets/*', c => c.notFound())
  app.get('/favicon.svg', serveStatic({ root }))
  app.get('*', c => {
    if (c.req.path.startsWith('/api/') || c.req.path === '/api' || !/^\/(?:login|overview|hub|shipments(?:\/[^/]+)?|flights(?:\/[^/]+)?|flyers(?:\/[^/]+)?|suppliers(?:\/[^/]+)?|finance|review|todos|settings|[ts]\/[A-Za-z0-9_-]+)?\/?$/.test(c.req.path) || !c.req.header('Accept')?.includes('text/html')) return c.notFound()
    c.header('Cache-Control', 'no-store')
    c.header('Referrer-Policy', 'no-referrer')
    c.header('X-Robots-Tag', 'noindex, nofollow, noarchive')
    c.header('X-Frame-Options', 'DENY')
    const account = process.env.R2_ACCOUNT_ID
    const storage = account && /^[a-f0-9]{32}$/i.test(account) ? 'https://' + account + '.r2.cloudflarestorage.com' : ''
    c.header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: " + storage + "; media-src 'self' blob: " + storage + "; font-src 'self'; connect-src 'self' " + storage + "; frame-src 'self' blob: " + storage + "; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'")
    return c.html(html)
  })
}
