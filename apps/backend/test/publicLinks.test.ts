import { describe, expect, it, vi } from 'vitest'

vi.mock('../src/core/db', () => ({ prisma: {} }))
const { newPublicToken, validToken } = await import('../src/shared/publicLinks')

describe('public link tokens', () => {
  it('are 22 random base64url characters', () => {
    const a = newPublicToken()
    const b = newPublicToken()
    expect(a).toMatch(/^[A-Za-z0-9_-]{22}$/)
    expect(a).not.toBe(b)
  })

  it('accept new short tokens and links already shared with the old length', () => {
    expect(validToken('a'.repeat(22))).toBe(true)
    expect(validToken('a'.repeat(43))).toBe(true)
    expect(validToken('a'.repeat(30))).toBe(false)
    expect(validToken('clx0abc123')).toBe(false)
  })
})
