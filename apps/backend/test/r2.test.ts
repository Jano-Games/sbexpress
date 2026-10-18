import {afterEach,beforeEach,describe,it,expect,vi} from 'vitest'
import {S3Client,HeadObjectCommand,GetObjectCommand,CopyObjectCommand,PutObjectCommand} from '@aws-sdk/client-s3'
import {r2Configured,signUpload,signDownload,finalizeUpload} from '../src/shared/r2'
const sample={stagingKey:'staging/11111111-1111-4111-8111-111111111111',objectKey:'media/22222222-2222-4222-8222-222222222222',contentType:'image/png',size:32}
beforeEach(()=>{vi.stubEnv('R2_ACCOUNT_ID','a'.repeat(32));vi.stubEnv('R2_BUCKET','test-private');vi.stubEnv('R2_ACCESS_KEY_ID','test-key');vi.stubEnv('R2_SECRET_ACCESS_KEY','test-secret')})
afterEach(()=>{vi.restoreAllMocks();vi.unstubAllEnvs()})
describe('R2 upload and download security',()=>{
 it('fails closed when storage credentials are missing',async()=>{vi.stubEnv('R2_SECRET_ACCESS_KEY','');expect(r2Configured()).toBe(false);await expect(signUpload(sample.stagingKey,sample.contentType,32)).rejects.toMatchObject({status:503})})
 it('signs exact file size/type and short-lived operation-specific URLs',async()=>{
  const url=new URL(await signUpload(sample.stagingKey,sample.contentType,32))
  expect(url.searchParams.get('X-Amz-Expires')).toBe('300')
  expect(url.searchParams.get('X-Amz-SignedHeaders')).toContain('content-type')
  expect(url.searchParams.get('X-Amz-SignedHeaders')).toContain('content-length')
  expect(url.pathname).toContain('/staging/')
  const read=new URL(await signDownload(sample.objectKey,45));expect(read.searchParams.get('X-Amz-Expires')).toBe('45')
  expect(new URL(await signDownload(sample.objectKey,999)).searchParams.get('X-Amz-Expires')).toBe('120')
  expect(new URL(await signUpload(sample.stagingKey,'image/jpeg',32,900)).searchParams.get('X-Amz-Expires')).toBe('900')
 })
 it('rejects oversize or mismatched uploaded objects before promotion',async()=>{
  const send=vi.spyOn(S3Client.prototype,'send').mockResolvedValue({ContentLength:33,ContentType:'image/png',ETag:'etag'} as never)
  await expect(finalizeUpload(sample)).rejects.toMatchObject({status:400});expect(send).toHaveBeenCalledTimes(1)
 })
 it('rejects disguised HTML even with image metadata',async()=>{
  const send=vi.spyOn(S3Client.prototype,'send')
  send.mockResolvedValueOnce({ContentLength:32,ContentType:'image/png',ETag:'etag'} as never)
  send.mockResolvedValueOnce({Body:{transformToByteArray:async()=>new TextEncoder().encode('<html><script>')}} as never)
  await expect(finalizeUpload(sample)).rejects.toMatchObject({status:400});expect(send).toHaveBeenCalledTimes(2)
 })
 it('re-encodes a verified image onto a distinct immutable key',async()=>{
  const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==','base64')
  const image={...sample,size:png.length}
  const send=vi.spyOn(S3Client.prototype,'send')
  send.mockResolvedValueOnce({ContentLength:png.length,ContentType:'image/png',ETag:'verified-etag'} as never)
  send.mockResolvedValueOnce({Body:{transformToByteArray:async()=>png}} as never)
  send.mockResolvedValueOnce({} as never)
  const stored=await finalizeUpload(image)
  expect(send.mock.calls[0]![0]).toBeInstanceOf(HeadObjectCommand)
  expect(send.mock.calls[1]![0]).toBeInstanceOf(GetObjectCommand)
  const put=send.mock.calls[2]![0] as PutObjectCommand
  expect(put).toBeInstanceOf(PutObjectCommand)
  expect(put.input.Key).toBe(sample.objectKey)
  expect(put.input.ContentType).toBe('image/png')
  expect(stored.contentType).toBe('image/png')
  expect(stored.size).toBeGreaterThan(0)
 })
 it('accepts real PDF headers only for document uploads, leaving photo/video rules intact',async()=>{
  const send=vi.spyOn(S3Client.prototype,'send')
  const pdf={...sample,contentType:'application/pdf'}
  const head={ContentLength:32,ContentType:'application/pdf',ETag:'pdf-etag'}
  const bytes={Body:{transformToByteArray:async()=>new TextEncoder().encode('%PDF-1.7\n')}}
  send.mockResolvedValueOnce(head as never).mockResolvedValueOnce(bytes as never).mockResolvedValueOnce({} as never)
  await expect(finalizeUpload(pdf,{allowPdf:true})).resolves.toEqual({size:32,contentType:'application/pdf'})
  send.mockResolvedValueOnce(head as never).mockResolvedValueOnce(bytes as never)
  await expect(finalizeUpload(pdf)).rejects.toMatchObject({status:400})
  send.mockResolvedValueOnce(head as never).mockResolvedValueOnce({Body:{transformToByteArray:async()=>new TextEncoder().encode('<html>')}} as never)
  await expect(finalizeUpload(pdf,{allowPdf:true})).rejects.toMatchObject({status:400})
 })

})
