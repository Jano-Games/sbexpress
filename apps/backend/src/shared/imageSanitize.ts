import sharp from 'sharp'
import { badRequest } from '../core/errors'

/**
 * Decode and write raster images again before they are stored.
 * JPEG, PNG and WebP lose EXIF, GPS, XMP and other metadata in the new bytes.
 * PDF and video are not re-encoded. There is no antivirus or malware scan;
 * signature checks only confirm the file format.
 */
export async function reencodeImage(bytes: Uint8Array, contentType: string): Promise<{ body: Buffer; contentType: string; size: number }> {
  try {
    const pipeline = sharp(bytes, { failOn: 'error', animated: false }).rotate()
    const body = contentType === 'image/jpeg'
      ? await pipeline.jpeg({ quality: 80 }).toBuffer()
      : contentType === 'image/png'
        ? await pipeline.png().toBuffer()
        : contentType === 'image/webp'
          ? await pipeline.webp({ quality: 80 }).toBuffer()
          : null
    if (!body) throw badRequest('Unsupported image')
    return { body, contentType, size: body.length }
  } catch (error) {
    if (error instanceof Error && error.message === 'Unsupported image') throw error
    throw badRequest('Image could not be processed')
  }
}
