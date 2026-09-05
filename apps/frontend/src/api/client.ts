/** Thin fetch wrapper — bearer token from localStorage, JSON in and out. */

/** Empty in development: the Vite proxy forwards /api to the backend. */
const API_BASE = import.meta.env.VITE_API_BASE_URL ?? ''

const TOKEN_KEY = 'sbx.token'
// Keep the same key across an in-flight duplicate or uncertain network failure.
const pendingFinancialRequests = new Map<string,string>()

export function getToken(): string | null {
  try {
    return localStorage.getItem(TOKEN_KEY)
  } catch {
    return null
  }
}

export function setToken(token: string | null): void {
  try {
    if (token) localStorage.setItem(TOKEN_KEY, token)
    else localStorage.removeItem(TOKEN_KEY)
  } catch {
    // Storage unavailable — the session just won't survive a reload.
  }
}

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message)
  }
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = {}
  const token = getToken()
  if (token) headers.Authorization = `Bearer ${token}`
  if (body !== undefined) headers['Content-Type'] = 'application/json'
  const financial = method !== 'GET' && !path.startsWith('/track/') && /\/(payments|incomes|expenses|transfers|refunds|apply-credit|mark-paid|after-sales|receipt\/approve|statement-receipts\/[^/]+\/approve|settlements)$/.test(path)
  const fingerprint = `${token}:${method}:${path}:${JSON.stringify(body)}`
  if (financial) {
    const key = pendingFinancialRequests.get(fingerprint) ?? crypto.randomUUID()
    pendingFinancialRequests.set(fingerprint,key)
    headers['Idempotency-Key'] = key
  }

  const res = await fetch(`${API_BASE}/api${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  })

  let data: unknown = null
  try {
    data = await res.json()
  } catch {
    // Non-JSON error body.
  }
  if (financial && res.ok && (data === null || typeof data !== 'object')) throw new Error('Payment response was interrupted; retry to confirm the same request')
  if (financial && res.status < 500) pendingFinancialRequests.delete(fingerprint)
  if (!res.ok) {
    const message =
      typeof data === 'object' && data !== null && 'error' in data
        ? String((data as { error: unknown }).error)
        : `Request failed (${res.status})`
    throw new ApiError(res.status, message)
  }
  return data as T
}

export const api = {
  get: <T>(path: string) => request<T>('GET', path),
  post: <T>(path: string, body?: unknown) => request<T>('POST', path, body ?? {}),
  patch: <T>(path: string, body: unknown) => request<T>('PATCH', path, body),
  delete: <T>(path: string) => request<T>('DELETE', path),
}
