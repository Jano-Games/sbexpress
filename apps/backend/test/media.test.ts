import {describe,it,expect} from 'vitest'
import {matchesMediaType,mediaLimit} from '../src/shared/mediaValidation'
describe('media verification',()=>{
 it('rejects active content and MIME spoofing',()=>{const html=new TextEncoder().encode('<html><script>alert(1)</script>');for(const t of ['image/jpeg','image/png','image/webp','video/mp4','video/webm','image/svg+xml'])expect(matchesMediaType(t,html)).toBe(false)})
 it('checks signatures, including webp container identity',()=>{expect(matchesMediaType('image/png',new Uint8Array([137,80,78,71,13,10,26,10]))).toBe(true);expect(matchesMediaType('image/webp',new TextEncoder().encode('RIFFxxxxWAVE'))).toBe(false);expect(matchesMediaType('video/mp4',new TextEncoder().encode('xxxxftypisom'))).toBe(true)})
 it('bounds image and video sizes',()=>{expect(mediaLimit('image/jpeg')).toBe(10485760);expect(mediaLimit('video/mp4')).toBe(104857600)})
})
