import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { EventEmitter } from 'node:events'

vi.mock('../src/core/config', () => ({config:{redisUrl:'redis://isolated-test'}}))
vi.mock('ioredis', async () => {
  const { EventEmitter } = await import('node:events')
  return {default:class extends EventEmitter {
    status='ready'
    incr=vi.fn().mockResolvedValue(1)
    expire=vi.fn().mockResolvedValue(1)
    constructor(_url:string,readonly options:{retryStrategy:(times:number)=>number|null}){super()}
  }}
})
const {redis,redisReady,rateLimit}=await import('../src/core/redis')
const client=redis as unknown as EventEmitter & {status:string;options:{retryStrategy:(times:number)=>number|null}}

describe('Redis outage recovery',()=>{
  beforeEach(()=>{client.status='ready';vi.mocked(redis.incr).mockReset().mockResolvedValue(1);vi.mocked(redis.expire).mockClear()})
  it('keeps reconnecting after more than five failed attempts',()=>{
    expect(client.options.retryStrategy(6)).toBeGreaterThan(0)
    expect(client.options.retryStrategy(100)).toBeGreaterThan(0)
    expect(client.options.retryStrategy(100)).toBeLessThanOrEqual(5000)
  })
  it('does not leave a ready connection disabled after a transient command error',()=>{
    client.emit('error',new Error('Transient command error'))
    expect(redisReady()).toBe(true)
  })
  it('reports an outage as unavailable instead of claiming too many attempts',async()=>{
    client.status='reconnecting'
    await expect(rateLimit('login:test',20)).rejects.toMatchObject({status:503})
    expect(redis.incr).not.toHaveBeenCalled()
    client.status='ready'
    await expect(rateLimit('login:test',20)).resolves.toBe(true)
  })
  it('reports a failed limiter command as unavailable',async()=>{
    vi.mocked(redis.incr).mockRejectedValueOnce(new Error('Redis disconnected'))
    await expect(rateLimit('login:test',20)).rejects.toMatchObject({status:503})
  })
  it('still blocks a real exhausted login bucket',async()=>{
    vi.mocked(redis.incr).mockResolvedValueOnce(21)
    await expect(rateLimit('login:test',20)).resolves.toBe(false)
  })
})
