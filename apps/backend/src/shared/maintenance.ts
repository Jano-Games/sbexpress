import { randomUUID } from 'node:crypto'
import { prisma } from '../core/db'
import { redis } from '../core/redis'
import { cleanupMedia } from './mediaCleanup'
import { r2Configured } from './r2'

/** Daily cleanup after the approved seven-day grace period with a renewable cross-process lease; no public file URLs are logged. */
export function startMaintenance() {
  if (process.env.MEDIA_CLEANUP_ENABLED !== 'true') return () => {}
  let running = false, stopped = false
  const tick = async () => {
    if (running || stopped || !r2Configured()) return
    running = true
    const token = randomUUID(), key = 'maintenance:media:lock'
    let lease: ReturnType<typeof setInterval> | undefined
    let acquired = false
    try {
      const previous = await prisma.setting.findUnique({ where: { key: 'maintenance.media.lastSuccess' } })
      if (previous && Date.now() - Date.parse(previous.value) < 86400_000) return
      acquired = await redis.set(key, token, 'EX', 120, 'NX') === 'OK'
      if (!acquired) return
      lease = setInterval(() => { void redis.eval("if redis.call('get',KEYS[1]) == ARGV[1] then return redis.call('expire',KEYS[1],120) end return 0", 1, key, token).catch(() => {}) }, 30_000)
      lease.unref()
      const result = await cleanupMedia(true)
      await prisma.setting.upsert({ where: { key: 'maintenance.media.lastSuccess' }, create: { key: 'maintenance.media.lastSuccess', value: new Date().toISOString() }, update: { value: new Date().toISOString() } })
      console.log('[maintenance] upload cleanup', JSON.stringify(result))
    } catch { console.error('[maintenance] upload cleanup failed; will retry in one hour') }
    finally {
      if (lease) clearInterval(lease)
      if (acquired) await redis.eval("if redis.call('get',KEYS[1]) == ARGV[1] then return redis.call('del',KEYS[1]) end return 0", 1, key, token).catch(() => {})
      running = false
    }
  }
  const timer = setInterval(() => { void tick() }, 3600_000)
  timer.unref(); void tick()
  return () => { stopped = true; clearInterval(timer) }
}
