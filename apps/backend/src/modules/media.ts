import { writeShipmentLog } from '../shared/actor'
import { Hono } from 'hono'
import { randomUUID } from 'node:crypto'
import { z } from 'zod'
import { prisma } from '../core/db'
import { rateLimit } from '../core/redis'
import { badRequest, notFound, HttpError } from '../core/errors'
import { requireRole, type AppEnv } from './auth'
import { mediaLimit, mediaTypes } from '../shared/mediaValidation'
import { r2Configured, signUpload, finalizeUpload, signDownload } from '../shared/r2'
import { resolvePublicLink, tokenHash } from '../shared/publicLinks'
const ref = z.string().uuid()
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
const row=(m:{reference:string;name:string;contentType:string;size:number;shared:boolean})=>({reference:m.reference,name:m.name,contentType:m.contentType,size:m.size,shared:m.shared})
export const mediaRoutes=new Hono<AppEnv>()
 .get('/:code/media',requireRole('admin','hub'),async c=>{
  const s=await shipment(c.req.param('code')!)
  const rows=await prisma.shipmentMedia.findMany({where:{shipmentId:s.id,status:'ready'},orderBy:{createdAt:'asc'}})
  return c.json({configured:r2Configured(),media:rows.map(row)})
 })
 .post('/:code/media/upload',requireRole('admin','hub'),async c=>{
  const s=await shipment(c.req.param('code')!)
  const b=z.object({name:z.string().trim().min(1).max(180),contentType:z.enum(mediaTypes),size:z.number().int().positive()}).parse(await c.req.json())
  if(b.size>mediaLimit(b.contentType)) throw badRequest('Maximum photo size is 10 MB; video size is 100 MB')
  if(await prisma.shipmentMedia.count({where:{shipmentId:s.id,OR:[{status:'ready'},{status:'pending',expiresAt:{gt:new Date()}}]}})>=50) throw badRequest('Maximum 50 attachments per shipment')
  const stagingKey=`staging/${randomUUID()}`,objectKey=`media/${randomUUID()}`
  const uploadUrl=await signUpload(stagingKey,b.contentType,b.size)
  const m=await prisma.shipmentMedia.create({data:{...b,shipmentId:s.id,stagingKey,objectKey,expiresAt:new Date(Date.now()+300000)}})
  return c.json({reference:m.reference,uploadUrl,expiresAt:m.expiresAt.toISOString()},201)
 })
 .post('/:code/media/:reference/complete',requireRole('admin','hub'),async c=>{
  const m=await media(c.req.param('code')!,c.req.param('reference')!)
  if(m.status==='ready') return c.json({ok:true})
  if(m.expiresAt<=new Date()) throw badRequest('Upload reservation expired; start a new upload')
  await finalizeUpload(m)
  await prisma.shipmentMedia.update({where:{id:m.id},data:{status:'ready'}})
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
  await prisma.shipmentMedia.update({where:{id:m.id},data:{shared}})
  return c.json({ok:true})
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
  const rows=await prisma.shipmentMedia.findMany({where:{shipmentId:link.shipmentId,status:'ready',shared:true},orderBy:{createdAt:'asc'}})
  return c.json({media:rows.map(row)})
 })
 .get('/:token/media/:reference/url',async c=>{
  const link=await resolvePublicLink(c.req.param('token'))
  const m=await prisma.shipmentMedia.findFirst({where:{shipmentId:link.shipmentId,reference:ref.parse(c.req.param('reference')!),status:'ready',shared:true}})
  if(!m) throw notFound('Attachment not found')
  return c.json({url:await signDownload(m.objectKey,Math.floor((link.expiresAt.getTime()-Date.now())/1000))})
 })
