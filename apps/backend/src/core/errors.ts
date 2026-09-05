import type { Context } from 'hono'
import { ZodError } from 'zod'

export class HttpError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message)
  }
}

export const badRequest = (message: string) => new HttpError(400, message)
export const unauthorized = (message = 'Not signed in') => new HttpError(401, message)
export const forbidden = (message = 'Not allowed for this role') => new HttpError(403, message)
export const notFound = (message = 'Not found') => new HttpError(404, message)

export function handleError(error: unknown, c: Context): Response {
  if (error instanceof HttpError) {
    return c.json({ error: error.message }, error.status as 400)
  }
  if (error instanceof ZodError) {
    const first = error.issues[0]
    const where = first?.path.join('.') || 'body'
    return c.json({ error: `${where}: ${first?.message ?? 'invalid'}` }, 400)
  }
  console.error('[api] unhandled error:', error)
  return c.json({ error: 'Internal server error' }, 500)
}
