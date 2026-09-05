import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { api, getToken, setToken } from '@/api/client'
import type { SessionUser } from '@/api/types'

interface AuthContextValue {
  user: SessionUser | null
  /** True while the persisted session is being validated on first load. */
  booting: boolean
  login: (email: string, password: string) => Promise<SessionUser>
  logout: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<SessionUser | null>(null)
  const [booting, setBooting] = useState(Boolean(getToken()))

  useEffect(() => {
    if (!getToken()) return
    api
      .get<{ user: SessionUser }>('/me')
      .then((r) => setUser(r.user))
      .catch(() => setToken(null))
      .finally(() => setBooting(false))
  }, [])

  const login = useCallback(async (email: string, password: string) => {
    const r = await api.post<{ token: string; user: SessionUser }>('/auth/login', { email, password })
    setToken(r.token)
    setUser(r.user)
    return r.user
  }, [])

  const logout = useCallback(async () => {
    await api.post('/auth/logout').catch(() => undefined)
    setToken(null)
    setUser(null)
  }, [])

  const value = useMemo(() => ({ user, booting, login, logout }), [user, booting, login, logout])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext)
  if (!context) throw new Error('useAuth must be used within <AuthProvider>')
  return context
}
