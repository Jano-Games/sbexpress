import {prisma,closeDb} from '../src/core/db'
import {removeStoredObject} from '../src/shared/r2'
const execute=process.argv.includes('--execute')
try{
 const rows=await prisma.shipmentMedia.findMany({where:{expiresAt:{lt:new Date(Date.now()-600000)}}})
 let staging=0,removed=0
 for(const m of rows){
  if(execute)await removeStoredObject(m.stagingKey);staging++
  if(m.status==='deleted'||m.status==='pending'){
   if(execute){await removeStoredObject(m.objectKey);await prisma.shipmentMedia.delete({where:{id:m.id}})}removed++
  }
 }
 console.log(JSON.stringify({mode:execute?'executed':'dry-run',expiredStagingObjects:staging,abandonedOrRemovedAttachments:removed}))
}finally{await closeDb()}
