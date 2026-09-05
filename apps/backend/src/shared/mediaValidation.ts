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
export const mediaLimit = (type: string) => type.startsWith('video/') ? 100 * 1024 * 1024 : 10 * 1024 * 1024
