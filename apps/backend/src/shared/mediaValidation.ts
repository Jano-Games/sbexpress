export const mediaTypes = ['image/jpeg','image/png','image/webp','video/mp4','video/webm'] as const
export function matchesMediaType(type: string, b: Uint8Array): boolean {
  const ascii = (start: number, end: number) => String.fromCharCode(...b.slice(start,end))
  if (type === 'image/jpeg') return b[0] === 255 && b[1] === 216 && b[2] === 255
  if (type === 'image/png') return [137,80,78,71,13,10,26,10].every((v,i)=>b[i]===v)
  if (type === 'image/webp') return ascii(0,4)==='RIFF' && ascii(8,12)==='WEBP'
  if (type === 'video/mp4') return ascii(4,8)==='ftyp'
  if (type === 'video/webm') return [26,69,223,163].every((v,i)=>b[i]===v)
  return false
}
export function matchesDocumentType(type: string, bytes: Uint8Array): boolean {
  if (type === 'application/pdf') return String.fromCharCode(...bytes.slice(0, 5)) === '%PDF-'
  return type.startsWith('image/') && matchesMediaType(type, bytes)
}
export const mediaLimit = (type: string) => type.startsWith('video/') ? 100 * 1024 * 1024 : 10 * 1024 * 1024

/** Payment QR images are raster data URLs only. SVG and other types are rejected. */
export function matchesQrDataUrl(value: string): boolean {
  if (value.length > 400_000 || /svg/i.test(value.slice(0, 80))) return false
  const match = /^data:image\/(png|jpeg|webp);base64,([A-Za-z0-9+/]+={0,2})$/.exec(value)
  if (!match?.[1] || !match[2]) return false
  const type = match[1] === 'png' ? 'image/png' : match[1] === 'webp' ? 'image/webp' : 'image/jpeg'
  const bytes = Buffer.from(match[2], 'base64')
  if (!bytes.length || bytes.length > 300 * 1024) return false
  return matchesMediaType(type, bytes)
}
