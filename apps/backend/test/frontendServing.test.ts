import { Hono } from 'hono'
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterAll, describe, expect, it } from 'vitest'
import { serveFrontend } from '../src/core/frontend'
const root=mkdtempSync(join(tmpdir(),'mamun-static-'))
mkdirSync(join(root,'assets'));writeFileSync(join(root,'index.html'),'<html>Built app</html>');writeFileSync(join(root,'assets/app-hash.js'),'export const safe = true;')
afterAll(()=>rmSync(root,{recursive:true,force:true}))
const app=new Hono();serveFrontend(app,root)
describe('built frontend serving',()=>{
 it('serves nested customer routes with privacy and framing headers',async()=>{
  const r=await app.request('/t/random-token',{headers:{Accept:'text/html'}})
  expect(r.status).toBe(200);expect(r.headers.get('cache-control')).toBe('no-store')
  expect(r.headers.get('content-security-policy')).toContain("media-src 'self' blob:");
  expect((await app.request('/flyers/Md.Rahim',{headers:{Accept:'text/html'}})).status).toBe(200)
  expect(r.headers.get('referrer-policy')).toBe('no-referrer');expect(r.headers.get('content-security-policy')).toContain("frame-ancestors 'none'")
 })
 it('never falls back to HTML for API, source maps or private files',async()=>{
  for(const path of ['/api/unknown','/.env','/assets/missing.js','/src/main.ts','/assets/app.js.map'])expect((await app.request(path,{headers:{Accept:'text/html'}})).status).toBe(404)
 })
 it('serves only built assets with immutable caching',async()=>{
  const r=await app.request('/assets/app-hash.js');expect(r.status).toBe(200);expect(r.headers.get('cache-control')).toContain('immutable')
 })
})
