import { writeShipmentLog } from '../shared/actor'
import { Hono } from 'hono'
import { randomUUID } from 'node:crypto'
import { Prisma } from '@prisma/client'
import { z } from 'zod'
import { prisma } from '../core/db'
import { rateLimit } from '../core/redis'
import { badRequest, notFound, HttpError } from '../core/errors'
import { requireRole, type AppEnv } from './auth'
import { attachUnitPhoto } from '../shared/devicePhotos'
import { mediaLimit, mediaTypes } from '../shared/mediaValidation'
import { r2Configured, signUpload, finalizeUpload, signDownload } from '../shared/r2'
import { resolvePublicLink, tokenHash } from '../shared/publicLinks'
import { assertStaffUploadBudget, reservationSeconds } from '../shared/uploadPolicy'
const ref = z.string().uuid()
/** Photos of single device pieces (IMEI label, the piece itself) stay with staff. */
const PIECE_PHOTOS = ['device_serial', 'device_photo']
const isPiecePhoto = (purpose: string) => PIECE_PHOTOS.includes(purpose)
async function syncCounts(shipmentId:string){
 const rows=await prisma.shipmentMedia.findMany({where:{shipmentId,status:'ready'},select:{contentType:true}})
 await prisma.shipment.update({where:{id:shipmentId},data:{photosCount:rows.filter(r=>r.contentType.startsWith('image/')).length,hasVideo:rows.some(r=>r.contentType.startsWith('video/'))}})
}
async function shipment(code: string) {
 const s=await prisma.shipment.findUnique({where:{code}})
 if(!s) throw notFound('Shipment not found')
 return s
}
async function media(code:string, reference:string) {
 const s=await shipment(code)
 const m=await prisma.shipmentMedia.findFirst({where:{shipmentId:s.id,reference:ref.parse(reference)}})
 if(!m || m.status==='deleted') throw notFound('Attachment not found')
 return m
}
const row=(m:{reference:string;name:string;contentType:string;size:number;shared:boolean;purpose:string;deviceKey:string|null})=>({reference:m.reference,name:m.name,contentType:m.contentType,size:m.size,shared:m.shared,
 /** "Mobile", "Laptop" … for photos of the devices in a category; null for parcel photos. */
 deviceCategory:m.purpose==='device_category'?m.deviceKey:null})
