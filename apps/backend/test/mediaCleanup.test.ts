import { beforeEach, describe, expect, it, vi } from 'vitest'
const fake=vi.hoisted(()=>({store:{findMany:vi.fn(),findUnique:vi.fn(),delete:vi.fn()},remove:vi.fn(),atomic:vi.fn()}))
vi.mock('../src/core/db',()=>({prisma:{shipmentMedia:fake.store,receiptUpload:fake.store,flyerDocument:fake.store},atomicMutation:fake.atomic}))
vi.mock('../src/shared/r2',()=>({removeStoredObject:fake.remove}))
import {cleanupMedia} from '../src/shared/mediaCleanup'
const row={id:'a',stagingKey:'staging/test',objectKey:'media/test',expiresAt:new Date(Date.now()-8*86400_000),status:'pending'}
beforeEach(()=>{vi.resetAllMocks();fake.store.findMany.mockResolvedValue([]);fake.atomic.mockImplementation((work:()=>unknown)=>work())})
describe('upload cleanup',()=>{
 it('defaults to reporting without deleting any objects or rows',async()=>{
  fake.store.findMany.mockResolvedValueOnce([{id:'a'}]);fake.store.findUnique.mockResolvedValue(row)
  expect(await cleanupMedia()).toMatchObject({mode:'dry-run',removedRecords:1})
  expect(fake.remove).not.toHaveBeenCalled();expect(fake.store.delete).not.toHaveBeenCalled()
 })
 it('preserves a ready final attachment while cleaning its staging copy',async()=>{
  fake.store.findMany.mockResolvedValueOnce([{id:'a'}]);fake.store.findUnique.mockResolvedValue({...row,status:'ready'})
  await cleanupMedia(true)
  expect(fake.remove.mock.calls).toEqual([['staging/test']]);expect(fake.store.delete).not.toHaveBeenCalled()
 })
 it('rechecks expiry after locking so a live upload is not removed',async()=>{
  fake.store.findMany.mockResolvedValueOnce([{id:'a'}]);fake.store.findUnique.mockResolvedValue({...row,expiresAt:new Date(Date.now()+3600_000)})
  await cleanupMedia(true);expect(fake.remove).not.toHaveBeenCalled();expect(fake.store.delete).not.toHaveBeenCalled()
 })
 it('advances by ID after deletion, preserving access to later batches',async()=>{
  fake.store.findMany.mockResolvedValueOnce([{id:'a'}]).mockResolvedValueOnce([{id:'b'}]);fake.store.findUnique.mockImplementation(({where}:{where:{id:string}})=>({...row,id:where.id}))
  expect((await cleanupMedia(true)).removedRecords).toBe(2)
  expect(fake.store.findMany.mock.calls[1]![0].where.id).toEqual({gt:'a'})
  expect(fake.store.delete).toHaveBeenCalledTimes(2)
 })
})


