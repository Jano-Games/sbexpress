import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('heic2any', () => ({
  default: vi.fn(async () => new Blob([Uint8Array.from([9, 9, 9])], { type: 'image/jpeg' })),
}))

const {
  describeUploadError,
  fittedSize,
  optionalScreenshotReference,
  planUpload,
  prepareUploadFile,
  sniffImage,
  transferUpload,
} = await import('../src/lib/uploadFile')
const heic2any = (await import('heic2any')).default

function bytes(text: string, length = 16) {
  const out = new Uint8Array(length)
  out.set(new TextEncoder().encode(text))
  return out
}

function file(data: Uint8Array, name: string, type: string) {
  return new File([data], name, { type })
}

beforeEach(() => {
  vi.clearAllMocks()
})
afterEach(() => {
  vi.unstubAllGlobals()
})

describe('upload preparation', () => {
  it('fits the longest edge to 2000px', () => {
    expect(fittedSize(4000, 3000)).toEqual({ width: 2000, height: 1500 })
    expect(fittedSize(3000, 4000)).toEqual({ width: 1500, height: 2000 })
    expect(fittedSize(800, 600)).toEqual({ width: 800, height: 600 })
  })

  it('sniffs HEIC brands and treats a JPEG named .heic as a JPEG', () => {
    const heic = new Uint8Array(16)
    heic.set(new TextEncoder().encode('ftyp'), 4)
    heic.set(new TextEncoder().encode('heic'), 8)
    expect(sniffImage(heic)).toBe('heic')
    const jpeg = Uint8Array.from([0xff, 0xd8, 0xff, 0xe1, 0, 0])
    expect(sniffImage(jpeg)).toBe('jpeg')
    expect(planUpload({ name: 'phone.heic', type: 'image/heic', size: 10, header: jpeg, allowPdf: false, allowVideo: false }).kind).toBe('reencode')
    expect(planUpload({ name: 'phone.heic', type: 'image/heic', size: 10, header: heic, allowPdf: false, allowVideo: false }).kind).toBe('heic')
    expect(planUpload({ name: 'icon.svg', type: 'image/svg+xml', size: 10, header: bytes('<svg'), allowPdf: false, allowVideo: false })).toMatchObject({
      kind: 'reject',
    })
  })

  it('explains storage, rate-limit, expiry and network failures', () => {
    expect(describeUploadError(Object.assign(new Error('storage'), { status: 503 }))).toMatch(/not configured/i)
    expect(describeUploadError(Object.assign(new Error('slow'), { status: 429 }))).toMatch(/Wait a minute/)
    expect(describeUploadError(new Error('Upload reservation expired'))).toMatch(/expired/)
    expect(describeUploadError(new TypeError('Failed to fetch'))).toMatch(/did not reach storage/)
  })

  it('re-encodes a large JPEG, including one named like HEIC, to at most 2000px', async () => {
    const canvas = {
      width: 0,
      height: 0,
      getContext: () => ({ drawImage: () => undefined }),
      toBlob: (done: (blob: Blob | null) => void) => {
        done(new Blob([Uint8Array.from([1, 2, 3])], { type: 'image/jpeg' }))
      },
    }
    vi.stubGlobal('document', { createElement: () => canvas })
    vi.stubGlobal('createImageBitmap', async () => ({ width: 4000, height: 3000, close: () => undefined }))
    const jpeg = Uint8Array.from([0xff, 0xd8, 0xff, 0xe1])
    const prepared = await prepareUploadFile(file(jpeg, 'IMG.HEIC', 'image/heic'), { maxBytes: 10 * 1024 * 1024 })
    expect(prepared.type).toBe('image/jpeg')
    expect(prepared.name.endsWith('.jpg')).toBe(true)
    expect(canvas.width).toBe(2000)
    expect(canvas.height).toBe(1500)
    expect(heic2any).not.toHaveBeenCalled()
  })

  it('converts a real HEIC file before compressing it', async () => {
    const canvas = {
      width: 0,
      height: 0,
      getContext: () => ({ drawImage: () => undefined }),
      toBlob: (done: (blob: Blob | null) => void) => done(new Blob([Uint8Array.from([4])], { type: 'image/jpeg' })),
    }
    vi.stubGlobal('document', { createElement: () => canvas })
    vi.stubGlobal('createImageBitmap', vi.fn()
      .mockRejectedValueOnce(new Error('cannot decode'))
      .mockResolvedValueOnce({ width: 100, height: 80, close: () => undefined }))
    const heic = new Uint8Array(16)
    heic.set(new TextEncoder().encode('ftyp'), 4)
    heic.set(new TextEncoder().encode('heic'), 8)
    const prepared = await prepareUploadFile(file(heic, 'shot.heic', 'image/heic'), { maxBytes: 5 * 1024 * 1024 })
    expect(heic2any).toHaveBeenCalledOnce()
    expect(prepared.type).toBe('image/jpeg')
    expect(canvas.width).toBe(100)
  })
})

