import { beforeEach, describe, expect, it, vi } from 'vitest'
const mocks = vi.hoisted(() => ({
  db: { count: vi.fn(), create: vi.fn(), findFirst: vi.fn(), update: vi.fn() },
  rateLimit: vi.fn(), signUpload: vi.fn(), finalizeUpload: vi.fn(),
}))
vi.mock('../src/core/db', () => ({ prisma: { receiptUpload: mocks.db } }))
vi.mock('../src/core/redis', () => ({ rateLimit: mocks.rateLimit }))
vi.mock('../src/shared/r2', () => ({ signUpload: mocks.signUpload, finalizeUpload: mocks.finalizeUpload }))
const { reserveReceiptScreenshot, acceptReceiptScreenshot } = await import('../src/shared/receiptScreenshots')
const valid = { name: 'proof.png', contentType: 'image/png', size: 200 }
beforeEach(() => {
  vi.resetAllMocks()
  mocks.rateLimit.mockResolvedValue(true)
  mocks.db.count.mockResolvedValue(0)
  mocks.signUpload.mockResolvedValue('https://storage.invalid/signed')
  mocks.db.create.mockImplementation(async ({ data }) => ({ ...data, reference: 'reserved' }))
})
describe('private receipt screenshot reservations', () => {
  it.each([
    { ...valid, contentType: 'image/svg+xml' }, { ...valid, contentType: 'text/html' },
    { ...valid, size: 0 }, { ...valid, size: 5242881 }, { ...valid, name: ' ' },
  ])('rejects unsupported or oversized input before reserving storage: %j', async input => {
    await expect(reserveReceiptScreenshot('link', 'shipment', input)).rejects.toThrow()
    expect(mocks.signUpload).not.toHaveBeenCalled()
    expect(mocks.db.create).not.toHaveBeenCalled()
  })
  it('binds a short-lived reservation to its link and kind without returning object keys', async () => {
    const result = await reserveReceiptScreenshot('link', 'statement', valid)
    const saved = mocks.db.create.mock.calls[0]![0].data
    expect(saved).toMatchObject({ ...valid, linkHash: 'link', kind: 'statement' })
    expect(saved.stagingKey).toMatch(/^staging\//)
    expect(saved.objectKey).toMatch(/^media\//)
    expect(saved.expiresAt.getTime() - Date.now()).toBeGreaterThan(290000)
    expect(Object.keys(result).sort()).toEqual(['expiresAt', 'reference', 'uploadUrl'])
  })
  it('limits abandoned uploads and rate-limits repeated reservations', async () => {
    mocks.db.count.mockResolvedValue(4)
    await expect(reserveReceiptScreenshot('link', 'shipment', valid)).rejects.toThrow('Finish the selected upload')
    mocks.rateLimit.mockResolvedValue(false)
    await expect(reserveReceiptScreenshot('link', 'shipment', valid)).rejects.toMatchObject({ status: 429 })
    expect(mocks.signUpload).not.toHaveBeenCalled()
  })
  it('keeps receipts without screenshots compatible', async () => {
    expect(await acceptReceiptScreenshot(undefined, 'link', 'shipment')).toBeNull()
    expect(mocks.db.findFirst).not.toHaveBeenCalled()
  })
  it('rejects missing, cross-link and already-attached references', async () => {
    mocks.db.findFirst.mockResolvedValue(null)
    await expect(acceptReceiptScreenshot('ref', 'link', 'statement')).rejects.toThrow('does not belong')
    expect(mocks.db.findFirst).toHaveBeenCalledWith({ where: { reference: 'ref', linkHash: 'link', kind: 'statement', status: 'pending' } })
    expect(mocks.finalizeUpload).not.toHaveBeenCalled()
  })
  it('requires unexpired and verified content before accepting evidence', async () => {
    const upload = { id: 'upload', reference: 'ref', expiresAt: new Date(Date.now() - 1) }
    mocks.db.findFirst.mockResolvedValue(upload)
    await expect(acceptReceiptScreenshot('ref', 'link', 'shipment')).rejects.toThrow('expired')
    expect(mocks.finalizeUpload).not.toHaveBeenCalled()
    upload.expiresAt = new Date(Date.now() + 60000)
    mocks.finalizeUpload.mockRejectedValueOnce(new Error('Bad contents'))
    await expect(acceptReceiptScreenshot('ref', 'link', 'shipment')).rejects.toThrow('Bad contents')
    expect(mocks.db.update).not.toHaveBeenCalled()
    mocks.finalizeUpload.mockResolvedValueOnce({ size: 180, contentType: 'image/jpeg' })
    expect(await acceptReceiptScreenshot('ref', 'link', 'shipment')).toBe('ref')
    expect(mocks.db.update).toHaveBeenCalledWith({ where: { id: 'upload' }, data: { status: 'attached', size: 180, contentType: 'image/jpeg' } })
  })
})
