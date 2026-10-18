import { describe, expect, it } from 'vitest'
import sharp from 'sharp'
import { reencodeImage } from '../src/shared/imageSanitize'

describe('image re-encode', () => {
  it('strips EXIF, including a GPS description, from JPEG bytes', async () => {
    const marker = 'GPS-LATITUDE-23.810332'
    const input = await sharp({
      create: { width: 12, height: 8, channels: 3, background: { r: 12, g: 34, b: 56 } },
    }).jpeg().withMetadata({
      exif: { IFD0: { ImageDescription: marker } },
    }).toBuffer()
    const before = await sharp(input).metadata()
    expect(before.exif).toBeDefined()
    expect(Buffer.from(input).includes(Buffer.from(marker))).toBe(true)

    const clean = await reencodeImage(new Uint8Array(input), 'image/jpeg')
    const after = await sharp(clean.body).metadata()
    expect(clean.contentType).toBe('image/jpeg')
    expect(clean.body[0]).toBe(0xff)
    expect(clean.body[1]).toBe(0xd8)
    expect(after.exif).toBeUndefined()
    expect(Buffer.from(clean.body).includes(Buffer.from(marker))).toBe(false)
  })

  it('rewrites PNG without a text metadata chunk', async () => {
    const input = await sharp({
      create: { width: 4, height: 4, channels: 3, background: { r: 1, g: 2, b: 3 } },
    }).png().toBuffer()
    const clean = await reencodeImage(new Uint8Array(input), 'image/png')
    expect(clean.contentType).toBe('image/png')
    expect(Buffer.from(clean.body.subarray(0, 8)).toString('hex')).toBe('89504e470d0a1a0a')
    const meta = await sharp(clean.body).metadata()
    expect(meta.exif).toBeUndefined()
  })

  it('rejects a type that is not a supported raster', async () => {
    const input = await sharp({
      create: { width: 2, height: 2, channels: 3, background: { r: 0, g: 0, b: 0 } },
    }).jpeg().toBuffer()
    await expect(reencodeImage(new Uint8Array(input), 'image/gif')).rejects.toMatchObject({ status: 400 })
  })
})
