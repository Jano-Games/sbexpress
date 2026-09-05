import {afterEach,beforeEach,describe,it,expect,vi} from 'vitest'
import {S3Client,HeadObjectCommand,GetObjectCommand,CopyObjectCommand} from '@aws-sdk/client-s3'
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
 it('promotes verified content conditionally to a distinct immutable key',async()=>{
  const send=vi.spyOn(S3Client.prototype,'send')
  send.mockResolvedValueOnce({ContentLength:32,ContentType:'image/png',ETag:'verified-etag'} as never)
  send.mockResolvedValueOnce({Body:{transformToByteArray:async()=>new Uint8Array([137,80,78,71,13,10,26,10])}} as never)
  send.mockResolvedValueOnce({} as never)
  await finalizeUpload(sample)
  expect(send.mock.calls[0]![0]).toBeInstanceOf(HeadObjectCommand)
  expect(send.mock.calls[1]![0]).toBeInstanceOf(GetObjectCommand)
  const copy=send.mock.calls[2]![0] as CopyObjectCommand
  expect(copy).toBeInstanceOf(CopyObjectCommand);expect(copy.input.Key).toBe(sample.objectKey);expect(copy.input.CopySourceIfMatch).toBe('verified-etag')
 })
})