export const mediaRoutes=new Hono<AppEnv>()
 .get('/:code/media',requireRole('admin','hub'),async c=>{
  const s=await shipment(c.req.param('code')!)
  const rows=await prisma.shipmentMedia.findMany({where:{shipmentId:s.id,status:'ready',purpose:{notIn:PIECE_PHOTOS}},orderBy:{createdAt:'asc'}})
  return c.json({configured:r2Configured(),media:rows.map(row)})
 })
 .post('/:code/media/upload',requireRole('admin','hub'),async c=>{
  await assertStaffUploadBudget(c.get('user').id)
  const s=await shipment(c.req.param('code')!)
  const {deviceCategory,...b}=z.object({name:z.string().trim().min(1).max(180),contentType:z.enum(mediaTypes),size:z.number().int().positive(),deviceCategory:z.string().trim().min(1).max(60).optional()}).parse(await c.req.json())
  if(b.size>mediaLimit(b.contentType)) throw badRequest('Maximum photo size is 10 MB; video size is 100 MB')
  if(await prisma.shipmentMedia.count({where:{shipmentId:s.id,OR:[{status:'ready'},{status:'pending',expiresAt:{gt:new Date()}}]}})>=50) throw badRequest('Maximum 50 attachments per shipment')
  const seconds=reservationSeconds(b.contentType)
  const stagingKey=`staging/${randomUUID()}`,objectKey=`media/${randomUUID()}`
  const uploadUrl=await signUpload(stagingKey,b.contentType,b.size,seconds)
  const m=await prisma.shipmentMedia.create({data:{...b,purpose:deviceCategory?'device_category':'general',deviceKey:deviceCategory??null,shipmentId:s.id,stagingKey,objectKey,expiresAt:new Date(Date.now()+seconds*1000)}})
  return c.json({reference:m.reference,uploadUrl,expiresAt:m.expiresAt.toISOString()},201)
 })
 .post('/:code/media/:reference/complete',requireRole('admin','hub'),async c=>{
  const m=await media(c.req.param('code')!,c.req.param('reference')!)
  if(isPiecePhoto(m.purpose)) throw badRequest('Finish this device photo from the device photo action')
  if(m.status==='ready') return c.json({ok:true})
  if(m.expiresAt<=new Date()) throw badRequest('Upload reservation expired; start a new upload')
  const stored=await finalizeUpload(m)
  await prisma.shipmentMedia.update({where:{id:m.id},data:{status:'ready',size:stored.size,contentType:stored.contentType}})
  await syncCounts(m.shipmentId)
  await writeShipmentLog(m.shipmentId,`Photo/video attached: ${m.name}`)
  return c.json({ok:true})
 })
 .get('/:code/media/:reference/url',requireRole('admin','hub'),async c=>{
  const m=await media(c.req.param('code')!,c.req.param('reference')!)
  if(m.status!=='ready') throw notFound('Attachment not available')
  return c.json({url:await signDownload(m.objectKey)})
 })
 .patch('/:code/media/:reference',requireRole('admin'),async c=>{
  const m=await media(c.req.param('code')!,c.req.param('reference')!)
  const {shared}=z.object({shared:z.boolean()}).parse(await c.req.json())
  if(isPiecePhoto(m.purpose)) throw badRequest('Device photos stay private to staff')
  await prisma.shipmentMedia.update({where:{id:m.id},data:{shared}})
  return c.json({ok:true})
 })
 .post('/:code/device-photo',requireRole('admin','hub'),async c=>{
  await assertStaffUploadBudget(c.get('user').id)
  const s=await shipment(c.req.param('code')!)
  const b=z.object({
    itemIndex:z.number().int().min(0),
    unitIndex:z.number().int().min(0),
    /** "serial": the IMEI or serial label. "device": a photo of the piece. */
    kind:z.enum(['serial','device']).default('serial'),
    name:z.string().trim().min(1).max(180),
    contentType:z.enum(['image/jpeg','image/png','image/webp']),
    size:z.number().int().positive().max(10*1024*1024),
  }).parse(await c.req.json())
  const items=Array.isArray(s.pcsItems)?s.pcsItems as {units?:unknown[]}[]:[]
  if(!items[b.itemIndex]?.units?.[b.unitIndex]) throw badRequest('Device unit not found')
  if(await prisma.shipmentMedia.count({where:{shipmentId:s.id,OR:[{status:'ready'},{status:'pending',expiresAt:{gt:new Date()}}]}})>=50) throw badRequest('Maximum 50 attachments per shipment')
  const seconds=reservationSeconds(b.contentType)
  const stagingKey=`staging/${randomUUID()}`,objectKey=`media/${randomUUID()}`
  const uploadUrl=await signUpload(stagingKey,b.contentType,b.size,seconds)
  const created=await prisma.shipmentMedia.create({data:{
    name:b.name,contentType:b.contentType,size:b.size,shipmentId:s.id,stagingKey,objectKey,
    purpose:b.kind==='device'?'device_photo':'device_serial',deviceKey:`${b.itemIndex}:${b.unitIndex}`,shared:false,
    expiresAt:new Date(Date.now()+seconds*1000),
  }})
  return c.json({reference:created.reference,uploadUrl,expiresAt:created.expiresAt.toISOString()},201)
 })
 .post('/:code/device-photo/:reference/complete',requireRole('admin','hub'),async c=>{
  const s=await shipment(c.req.param('code')!)
  const m=await prisma.shipmentMedia.findFirst({where:{shipmentId:s.id,reference:ref.parse(c.req.param('reference')!),status:{not:'deleted'}}})
  if(!m) throw notFound('Attachment not found')
  if(!isPiecePhoto(m.purpose)||!m.deviceKey) throw badRequest('This upload is not a device photo')
  if(!m.contentType.startsWith('image/')) throw badRequest('Device photos must be images')
  const piece=m.purpose==='device_photo'
  if(m.status!=='ready'){
    if(m.expiresAt<=new Date()) throw badRequest('Upload reservation expired; start a new upload')
    const stored=await finalizeUpload(m)
    await prisma.shipmentMedia.update({where:{id:m.id},data:{status:'ready',shared:false,size:stored.size,contentType:stored.contentType}})
  } else if(m.shared) {
    await prisma.shipmentMedia.update({where:{id:m.id},data:{shared:false}})
  }
  const [itemIndex,unitIndex]=m.deviceKey.split(':').map((part)=>Number(part))
  if(itemIndex===undefined||unitIndex===undefined||Number.isNaN(itemIndex)||Number.isNaN(unitIndex)) throw badRequest('Device unit not found')
  const attached=attachUnitPhoto(s.pcsItems,itemIndex,unitIndex,m.reference,piece?'photoRef':'serialPhotoRef')
  await prisma.shipment.update({where:{id:s.id},data:{pcsItems:attached.items as Prisma.InputJsonValue}})
  if(attached.previous&&attached.previous!==m.reference){
    await prisma.shipmentMedia.updateMany({where:{shipmentId:s.id,reference:attached.previous,purpose:m.purpose},data:{status:'deleted',shared:false,expiresAt:new Date(Date.now()+120000)}})
  }
  await syncCounts(s.id)
  await writeShipmentLog(s.id,piece?'Device photo attached':'Device IMEI photo attached')
  return c.json({ok:true,reference:m.reference})
 })
 .delete('/:code/media/:reference',requireRole('admin'),async c=>{
  const m=await media(c.req.param('code')!,c.req.param('reference')!)
  await prisma.shipmentMedia.update({where:{id:m.id},data:{status:'deleted',shared:false,expiresAt:new Date(Date.now()+120000)}})
  await syncCounts(m.shipmentId)
  return c.json({ok:true})
 })
export const publicMediaRoutes=new Hono()
 .use('*',async(c,next)=>{if(!await rateLimit(`public-media:${tokenHash(c.req.path.split('/')[3] ?? '')}`,120))throw new HttpError(429,'Too many requests');await next()})
 .get('/:token/media',async c=>{
  const link=await resolvePublicLink(c.req.param('token'))
  const rows=await prisma.shipmentMedia.findMany({where:{shipmentId:link.shipmentId,status:'ready',shared:true,purpose:{notIn:PIECE_PHOTOS}},orderBy:{createdAt:'asc'}})
  return c.json({media:rows.map(row)})
 })
 .get('/:token/media/:reference/url',async c=>{
  const link=await resolvePublicLink(c.req.param('token'))
  const m=await prisma.shipmentMedia.findFirst({where:{shipmentId:link.shipmentId,reference:ref.parse(c.req.param('reference')!),status:'ready',shared:true,purpose:{notIn:PIECE_PHOTOS}}})
  if(!m) throw notFound('Attachment not found')
  return c.json({url:await signDownload(m.objectKey,Math.floor((link.expiresAt.getTime()-Date.now())/1000))})
 })
