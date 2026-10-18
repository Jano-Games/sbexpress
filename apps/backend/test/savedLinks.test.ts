import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
vi.mock('../src/core/db',()=>({prisma:{}}))
vi.mock('../src/core/config',()=>({config:{publicTrackBaseUrl:'https://customer.invalid'}}))
const {sealLinkToken,openLinkToken,savedLink}=await import('../src/shared/savedLinks')
const {newPublicToken,tokenHash}=await import('../src/shared/publicLinks')
let previous:string|undefined
beforeEach(()=>{previous=process.env.LINK_ENCRYPTION_KEY;process.env.LINK_ENCRYPTION_KEY='10'.repeat(32)})
afterEach(()=>{if(previous===undefined)delete process.env.LINK_ENCRYPTION_KEY;else process.env.LINK_ENCRYPTION_KEY=previous})
describe('durable private customer links',()=>{
 it('recovers the same link across reads without storing a plaintext token',()=>{
  const token=newPublicToken(),digest=tokenHash(token),a=sealLinkToken(token),b=sealLinkToken(token)
  expect(a).not.toContain(token);expect(a).not.toBe(b)
  expect(openLinkToken(a,digest)).toBe(token)
  expect(openLinkToken(b,digest)).toBe(token)
 })
 it('rejects tampering, swapped digests and changed keys',()=>{
  const token=newPublicToken(),digest=tokenHash(token),ciphertext=sealLinkToken(token)
  expect(openLinkToken(ciphertext,tokenHash(newPublicToken()))).toBeNull()
  expect(openLinkToken(ciphertext.slice(0,-5)+'XXXXX',digest)).toBeNull()
  process.env.LINK_ENCRYPTION_KEY='20'.repeat(32)
  expect(openLinkToken(ciphertext,digest)).toBeNull()
 })
 it('requires an explicit encryption key and safely lists older hashed links',()=>{
  delete process.env.LINK_ENCRYPTION_KEY
  expect(()=>sealLinkToken(newPublicToken())).toThrow('not configured')
  expect(openLinkToken(null,'hash')).toBeNull()
 })
 it('retains expired/revoked history without exposing ciphertext or the digest',()=>{
  const token=newPublicToken(),row={id:'link',tokenCiphertext:sealLinkToken(token),tokenHash:tokenHash(token),createdAt:new Date(),expiresAt:new Date(Date.now()-1000),revokedAt:null}
  const result=savedLink(row,'t')
  expect(result.status).toBe('expired');expect(result.url).toBe(`https://customer.invalid/t/${token}`)
  expect(result).not.toHaveProperty('tokenCiphertext');expect(result).not.toHaveProperty('tokenHash')
  expect(savedLink({...row,revokedAt:new Date()},'t').status).toBe('revoked')
 })
})
