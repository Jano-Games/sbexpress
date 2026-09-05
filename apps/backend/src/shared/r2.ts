import { S3Client, PutObjectCommand, GetObjectCommand, HeadObjectCommand, CopyObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'
import { HttpError, badRequest } from '../core/errors'
import { matchesMediaType } from './mediaValidation'
let client: S3Client | undefined
export const r2Configured = () => ['R2_ACCOUNT_ID','R2_BUCKET','R2_ACCESS_KEY_ID','R2_SECRET_ACCESS_KEY'].every(k=>Boolean(process.env[k]))
function storage() {
  if (!r2Configured()) throw new HttpError(503,'Photo/video storage is not configured yet')
  const account = process.env.R2_ACCOUNT_ID!
  if (!/^[a-f0-9]{32}$/i.test(account)) throw new HttpError(503,'Invalid R2 account configuration')
  client ??= new S3Client({region:'auto',endpoint:`https://${account}.r2.cloudflarestorage.com`,credentials:{accessKeyId:process.env.R2_ACCESS_KEY_ID!,secretAccessKey:process.env.R2_SECRET_ACCESS_KEY!},requestChecksumCalculation:'WHEN_REQUIRED',responseChecksumValidation:'WHEN_REQUIRED'})
  return {client,bucket:process.env.R2_BUCKET!}
}
export async function signUpload(key: string, contentType: string, size: number) {
  const {client,bucket}=storage()
  return getSignedUrl(client,new PutObjectCommand({Bucket:bucket,Key:key,ContentType:contentType,ContentLength:size}),{expiresIn:300,signableHeaders:new Set(['content-type','content-length'])})
}
export async function finalizeUpload(m: {stagingKey:string;objectKey:string;contentType:string;size:number}) {
  const {client,bucket}=storage()
  try {
    const head=await client.send(new HeadObjectCommand({Bucket:bucket,Key:m.stagingKey}))
    if(head.ContentLength!==m.size || head.ContentType!==m.contentType || !head.ETag) throw badRequest('Uploaded file size/type does not match the reservation')
    const sample=await client.send(new GetObjectCommand({Bucket:bucket,Key:m.stagingKey,Range:'bytes=0-31',IfMatch:head.ETag}))
    if(!sample.Body || !matchesMediaType(m.contentType,await sample.Body.transformToByteArray())) throw badRequest('File contents are not a supported photo/video')
    // Promote to an immutable key. Reusing the PUT URL can only overwrite staging.
    await client.send(new CopyObjectCommand({Bucket:bucket,Key:m.objectKey,CopySource:`${bucket}/${m.stagingKey}`,CopySourceIfMatch:head.ETag,MetadataDirective:'REPLACE',ContentType:m.contentType,CacheControl:'private, no-store',ContentDisposition:'inline'}))
  } catch(e) {
    if(e instanceof HttpError) throw e
    throw badRequest('Upload could not be verified. Finish uploading and try again.')
  }
}
export async function signDownload(key: string, seconds=120) {
  const {client,bucket}=storage()
  return getSignedUrl(client,new GetObjectCommand({Bucket:bucket,Key:key,ResponseCacheControl:'private, no-store'}),{expiresIn:Math.max(1,Math.min(120,seconds))})
}

export async function removeStoredObject(key:string){
 if(!/^(staging|media)\/[0-9a-f-]{36}$/.test(key))throw badRequest('Unexpected storage key')
 const {client,bucket}=storage();await client.send(new DeleteObjectCommand({Bucket:bucket,Key:key}))
}
