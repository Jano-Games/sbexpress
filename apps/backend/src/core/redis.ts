/**
 * Redis tier — sessions, rate-limit buckets and short-TTL read caches.
 *
 * Sessions are correctness-bearing (losing them logs everyone out, which is
 * annoying but safe), caches are not — cache helpers silently degrade to
 * a miss when the connection is down.
 */

import Redis from 'ioredis'
import { config } from './config'
import { HttpError } from './errors'

export const redis = new Redis(config.redisUrl, {
  lazyConnect: true,
  maxRetriesPerRequest: 2,
  connectTimeout: 3000,
  // Recover when a local container or remote Redis returns after an outage.
  retryStrategy: (times) => Math.min(times * 200, 5000),
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
  // A command error does not necessarily disconnect the client. Its actual
  // connection state is authoritative, rather than the logging flag above.
  return redis.status === 'ready'
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
  if (!redisReady()) throw new HttpError(503, 'Login and payment services are reconnecting. Please try again shortly.')
  try {
    const key = `rate:${bucket}:${Math.floor(Date.now() / 60_000)}`
    const count = await redis.incr(key)
    if (count === 1) await redis.expire(key, 90)
    return count <= limit
  } catch {
    throw new HttpError(503, 'Login and payment services are temporarily unavailable. Please try again shortly.')
  }
}
