import {describe,it,expect} from 'vitest'
import {matchesMediaType,matchesQrDataUrl,mediaLimit} from '../src/shared/mediaValidation'
describe('media verification',()=>{
 it('rejects active content and MIME spoofing',()=>{const html=new TextEncoder().encode('<html><script>alert(1)</script>');for(const t of ['image/jpeg','image/png','image/webp','video/mp4','video/webm','image/svg+xml'])expect(matchesMediaType(t,html)).toBe(false)})
 it('checks signatures, including webp container identity',()=>{expect(matchesMediaType('image/png',new Uint8Array([137,80,78,71,13,10,26,10]))).toBe(true);expect(matchesMediaType('image/webp',new TextEncoder().encode('RIFFxxxxWAVE'))).toBe(false);expect(matchesMediaType('video/mp4',new TextEncoder().encode('xxxxftypisom'))).toBe(true)})
 it('bounds image and video sizes',()=>{expect(mediaLimit('image/jpeg')).toBe(10485760);expect(mediaLimit('video/mp4')).toBe(104857600)})
 it('accepts only png, jpeg and webp payment QR images',()=>{
  const png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  expect(matchesQrDataUrl(`data:image/png;base64,${png}`)).toBe(true)
  const jpeg=Buffer.from([0xff,0xd8,0xff,0xdb,0x00,0x43]).toString('base64')
  expect(matchesQrDataUrl(`data:image/jpeg;base64,${jpeg}`)).toBe(true)
  const webp=Buffer.concat([Buffer.from('RIFF'),Buffer.from([8,0,0,0]),Buffer.from('WEBP')]).toString('base64')
  expect(matchesQrDataUrl(`data:image/webp;base64,${webp}`)).toBe(true)
  expect(matchesQrDataUrl('data:image/svg+xml;base64,PHN2Zy8+')).toBe(false)
  expect(matchesQrDataUrl('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg"/>')).toBe(false)
  expect(matchesQrDataUrl(`data:image/jpeg;base64,${png}`)).toBe(false)
  expect(matchesQrDataUrl(`data:image/png;base64,${jpeg}`)).toBe(false)
 })
})