describe('upload transfer', () => {
  const payload = file(Uint8Array.from([1]), 'a.jpg', 'image/jpeg')

  it('reserves again after a failed put', async () => {
    const reserve = vi.fn()
      .mockResolvedValueOnce({ reference: 'first', uploadUrl: 'https://storage.example/first' })
      .mockResolvedValueOnce({ reference: 'second', uploadUrl: 'https://storage.example/second' })
    const fetchImpl = vi.fn()
      .mockResolvedValueOnce({ ok: false, status: 500 })
      .mockResolvedValueOnce({ ok: true, status: 200 })
    const complete = vi.fn().mockResolvedValue({ ok: true })
    await expect(transferUpload({ file: payload, reserve, complete, fetchImpl })).resolves.toBe('second')
    expect(reserve).toHaveBeenCalledTimes(2)
    expect(complete).toHaveBeenCalledWith('second')
  })

  it('retries completion once unless the reservation expired', async () => {
    const reserve = vi.fn()
      .mockResolvedValueOnce({ reference: 'kept', uploadUrl: 'https://storage.example/kept' })
      .mockResolvedValueOnce({ reference: 'fresh', uploadUrl: 'https://storage.example/fresh' })
    const fetchImpl = vi.fn().mockResolvedValue({ ok: true, status: 200 })
    const complete = vi.fn()
      .mockRejectedValueOnce(new Error('temporary'))
      .mockResolvedValueOnce({ ok: true })
    await expect(transferUpload({ file: payload, reserve, complete, fetchImpl })).resolves.toBe('kept')
    expect(reserve).toHaveBeenCalledTimes(1)
    expect(complete).toHaveBeenCalledTimes(2)

    reserve.mockReset()
    reserve
      .mockResolvedValueOnce({ reference: 'stale', uploadUrl: 'https://storage.example/stale' })
      .mockResolvedValueOnce({ reference: 'fresh', uploadUrl: 'https://storage.example/fresh' })
    fetchImpl.mockReset()
    fetchImpl.mockResolvedValue({ ok: true, status: 200 })
    complete.mockReset()
    complete.mockRejectedValueOnce(new Error('Upload reservation expired')).mockResolvedValueOnce({ ok: true })
    await expect(transferUpload({ file: payload, reserve, complete, fetchImpl })).resolves.toBe('fresh')
    expect(reserve).toHaveBeenCalledTimes(2)
  })

  it('does not retry a rejected reservation', async () => {
    const reserve = vi.fn().mockRejectedValue(Object.assign(new Error('bad file'), { status: 400 }))
    await expect(transferUpload({
      file: payload,
      reserve,
      complete: vi.fn(),
      fetchImpl: vi.fn(),
    })).rejects.toThrow(/400/)
    expect(reserve).toHaveBeenCalledTimes(1)
  })
})

describe('optional payment screenshot', () => {
  it('submits without a screenshot when none was chosen or the upload is skipped', async () => {
    await expect(optionalScreenshotReference({
      hasFile: false,
      upload: async () => 'unused',
      confirmWithoutScreenshot: () => false,
    })).resolves.toBeUndefined()

    await expect(optionalScreenshotReference({
      hasFile: true,
      upload: async () => 'ref-1',
      confirmWithoutScreenshot: () => false,
    })).resolves.toBe('ref-1')

    await expect(optionalScreenshotReference({
      hasFile: true,
      upload: async () => { throw new Error('storage down') },
      confirmWithoutScreenshot: () => true,
    })).resolves.toBeUndefined()

    await expect(optionalScreenshotReference({
      hasFile: true,
      upload: async () => { throw new Error('storage down') },
      confirmWithoutScreenshot: () => false,
    })).rejects.toThrow(/storage down/)
  })
})
