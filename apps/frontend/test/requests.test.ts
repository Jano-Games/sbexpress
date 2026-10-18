import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const response = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status, headers: { 'Content-Type': 'application/json' },
})
function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>(yes => { resolve = yes })
  return { promise, resolve }
}

beforeEach(() => {
  vi.resetModules()
  const storage = new Map<string, string>()
  vi.stubGlobal('localStorage', {
    getItem: (key: string) => storage.get(key) ?? null,
    setItem: (key: string, value: string) => storage.set(key, value),
    removeItem: (key: string) => storage.delete(key),
  })
})
afterEach(() => { vi.unstubAllGlobals(); vi.useRealTimers() })

// Pure browser-client tests: no application server, Redis or database connections.
describe('frontend request sharing and snapshot freshness', () => {
  it('shares concurrent reads but revalidates on later visits', async () => {
    const { api, cachedRead } = await import('../src/api/client')
    const pending = deferred<Response>()
    const fetch = vi.fn().mockReturnValueOnce(pending.promise).mockResolvedValueOnce(response({ amount: 25 }))
    vi.stubGlobal('fetch', fetch)
    const first = api.get('/finance')
    const second = api.get('/finance')
    await Promise.resolve()
    expect(fetch).toHaveBeenCalledTimes(1)
    pending.resolve(response({ amount: 20 }))
    expect(await first).toEqual({ amount: 20 })
    expect(await second).toEqual({ amount: 20 })
    expect(cachedRead('/finance')).toEqual({ amount: 20 })
    expect(await api.get('/finance')).toEqual({ amount: 25 })
    expect(fetch).toHaveBeenCalledTimes(2)
  })

  it('invalidates snapshots and pending reads when a write completes', async () => {
    const { api, cachedRead, onReadsInvalidated } = await import('../src/api/client')
    const stale = deferred<Response>()
    const fetch = vi.fn()
      .mockResolvedValueOnce(response({ amount: 20 }))
      .mockReturnValueOnce(stale.promise)
      .mockResolvedValueOnce(response({ ok: true }))
      .mockResolvedValueOnce(response({ amount: 25 }))
    vi.stubGlobal('fetch', fetch)
    await api.get('/finance')
    const obsolete = api.get('/finance')
    await Promise.resolve()
    const invalidated = vi.fn()
    const unsubscribe = onReadsInvalidated(invalidated)
    await api.post('/finance/incomes', { amount: 5 })
    expect(invalidated).toHaveBeenCalledTimes(1)
    expect(cachedRead('/finance')).toBeNull()
    expect(await api.get('/finance')).toEqual({ amount: 25 })
    stale.resolve(response({ amount: 20 }))
    await obsolete
    expect(cachedRead('/finance')).toEqual({ amount: 25 })
    unsubscribe()
  })

  it('keeps session data isolated, including reads still in flight during logout', async () => {
    const { api, cachedRead, setToken } = await import('../src/api/client')
    const old = deferred<Response>()
    const fetch = vi.fn().mockReturnValueOnce(old.promise).mockResolvedValueOnce(response({ account: 'B' }))
    vi.stubGlobal('fetch', fetch)
    setToken('session-A')
    const obsolete = api.get('/me')
    setToken('session-B')
    expect(cachedRead('/me')).toBeNull()
    expect(await api.get('/me')).toEqual({ account: 'B' })
    old.resolve(response({ account: 'A' }))
    await obsolete
    expect(cachedRead('/me')).toEqual({ account: 'B' })
    expect(fetch.mock.calls[0]![1].headers.Authorization).toBe('Bearer session-A')
    expect(fetch.mock.calls[1]![1].headers.Authorization).toBe('Bearer session-B')
    setToken(null)
    expect(cachedRead('/me')).toBeNull()
  })

  it('does not cache errors and permits retry', async () => {
    const { api, cachedRead } = await import('../src/api/client')
    const fetch = vi.fn().mockResolvedValueOnce(response({ error: 'Unavailable' }, 503)).mockResolvedValueOnce(response({ ok: true }))
    vi.stubGlobal('fetch', fetch)
    await expect(api.get('/shipments')).rejects.toThrow('Unavailable')
    expect(cachedRead('/shipments')).toBeNull()
    expect(await api.get('/shipments')).toEqual({ ok: true })
  })

  it('expires display snapshots without retaining a long-lived financial cache', async () => {
    const { api, cachedRead } = await import('../src/api/client')
    vi.useFakeTimers()
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(response({ amount: 20 })))
    await api.get('/finance')
    expect(cachedRead('/finance')).toEqual({ amount: 20 })
    vi.advanceTimersByTime(60_001)
    expect(cachedRead('/finance')).toBeNull()
  })

  it('refreshes after uncertain payments while retaining their idempotency key', async () => {
    const { api, onReadsInvalidated } = await import('../src/api/client')
    const fetch = vi.fn().mockRejectedValueOnce(new TypeError('Network interrupted')).mockResolvedValueOnce(response({ ok: true }))
    vi.stubGlobal('fetch', fetch)
    const invalidated = vi.fn()
    const unsubscribe = onReadsInvalidated(invalidated)
    await expect(api.post('/finance/incomes', { amount: 5 })).rejects.toThrow('Network interrupted')
    await api.post('/finance/incomes', { amount: 5 })
    const firstKey = fetch.mock.calls[0]![1].headers['Idempotency-Key']
    expect(firstKey).toBeTruthy()
    expect(fetch.mock.calls[1]![1].headers['Idempotency-Key']).toBe(firstKey)
    expect(invalidated).toHaveBeenCalledTimes(2)
    unsubscribe()
  })
})
