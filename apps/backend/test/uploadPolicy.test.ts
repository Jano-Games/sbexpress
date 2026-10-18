import { beforeEach, describe, expect, it, vi } from 'vitest'

const rateLimit = vi.hoisted(() => vi.fn())
vi.mock('../src/core/redis', () => ({ rateLimit }))

const { assertStaffUploadBudget, reservationSeconds, STAFF_UPLOADS_PER_MINUTE } = await import('../src/shared/uploadPolicy')

beforeEach(() => {
  rateLimit.mockReset()
})

describe('staff upload reservations', () => {
  it('gives images a longer reservation than other files', () => {
    expect(reservationSeconds('image/jpeg')).toBe(900)
    expect(reservationSeconds('image/png')).toBe(900)
    expect(reservationSeconds('application/pdf')).toBe(300)
    expect(reservationSeconds('video/mp4')).toBe(300)
  })

  it('counts reservations against the signed-in user', async () => {
    rateLimit.mockResolvedValue(true)
    await expect(assertStaffUploadBudget('user-7')).resolves.toBeUndefined()
    expect(rateLimit).toHaveBeenCalledWith('staff-upload:user-7', STAFF_UPLOADS_PER_MINUTE)
    expect(STAFF_UPLOADS_PER_MINUTE).toBe(30)
  })

  it('rejects the next reservation when that user is over the minute budget', async () => {
    rateLimit.mockResolvedValue(false)
    await expect(assertStaffUploadBudget('user-7')).rejects.toMatchObject({ status: 429 })
  })
})
