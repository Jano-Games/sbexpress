/**
 * Redis tier — sessions, rate-limit buckets and short-TTL read caches.
 *
 * Sessions are correctness-bearing (losing them logs everyone out, which is
 * annoying but safe), caches are not — cache helpers silently degrade to
 * a miss when the connection is down.
 */

import Redis from 'ioredis'
import { config } from './config'

export const redis = new Redis(config.redisUrl, {
  lazyConnect: true,
  maxRetriesPerRequest: 2,
  connectTimeout: 3000,
  retryStrategy: (times) => (times > 5 ? null : Math.min(times * 200, 2000)),
})

let connected = false

redis.on('error', (error: Error) => {
  if (connected) {
    console.warn(`[redis] connection lost: ${error.message}`)
    connected = false
  }
})

redis.on('ready', () => {
  connected = true
  console.log('[redis] connected')
})

export async function connectRedis(): Promise<void> {
  await redis.connect()
}

export function redisReady(): boolean {
  return connected && redis.status === 'ready'
}

export async function closeRedis(): Promise<void> {
  await redis.quit().catch(() => undefined)
}

// ---------------------------------------------------------------------
// Read cache — best effort, misses on any Redis trouble.
// ---------------------------------------------------------------------

export async function cacheGetJson<T>(key: string): Promise<T | null> {
  if (!redisReady()) return null
  try {
    const raw = await redis.get(`cache:${key}`)
    return raw ? (JSON.parse(raw) as T) : null
  } catch {
    return null
  }
}

export async function cacheSetJson(key: string, value: unknown, ttlSeconds: number): Promise<void> {
  if (!redisReady()) return
  try {
    await redis.set(`cache:${key}`, JSON.stringify(value), 'EX', ttlSeconds)
  } catch {
    // Best effort.
  }
}

/** Drop every cache entry under a prefix — called after any write. */
export async function cacheInvalidate(prefix: string): Promise<void> {
  if (!redisReady()) return
  try {
    const keys = await redis.keys(`cache:${prefix}*`)
    if (keys.length) await redis.del(...keys)
  } catch {
    // Best effort.
  }
}

// ---------------------------------------------------------------------
// Rate limiting — fixed one-minute window per bucket.
// ---------------------------------------------------------------------

/** Fail closed if the shared rate limiter is unavailable. */
export async function rateLimit(bucket: string, limit: number): Promise<boolean> {
  if (!redisReady()) return false
  try {
    const key = `rate:${bucket}:${Math.floor(Date.now() / 60_000)}`
    const count = await redis.incr(key)
    if (count === 1) await redis.expire(key, 90)
    return count <= limit
  } catch {
    return false
  }
}
