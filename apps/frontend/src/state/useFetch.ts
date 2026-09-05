import { useCallback, useEffect, useRef, useState } from 'react'
import { api } from '@/api/client'

/**
 * Minimal data hook: fetch on mount and whenever `path` changes, expose a
 * `reload` for after mutations. Stale responses from an outdated path are
 * dropped so quick navigation can't paint the wrong screen.
 */
export function useFetch<T>(path: string | null) {
  const [data, setData] = useState<T | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(Boolean(path))
  const generation = useRef(0)

  const load = useCallback(async () => {
    if (!path) return
    const mine = ++generation.current
    setLoading(true)
    try {
      const result = await api.get<T>(path)
      if (generation.current === mine) {
        setData(result)
        setError(null)
      }
    } catch (e) {
      if (generation.current === mine) setError(e instanceof Error ? e.message : 'Request failed')
    } finally {
      if (generation.current === mine) setLoading(false)
    }
  }, [path])

  useEffect(() => {
    setData(null)
    void load()
  }, [load])

  return { data, error, loading, reload: load }
}
