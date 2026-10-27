import { randomUUID, createHash } from 'node:crypto'
import { beforeAll, afterAll, beforeEach, describe, expect, it, vi } from 'vitest'

// Never run destructive fixtures against the real agency database.
const enabled = process.env.AUDIT_INTEGRATION === '1'
let prisma: any, app: any, redis: any, closeDb: any, closeRedis: any
const admin = randomUUID(), hub = randomUUID()
let shipment: any, supplier: any
const call = async (path: string, method = 'GET', body?: unknown, role: 'admin' | 'hub' | 'public' = 'admin', key?: string) => {
  const res = await app.request(`/api${path}`, { method, headers: {
    ...(key ? {'Idempotency-Key':key} : {}),
    ...(role !== 'public' ? { Authorization: `Bearer ${role === 'admin' ? admin : hub}` } : {}),
    ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
  }, body: body === undefined ? undefined : JSON.stringify(body) })
  return { status: res.status, data: await res.json(), headers: res.headers }
}

async function issueInvoice(code='SH-AUDIT', reason='Confirmed shipment charges') {
  const inv=(await call(`/shipments/${code}/invoice`)).data.invoice,rate=inv.sourceFxRate||1;
  const response=await call(`/shipments/${code}/invoice`,'POST',{state:'issued',pricingMode:inv.pricingMode,revisionReason:reason,confirmFree:true,lines:inv.suggestedLines.map((l:any)=>({...l,amount:Math.round(l.amount/rate*100)/100})),discount:inv.discount/rate,note:inv.note,money:{currency:inv.sourceCurrency??'BDT',exchangeRate:rate}});
  expect([200,201]).toContain(response.status); return response;
}

describe.skipIf(!enabled)('agency security and money integration', () => {
  beforeAll(async () => {
    const url = new URL(process.env.DATABASE_URL!)
    if (url.pathname !== '/mamun_audit_20260905') throw new Error('Refusing fixtures outside the dedicated audit database')
    ;({ prisma, closeDb } = await import('../src/core/db'))
    const r = await import('../src/core/redis'); redis = r.redis; closeRedis = r.closeRedis
    await r.connectRedis()
    app = (await import('../src/core/http')).createApp()
    for (const [token, role] of [[admin,'admin'],[hub,'hub']]) await redis.set(`session:${token}`,JSON.stringify({id:role,name:role,role}), 'EX',3600)
  })
  afterAll(async () => { if (redis) { await redis.del(`session:${admin}`,`session:${hub}`); await closeRedis() } if(closeDb) await closeDb() })
  beforeEach(async () => {
    for (const [token, role] of [[admin,'admin'],[hub,'hub']]) {
      await prisma.user.upsert({where:{id:role},create:{id:role,email:`${role}@audit.invalid`,name:role,role,passwordHash:'audit-fixture',active:true,sessionVersion:0},update:{role,passwordHash:'audit-fixture',active:true,sessionVersion:0}})
      await redis.set(`session:${token}`,JSON.stringify({id:role,name:role,role,passwordVersion:createHash('sha256').update('audit-fixture').digest('hex')}),'EX',3600)
    }

    for (const model of ['flyerDocument','ledgerReversal','auditEvent','todo','payment','statementReceipt','statementLink','invoiceRevision','creditNote','customerRefund','customerCredit','shipmentMedia','financialRequest','publicLink','fundTransfer','receipt','receiptUpload','shipmentLog','invoice','expense','shipmentCost','shipment','flightLeg','flightFlyer','flight','flyer','supplier','account','payMethod']) await prisma[model].deleteMany()
    for (const prefix of ['rate:track:', 'rate:track-upload:', 'cache:dashboard']) {
      const keys = await redis.keys(`${prefix}*`); if(keys.length) await redis.del(...keys)
    }
    supplier = await prisma.supplier.create({data:{code:'SUP-AUDIT',name:'Private Supplier',terms:'monthly'}})
    shipment = await prisma.shipment.create({data:{code:'SH-AUDIT',supplierId:supplier.id,charge:1000,bookedKg:10,trackToken:'sh-audit-abcd'}})
    await prisma.account.createMany({data:[{name:'Cash',kind:'cash',currency:'BDT',balance:100000},{name:'Bank',kind:'bank',currency:'BDT',balance:0},{name:'Alipay',kind:'wallet',currency:'CNY',balance:0}]})
    await prisma.payMethod.create({data:{kind:'mobile_banking',provider:'Cash',number:'test-account'}})
  })
  it('blocks excess capacity on creation and serializes concurrent bookings', async () => {
    const flight = await prisma.flight.create({data:{code:'CAPACITY',date:new Date('2026-12-01'),spaceKg:10}})
    const body = {supplierCode:supplier.code,flightCode:flight.code,categories:['Clothes'],bookedKg:6}
    const over = await call('/shipments','POST',{...body,bookedKg:11})
    expect(over.status).toBe(400);expect(over.data.error).toContain('capacity')
    expect(await prisma.shipment.count({where:{flightId:flight.id}})).toBe(0)
    const results=await Promise.all([call('/shipments','POST',body),call('/shipments','POST',body)])
    expect(results.map(r=>r.status).sort()).toEqual([201,400])
    expect(Number((await prisma.shipment.aggregate({where:{flightId:flight.id},_sum:{bookedKg:true}}))._sum.bookedKg)).toBe(6)
    expect((await call('/shipments','POST',{...body,bookedKg:4})).status).toBe(201)
  })

  it('checks edits, reassignment and capacity reductions without blocking safe corrections', async () => {
    const flight=await prisma.flight.create({data:{code:'CAPACITY-EDIT',date:new Date('2026-12-01'),spaceKg:12}})
    expect((await call('/shipments/SH-AUDIT','PATCH',{flightCode:flight.code})).status).toBe(200)
    expect((await call('/shipments/SH-AUDIT','PATCH',{bookedKg:13})).status).toBe(400)
    expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).bookedKg)).toBe(10)
    expect((await call('/flights/'+flight.code,'PATCH',{spaceKg:9})).status).toBe(400)
    expect((await call('/flights/'+flight.code,'PATCH',{spaceKg:20})).status).toBe(200)
    expect((await call('/shipments/SH-AUDIT','PATCH',{bookedKg:13})).status).toBe(200)
    // A legacy overbooking can be reduced or cleared without requiring another override.
    await prisma.flight.update({where:{id:flight.id},data:{spaceKg:5}})
    expect((await call('/shipments/SH-AUDIT','PATCH',{bookedKg:12})).status).toBe(200)
    expect((await call('/shipments/SH-AUDIT','PATCH',{description:'Correction only'})).status).toBe(200)
    expect((await call('/shipments/SH-AUDIT','PATCH',{flightCode:null})).status).toBe(200)
  })

  it('applies the same capacity rule to historical flight corrections', async () => {
    const flyer=await prisma.flyer.create({data:{name:'Capacity flyer'}})
    const flight=await prisma.flight.create({data:{code:'CAPACITY-HISTORY',date:new Date('2026-12-01'),spaceKg:5,flyers:{create:{flyerId:flyer.id}}}})
    const body={flightCode:flight.code,flyerName:flyer.name,reason:'Correct mistaken assignment'}
    expect((await call('/shipments/SH-AUDIT/assignment-correction','POST',body)).status).toBe(400)
    expect((await prisma.shipment.findUnique({where:{id:shipment.id}})).flightId).toBeNull()
    expect((await call('/shipments/SH-AUDIT/assignment-correction','POST',body,'hub')).status).toBe(403)
    await prisma.flight.update({where:{id:flight.id},data:{spaceKg:10}})
    expect((await call('/shipments/SH-AUDIT/assignment-correction','POST',body)).status).toBe(200)
  })

  it('shows setup status only to admins and distinguishes defaults from a confirmed rate', async () => {
    await prisma.setting.deleteMany({where:{key:'rate'}})
    expect((await call('/settings/setup-status','GET',undefined,'public')).status).toBe(401)
    expect((await call('/settings/setup-status','GET',undefined,'hub')).status).toBe(403)
    expect((await call('/settings/setup-status')).data).toMatchObject({rateConfirmed:false,accounts:3,paymentMethods:0})
    expect((await call('/settings','PATCH',{rate:19.2})).status).toBe(200)
    expect((await call('/settings/setup-status')).data.rateConfirmed).toBe(true)
    await prisma.setting.deleteMany({where:{key:'rate'}})
  })

  it('keeps the complete active count while limiting dashboard rows to the latest eight', async () => {
    await prisma.shipment.createMany({data:Array.from({length:12},(_,i)=>({code:'COUNT-'+i,trackToken:randomUUID(),supplierId:supplier.id,createdAt:new Date(Date.UTC(2026,9,1+i))}))})
    const overview=await call('/dashboard/overview')
    expect(overview.status).toBe(200);expect(overview.data.activeShipmentCount).toBe(13)
    expect(overview.data.activeShipments).toHaveLength(8)
    expect(overview.data.activeShipments.some((s:any)=>s.code==='COUNT-0')).toBe(false)
  })

  it('prevents hub staff from changing legacy cost fields through an old endpoint', async () => {
    expect((await call('/shipments/SH-AUDIT/bd-fare','POST',{amount:200},'hub')).status).toBe(403)
    expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).bdFare)).toBe(0)
    expect((await call('/shipments/SH-AUDIT/bd-fare','POST',{amount:200})).status).toBe(200)
  })

  it('limits staff management to admins and never exposes passwords or hashes', async () => {
    for (const [method,path,body] of [
      ['GET','/settings/users',undefined],
      ['POST','/settings/users',{name:'New staff',email:'blocked@audit.invalid',role:'admin',password:'NewPass123'}],
      ['PATCH','/settings/users/admin',{name:'Changed'}],
      ['POST','/settings/users/admin/password',{password:'NewPass123'}],
    ] as const) {
      expect((await call(path,method,body,'public')).status).toBe(401)
      expect((await call(path,method,body,'hub')).status).toBe(403)
    }
    const list=await call('/settings/users')
    expect(list.status).toBe(200)
    expect(list.data.users.some((user:any)=>user.id==='admin')).toBe(true)
    for (const user of list.data.users) expect(Object.keys(user).sort()).toEqual(['active','createdAt','email','id','name','role'])
    expect((await prisma.user.findUnique({where:{id:'admin'}})).name).toBe('admin')
  })

  it('creates sign-in accounts with normalized emails and hashed passwords while rejecting duplicates', async () => {
    const email=`users-${randomUUID()}@audit.invalid`, password='New staff password 123'
    let id:string|undefined,token:string|undefined
    try {
      const created=await call('/settings/users','POST',{name:'  New staff  ',email:`  ${email.toUpperCase()}  `,role:'hub',password})
      expect(created.status).toBe(201)
      expect(created.data.user).toMatchObject({name:'New staff',email,role:'hub'})
      expect(created.data.user).not.toHaveProperty('passwordHash')
      id=created.data.user.id
      const stored=await prisma.user.findUnique({where:{id}})
      expect(stored.passwordHash).not.toBe(password)
      expect(await (await import('@node-rs/argon2')).verify(stored.passwordHash,password)).toBe(true)
      expect((await call('/settings/users','POST',{name:'Duplicate',email:email.toUpperCase(),role:'admin',password})).status).toBe(400)
      const login=await call('/auth/login','POST',{email,password},'public')
      expect(login.status).toBe(200);token=login.data.token
      expect(login.data.user.role).toBe('hub')
      expect((await app.request('/api/settings/users',{headers:{Authorization:`Bearer ${token}`}})).status).toBe(403)
      expect(await prisma.user.count({where:{email}})).toBe(1)
    } finally { if(token)await redis.del(`session:${token}`);if(id)await prisma.user.delete({where:{id}}) }
  })

  it('validates staff fields and prevents self-demotion without changing the existing account', async () => {
    const email=`invalid-${randomUUID()}@audit.invalid`, valid={name:'Staff',email,role:'hub',password:'ValidPass123'}
    for(const change of [{name:'   '},{email:'invalid'},{role:'owner'},{password:'short'},{password:'x'.repeat(129)},{passwordHash:'supplied-hash'}])
      expect((await call('/settings/users','POST',{...valid,...change})).status).toBe(400)
    expect(await prisma.user.count({where:{email}})).toBe(0)
    expect((await call('/settings/users/admin','PATCH',{role:'hub'})).status).toBe(400)
    expect((await call('/settings/users/admin','PATCH',{email:'HUB@AUDIT.INVALID'})).status).toBe(400)
    expect((await call('/settings/users/admin','PATCH',{})).status).toBe(400)
    expect((await call('/settings/users/missing-user','PATCH',{name:'Test'})).status).toBe(404)
    expect((await call('/settings/users/missing-user/password','POST',{password:'ValidPass123'})).status).toBe(404)
    expect((await prisma.user.findUnique({where:{id:'admin'}})).role).toBe('admin')
  })

  it('edits staff profiles and roles, resets passwords and invalidates existing sessions', async () => {
    const email=`edit-${randomUUID()}@audit.invalid`, nextEmail=`updated-${randomUUID()}@audit.invalid`, oldPassword='OldPassword123', newPassword='NewPassword456'
    let id:string|undefined;const tokens:string[]=[]
    try {
      const created=await call('/settings/users','POST',{name:'Staff',email,role:'hub',password:oldPassword});id=created.data.user.id
      const login=await call('/auth/login','POST',{email,password:oldPassword},'public');tokens.push(login.data.token)
      const edited=await call(`/settings/users/${id}`,'PATCH',{name:'Updated staff',email:nextEmail.toUpperCase(),role:'admin'})
      expect(edited.status).toBe(200);expect(edited.data.user).toMatchObject({name:'Updated staff',email:nextEmail,role:'admin'})
      expect(edited.data.user).not.toHaveProperty('passwordHash')
      expect((await app.request('/api/me',{headers:{Authorization:`Bearer ${tokens[0]}`}})).status).toBe(401)
      expect((await call('/auth/login','POST',{email,password:oldPassword},'public')).status).toBe(401)
      const again=await call('/auth/login','POST',{email:nextEmail,password:oldPassword},'public');expect(again.status).toBe(200);tokens.push(again.data.token)
      expect((await call(`/settings/users/${id}/password`,'POST',{password:newPassword})).status).toBe(200)
      expect((await app.request('/api/me',{headers:{Authorization:`Bearer ${tokens[1]}`}})).status).toBe(401)
      expect((await call('/auth/login','POST',{email:nextEmail,password:oldPassword},'public')).status).toBe(401)
      const finalLogin=await call('/auth/login','POST',{email:nextEmail,password:newPassword},'public');expect(finalLogin.status).toBe(200);tokens.push(finalLogin.data.token)
      expect((await app.request('/api/settings/users',{headers:{Authorization:`Bearer ${finalLogin.data.token}`}})).status).toBe(200)
    } finally { for(const token of tokens)await redis.del(`session:${token}`);if(id)await prisma.user.delete({where:{id}}) }
  })

  it('requires the current password to change your own password and then revokes your session', async () => {
    const email=`self-${randomUUID()}@audit.invalid`, oldPassword='CurrentPass123', newPassword='ChangedPass456'
    let id:string|undefined,token:string|undefined
    try {
      const created=await call('/settings/users','POST',{name:'Admin test',email,role:'admin',password:oldPassword});id=created.data.user.id
      const login=await call('/auth/login','POST',{email,password:oldPassword},'public');token=login.data.token
      const change=(body:unknown)=>app.request(`/api/settings/users/${id}/password`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify(body)})
      expect((await change({password:newPassword})).status).toBe(400)
      expect((await change({password:newPassword,currentPassword:'wrong'})).status).toBe(400)
      expect((await change({password:newPassword,currentPassword:oldPassword})).status).toBe(200)
      expect((await app.request('/api/me',{headers:{Authorization:`Bearer ${token}`}})).status).toBe(401)
    } finally {if(token)await redis.del(`session:${token}`);if(id)await prisma.user.delete({where:{id}})}
  })

  it('presents legacy and new costs once, preserves CNY, and settles existing costs without rebilling', async () => {
    await prisma.shipment.update({where:{id:shipment.id},data:{cnFare:200,bdFare:300,customsTax:100,chargeCurrency:'CNY',pricingRates:{BDT:1,CNY:20},costSources:{cnFare:{sourceCurrency:'CNY',sourceAmount:10,sourceFxRate:20}}}})
    await prisma.account.updateMany({where:{name:'Alipay'},data:{balance:100}})
    const settle={category:'transport',costField:'cnFare',amount:50,reason:'Part payment',accountName:'Cash'}
    const key=randomUUID()
    expect((await call('/shipments/SH-AUDIT/expenses','POST',settle,'admin',key)).status).toBe(200)
    expect((await call('/shipments/SH-AUDIT/expenses','POST',settle,'admin',key)).status).toBe(200)
    expect(await prisma.invoice.count()).toBe(0)
    const added=await call('/shipments/SH-AUDIT/expenses','POST',{category:'courier',reason:'Private courier reference',label:'Dhaka courier',amount:10,accountName:'Alipay',money:{currency:'CNY',exchangeRate:20}})
    expect(added.status).toBe(200)
    const detail=(await call('/shipments/SH-AUDIT')).data.shipment
    expect(detail.costs.total).toBe(800)
    expect(detail.costs.items).toHaveLength(4)
    const old=detail.costs.items.find((item:any)=>item.costField==='cnFare')
    expect(old).toMatchObject({name:'China transport',amount:200,paidAmount:50,dueAmount:150,sourceCurrency:'CNY',sourceAmount:10,sourceFxRate:20})
    expect(old.payments).toHaveLength(1)
    expect(old.payments[0]).toMatchObject({amount:50,accountName:'Cash'})
    const addedCost=detail.costs.items.find((item:any)=>item.costField===null)
    expect(addedCost).toMatchObject({amount:200,paidAmount:200,dueAmount:0,sourceCurrency:'CNY',sourceAmount:10,sourceFxRate:20})
    expect(addedCost.payments[0]).toMatchObject({accountName:'Alipay',sourceCurrency:'CNY',sourceAmount:10,accountCurrency:'CNY',accountAmount:10})
    const invoice=(await call('/shipments/SH-AUDIT/invoice')).data.invoice
    expect(invoice).toMatchObject({total:1300,sourceCurrency:'CNY',sourceAmount:65,sourceFxRate:20})
    expect(invoice.lines.at(-1)).toMatchObject({label:'Dhaka courier',amount:200})
    const link=(await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'})).data
    const publicPage=(await call(`/track/${link.token}`,'GET',undefined,'public')).data
    expect(publicPage.shipment.billLines.at(-1)).toEqual({label:'Dhaka courier',amount:200})
    expect(JSON.stringify(publicPage)).not.toContain('Private courier reference')
    const finance=(await call('/finance?period=all')).data
    expect(finance.results).toMatchObject({shipmentCosts:800,businessExpenses:0,costs:800,profit:500})
    expect(finance.costPayables).toBe(550)
    expect(detail.costs.profit).toBe(500)
    expect((await call('/shipments/SH-AUDIT/expenses','POST',{...settle,amount:150})).status).toBe(200)
    const after=(await call('/shipments/SH-AUDIT')).data.shipment
    expect(after.costs.items.find((item:any)=>item.costField==='cnFare')).toMatchObject({paidAmount:200,dueAmount:0})
    expect(after.costs.items).toHaveLength(4)
    expect(after.costs.total).toBe(800)
    expect(after.billAmount).toBe(1300)
    expect((await call('/shipments/SH-AUDIT','GET',undefined,'hub')).data.shipment.costs).toBeNull()
    await call('/finance/expenses','POST',{category:'salary',amount:125,reason:'Business salary',accountName:'Cash'})
    const grouped=(await call('/finance?period=all')).data.results
    expect(grouped).toMatchObject({shipmentCosts:800,businessExpenses:125,costs:925,profit:375})
    expect(grouped.shipmentCosts+grouped.businessExpenses+grouped.tickets).toBe(grouped.costs)
  })

  it('returns a small admin account directory and rejects invalid cost names atomically', async () => {
    expect((await call('/finance/accounts','GET',undefined,'public')).status).toBe(401)
    expect((await call('/finance/accounts','GET',undefined,'hub')).status).toBe(403)
    const directory=(await call('/finance/accounts')).data
    expect(Object.keys(directory)).toEqual(['accounts'])
    expect(directory.accounts).toHaveLength(3)
    expect(directory.accounts.find((a:any)=>a.name==='Cash')).toEqual({name:'Cash',currency:'BDT',balance:100000})
    expect(directory.accounts.find((a:any)=>a.name==='Alipay').currency).toBe('CNY')
    const body={category:'others',amount:10,reason:'Cost',accountName:'Cash'}
    expect((await call('/shipments/SH-AUDIT/expenses','POST',{...body,label:'   '})).status).toBe(400)
    expect((await call('/shipments/SH-AUDIT/expenses','POST',{...body,label:'x'.repeat(121)})).status).toBe(400)
    expect((await call('/shipments/SH-AUDIT/expenses','POST',{...body,reason:'   '})).status).toBe(400)
    expect(await prisma.expense.count()).toBe(0)
    expect(await prisma.invoice.count()).toBe(0)
    expect(Number((await prisma.account.findFirst({where:{name:'Cash'}})).balance)).toBe(100000)
  })

  it('shares tracking without financial access unless invoice inclusion is selected', async () => {
    const tracking = await call('/shipments/SH-AUDIT/track-link', 'POST', {scope:'tracking_only', days:7})
    expect(tracking.status).toBe(201)
    expect(await prisma.invoice.count()).toBe(0)
    const path = `/track/${tracking.data.token}`
    const assertTrackingOnly = async () => {
      const publicPage = await call(path, 'GET', undefined, 'public')
      expect(publicPage.status).toBe(200)
      expect(publicPage.data.shipment).toMatchObject({code:'SH-AUDIT',includesInvoice:false,statusLabel:'Pending'})
      for (const field of ['invoice','invoiceNumber','due','totalBill','billLines','billSubtotal','paidSoFar','discount','requestedAmount','payMethods','exchangeRates','showPay','showPaid','showPending'])
        expect(publicPage.data.shipment).not.toHaveProperty(field)
      expect((await app.request(`/api${path}/invoice.pdf`)).status).toBe(404)
      expect((await call(`${path}/receipt-image/upload`, 'POST', {name:'proof.png',contentType:'image/png',size:100}, 'public')).status).toBe(404)
      expect((await call(`${path}/receipt`, 'POST', {methodId:'cash',amount:100,txnRef:'TRACKING-ONLY'}, 'public')).status).toBe(404)
      expect(await prisma.receiptUpload.count()).toBe(0)
      expect(await prisma.receipt.count()).toBe(0)
      expect(await prisma.payment.count()).toBe(0)
    }
    await assertTrackingOnly()
    const history = (await call('/shipments/SH-AUDIT/track-links')).data.links
    expect(history[0]).toMatchObject({url:tracking.data.url,includesInvoice:false})
    expect((await call('/shipments/SH-AUDIT/track-links')).data.links[0].url).toBe(tracking.data.url)
    const included = await call('/shipments/SH-AUDIT/track-link', 'POST', {scope:'invoice',days:7})
    expect(included.status).toBe(201)
    expect(await prisma.invoice.count()).toBe(1)
    const withInvoice = (await call(`/track/${included.data.token}`, 'GET', undefined, 'public')).data.shipment
    expect(withInvoice).toMatchObject({includesInvoice:true,totalBill:1000,due:1000,showPay:true,pricingState:'issued'});expect((await app.request(`/api/track/${included.data.token}/invoice.pdf`)).status).toBe(200);await issueInvoice()
    expect(withInvoice.invoice).not.toBeNull()
    expect(withInvoice.billLines.length).toBeGreaterThan(0)
    expect(withInvoice.payMethods).toHaveLength(1)
    expect((await app.request(`/api/track/${included.data.token}/invoice.pdf`)).status).toBe(200)
    const saved = (await call('/shipments/SH-AUDIT/track-links')).data.links
    expect(saved).toHaveLength(2)
    expect(saved.find((row:any)=>row.url===included.data.url).includesInvoice).toBe(true)
    // Creating an invoice must never broaden access through an existing tracking-only link.
    await assertTrackingOnly()
    const legacy = (await call('/shipments/SH-AUDIT/track-link', 'POST', {scope:'tracking'})).data
    expect((await call(`/track/${legacy.token}`, 'GET', undefined, 'public')).data.shipment.includesInvoice).toBe(true)
    expect(await prisma.invoice.count()).toBe(1)
  })

  it('persists share URLs and uses one itemized invoice balance across admin, tracking and statements', async () => {
    await prisma.shipment.update({where:{id:shipment.id},data:{charge:5000,bookedKg:2,chargeRate:1500,chargeCurrency:'BDT',pricingRates:{BDT:1,CNY:20},customsTax:100,afterSalesFee:50,pcsItems:[{category:'Mobile',count:2,rate:50,currency:'CNY'}]}})
    const created=await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice',days:7})
    expect(created.status).toBe(201)
    const inv=await prisma.invoice.findFirst()
    expect(Number(inv.total)).toBe(5050)
    expect(inv.lines).toHaveLength(3);expect(inv.state).toBe('issued');expect(Number(inv.discount)).toBe(50)
    expect((await prisma.publicLink.findFirst()).requestedAmount).toBeNull()
    const history=(await call('/shipments/SH-AUDIT/track-links')).data.links
    expect(history[0].url).toBe(created.data.url)
    expect(history[0].status).toBe('active')
    expect((await call('/shipments/SH-AUDIT/track-links','GET',undefined,'hub')).status).toBe(403)
    expect((await call('/shipments/SH-AUDIT/track-links','GET',undefined,'public')).status).toBe(401)
    expect((await call('/shipments/SH-AUDIT/track-links')).data.links[0].url).toBe(created.data.url)
    await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'})
    expect(await prisma.invoice.count()).toBe(1)
    expect((await call('/shipments/SH-AUDIT/track-links')).data.links).toHaveLength(2)
    await call('/shipments/SH-AUDIT/expenses','POST',{category:'courier',amount:50,reason:'Internal courier notes',accountName:'Cash'})
    await issueInvoice()
    await call('/shipments/SH-AUDIT/payments','POST',{amount:100,method:'Cash'})
    const adminInvoice=(await call('/shipments/SH-AUDIT/invoice')).data.invoice
    const publicInvoice=(await call(`/track/${created.data.token}`,'GET',undefined,'public')).data.shipment
    expect(adminInvoice.total).toBe(5100);expect(adminInvoice.paidAmount).toBe(100);expect(adminInvoice.dueAmount).toBe(5000)
    expect(publicInvoice.billLines).toEqual(adminInvoice.lines.map(({label,amount}:any)=>({label,amount})))
    expect(publicInvoice.invoice.lines).toEqual(adminInvoice.lines.map(({label,amount}:any)=>({label,amount})))
    expect(publicInvoice.requestedAmount).toBe(publicInvoice.due)
    expect(publicInvoice.due).toBe(5000)
    expect(JSON.stringify(publicInvoice)).not.toContain('Internal courier notes')
    const month=new Date().toISOString().slice(0,7)
    const statement=await call('/suppliers/SUP-AUDIT/statement-link','POST',{month})
    const statementHistory=(await call(`/suppliers/SUP-AUDIT/statement-links?month=${month}`)).data
    expect(statementHistory.links[0].url).toBe(statement.data.url)
    expect(statementHistory.balance).toEqual({billed:5100,paid:100,due:5000})
    await call('/shipments/SH-AUDIT/track-link','DELETE')
    const revoked=(await call('/shipments/SH-AUDIT/track-links')).data.links
    expect(revoked).toHaveLength(2);expect(revoked.every((row:any)=>row.status==='revoked'&&row.url)).toBe(true)
    expect((await call(`/track/${created.data.token}`,'GET',undefined,'public')).status).toBe(404)
  })

  it('rolls back invoice creation when a share link cannot be saved',async()=>{
    const key=process.env.LINK_ENCRYPTION_KEY
    try {
      delete process.env.LINK_ENCRYPTION_KEY
      expect((await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'})).status).toBe(503)
      expect(await prisma.invoice.count()).toBe(0)
      expect(await prisma.publicLink.count()).toBe(0)
    } finally {process.env.LINK_ENCRYPTION_KEY=key}
  })

  it('accepts private screenshots for shipment and statement receipts, with scoped access and no automatic credit', async () => {
    await issueInvoice()
    const storage = await import('../src/shared/r2')
    const upload = vi.spyOn(storage, 'signUpload').mockResolvedValue('https://storage.invalid/upload')
    const finalize = vi.spyOn(storage, 'finalizeUpload').mockImplementation(async (row: { size: number; contentType: string }) => ({ size: row.size, contentType: row.contentType }))
    const download = vi.spyOn(storage, 'signDownload').mockResolvedValue('https://storage.invalid/preview')
    try {
      const link = (await call('/shipments/SH-AUDIT/track-link', 'POST', {scope:'invoice'})).data
      const other = (await call('/shipments/SH-AUDIT/track-link', 'POST', {scope:'invoice'})).data
      const methodId = (await call(`/track/${link.token}`, 'GET', undefined, 'public')).data.shipment.payMethods[0].id
      const meta = { name: 'payment.png', contentType: 'image/png', size: 1234 }
      const reserved = await call(`/track/${link.token}/receipt-image/upload`, 'POST', meta, 'public')
      expect(reserved.status).toBe(201)
      const imageReference = reserved.data.reference
      const body = { methodId, amount: 200, txnRef: 'SCREENSHOT-SHIPMENT', imageReference }
      expect((await call(`/track/${other.token}/receipt`, 'POST', body, 'public')).status).toBe(400)
      expect(finalize).not.toHaveBeenCalled()
      expect((await call(`/track/${link.token}/receipt`, 'POST', body, 'public')).status).toBe(201)
      expect((await prisma.receipt.findFirst()).screenshotReference).toBe(imageReference)
      expect(Number((await prisma.shipment.findUnique({ where: { id: shipment.id } })).paidAmount)).toBe(0)
      const queue = (await call('/review')).data.queue
      expect(queue[0].screenshot).toEqual({ ...meta, reference: imageReference })
      expect(JSON.stringify(queue)).not.toMatch(/stagingKey|objectKey|linkHash/)
      const preview = `/review/screenshots/${imageReference}/url`
      expect((await call(preview, 'GET', undefined, 'public')).status).toBe(401)
      expect((await call(preview, 'GET', undefined, 'hub')).status).toBe(403)
      expect((await call(preview)).data.url).toBe('https://storage.invalid/preview')
      expect((await call('/shipments/SH-AUDIT')).data.shipment.receipt.screenshot.reference).toBe(imageReference)
      expect((await call('/shipments/SH-AUDIT', 'GET', undefined, 'hub')).data.shipment.receipt).toBeNull()
      expect((await call(`/track/${link.token}/receipt`, 'POST', body, 'public')).status).toBe(400)
      await call('/shipments/SH-AUDIT/receipt/reject', 'POST', {})
      const month = new Date().toISOString().slice(0, 7)
      const statement = (await call('/suppliers/SUP-AUDIT/statement-link', 'POST', { month })).data
      expect((await call(`/statements/${statement.token}/receipt`, 'POST', { ...body, txnRef: 'WRONG-KIND' }, 'public')).status).toBe(400)
      const statementImage = await call(`/statements/${statement.token}/receipt-image/upload`, 'POST', meta, 'public')
      expect(statementImage.status).toBe(201)
      expect((await call(`/statements/${statement.token}/receipt`, 'POST', { ...body, txnRef: 'SCREENSHOT-STATEMENT', imageReference: statementImage.data.reference }, 'public')).status).toBe(201)
      const receipt = await prisma.statementReceipt.findFirst()
      expect((await call('/review')).data.statements[0].screenshot.reference).toBe(statementImage.data.reference)
      expect((await call(`/suppliers/SUP-AUDIT/statement-receipts/${receipt.reference}/approve`, 'POST', {})).status).toBe(200)
      expect(Number((await prisma.shipment.findUnique({ where: { id: shipment.id } })).paidAmount)).toBe(200)
      expect((await call('/suppliers/SUP-AUDIT/statement-receipts')).data.receipts[0].screenshot.reference).toBe(statementImage.data.reference)
    } finally { upload.mockRestore(); finalize.mockRestore(); download.mockRestore() }
  })

  it('rolls screenshot attachment back when storage verification or receipt validation fails', async () => {
    await issueInvoice()
    const storage = await import('../src/shared/r2')
    const { badRequest } = await import('../src/core/errors')
    const upload = vi.spyOn(storage, 'signUpload').mockResolvedValue('https://storage.invalid/upload')
    const finalize = vi.spyOn(storage, 'finalizeUpload').mockRejectedValueOnce(badRequest('File contents invalid'))
    try {
      const link = (await call('/shipments/SH-AUDIT/track-link', 'POST', {scope:'invoice'})).data
      const methodId = (await call(`/track/${link.token}`, 'GET', undefined, 'public')).data.shipment.payMethods[0].id
      const reserved = (await call(`/track/${link.token}/receipt-image/upload`, 'POST', { name: 'x.png', contentType: 'image/png', size: 100 }, 'public')).data
      const body = { methodId, amount: 100, txnRef: 'ROLLBACK-PROOF', imageReference: reserved.reference }
      expect((await call(`/track/${link.token}/receipt`, 'POST', body, 'public')).status).toBe(400)
      expect((await prisma.receiptUpload.findUnique({ where: { reference: reserved.reference } })).status).toBe('pending')
      expect(await prisma.receipt.count()).toBe(0)
      expect((await call(`/review/screenshots/${reserved.reference}/url`)).status).toBe(404)
      finalize.mockImplementation(async (row: { size: number; contentType: string }) => ({ size: row.size, contentType: row.contentType }))
      await prisma.receipt.create({ data: { shipmentId: shipment.id, method: 'Cash', amount: 1, txnRef: 'ALREADY-PENDING' } })
      expect((await call(`/track/${link.token}/receipt`, 'POST', body, 'public')).status).toBe(400)
      expect(finalize).toHaveBeenCalledTimes(2)
      expect((await prisma.receiptUpload.findUnique({ where: { reference: reserved.reference } })).status).toBe('pending')
      expect((await prisma.receipt.findFirst()).screenshotReference).toBeNull()
      await call('/shipments/SH-AUDIT/track-link', 'DELETE')
      expect((await call(`/track/${link.token}/receipt-image/upload`, 'POST', { name: 'x.png', contentType: 'image/png', size: 100 }, 'public')).status).toBe(404)
    } finally { upload.mockRestore(); finalize.mockRestore() }
  })

  it('includes shipment billing and flyer contribution in flight profit, independent of collection', async () => {
    const flight = await prisma.flight.create({data:{code:'PROFIT-TEST',date:new Date('2026-09-10'),actualCost:55000,agencyShare:50000,fare:5000}})
    await prisma.shipment.update({where:{id:shipment.id},data:{flightId:flight.id,charge:67000}})
    const detail = (await call('/flights/PROFIT-TEST')).data.flight
    expect(detail.revenue).toBe(67000)
    expect(detail.margin).toBe(17000)
    expect(detail.ticketPaid).toBe(0)
    expect((await call('/flights')).data.flights.find((f:any)=>f.code===flight.code).margin).toBe(17000)
    await prisma.invoice.create({data:{number:'INV-PROFIT',shipmentId:shipment.id,supplierId:supplier.id,total:65000,discount:2000}})
    expect((await call('/flights/PROFIT-TEST')).data.flight.margin).toBe(15000)
    await prisma.shipment.update({where:{id:shipment.id},data:{flightId:null}})
    expect((await call('/flights/PROFIT-TEST')).data.flight.margin).toBe(-50000)
  })

  it('deducts costs of all onboard shipments once, including unpaid costs and standalone expenses', async () => {
    const flight = await prisma.flight.create({data:{code:'COST-TEST',date:new Date('2026-09-10'),actualCost:55000,agencyShare:50000,fare:5000}})
    await prisma.shipment.update({where:{id:shipment.id},data:{flightId:flight.id,charge:66000,cnFare:1000,bdFare:500,customsTax:1000}})
    const second = await prisma.shipment.create({data:{code:'SH-COST2',trackToken:'audit-cost-2',supplierId:supplier.id,flightId:flight.id,charge:0,bdFare:200}})
    await prisma.expense.createMany({data:[
      {date:new Date(),shipmentId:shipment.id,category:'courier',amount:300,reason:'Extra delivery'},
      {date:new Date(),shipmentId:shipment.id,category:'packaging',amount:400,reason:'Packing'},
      {date:new Date(),shipmentId:shipment.id,category:'transport',amount:600,costField:'cnFare',reason:'Partial carrier payment'},
    ]})
    let detail = (await call('/flights/COST-TEST')).data.flight
    expect(detail.revenue).toBe(67000)
    expect(detail.shipmentCosts).toEqual({cnTransport:1000,courier:1000,customs:1000,other:400})
    expect(detail.totalShipmentCosts).toBe(3400)
    expect(detail.margin).toBe(13600)
    expect(detail.profitBreakdown).toMatchObject({shipmentCharges:66000,flightCosts:0,otherCosts:2400,profit:13600})
    await prisma.expense.create({data:{date:new Date(),shipmentId:shipment.id,category:'courier',amount:500,costField:'bdFare',reason:'Settle courier'}})
    expect((await call('/flights/COST-TEST')).data.flight.margin).toBe(13600)
    await prisma.shipment.update({where:{id:second.id},data:{flightId:null}})
    detail = (await call('/flights/COST-TEST')).data.flight
    expect(detail.totalShipmentCosts).toBe(3200)
    expect(detail.margin).toBe(13800)
  })

  it('synchronizes dashboard and finance net profit after salary, rent and all shipment costs, excluding capital', async () => {
    const flight=await prisma.flight.create({data:{code:'SYNC-TEST',date:new Date(),actualCost:55000,agencyShare:50000,fare:5000}})
    await prisma.shipment.update({where:{id:shipment.id},data:{flightId:flight.id,charge:67000,cnFare:500,bdFare:1000}})
    expect((await call('/finance/incomes','POST',{amount:100000,method:'Cash',note:'Owner deposit',kind:'capital'})).status).toBe(201)
    expect((await call('/finance/incomes','POST',{amount:2000,method:'Cash',note:'Service income',kind:'income'})).status).toBe(201)
    for (const [category,amount,reason] of [['salary',10000,'Staff salary'],['others',3000,'Office rent']] as const) {
      expect((await call('/finance/expenses','POST',{category,amount,reason,accountName:'Cash'})).status).toBe(201)
    }
    expect((await call('/shipments/SH-AUDIT/expenses','POST',{category:'packaging',amount:500,reason:'Packing',accountName:'Cash'})).status).toBe(200)
    await issueInvoice()
    let finance=(await call('/finance?period=week')).data
    let dashboard=(await call('/dashboard/overview')).data
    expect(finance.results.profit).toBe(4500)
    expect((await call('/flights/SYNC-TEST')).data.flight.margin).toBe(15500)
    expect(dashboard.profit).toBe(finance.results.profit)
    expect(dashboard.capitalReceived).toBe(100000)
    expect(dashboard.unpaid).toBe(67500)
    expect(dashboard.payables).toBe(56500)
    expect(dashboard.flyerReceivables).toBe(5000)
    expect(dashboard.cash).toEqual(finance.cash)
    expect(dashboard.net).toBe(finance.net)
    expect((await call('/shipments/SH-AUDIT/expenses','POST',{category:'courier',costField:'bdFare',amount:1000,reason:'Settle booked courier cost',accountName:'Cash'})).status).toBe(200)
    finance=(await call('/finance?period=week')).data
    dashboard=(await call('/dashboard/overview')).data
    expect(dashboard.profit).toBe(4500)
    expect(dashboard.net).toBe(finance.net)
    expect(dashboard.payables).toBe(55500)
    expect((await call('/finance/transfers','POST',{from:'Cash',to:'Bank',amount:2000,note:'Move reserves',reference:randomUUID()})).status).toBe(201)
    const transferred=(await call('/dashboard/overview')).data
    expect(transferred.cash).toEqual(dashboard.cash)
    expect(transferred.profit).toBe(dashboard.profit)
    expect(transferred.net).toBe(dashboard.net)
  })

  it('adds shipment expenses to the bill once and exposes a private-safe tracking breakdown with discounts and partial requests', async () => {
    await call('/shipments/SH-AUDIT/invoice','POST',{lines:[{label:'Freight',amount:1000}],discount:100})
    await call('/shipments/SH-AUDIT/payments','POST',{amount:400,method:'Cash'})
    const link=await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice',amount:200})
    const key=randomUUID(), expense={category:'courier',amount:200,reason:'Private carrier account notes',accountName:'Cash'}
    expect((await call('/shipments/SH-AUDIT/expenses','POST',expense,'admin',key)).status).toBe(200)
    expect((await call('/shipments/SH-AUDIT/expenses','POST',expense,'admin',key)).status).toBe(200)
    expect(await prisma.expense.count()).toBe(1)
    expect((await call('/shipments/SH-AUDIT/invoice')).data.invoice).toMatchObject({total:900,needsReview:true});await issueInvoice()
    const track=(await call(`/track/${link.data.token}`,'GET',undefined,'public')).data.shipment
    expect(track.totalBill).toBe(1100)
    expect(track.paidSoFar).toBe(400)
    expect(track.due).toBe(700)
    expect(track.requestedAmount).toBe(200)
    expect(track.billLines).toEqual([{label:'Freight',amount:1000},{label:'Courier charge',amount:200}])
    expect(track.billSubtotal-track.discount).toBe(track.totalBill)
    expect(JSON.stringify(track)).not.toContain('Private carrier')
    expect(JSON.stringify(track)).not.toContain(shipment.id)
    const finance=(await call('/finance?period=all')).data
    expect(finance.results.billing).toBe(1100)
    expect(finance.results.profit).toBe(900)
    expect(finance.receivables.total).toBe(700)
    expect((await call('/shipments/SH-AUDIT/invoice-history')).data.revisions).toHaveLength(2)
    expect((await call('/finance/expenses','POST',{shipmentCode:'SH-AUDIT',category:'packaging',amount:50,reason:'Packing',accountName:'Cash'})).status).toBe(201)
    expect((await call('/shipments/SH-AUDIT/invoice')).data.invoice.needsReview).toBe(true);await issueInvoice();expect((await call('/shipments/SH-AUDIT/invoice')).data.invoice.total).toBe(1150)
  })
  it('rolls back both bill and expense on insufficient funds and does not rebill cost settlements', async () => {
    await prisma.shipment.update({where:{id:shipment.id},data:{bdFare:100}})
    const bad=await call('/shipments/SH-AUDIT/expenses','POST',{category:'courier',amount:200000,reason:'Too much',accountName:'Cash'})
    expect(bad.status).toBe(400)
    expect(await prisma.invoice.count()).toBe(0)
    expect(await prisma.expense.count()).toBe(0)
    await call('/shipments/SH-AUDIT/expenses','POST',{category:'courier',costField:'bdFare',amount:100,reason:'Settle booked cost',accountName:'Cash'})
    expect(await prisma.invoice.count()).toBe(0)
    await call('/shipments/SH-AUDIT/expenses','POST',{category:'packaging',amount:50,reason:'Extra packing',accountName:'Cash'})
    const invoice=(await call('/shipments/SH-AUDIT/invoice')).data.invoice
    expect(invoice.total).toBe(1050)
    expect(invoice.lines.map(({label,amount}:any)=>({label,amount}))).toEqual([{label:'Shipment charges',amount:1000},{label:'Packaging charge',amount:50}])
  })

  it('serves real PDFs only through valid public links or admin access, retaining flight date without its booking suffix', async () => {
    const flight=await prisma.flight.create({data:{code:'MU5850+MU2035-20260905-e037bf',date:new Date('2026-09-05')}})
    await prisma.shipment.update({where:{id:shipment.id},data:{flightId:flight.id}})
    await call('/shipments/SH-AUDIT/invoice','POST',{lines:[{label:'প্যাকেজিং / Packaging',amount:1000}],discount:100})
    const link=await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'})
    const pdf=await app.request(`/api/track/${link.data.token}/invoice.pdf`)
    expect(pdf.status).toBe(200)
    expect(pdf.headers.get('content-type')).toBe('application/pdf')
    expect(pdf.headers.get('cache-control')).toBe('no-store')
    const bytes=Buffer.from(await pdf.arrayBuffer())
    expect(bytes.subarray(0,5).toString()).toBe('%PDF-')
    expect(bytes.length).toBeGreaterThan(3000)
    expect((await app.request('/api/shipments/SH-AUDIT/invoice.pdf',{headers:{Authorization:`Bearer ${hub}`}})).status).toBe(403)
    expect((await app.request('/api/shipments/SH-AUDIT/invoice.pdf',{headers:{Authorization:`Bearer ${admin}`}})).status).toBe(200)
    const {cleanFlightCode}=await import('../src/shared/invoicePdf')
    expect(cleanFlightCode(flight.code)).toBe('MU5850-MU2035')
    await prisma.publicLink.updateMany({data:{expiresAt:new Date(Date.now()-1000)}})
    expect((await app.request(`/api/track/${link.data.token}/invoice.pdf`)).status).toBe(404)
    const fresh=await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'})
    await prisma.publicLink.updateMany({data:{revokedAt:new Date()}})
    expect((await app.request(`/api/track/${fresh.data.token}/invoice.pdf`)).status).toBe(404)
    expect((await app.request(`/api/track/${'a'.repeat(43)}/invoice.pdf`)).status).toBe(404)
  })

  it('rejects old/guessed tokens and requires admin for link issuance', async () => {
    expect((await call('/track/sh-audit-abcd','GET',undefined,'public')).status).toBe(404)
    expect((await call('/track/'+ 'a'.repeat(43),'GET',undefined,'public')).status).toBe(404)
    expect((await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'},'hub')).status).toBe(403)
    expect((await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'},'public')).status).toBe(401)
  })
  it('stores a digest and encrypted token without exposing database ids', async () => {
    const link=await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'})
    expect(link.status).toBe(201); expect(link.data.token).toHaveLength(22)
    const stored=await prisma.publicLink.findFirst()
    expect(stored.tokenHash).not.toBe(link.data.token)
    const page=await call(`/track/${link.data.token}`,'GET',undefined,'public')
    expect(page.status).toBe(200)
    expect(JSON.stringify(page.data)).not.toContain(shipment.id)
    expect(JSON.stringify(page.data)).not.toContain(supplier.id)
    expect(page.headers.get('cache-control')).toBe('no-store')
    expect(page.headers.get('referrer-policy')).toBe('no-referrer')
  })
  it('expiry and revocation block reads and payments immediately', async () => {
    const a=await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'})
    await prisma.publicLink.updateMany({data:{expiresAt:new Date(Date.now()-1000)}})
    expect((await call(`/track/${a.data.token}`,'GET',undefined,'public')).status).toBe(404)
    const b=await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'})
    await call('/shipments/SH-AUDIT/track-link','DELETE')
    expect((await call(`/track/${b.data.token}`,'GET',undefined,'public')).status).toBe(404)
    expect((await call(`/track/${b.data.token}/receipt`,'POST',{methodId:'x',amount:10,txnRef:'real-transaction'},'public')).status).toBe(404)
  })
  it('partial invoice request caps receipt amount and duplicate approval credits only once', async () => {
    expect((await call('/shipments/SH-AUDIT/invoice','POST',{lines:[{label:'Freight',amount:1000}],discount:100})).status).toBe(201)
    const link=await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice',amount:250})
    const page=await call(`/track/${link.data.token}`,'GET',undefined,'public')
    expect(page.data.shipment.invoice.total).toBe(900)
    const methodId=page.data.shipment.payMethods[0].id
    expect((await call(`/track/${link.data.token}/receipt`,'POST',{methodId,amount:251,txnRef:'TX-1'},'public')).status).toBe(400)
    expect((await call(`/track/${link.data.token}/receipt`,'POST',{methodId,amount:250,txnRef:'TX-1'},'public')).status).toBe(201)
    const approvals=await Promise.all([call('/shipments/SH-AUDIT/receipt/approve','POST',{}),call('/shipments/SH-AUDIT/receipt/approve','POST',{})])
    expect(approvals.map(x=>x.status).sort()).toEqual([200,400])
    expect(await prisma.payment.count()).toBe(1)
    expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).paidAmount)).toBe(250)
    expect(Number((await prisma.account.findFirst({where:{name:'Cash'}})).balance)).toBe(100250)
    const refreshed=await call(`/track/${link.data.token}`,'GET',undefined,'public')
    expect(refreshed.data.shipment.requestedAmount).toBe(0)
    expect(refreshed.data.shipment.due).toBe(650)
    expect(refreshed.data.shipment.showPaid).toBe(false)
  })
  it('concurrent payments cannot overpay or lose account updates', async () => {
    await issueInvoice()
    const results=await Promise.all([call('/shipments/SH-AUDIT/payments','POST',{amount:700,method:'Cash'}),call('/shipments/SH-AUDIT/payments','POST',{amount:700,method:'Cash'})])
    expect(results.map(x=>x.status).sort()).toEqual([201,400])
    expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).paidAmount)).toBe(700)
    expect(await prisma.payment.count()).toBe(1)
  })
  it('missing receiving account rolls back payment, balance, logs and approval', async () => {
    await prisma.receipt.create({data:{shipmentId:shipment.id,method:'Missing account',amount:200,txnRef:'missing-bank'}})
    expect((await call('/shipments/SH-AUDIT/receipt/approve','POST',{})).status).toBe(400)
    expect((await prisma.receipt.findFirst()).status).toBe('pending')
    expect(await prisma.payment.count()).toBe(0)
    expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).paidAmount)).toBe(0)
    expect(await prisma.shipmentLog.count()).toBe(0)
  })
  it('allocates supplier payment oldest first in one transaction', async () => {
    await issueInvoice()
    const second=await prisma.shipment.create({data:{code:'SH-AUDIT-2',supplierId:supplier.id,charge:500,trackToken:randomUUID(),createdAt:new Date(Date.now()+1000)}})
    await issueInvoice('SH-AUDIT-2')
    expect((await call('/suppliers/SUP-AUDIT/payments','POST',{amount:1200,method:'Cash'})).status).toBe(201)
    expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).paidAmount)).toBe(1000)
    expect(Number((await prisma.shipment.findUnique({where:{id:second.id}})).paidAmount)).toBe(200)
    expect(await prisma.payment.count()).toBe(2)
  })
  it('invoice edits preserve received money and recompute paid status', async () => {
    await issueInvoice()
    await call('/shipments/SH-AUDIT/payments','POST',{amount:400,method:'Cash'})
    expect((await call('/shipments/SH-AUDIT/invoice','POST',{lines:[{label:'Freight',amount:1000}],discount:1001})).status).toBe(400)
    expect((await call('/shipments/SH-AUDIT/invoice','POST',{lines:[{label:'Freight',amount:1000}],discount:600,revisionReason:'Agreed reduction'})).status).toBe(200)
    expect((await call('/shipments/SH-AUDIT')).data.shipment.payStatus).toBe('paid')
    await call('/shipments/SH-AUDIT/invoice','POST',{lines:[{label:'Freight',amount:1000}],discount:200,revisionReason:'Corrected discount'})
    expect((await call('/shipments/SH-AUDIT')).data.shipment.payStatus).toBe('partial')
  })
  it('transfers conserve funds, exclude income, reject overdraft and safely replay', async () => {
    const reference=randomUUID(), body={from:'Cash',to:'Bank',amount:500,note:'Reserve',reference}
    expect((await call('/finance/transfers','POST',body)).status).toBe(201)
    expect((await call('/finance/transfers','POST',body)).status).toBe(200)
    expect(Number((await prisma.account.findFirst({where:{name:'Bank'}})).balance)).toBe(500)
    expect((await call('/finance/transfers','POST',{...body,amount:100001,reference:randomUUID()})).status).toBe(400)
    expect(await prisma.payment.count()).toBe(0)
    const finance=await call('/finance?period=all')
    expect(finance.data.cash.bdt).toBe(100000)
    expect(finance.data.received).toBe(0)
    expect(finance.data.transfers).toHaveLength(1)
  })
  it('cross currency transfer records actual received amount', async () => {
    expect((await call('/finance/transfers','POST',{from:'Cash',to:'Alipay',amount:1705,receivedAmount:100,note:'Exchange',reference:randomUUID()})).status).toBe(201)
    expect(Number((await prisma.account.findFirst({where:{name:'Alipay'}})).balance)).toBe(100)
    expect(Number((await prisma.account.findFirst({where:{name:'Cash'}})).balance)).toBe(98295)
  })
  it('models flyer contribution and records only actual flyer receipts', async () => {
    await prisma.flyer.create({data:{name:'Audit Flyer'}})
    const f=await call('/flights','POST',{code:'CA123',date:'2026-09-10',flyerNames:['Audit Flyer'],actualCost:50000,agencyShare:30000})
    expect(f.status).toBe(201)
    const flight=await call(`/flights/${f.data.code}`)
    expect(flight.data.flight.fare).toBe(20000)
    expect(flight.data.flight.flyerDue).toBe(20000)
    expect(await prisma.payment.count()).toBe(0)
    expect((await call(`/flights/${f.data.code}/payments`,'POST',{amount:5000,method:'Cash'})).status).toBe(201)
    expect((await call(`/flights/${f.data.code}`)).data.flight.flyerDue).toBe(15000)
    expect((await call(`/flights/${f.data.code}/payments`,'POST',{amount:15001,method:'Cash'})).status).toBe(400)
    expect((await call(`/flights/${f.data.code}`,'DELETE')).status).toBe(400)
  })
  it('owner capital is cash in but never business profit', async () => {
    const before=await call('/finance?period=all')
    expect((await call('/finance/incomes','POST',{amount:10000,method:'Cash',note:'Owner investment',kind:'capital'})).status).toBe(201)
    const after=await call('/finance?period=all')
    expect(after.data.received-before.data.received).toBe(10000)
    expect(after.data.results.profit).toBe(before.data.results.profit)
    expect(after.data.capitalReceived).toBe(10000)
  })
  it('hub cannot see private supplier or admin cost logs', async () => {
    await prisma.shipmentLog.create({data:{shipmentId:shipment.id,actor:'Admin',message:'Supplier private name and costs'}})
    const page=await call('/shipments/SH-AUDIT','GET',undefined,'hub')
    expect(page.data.shipment.supplierName).toBeNull()
    expect(page.data.shipment.costs).toBeNull()
    expect(page.data.shipment.log).toEqual([])
    expect((await call('/finance?period=all','GET',undefined,'hub')).status).toBe(403)
  })
  it('accepts intake before flight assignment and enforces hub packing before dispatch', async () => {
    const created=await call('/shipments','POST',{supplierCode:supplier.code,categories:['Garments'],bookedKg:10,chargeRate:100})
    expect(created.status).toBe(201)
    const code=created.data.code
    expect((await call(`/shipments/${code}`)).data.shipment.flightCode).toBeNull()
    await call(`/shipments/${code}/advance`,'POST',{})
    await call(`/shipments/${code}/advance`,'POST',{})
    expect((await call(`/shipments/${code}/advance`,'POST',{})).status).toBe(400)
    await prisma.flyer.create({data:{name:'Carrier'}})
    const flight=await call('/flights','POST',{code:'CA999',date:'2026-12-10',flyerNames:['Carrier'],actualCost:0,agencyShare:0})
    expect((await call(`/shipments/${code}`,'PATCH',{flightCode:flight.data.code,flyerName:'Carrier'})).status).toBe(200)
    await call(`/shipments/${code}/advance`,'POST',{})
    await call(`/shipments/${code}/advance`,'POST',{})
    expect((await call(`/shipments/${code}/advance`,'POST',{},'hub')).status).toBe(200)
    expect((await call(`/shipments/${code}/pack`,'POST',{count:2},'hub')).status).toBe(400)
    expect((await call(`/shipments/${code}/weigh`,'POST',{kg:12},'hub')).status).toBe(200)
    expect((await call(`/shipments/${code}`)).data.shipment.billAmount).toBe(1200)
    expect((await call(`/shipments/${code}/pack`,'POST',{count:2},'hub')).status).toBe(200)
    expect((await call(`/shipments/${code}/last-mile`,'POST',{courier:'Pathao',ref:''},'hub')).status).toBe(400)
    expect((await call(`/shipments/${code}/last-mile`,'POST',{courier:'Pathao',ref:'REAL-123'},'hub')).status).toBe(200)
    expect((await call(`/shipments/${code}`)).data.shipment.status).toBe('ready_for_last_mile')
    expect((await call(`/shipments/${code}/dispatch`,'POST',{},'hub')).status).toBe(200)
    expect((await call(`/shipments/${code}/handover`,'POST',{recipient:'Recipient',confirmation:'Confirmed delivery'},'hub')).status).toBe(200)
    expect((await call(`/shipments/${code}`)).data.shipment.status).toBe('delivered')
  })
  it('same airline flight can be booked again with a distinct stable reference',async()=>{
    await prisma.flyer.create({data:{name:'Carrier'}})
    const body={code:'CA888',date:'2026-12-10',flyerNames:['Carrier'],actualCost:0,agencyShare:0}
    const a=await call('/flights','POST',body),b=await call('/flights','POST',body)
    expect(a.status).toBe(201);expect(b.status).toBe(201)
    expect(a.data.code).not.toBe(b.data.code)
    const updated=await call(`/flights/${a.data.code}`,'PATCH',{date:'2026-09-11'})
    expect(updated.data.code).toBe(a.data.code)
  })
  it('arbitrary credit adjusts a finalized invoice without erasing payment history',async()=>{
    await call('/shipments/SH-AUDIT/invoice','POST',{lines:[{label:'Freight',amount:1000}]})
    await call('/shipments/SH-AUDIT/payments','POST',{amount:200,method:'Cash'})
    expect((await call('/shipments/SH-AUDIT/after-sales','POST',{amount:125,reason:'Damaged packaging'})).status).toBe(200)
    const s=await call('/shipments/SH-AUDIT')
    expect(s.data.shipment.billAmount).toBe(875)
    expect(s.data.shipment.dueAmount).toBe(675)
    expect((await call('/shipments/SH-AUDIT/after-sales','POST',{amount:876,reason:'Too much'})).status).toBe(400)
    expect(await prisma.payment.count()).toBe(1)
  })
  it('fake photo and video actions no longer claim an upload succeeded',async()=>{
    expect((await call('/shipments/SH-AUDIT/photos','POST',{})).status).toBe(404)
    expect((await call('/shipments/SH-AUDIT/video','POST',{})).status).toBe(404)
    expect((await prisma.shipment.findUnique({where:{id:shipment.id}})).photosCount).toBe(0)
  })

  it('pays an expense from the chosen account and snapshots the currency conversion',async()=>{
    await prisma.account.updateMany({where:{name:'Alipay'},data:{balance:100}})
    await prisma.setting.upsert({where:{key:'rate'},update:{value:'17.05'},create:{key:'rate',value:'17.05'}})
    expect((await call('/finance/expenses','POST',{category:'packaging',amount:170.5,reason:'Supplies',accountName:'Alipay'})).status).toBe(201)
    const expense=await prisma.expense.findFirst()
    expect(expense.accountName).toBe('Alipay');expect(expense.accountCurrency).toBe('CNY')
    expect(Number(expense.accountAmount)).toBe(10)
    expect(Number((await prisma.account.findFirst({where:{name:'Alipay'}})).balance)).toBe(90)
    expect(Number((await prisma.account.findFirst({where:{name:'Cash'}})).balance)).toBe(100000)
  })
  it('insufficient expense funds roll back both expense and account change',async()=>{
    expect((await call('/finance/expenses','POST',{category:'salary',amount:10,reason:'Salary',accountName:'Bank'})).status).toBe(400)
    expect(await prisma.expense.count()).toBe(0)
    expect(Number((await prisma.account.findFirst({where:{name:'Bank'}})).balance)).toBe(0)
  })
  it('an unassigned shipment has no fabricated ticket charge and discount drives margin',async()=>{
    await call('/shipments/SH-AUDIT/invoice','POST',{lines:[{label:'Freight',amount:1000}],discount:100})
    const s=await call('/shipments/SH-AUDIT')
    expect(s.data.shipment.costs.fareShare).toBe(0)
    expect(s.data.shipment.costs.profit).toBe(900)
    expect(s.data.shipment.costs.profitPct).toBe(100)
  })

  it('settles recorded costs partially without double counting profit',async()=>{
    await call('/shipments/SH-AUDIT','PATCH',{cnFare:200})
    const before=await call('/finance?period=all')
    expect(before.data.costPayables).toBe(200)
    expect((await call('/shipments/SH-AUDIT/expenses','POST',{category:'transport',amount:75,reason:'Pay CN carrier',accountName:'Cash',costField:'cnFare'})).status).toBe(200)
    const after=await call('/finance?period=all')
    expect(after.data.results.profit).toBe(before.data.results.profit)
    expect(after.data.expenses-before.data.expenses).toBe(75)
    expect(after.data.costPayables).toBe(125)
    const ship=await call('/shipments/SH-AUDIT')
    expect(ship.data.shipment.costs.unpaidCosts.cnFare).toBe(125)
    expect(ship.data.shipment.costs.profit).toBe(800)
    expect((await call('/shipments/SH-AUDIT/expenses','POST',{category:'transport',amount:126,reason:'Overpay',costField:'cnFare'})).status).toBe(400)
    expect((await call('/shipments/SH-AUDIT','PATCH',{cnFare:50})).status).toBe(400)
  })

  it('replays a partial payment request without crediting it twice',async()=>{
    await issueInvoice()
    const key=randomUUID(),body={amount:100,method:'Cash'}
    const pair=await Promise.all([call('/shipments/SH-AUDIT/payments','POST',body,'admin',key),call('/shipments/SH-AUDIT/payments','POST',body,'admin',key)])
    expect(pair.map(r=>r.status)).toEqual([201,201])
    expect(await prisma.payment.count()).toBe(1)
    expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).paidAmount)).toBe(100)
    expect((await call('/shipments/SH-AUDIT/payments','POST',body,'admin',key)).status).toBe(201)
    expect(await prisma.payment.count()).toBe(1)
    expect((await call('/shipments/SH-AUDIT/payments','POST',{...body,amount:200},'admin',key)).status).toBe(409)
  })

  it('keeps advances as liabilities, applies credit without new cash and refunds exactly once', async()=>{
    await issueInvoice()
    const pay=await call('/suppliers/SUP-AUDIT/payments','POST',{amount:1300,method:'Cash'})
    expect(pay.status).toBe(201);expect(pay.data.creditAdded).toBe(300)
    expect(Number((await prisma.supplier.findUnique({where:{id:supplier.id}})).creditBalance)).toBe(300)
    const second=await prisma.shipment.create({data:{code:'SH-CREDIT',supplierId:supplier.id,charge:500,trackToken:randomUUID()}})
    await issueInvoice(second.code)
    expect((await call('/suppliers/SUP-AUDIT/apply-credit','POST',{shipmentCode:second.code,amount:100})).status).toBe(200)
    expect(Number((await prisma.account.findFirst({where:{name:'Cash'}})).balance)).toBe(101300)
    const key=randomUUID(),body={amount:200,accountName:'Cash',reason:'Customer requested refund'}
    expect((await call('/suppliers/SUP-AUDIT/refunds','POST',body,'admin',key)).status).toBe(201)
    expect((await call('/suppliers/SUP-AUDIT/refunds','POST',body,'admin',key)).status).toBe(201)
    expect(await prisma.customerRefund.count()).toBe(1)
    const finance=await call('/finance?period=all')
    expect(finance.data.refunded).toBe(200);expect(finance.data.customerCreditLiability).toBe(0)
    expect(finance.data.results.billing).toBe(1500);expect(finance.data.net).toBe(1100)
    const dashboard=(await call('/dashboard/overview')).data
    const weekly=(await call('/finance?period=week')).data
    expect(dashboard.refunded).toBe(200)
    expect(dashboard.net).toBe(1100)
    expect(dashboard.net).toBe(weekly.net)
    expect(dashboard.unpaid).toBe(400)
    expect(dashboard.profit).toBe(weekly.results.profit)
    expect((await call('/suppliers/SUP-AUDIT/refunds','POST',{...body,amount:1})).status).toBe(400)
  })
  it('issues credit notes on paid bills and preserves every invoice revision',async()=>{
    await call('/shipments/SH-AUDIT/invoice','POST',{lines:[{label:'Freight',amount:1000}]})
    await call('/shipments/SH-AUDIT/payments','POST',{amount:1000,method:'Cash'})
    expect((await call('/shipments/SH-AUDIT/after-sales','POST',{amount:200,reason:'Damaged parcel'})).status).toBe(200)
    const sh=await prisma.shipment.findUnique({where:{id:shipment.id},include:{invoice:true}})
    expect(Number(sh.paidAmount)).toBe(800);expect(Number(sh.invoice.total)).toBe(800)
    expect(Number((await prisma.supplier.findUnique({where:{id:supplier.id}})).creditBalance)).toBe(200)
    const history=await call('/shipments/SH-AUDIT/invoice-history')
    expect(history.data.revisions.map((r:any)=>r.snapshot.total)).toEqual([800,1000])
    expect(history.data.creditNotes[0].reason).toBe('Damaged parcel')
    expect((await call('/shipments/SH-AUDIT/invoice','POST',{lines:[{label:'Freight',amount:700}]})).status).toBe(400)
    expect((await call('/shipments/SH-AUDIT/invoice-history','GET',undefined,'hub')).status).toBe(403)
  })
  it('refund failure rolls back credit ledger and supplier liability',async()=>{
    await issueInvoice()
    await call('/suppliers/SUP-AUDIT/payments','POST',{amount:1200,method:'Cash'})
    const before=await prisma.customerCredit.count()
    expect((await call('/suppliers/SUP-AUDIT/refunds','POST',{amount:100,accountName:'Bank',reason:'Return funds'})).status).toBe(400)
    expect(await prisma.customerCredit.count()).toBe(before)
    expect(Number((await prisma.supplier.findUnique({where:{id:supplier.id}})).creditBalance)).toBe(200)
    expect(await prisma.customerRefund.count()).toBe(0)
  })
  it('scopes statement links to one supplier/month, caps partial requests and allocates approvals',async()=>{
    await issueInvoice()
    const month=new Date().toISOString().slice(0,7)
    const other=await prisma.supplier.create({data:{code:'OTHER',name:'Never public'}})
    await prisma.shipment.create({data:{code:'SH-SECRET',supplierId:other.id,charge:9999,trackToken:randomUUID()}})
    const link=await call('/suppliers/SUP-AUDIT/statement-link','POST',{month,amount:400})
    expect(link.status).toBe(201)
    const page=await call(`/statements/${link.data.token}`,'GET',undefined,'public')
    expect(page.data.statement.rows.map((s:any)=>s.code)).toEqual(['SH-AUDIT'])
    expect(JSON.stringify(page.data)).not.toContain(supplier.id)
    const methodId=page.data.statement.payMethods[0].id
    expect((await call(`/statements/${link.data.token}/receipt`,'POST',{methodId,amount:401,txnRef:'STMT-TXN'},'public')).status).toBe(400)
    expect((await call(`/statements/${link.data.token}/receipt`,'POST',{methodId,amount:400,txnRef:'STMT-TXN'},'public')).status).toBe(201)
    const receipt=await prisma.statementReceipt.findFirst()
    const path=`/suppliers/SUP-AUDIT/statement-receipts/${receipt.reference}/approve`
    expect((await call(path,'POST')).status).toBe(200)
    expect((await call(path,'POST')).status).toBe(400)
    expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).paidAmount)).toBe(400)
    const after=await call(`/statements/${link.data.token}`,'GET',undefined,'public')
    expect(after.data.statement.requested).toBe(0)
    await call('/suppliers/SUP-AUDIT/statement-link','DELETE')
    expect((await call(`/statements/${link.data.token}`,'GET',undefined,'public')).status).toBe(404)
  })
  it('keeps private media out of public listings and rejects cross-shipment media access',async()=>{
    const m=await prisma.shipmentMedia.create({data:{shipmentId:shipment.id,stagingKey:randomUUID(),objectKey:randomUUID(),name:'photo.jpg',size:20,contentType:'image/jpeg',status:'ready',expiresAt:new Date()}})
    const link=await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'})
    const base=`/track/${link.data.token}/media`
    expect((await call(base,'GET',undefined,'public')).data.media).toHaveLength(0)
    expect((await call(`${base}/${m.reference}/url`,'GET',undefined,'public')).status).toBe(404)
    expect((await call(`/shipments/SH-AUDIT/media/${m.reference}`,'PATCH',{shared:true},'hub')).status).toBe(403)
    await call(`/shipments/SH-AUDIT/media/${m.reference}`,'PATCH',{shared:true})
    const shared=await call(base,'GET',undefined,'public')
    expect(shared.data.media).toHaveLength(1);expect(JSON.stringify(shared.data)).not.toContain(m.objectKey)
    expect(JSON.stringify(shared.data)).not.toContain(m.id)
    await call(`/shipments/SH-AUDIT/media/${m.reference}`,'DELETE')
    expect((await call(base,'GET',undefined,'public')).data.media).toHaveLength(0)
    expect((await call('/shipments/SH-AUDIT/media/upload','POST',{name:'x.html',contentType:'text/html',size:50})).status).toBe(400)
    expect((await call('/shipments/SH-AUDIT/media/upload','POST',{name:'x.jpg',contentType:'image/jpeg',size:11000000})).status).toBe(400)
  })
  it('separates flyer balances and prevents charging the wrong flyer',async()=>{
    const flyers=await prisma.flyer.createManyAndReturn({data:[{name:'Flyer A'},{name:'Flyer B'}]})
    const f=await prisma.flight.create({data:{code:'AUDIT-FLYERS',date:new Date(),actualCost:50000,agencyShare:30000,fare:20000,flyers:{create:flyers.map((x:any)=>({flyerId:x.id}))}}})
    expect((await call(`/flights/${f.code}/settlements`,'POST',{allocations:[{name:'Flyer A',contribution:12000},{name:'Flyer B',contribution:8000}]})).status).toBe(200)
    expect((await call(`/flights/${f.code}/payments`,'POST',{amount:9000,method:'Cash',flyerName:'Flyer B'})).status).toBe(400)
    expect((await call(`/flights/${f.code}/payments`,'POST',{amount:5000,method:'Cash',flyerName:'Flyer A'})).status).toBe(201)
    const ff=await prisma.flightFlyer.findMany({where:{flightId:f.id},include:{flyer:true}})
    expect(Number(ff.find((x:any)=>x.flyer.name==='Flyer A').paidAmount)).toBe(5000)
    expect(Number(ff.find((x:any)=>x.flyer.name==='Flyer B').paidAmount)).toBe(0)
  })

  it('reconciliation distinguishes opening balances from missing historical postings',async()=>{
    await call('/suppliers/SUP-AUDIT/payments','POST',{amount:1200,method:'Cash'})
    const report=await call('/finance/reconciliation')
    expect(report.status).toBe(200);expect(report.data.shipmentDifferences).toEqual([])
    expect(report.data.accounts.find((a:any)=>a.name==='Cash').impliedOpeningBalance).toBe(100000)
    await prisma.payment.create({data:{date:new Date(),method:'Cash',amount:50,reference:'Legacy deposit',kind:'income'}})
    expect((await call('/finance/reconciliation')).data.missingPostings).toHaveLength(1)
    expect((await call('/finance/reconciliation','GET',undefined,'hub')).status).toBe(403)
  })

  it('unifies the cash ledger with account filtering, native currency transfers and refunds',async()=>{
    await issueInvoice()
    await call('/suppliers/SUP-AUDIT/payments','POST',{amount:1200,method:'Cash'})
    await call('/finance/incomes','POST',{amount:100,method:'Cash',note:'Working capital',kind:'capital'})
    await call('/finance/expenses','POST',{amount:30,accountName:'Cash',reason:'Office supplies',category:'others'})
    await call('/suppliers/SUP-AUDIT/refunds','POST',{amount:50,accountName:'Cash',reason:'Return advance'})
    await call('/finance/transfers','POST',{from:'Cash',to:'Alipay',amount:100,receivedAmount:5,note:'Exchange reserve',reference:randomUUID()})
    const ledger=await call('/finance/ledger?period=all')
    expect(ledger.status).toBe(200);expect(ledger.data.total).toBe(7)
    expect(ledger.data.entries.filter((e:any)=>e.type==='transfer').map((e:any)=>[e.currency,e.amount]).sort()).toEqual([['BDT',-100],['CNY',5]])
    const cash=await call('/finance/ledger?period=all&account=Cash')
    expect(cash.data.total).toBe(6);expect(cash.data.entries.every((e:any)=>e.currency==='BDT')).toBe(true)
    expect(cash.data.totals.find((t:any)=>t.currency==='BDT')).toEqual({currency:'BDT',moneyIn:1300,moneyOut:180})
    expect((await call('/finance/ledger?period=all&type=refund')).data.entries[0].amount).toBe(-50)
    expect((await call('/finance/ledger?period=all&search=office')).data.entries).toHaveLength(1)
    const first=(await call('/finance/ledger?period=all&limit=2&page=1')).data.entries
    const second=(await call('/finance/ledger?period=all&limit=2&page=2')).data.entries
    expect(new Set([...first,...second].map((x:any)=>x.key)).size).toBe(4)
    expect(JSON.stringify(ledger.data)).not.toContain(shipment.id)
    expect((await call('/finance/ledger','GET',undefined,'hub')).status).toBe(403)
    expect((await call('/finance/ledger','GET',undefined,'public')).status).toBe(401)
  })
  it('filters ledger dates and keeps unknown historical accounts unassigned',async()=>{
    await prisma.payment.create({data:{date:new Date('2020-01-02T12:00:00Z'),method:'Cash',amount:70,reference:'Historical receipt',kind:'income'}})
    expect((await call('/finance/ledger?period=2020-01&account=__unassigned')).data.total).toBe(1)
    expect((await call('/finance/ledger?period=2020-02')).data.total).toBe(0)
    expect((await call('/finance/ledger?period=2020-01&account=Cash')).data.total).toBe(0)
    expect((await call('/finance/ledger?period=2020-13')).status).toBe(400)
    expect((await call('/finance/ledger?limit=101')).status).toBe(400)
  })

  it('creates exactly one bank fund from a settings payment method and preserves its balance on edits', async () => {
    const bank={kind:'bank_account',bankName:'Example Bank',accountNumber:'001234',accountName:'Agency',branch:'Dhaka'}
    const created=await call('/settings/pay-methods','POST',bank)
    expect(created.status).toBe(201)
    const method=await prisma.payMethod.findUnique({where:{id:created.data.method.id},include:{account:true}})
    expect(method.account.kind).toBe('bank')
    expect(method.account.name).toBe('Example Bank · 001234')
    expect(Number(method.account.balance)).toBe(0)
    await prisma.account.update({where:{id:method.accountId},data:{balance:500}})
    expect((await call(`/settings/pay-methods/${method.id}`,'PATCH',{...bank,branch:'Chengdu'})).status).toBe(200)
    expect((await prisma.payMethod.findUnique({where:{id:method.id}})).accountId).toBe(method.accountId)
    expect(Number((await prisma.account.findUnique({where:{id:method.accountId}})).balance)).toBe(500)
    expect((await call('/settings/pay-methods','POST',{...bank,bankName:' example bank '})).status).toBe(400)
    expect(await prisma.account.count({where:{name:method.account.name}})).toBe(1)
    expect((await call(`/settings/pay-methods/${method.id}`,'PATCH',{enabled:false})).status).toBe(200)
    expect(Number((await prisma.account.findUnique({where:{id:method.accountId}})).balance)).toBe(500)
  })

  it('creates a linked payment method from Finance bank funds and rejects duplicate banks atomically', async () => {
    const bank={bankName:'Example Bank',accountNumber:'009876',accountName:'Agency'}
    expect((await call('/finance/accounts','POST',{name:'Dhaka collections',kind:'bank',currency:'BDT',balance:2500,bank})).status).toBe(201)
    const fund=await prisma.account.findFirst({where:{name:'Dhaka collections'},include:{paymentMethod:true}})
    expect(fund.paymentMethod.bankName).toBe(bank.bankName)
    expect(fund.paymentMethod.accountNumber).toBe(bank.accountNumber)
    expect(fund.paymentMethod.enabled).toBe(true)
    expect(Number(fund.balance)).toBe(2500)
    expect((await call('/finance/accounts','POST',{name:'Duplicate bank',kind:'bank',bank})).status).toBe(400)
    expect(await prisma.account.count({where:{name:'Duplicate bank'}})).toBe(0)
    expect((await call('/settings/pay-methods','POST',{kind:'bank_account',...bank})).status).toBe(400)
    expect((await call('/finance/accounts','POST',{name:'Incomplete bank',kind:'bank'})).status).toBe(400)
    expect(await prisma.account.count({where:{name:'Incomplete bank'}})).toBe(0)
  })

  it('credits the selected linked bank fund when two payment methods use the same bank', async () => {
    await issueInvoice()
    for(const [name,accountNumber] of [['Bank fund A','111'],['Bank fund B','222']]) {
      expect((await call('/finance/accounts','POST',{name,kind:'bank',bank:{bankName:'Same Bank',accountNumber,accountName:'Agency'}})).status).toBe(201)
    }
    const link=await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'})
    const page=await call(`/track/${link.data.token}`,'GET',undefined,'public')
    const method=page.data.shipment.payMethods.find((m:any)=>m.accountNumber==='222')
    expect(JSON.stringify(page.data)).not.toContain('accountId')
    expect((await call(`/track/${link.data.token}/receipt`,'POST',{methodId:method.id,amount:200,txnRef:'bank-fund-routing'},'public')).status).toBe(201)
    expect((await call('/shipments/SH-AUDIT/receipt/approve','POST',{})).status).toBe(200)
    expect(Number((await prisma.account.findFirst({where:{name:'Bank fund A'}})).balance)).toBe(0)
    expect(Number((await prisma.account.findFirst({where:{name:'Bank fund B'}})).balance)).toBe(200)
    expect((await prisma.payment.findFirst()).accountName).toBe('Bank fund B')
  })

  it('keeps ordinary reserves separate from bank payment instructions and restricts bank creation to admin', async () => {
    expect((await call('/finance/accounts','POST',{name:'Emergency reserve',kind:'fund',balance:100})).status).toBe(201)
    expect(await prisma.payMethod.count({where:{kind:'bank_account'}})).toBe(0)
    expect((await call('/finance/accounts','POST',{name:'Denied bank',kind:'bank',bank:{bankName:'Denied',accountNumber:'1',accountName:'Agency'}},'hub')).status).toBe(403)
  })

  it('links mobile methods to funds and credits the selected phone account', async () => {
    await issueInvoice()
    const r=await call('/settings/pay-methods','POST',{kind:'mobile_banking',provider:'bKash',number:'01700000001',label:'Personal'})
    expect(r.status).toBe(201)
    const m=await prisma.payMethod.findUnique({where:{id:r.data.method.id},include:{account:true}})
    expect(m.account.kind).toBe('mobile')
    expect(m.account.name).toBe('bKash · 01700000001')
    expect((await call('/finance/accounts','POST',{name:'Other bKash',kind:'mobile',mobile:{provider:'bKash',number:'01700000002'}})).status).toBe(201)
    expect((await call('/finance/accounts','POST',{name:'Duplicate bKash',kind:'mobile',mobile:{provider:'bKash',number:'01700000001'}})).status).toBe(400)
    const link=await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'})
    const page=await call(`/track/${link.data.token}`,'GET',undefined,'public')
    const key=page.data.shipment.payMethods.find((x:any)=>x.number==='01700000002').id
    expect((await call(`/track/${link.data.token}/receipt`,'POST',{methodId:key,amount:100,txnRef:'mobile-linked'},'public')).status).toBe(201)
    expect((await call('/shipments/SH-AUDIT/receipt/approve','POST',{})).status).toBe(200)
    expect(Number((await prisma.account.findFirst({where:{name:'Other bKash'}})).balance)).toBe(100)
    expect(Number((await prisma.account.findUnique({where:{id:m.accountId}})).balance)).toBe(0)
  })
  it('converts an existing reserve to a linked bank without resetting its balance', async () => {
    await call('/finance/accounts','POST',{name:'UCB Current',balance:300})
    const before=await prisma.account.findFirst({where:{name:'UCB Current'}})
    expect((await call('/finance/accounts/UCB%20Current','PATCH',{kind:'bank',bank:{bankName:'UCB',accountNumber:'12345',accountName:'Agency'}})).status).toBe(200)
    const after=await prisma.account.findUnique({where:{id:before.id},include:{paymentMethod:true}})
    expect(Number(after.balance)).toBe(300)
    expect(after.paymentMethod.accountNumber).toBe('12345')
    expect((await call('/finance/accounts/UCB%20Current','DELETE')).status).toBe(400)
  })
  it('deletes only unused zero-balance funds and their linked methods', async () => {
    await call('/finance/accounts','POST',{name:'Unused bank',kind:'bank',bank:{bankName:'Unused',accountNumber:'987',accountName:'Agency'}})
    const a=await prisma.account.findFirst({where:{name:'Unused bank'}})
    expect((await call('/finance/accounts/Unused%20bank','DELETE',undefined,'hub')).status).toBe(403)
    expect((await call('/finance/accounts/Unused%20bank','DELETE')).status).toBe(200)
    expect(await prisma.account.count({where:{id:a.id}})).toBe(0)
    expect(await prisma.payMethod.count({where:{accountId:a.id}})).toBe(0)
    expect((await call('/finance/accounts/Cash','DELETE')).status).toBe(400)
    await call('/finance/accounts','POST',{name:'Historical fund'})
    await prisma.payment.create({data:{date:new Date(),method:'Historical fund',amount:1,reference:'old',accountName:'Historical fund'}})
    expect((await call('/finance/accounts/Historical%20fund','DELETE')).status).toBe(400)
    await call('/finance/accounts','POST',{name:'Pending fund'})
    await prisma.receipt.create({data:{shipmentId:shipment.id,method:'Pending fund',amount:1,txnRef:'pending-fund'}})
    expect((await call('/finance/accounts/Pending%20fund','DELETE')).status).toBe(400)
  })

  it('pays flight tickets from the selected fund without requiring a Cash account', async () => {
    await prisma.account.deleteMany({where:{name:'Cash'}})
    await prisma.account.updateMany({where:{name:'Bank'},data:{balance:1000}})
    const flyer=await prisma.flyer.create({data:{name:'Ticket Flyer'}})
    const flight=await call('/flights','POST',{code:'TK123',date:'2027-01-01',actualCost:600,agencyShare:400,accountName:'Bank',flyerNames:[flyer.name]})
    expect(flight.status).toBe(201)
    expect(Number((await prisma.account.findFirst({where:{name:'Bank'}})).balance)).toBe(400)
    expect((await prisma.expense.findFirst()).accountName).toBe('Bank')
    expect((await call(`/flights/${flight.data.code}`,'PATCH',{actualCost:700,accountName:'Bank'})).status).toBe(200)
    expect(Number((await prisma.account.findFirst({where:{name:'Bank'}})).balance)).toBe(300)
    expect((await call(`/flights/${flight.data.code}`,'PATCH',{actualCost:650,accountName:'Bank'})).status).toBe(200)
    expect(Number((await prisma.account.findFirst({where:{name:'Bank'}})).balance)).toBe(350)
  })
  it('rolls back flight creation when the selected paying account is missing or underfunded', async () => {
    const flyer=await prisma.flyer.create({data:{name:'Unfunded Flyer'}})
    const body={code:'TK456',date:'2027-01-01',actualCost:600,agencyShare:400,flyerNames:[flyer.name]}
    expect((await call('/flights','POST',{...body,accountName:'Missing fund'})).status).toBe(400)
    expect((await call('/flights','POST',{...body,accountName:'Bank'})).status).toBe(400)
    expect(await prisma.flight.count()).toBe(0)
    expect(await prisma.flightFlyer.count()).toBe(0)
    expect(await prisma.expense.count()).toBe(0)
    expect((await call('/flights','POST',{...body,actualCost:0,agencyShare:0})).status).toBe(201)
  })

  it('saves an unpaid flight without any funds and settles it later exactly once', async () => {
    await prisma.account.deleteMany()
    await prisma.flyer.create({data:{name:'Pay Later Flyer'}})
    const f=await call('/flights','POST',{code:'PL123',date:'2027-01-01',flyerNames:['Pay Later Flyer'],actualCost:55000,agencyShare:50000})
    expect(f.status).toBe(201)
    expect(await prisma.expense.count()).toBe(0)
    expect(await prisma.account.count()).toBe(0)
    let detail=(await call(`/flights/${f.data.code}`)).data.flight
    expect(detail.ticketDue).toBe(55000)
    expect(detail.ticketPaid).toBe(0)
    expect(detail.flyerDue).toBe(5000)
    const before=(await call('/finance?period=all')).data
    expect(before.ticketPayables).toBe(55000)
    await call('/finance/accounts','POST',{name:'Ticket fund',balance:60000})
    expect((await call(`/flights/${f.data.code}`,'PATCH',{accountName:'Ticket fund'})).status).toBe(200)
    expect((await call(`/flights/${f.data.code}`,'PATCH',{accountName:'Ticket fund'})).status).toBe(200)
    expect(await prisma.expense.count()).toBe(1)
    expect(Number((await prisma.account.findFirst({where:{name:'Ticket fund'}})).balance)).toBe(5000)
    detail=(await call(`/flights/${f.data.code}`)).data.flight
    expect(detail.ticketDue).toBe(0)
    expect(detail.ticketPaid).toBe(55000)
    const after=(await call('/finance?period=all')).data
    expect(after.ticketPayables).toBe(0)
    expect(after.results.profit).toBe(before.results.profit)
  })
  it('cost edits without a selected fund never invent a ticket payment or refund', async () => {
    await prisma.flyer.create({data:{name:'Cost Edit Flyer'}})
    const f=await call('/flights','POST',{code:'PL456',date:'2027-01-01',flyerNames:['Cost Edit Flyer'],actualCost:600,agencyShare:100,accountName:'Cash'})
    expect(f.status).toBe(201)
    const balance=Number((await prisma.account.findFirst({where:{name:'Cash'}})).balance)
    expect((await call(`/flights/${f.data.code}`,'PATCH',{actualCost:700})).status).toBe(200)
    expect((await call(`/flights/${f.data.code}`)).data.flight.ticketDue).toBe(100)
    expect((await call(`/flights/${f.data.code}`,'PATCH',{actualCost:500})).status).toBe(200)
    expect((await call(`/flights/${f.data.code}`)).data.flight.ticketRefundDue).toBe(100)
    expect((await call('/finance?period=all')).data.ticketRefundReceivables).toBe(100)
    expect(Number((await prisma.account.findFirst({where:{name:'Cash'}})).balance)).toBe(balance)
    expect(await prisma.expense.count()).toBe(1)
  })

  it('blocks draft credit allocation and protects an issued shipment with applied credit', async () => {
    expect((await call('/suppliers/SUP-AUDIT/apply-credit','POST',{shipmentCode:shipment.code,amount:500})).status).toBe(400)
    await issueInvoice()
    await prisma.supplier.update({where:{id:supplier.id},data:{creditBalance:500}})
    expect((await call('/suppliers/SUP-AUDIT/apply-credit','POST',{shipmentCode:shipment.code,amount:500})).status).toBe(200)
    expect((await call(`/shipments/${shipment.code}`,'DELETE')).status).toBe(400)
    expect(Number((await prisma.supplier.findUnique({where:{id:supplier.id}})).creditBalance)).toBe(0)
    expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).paidAmount)).toBe(500)
  })
  it('never invents a refund or erases a ticket payment when deleting a cancelled flight', async () => {
    const f=await prisma.flight.create({data:{code:'CANCELLED',date:new Date(),actualCost:0,agencyShare:0}})
    await prisma.expense.create({data:{flightId:f.id,category:'ticket',date:new Date(),amount:5000,reason:'Original ticket',accountName:'Bank'}})
    expect((await call('/flights/CANCELLED','DELETE')).status).toBe(400)
    expect(await prisma.expense.count({where:{flightId:f.id}})).toBe(1)
    expect(Number((await prisma.account.findFirst({where:{name:'Cash'}})).balance)).toBe(100000)
  })
  it('revokes existing sessions after a password reset or role change', async () => {
    await prisma.user.update({where:{id:'admin'},data:{passwordHash:'new-password-hash'}})
    expect((await call('/me')).status).toBe(401)
    await prisma.user.update({where:{id:'hub'},data:{role:'admin'}})
    expect((await call('/me','GET',undefined,'hub')).status).toBe(401)
  })
  it('posts CNY receipts at the entered rate and retains both original and base amounts', async () => {
    await issueInvoice()
    const payload={amount:10,method:'Alipay',money:{currency:'CNY',exchangeRate:20}}
    const key=randomUUID()
    expect((await call(`/shipments/${shipment.code}/payments`,'POST',payload,'admin',key)).status).toBe(201)
    expect((await call(`/shipments/${shipment.code}/payments`,'POST',payload,'admin',key)).status).toBe(201)
    const payment=await prisma.payment.findFirst()
    expect(Number(payment.amount)).toBe(200)
    expect(payment.sourceCurrency).toBe('CNY')
    expect(Number(payment.sourceAmount)).toBe(10)
    expect(Number(payment.sourceFxRate)).toBe(20)
    expect(Number(payment.accountAmount)).toBe(10)
    expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).paidAmount)).toBe(200)
    expect(Number((await prisma.account.findFirst({where:{name:'Alipay'}})).balance)).toBe(10)
  })
  it('preserves a CNY invoice denomination when an extra BDT expense is added', async () => {
    expect((await call(`/shipments/${shipment.code}/invoice`,'POST',{lines:[{label:'Freight',amount:50}],discount:5,money:{currency:'CNY',exchangeRate:20}})).status).toBe(201)
    let invoice=await prisma.invoice.findFirst()
    expect(Number(invoice.total)).toBe(900)
    expect(Number(invoice.sourceAmount)).toBe(45)
    expect((await call(`/shipments/${shipment.code}/expenses`,'POST',{category:'packaging',amount:100,reason:'Packing',accountName:'Cash'})).status).toBe(200)
    invoice=await prisma.invoice.findFirst()
    expect(invoice.sourceCurrency).toBe('CNY')
    expect(Number(invoice.sourceFxRate)).toBe(20)
    expect(Number(invoice.total)).toBe(900);expect(invoice.needsReview).toBe(true)
    await issueInvoice();invoice=await prisma.invoice.findFirst()
    expect(Number(invoice.total)).toBe(1000);expect(Number(invoice.sourceAmount)).toBe(50);expect(invoice.sourceCurrency).toBe('CNY');expect(Number(invoice.sourceFxRate)).toBe(20)
  })
  it('uses the agreed shipment rate when reweighing after settings change', async () => {
    await prisma.shipment.update({where:{id:shipment.id},data:{chargeCurrency:'CNY',chargeRate:10,charge:2000,bookedKg:10,pricingRates:{BDT:1,CNY:20},status:'received_bd_hub'}})
    await prisma.setting.upsert({where:{key:'rate'},create:{key:'rate',value:'25'},update:{value:'25'}})
    expect((await call(`/shipments/${shipment.code}/weigh`,'POST',{kg:11})).status).toBe(200)
    expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).charge)).toBe(2200)
  })
  it('rejects a customer supplied fake exchange rate without accepting a receipt', async () => {
    const link=await call(`/shipments/${shipment.code}/track-link`,'POST',{scope:'invoice'})
    const methods=(await call(`/track/${link.data.token}`,'GET',undefined,'public')).data.shipment.payMethods
    expect((await call(`/track/${link.data.token}/receipt`,'POST',{methodId:methods[0].id,amount:1,txnRef:'BAD-FX',money:{currency:'CNY',exchangeRate:9999}},'public')).status).toBe(400)
    expect(await prisma.receipt.count()).toBe(0)
  })
  it('keeps CNY expense posting and refunds in native account currency', async () => {
    await prisma.account.updateMany({where:{name:'Alipay'},data:{balance:100}})
    expect((await call('/finance/expenses','POST',{category:'others',amount:10,reason:'CNY expense',accountName:'Alipay',money:{currency:'CNY',exchangeRate:20}})).status).toBe(201)
    expect(Number((await prisma.expense.findFirst()).amount)).toBe(200)
    expect(Number((await prisma.account.findFirst({where:{name:'Alipay'}})).balance)).toBe(90)
    await prisma.supplier.update({where:{id:supplier.id},data:{creditBalance:200}})
    expect((await call('/suppliers/SUP-AUDIT/refunds','POST',{amount:10,reason:'Refund advance',accountName:'Alipay',money:{currency:'CNY',exchangeRate:20}})).status).toBe(201)
    expect(Number((await prisma.customerRefund.findFirst()).sourceAmount)).toBe(10)
    expect(Number((await prisma.account.findFirst({where:{name:'Alipay'}})).balance)).toBe(80)
  })

  it('creates a CNY payment method and preserves its account denomination', async () => {
    const created=await call('/settings/pay-methods','POST',{kind:'mobile_banking',provider:'WeChat',number:'test-cny',currency:'CNY'})
    expect(created.status).toBe(201)
    expect(created.data.method.currency).toBe('CNY')
    const method=await prisma.payMethod.findUnique({where:{id:created.data.method.id},include:{account:true}})
    expect(method.account.currency).toBe('CNY')
    expect((await call(`/settings/pay-methods/${method.id}`,'PATCH',{kind:'mobile_banking',provider:'WeChat',number:'test-cny',currency:'BDT'})).status).toBe(400)
    const list=await call('/settings/pay-methods')
    expect(list.data.methods.find((m:{id:string})=>m.id===method.id).currency).toBe('CNY')
  })
  it('approves a public CNY receipt using its saved rate after settings change', async () => {
    await issueInvoice()
    await prisma.setting.upsert({where:{key:'rate'},create:{key:'rate',value:'20'},update:{value:'20'}})
    await call('/settings/pay-methods','POST',{kind:'mobile_banking',provider:'Alipay',number:'test-public-cny',currency:'CNY'})
    const link=await call(`/shipments/${shipment.code}/track-link`,'POST',{scope:'invoice'})
    const methods=(await call(`/track/${link.data.token}`,'GET',undefined,'public')).data.shipment.payMethods
    const method=methods.find((m:{currency:string})=>m.currency==='CNY')
    expect(method).toBeTruthy()
    expect((await call(`/track/${link.data.token}/receipt`,'POST',{methodId:method.id,amount:10,txnRef:'SAVED-FX',money:{currency:'CNY',exchangeRate:20}},'public')).status).toBe(201)
    expect(Number((await prisma.receipt.findFirst()).sourceAmount)).toBe(10)
    await prisma.setting.update({where:{key:'rate'},data:{value:'25'}})
    expect((await call(`/shipments/${shipment.code}/receipt/approve`,'POST',{})).status).toBe(200)
    const payment=await prisma.payment.findFirst()
    expect(Number(payment.amount)).toBe(200)
    expect(Number(payment.accountAmount)).toBe(10)
    expect(Number(payment.sourceFxRate)).toBe(20)
  })
  it('rejects fractional cents and unsupported currencies without changing the ledger', async () => {
    expect((await call(`/shipments/${shipment.code}/payments`,'POST',{amount:1.001,method:'Cash',money:{currency:'CNY',exchangeRate:20}})).status).toBe(400)
    expect((await call(`/shipments/${shipment.code}/payments`,'POST',{amount:10,method:'Cash',money:{currency:'USD',exchangeRate:120}})).status).toBe(400)
    expect(await prisma.payment.count()).toBe(0)
  })


  it('issues automatic bills at booking, keeps them issued when the price changes and needs a free confirmation for ৳0', async()=>{
    const created=await call('/shipments','POST',{supplierCode:supplier.code,categories:['Garments'],bookedKg:2,chargeRate:100,paymentTerms:'cod'});const code=created.data.code;
    expect((await call(`/shipments/${code}/invoice`)).data.invoice).toMatchObject({state:'issued',pricingMode:'automatic',needsReview:false,total:200});
    const link=await call(`/shipments/${code}/track-link`,'POST',{scope:'invoice'});
    expect((await call(`/track/${link.data.token}`,'GET',undefined,'public')).data.shipment).toMatchObject({pricingState:'issued',showPay:true,showPaid:false,totalBill:200});
    expect((await call(`/shipments/${code}`,'PATCH',{bookedKg:3})).status).toBe(200);
    expect((await call(`/shipments/${code}/invoice`)).data.invoice).toMatchObject({state:'issued',needsReview:false,total:300});
    expect((await call(`/shipments/${code}/payments`,'POST',{amount:20,method:'Cash'})).status).toBe(201);
    await call(`/shipments/${code}`,'PATCH',{bookedKg:4});
    expect((await call(`/shipments/${code}/invoice`)).data.invoice).toMatchObject({state:'issued',total:400,needsReview:false});
    expect((await call(`/shipments/${code}/invoice-history`)).data.revisions).toHaveLength(3);
    const unpriced=await call('/shipments','POST',{supplierCode:supplier.code,categories:['Document'],bookedKg:0,chargeRate:0});
    expect((await call(`/shipments/${unpriced.data.code}/invoice`)).data.invoice).toMatchObject({state:'draft',total:0});
    const zero=await call(`/shipments/${unpriced.data.code}/track-link`,'POST',{scope:'invoice'});
    expect((await call(`/track/${zero.data.token}`,'GET',undefined,'public')).data.shipment.showPaid).toBe(false);
    expect((await call(`/shipments/${unpriced.data.code}/invoice`,'POST',{lines:[{label:'Complimentary',amount:0}]})).status).toBe(400);
    await issueInvoice(unpriced.data.code);expect((await call(`/track/${zero.data.token}`,'GET',undefined,'public')).data.shipment.showPaid).toBe(true);
    const free=await call('/shipments','POST',{supplierCode:supplier.code,categories:['Document'],bookedKg:1,freeOfCharge:true});
    expect((await call(`/shipments/${free.data.code}/invoice`)).data.invoice).toMatchObject({state:'issued',total:0});
  });

  it('preserves manually agreed drafts when shipment pricing changes',async()=>{
    await call('/shipments/SH-AUDIT/invoice','POST',{state:'draft',pricingMode:'manual',lines:[{label:'Agreed service',amount:750}]});
    await call('/shipments/SH-AUDIT/expenses','POST',{category:'courier',amount:100,reason:'Private note',label:'Dhaka courier',paymentTiming:'later'});
    const inv=(await call('/shipments/SH-AUDIT/invoice')).data.invoice;
    expect(inv).toMatchObject({total:750,state:'draft',needsReview:true,pricingMode:'manual'});
    expect(inv.suggestedLines.map((l:any)=>l.amount)).toEqual([750,100]);
    await issueInvoice();expect((await call('/shipments/SH-AUDIT/invoice')).data.invoice.total).toBe(850);
  });

  it('retains separate receipt submissions, their proofs, named decisions and linked task completion',async()=>{
    await issueInvoice();const link=await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'});const url=`/track/${link.data.token}`;
    const methodId=(await call(url,'GET',undefined,'public')).data.shipment.payMethods[0].id;
    expect((await call(`${url}/receipt`,'POST',{amount:300,methodId,txnRef:'FIRST-PART'},'public')).status).toBe(201);
    let first=await prisma.receipt.findFirst();expect(await prisma.todo.count({where:{receiptId:first.id,done:false}})).toBe(1);
    const proof=await prisma.receiptUpload.create({data:{reference:randomUUID(),kind:'shipment',linkHash:createHash('sha256').update(link.data.token).digest('hex'),name:'receipt.png',contentType:'image/png',size:100,objectKey:'audit/retained.png',stagingKey:'audit/staging.png',status:'attached',expiresAt:new Date(Date.now()+3600000)}});
    await prisma.receipt.update({where:{id:first.id},data:{screenshotReference:proof.reference}});
    expect((await call('/shipments/SH-AUDIT/receipt/approve','POST',{})).status).toBe(200);
    expect(await prisma.todo.count({where:{receiptId:first.id,done:true}})).toBe(1);
    expect((await call(`${url}/receipt`,'POST',{amount:400,methodId,txnRef:'SECOND-PART'},'public')).status).toBe(201);
    expect(await prisma.receipt.count()).toBe(2);first=await prisma.receipt.findUnique({where:{id:first.id}});expect(first.status).toBe('approved');expect(Number(first.amount)).toBe(300);expect(first.screenshotReference).toBe(proof.reference);
    expect((await call('/shipments/SH-AUDIT/receipt/reject','POST',{})).status).toBe(400);
    expect((await call('/shipments/SH-AUDIT/receipt/reject','POST',{reason:'Reference does not match the receiving account'})).status).toBe(200);
    const page=(await call(url,'GET',undefined,'public')).data.shipment;
    expect(page.receiptHistory).toHaveLength(2);expect(page.receiptHistory.find((r:any)=>r.status==='rejected').reason).toContain('does not match');
    expect(await prisma.todo.count({where:{done:false}})).toBe(0);
    const payment=await prisma.payment.findFirst();expect(payment.receiptId).toBe(first.id);
    expect((await call('/finance/reverse','POST',{kind:'payment',id:payment.id,reason:'Transfer was returned'})).status).toBe(200);
    expect((await call(url,'GET',undefined,'public')).data.shipment.receiptHistory.find((r:any)=>r.reference===first.reference).reversedAmount).toBe(300);
  });

  it('archives used flyers and never drops their paid ticket settlement ownership',async()=>{
    const flyer=await prisma.flyer.create({data:{name:'Archive carrier'}});
    const f=await prisma.flight.create({data:{code:'ARCHIVE-FLIGHT',date:new Date(),actualCost:1000,agencyShare:0,flyerPaidAmount:300,flyers:{create:{flyerId:flyer.id,contribution:1000,paidAmount:300}}}});
    expect((await call('/flyers/Archive%20carrier','DELETE')).status).toBe(400);
    expect((await call('/flyers/Archive%20carrier/archive','POST',{archived:true})).status).toBe(200);
    expect((await call('/flyers')).data.flyers).toHaveLength(0);expect((await call('/flyers?includeArchived=1')).data.flyers[0].archivedAt).toBeTruthy();
    expect(Number((await prisma.flightFlyer.findFirst({where:{flightId:f.id}})).paidAmount)).toBe(300);
    expect((await call('/flyers/Archive%20carrier/archive','POST',{archived:false})).status).toBe(200);
  });

  it('matches cost accrual to the shipment booking cohort and keeps cash in the actual payment month',async()=>{
    await prisma.shipment.update({where:{id:shipment.id},data:{createdAt:new Date('2026-08-15T00:00:00Z')}});
    const cost=await call('/shipments/SH-AUDIT/expenses','POST',{category:'courier',amount:100,reason:'Courier bill',paymentTiming:'later'});
    expect(cost.status).toBe(200);expect(await prisma.expense.count()).toBe(0);
    let aug=(await call('/finance?period=2026-08')).data;expect(aug.recognitionBasis).toBe('booking-cohort');expect(aug.results.billing).toBe(1100);expect(aug.results.shipmentCosts).toBe(100);expect(aug.results.profit).toBe(1000);expect(aug.costPayables).toBe(100);
    await call('/shipments/SH-AUDIT/expenses','POST',{costId:cost.data.costId,category:'courier',amount:40,reason:'First settlement',accountName:'Cash'});
    await prisma.expense.updateMany({data:{date:new Date('2026-09-10T00:00:00Z')}});
    aug=(await call('/finance?period=2026-08')).data;const sep=(await call('/finance?period=2026-09')).data;
    expect(aug.results.profit).toBe(1000);expect(aug.expenses).toBe(0);expect(sep.results.shipmentCosts).toBe(0);expect(sep.expenses).toBe(40);expect(sep.costPayables).toBe(60);
  });

  it('settles accrued costs once, reverses exact native postings and cancels incorrect costs without deleting history',async()=>{
    await prisma.account.updateMany({where:{name:'Alipay'},data:{balance:100}});
    const c=await call('/shipments/SH-AUDIT/expenses','POST',{category:'courier',label:'China courier',reason:'Private note',amount:10,paymentTiming:'later',money:{currency:'CNY',exchangeRate:20}});expect(c.status).toBe(200);
    expect(Number((await prisma.account.findFirst({where:{name:'Alipay'}})).balance)).toBe(100);
    const pay={costId:c.data.costId,category:'courier',reason:'First part',amount:4,accountName:'Alipay',money:{currency:'CNY',exchangeRate:20}};
    expect((await call('/shipments/SH-AUDIT/expenses','POST',pay)).status).toBe(200);
    let detail=(await call('/shipments/SH-AUDIT')).data.shipment;expect(detail.costs.items[0]).toMatchObject({amount:200,paidAmount:80,dueAmount:120});expect(detail.billAmount).toBe(1200);
    const e=await prisma.expense.findFirst();const key=randomUUID(),reverse={kind:'expense',id:e.id,reason:'Wrong paying account'};
    expect((await call('/finance/reverse','POST',reverse,'hub')).status).toBe(403);
    expect((await call('/finance/reverse','POST',reverse,'admin',key)).status).toBe(200);expect((await call('/finance/reverse','POST',reverse,'admin',key)).status).toBe(200);
    expect((await call('/finance/reverse','POST',reverse)).status).toBe(400);
    expect(Number((await prisma.account.findFirst({where:{name:'Alipay'}})).balance)).toBe(100);
    const offset=await prisma.expense.findFirst({where:{reversalOfId:e.id}});expect(Number(offset.accountAmount)).toBe(-4);expect(Number(offset.amount)).toBe(-80);
    detail=(await call('/shipments/SH-AUDIT')).data.shipment;expect(detail.costs.items[0]).toMatchObject({paidAmount:0,dueAmount:200});expect(detail.billAmount).toBe(1200);
    expect((await call(`/shipments/SH-AUDIT/costs/${c.data.costId}/void`,'POST',{reason:'Cost entered twice'})).status).toBe(200);
    detail=(await call('/shipments/SH-AUDIT')).data.shipment;expect(detail.costs.total).toBe(0);expect(detail.billAmount).toBe(1000);expect(detail.costs.items[0].voidedAt).toBeTruthy();expect(await prisma.expense.count()).toBe(2);
  });

  it('keeps payment terms independent of settlement progress',async()=>{
    expect((await call('/shipments/SH-AUDIT','PATCH',{paymentTerms:'cod'})).status).toBe(200);await issueInvoice();
    await call('/shipments/SH-AUDIT/payments','POST',{amount:400,method:'Cash'});
    expect((await call('/shipments/SH-AUDIT')).data.shipment).toMatchObject({paymentTerms:'cod',payStatus:'partial'});
    await call('/shipments/SH-AUDIT','PATCH',{paymentTerms:'monthly'});
    expect((await call('/shipments/SH-AUDIT')).data.shipment).toMatchObject({paymentTerms:'monthly',payStatus:'partial'});
  });

  it('separates pickup booking, courier correction, dispatch and actual handover',async()=>{
    await prisma.shipment.update({where:{id:shipment.id},data:{status:'ready_for_last_mile',packedAt:new Date(),packageCount:2}});
    expect((await call('/shipments/SH-AUDIT/last-mile','POST',{courier:'Hub pickup',mode:'pickup',ref:'Collect tomorrow'},'hub')).status).toBe(200);
    expect((await call('/shipments/SH-AUDIT')).data.shipment.status).toBe('ready_for_last_mile');expect((await call('/shipments/SH-AUDIT/dispatch','POST',{},'hub')).status).toBe(400);
    expect((await call('/shipments/SH-AUDIT/last-mile','POST',{courier:'Custom courier',mode:'courier',ref:'TRK-123'},'hub')).status).toBe(400);
    expect((await call('/shipments/SH-AUDIT/last-mile','POST',{courier:'Custom courier',mode:'courier',ref:'TRK-123',reason:'Customer requested courier'},'hub')).status).toBe(200);
    expect((await call('/shipments/SH-AUDIT/advance','POST',{},'hub')).status).toBe(400);
    expect((await call('/shipments/SH-AUDIT/dispatch','POST',{},'hub')).status).toBe(200);
    expect((await call('/shipments/SH-AUDIT/last-mile','POST',{courier:'Custom courier',mode:'courier',ref:'TRK-124',reason:'Correct tracking typo'},'hub')).status).toBe(200);
    expect((await call('/shipments/SH-AUDIT/handover','POST',{confirmation:'Delivered to named recipient'},'hub')).status).toBe(200);
    const sh=await prisma.shipment.findUnique({where:{id:shipment.id}});expect(sh.status).toBe('delivered');expect(sh.dispatchedAt).toBeTruthy();expect(sh.handedOverAt).toBeTruthy();
  });

  it('allows pre-dispatch unassignment and requires explicit reasons for journey corrections',async()=>{
    const fl=await prisma.flyer.create({data:{name:'Journey carrier'}});const f=await prisma.flight.create({data:{code:'JOURNEY',date:new Date('2030-01-01'),flyers:{create:{flyerId:fl.id}}}});
    expect((await call('/shipments/SH-AUDIT','PATCH',{flightCode:f.code,flyerName:fl.name})).status).toBe(200);
    await prisma.flyer.update({where:{id:fl.id},data:{archivedAt:new Date()}});expect((await call('/shipments/SH-AUDIT','PATCH',{flightCode:f.code,flyerName:fl.name,description:'Correct description only'})).status).toBe(200);await prisma.flyer.update({where:{id:fl.id},data:{archivedAt:null}});
    expect((await call('/shipments/SH-AUDIT','PATCH',{flightCode:null,flyerName:null})).status).toBe(200);expect((await call('/shipments/SH-AUDIT')).data.shipment.flightCode).toBeNull();
    await prisma.shipment.update({where:{id:shipment.id},data:{status:'delivered'}});
    expect((await call('/shipments/SH-AUDIT','PATCH',{flightCode:f.code,flyerName:fl.name})).status).toBe(400);
    expect((await call('/shipments/SH-AUDIT/assignment-correction','POST',{flightCode:f.code,flyerName:fl.name,reason:'Corrected historical ticket association'})).status).toBe(200);
    expect((await call('/shipments/SH-AUDIT/correct-stage','POST',{status:'received_bd_hub',reason:'Delivery was checked in error'})).status).toBe(200);
    const logs=(await call('/shipments/SH-AUDIT')).data.shipment.log;expect(logs.some((l:any)=>l.message?.includes('historical ticket')||l.text?.includes('historical ticket'))).toBe(true);
  });

  it('keeps reads free of flight status mutations and stores manual itinerary provenance',async()=>{
    const carrier=await prisma.flyer.create({data:{name:'Manual carrier'}});
    const create=await call('/flights','POST',{code:'ZZ123',date:'2026-01-01',flyerNames:[carrier.name],actualCost:0,agencyShare:0,legs:[{source:'manual',code:'ZZ123',date:'2026-01-01',fromIata:'CTU',fromCity:'Chengdu',toIata:'DAC',toCity:'Dhaka',depTime:'10:30',arrTime:'12:00'}]});expect(create.status).toBe(201);
    const before=await prisma.flight.findUnique({where:{code:create.data.code}});expect(before.status).toBe('upcoming');
    const response=await call(`/flights/${create.data.code}`);await call('/flights');await call('/dashboard/overview');
    expect((await prisma.flight.findUnique({where:{code:create.data.code}})).status).toBe('upcoming');expect(response.data.flight.scheduleNeedsConfirmation).toBe(true);expect(response.data.flight.legs[0].source).toBe('manual');
  });

  it('deactivates staff, invalidates old sessions permanently, and preserves named redacted activity',async()=>{
    const email=`deactivate-${randomUUID()}@audit.invalid`,password='StaffAccess123';const created=await call('/settings/users','POST',{name:'Review operator',email,role:'hub',password});const id=created.data.user.id;
    const login=await call('/auth/login','POST',{email,password},'public');const token=login.data.token;
    try{
      expect((await call(`/settings/users/${id}`,'PATCH',{active:false})).status).toBe(200);
      expect((await call('/auth/login','POST',{email,password},'public')).status).toBe(401);
      expect((await call(`/settings/users/${id}`,'PATCH',{active:true})).status).toBe(200);
      expect((await app.request('/api/me',{headers:{Authorization:`Bearer ${token}`}})).status).toBe(401);
      expect((await call('/settings/users/admin','PATCH',{active:false})).status).toBe(400);
      await call('/shipments/SH-AUDIT/exception','POST',{type:'on_hold',reason:'Waiting for customer documents'});
      const activity=(await call('/settings/activity')).data;expect(activity.events.some((e:any)=>e.actorId==='admin'&&e.actorName==='admin')).toBe(true);expect(JSON.stringify(activity)).not.toContain(password);
      expect((await call('/shipments/SH-AUDIT/advance','POST',{})).status).toBe(400);
      expect((await call('/shipments/SH-AUDIT/exception','POST',{type:'cancelled',reason:'Customer cancellation'},'hub')).status).toBe(403);
      expect((await call('/shipments/SH-AUDIT/exception','POST',{type:'resume',reason:'Documents verified'},'hub')).status).toBe(200);
    }finally{await prisma.user.delete({where:{id}});await redis.del(`session:${token}`)}
  });

  it('reverses payment, credit, refund and transfers atomically using original account values',async()=>{
    await issueInvoice();await call('/suppliers/SUP-AUDIT/payments','POST',{amount:1300,method:'Cash'});
    const advance=await prisma.payment.findFirst({where:{kind:'customer-credit'}});expect(Number(advance.amount)).toBe(300);
    await call('/suppliers/SUP-AUDIT/refunds','POST',{amount:100,accountName:'Cash',reason:'Advance returned'});const refund=await prisma.customerRefund.findFirst();
    expect((await call('/finance/reverse','POST',{kind:'refund',id:refund.id,reason:'Refund was cancelled'})).status).toBe(200);
    expect(Number((await prisma.supplier.findUnique({where:{id:supplier.id}})).creditBalance)).toBe(300);
    expect((await call('/finance/reverse','POST',{kind:'payment',id:advance.id,reason:'Advance transfer reversed'})).status).toBe(200);
    const p=await prisma.payment.findFirst({where:{shipmentId:shipment.id,reversalOfId:null}});
    expect((await call('/finance/reverse','POST',{kind:'payment',id:p.id,reason:'Wrong receipt posting'})).status).toBe(200);expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).paidAmount)).toBe(0);
    await call('/finance/transfers','POST',{from:'Cash',to:'Alipay',amount:200,receivedAmount:10,note:'Currency transfer',reference:randomUUID()});const transfer=await prisma.fundTransfer.findFirst();
    expect((await call('/finance/reverse','POST',{kind:'transfer',id:transfer.id,reason:'Wrong destination account'})).status).toBe(200);expect(Number((await prisma.account.findFirst({where:{name:'Cash'}})).balance)).toBe(100000);
    expect(Number((await prisma.account.findFirst({where:{name:'Alipay'}})).balance)).toBe(0);
  });


  it('refuses a reversal when original funds are unavailable and rolls back every linked change',async()=>{
    await issueInvoice();await call('/shipments/SH-AUDIT/payments','POST',{amount:400,method:'Cash'});const p=await prisma.payment.findFirst();
    await prisma.account.updateMany({where:{name:'Cash'},data:{balance:1}});
    expect((await call('/finance/reverse','POST',{kind:'payment',id:p.id,reason:'Wrong entry'})).status).toBe(400);
    expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).paidAmount)).toBe(400);expect((await prisma.payment.findUnique({where:{id:p.id}})).reversedAt).toBeNull();expect(await prisma.ledgerReversal.count()).toBe(0);expect(Number((await prisma.account.findFirst({where:{name:'Cash'}})).balance)).toBe(1);
  });
  it('shows native CNY advances and refunds together, and reverses a credit allocation without moving cash',async()=>{
    const advance=await call('/suppliers/SUP-AUDIT/payments','POST',{amount:10,method:'Alipay',money:{currency:'CNY',exchangeRate:20}});expect(advance.status).toBe(201);expect(advance.data.creditAdded).toBe(200);
    expect((await call('/suppliers/SUP-AUDIT/refunds','POST',{amount:2,accountName:'Alipay',reason:'Return part of advance',money:{currency:'CNY',exchangeRate:20}})).status).toBe(201);
    const activity=(await call('/suppliers/SUP-AUDIT/activity')).data.entries;
    expect(activity.find((x:any)=>x.kind==='customer-credit')).toMatchObject({sourceCurrency:'CNY',sourceAmount:10,sourceFxRate:20,amount:200});expect(activity.find((x:any)=>x.kind==='refund')).toMatchObject({sourceCurrency:'CNY',sourceAmount:2,sourceFxRate:20,amount:-40});
    await issueInvoice();expect((await call('/suppliers/SUP-AUDIT/apply-credit','POST',{shipmentCode:shipment.code,amount:100})).status).toBe(200);const applied=await prisma.customerCredit.findFirst({where:{kind:'applied'}});
    expect((await call('/finance/reverse','POST',{kind:'credit',id:applied.id,reason:'Applied to wrong invoice'})).status).toBe(200);
    expect(Number((await prisma.shipment.findUnique({where:{id:shipment.id}})).paidAmount)).toBe(0);expect(Number((await prisma.supplier.findUnique({where:{id:supplier.id}})).creditBalance)).toBe(160);expect(Number((await prisma.account.findFirst({where:{name:'Alipay'}})).balance)).toBe(8);
  });

  it('can reverse a recorded ticket refund without changing the ticket agreement or deleting the refund',async()=>{
    const f=await prisma.flight.create({data:{code:'REFUND-CORRECTION',date:new Date(),actualCost:900,agencyShare:900}});
    const original=await prisma.expense.create({data:{flightId:f.id,date:new Date(),category:'ticket',amount:-100,sourceCurrency:'BDT',sourceAmount:-100,sourceFxRate:1,accountName:'Cash',accountCurrency:'BDT',accountAmount:-100,fxRate:1,reason:'Ticket refund received'}});
    expect((await call('/finance/reverse','POST',{kind:'expense',id:original.id,reason:'Refund was entered before receipt'})).status).toBe(200);
    expect(Number((await prisma.account.findFirst({where:{name:'Cash'}})).balance)).toBe(99900);expect(Number((await prisma.expense.findFirst({where:{reversalOfId:original.id}})).amount)).toBe(100);expect(Number((await prisma.flight.findUnique({where:{id:f.id}})).actualCost)).toBe(900);
  });
  it('new flyers have no fabricated verification and document flags cannot be set in profile edits', async () => {
    expect((await call('/flyers', 'POST', {firstName:'Document',lastName:'Traveler'})).status).toBe(201)
    const name='Document%20Traveler'
    expect((await call(`/flyers/${name}`)).data.flyer).toMatchObject({docStudentId:false,docVisa:false,docAdmission:false,documentCount:0,verifiedDocumentCount:0})
    expect((await call(`/flyers/${name}`, 'PATCH', {docStudentId:true})).status).toBe(400)
    expect((await prisma.flyer.findUnique({where:{name:'Document Traveler'}})).docStudentId).toBe(false)
  })

  it('keeps flyer documents admin-only and rejects cross-flyer access', async () => {
    const owner=await prisma.flyer.create({data:{name:'Doc Owner'}})
    await prisma.flyer.create({data:{name:'Other Owner'}})
    const doc=await prisma.flyerDocument.create({data:{flyerId:owner.id,kind:'passport',name:'passport.pdf',contentType:'application/pdf',size:100,stagingKey:`staging/${randomUUID()}`,objectKey:`media/${randomUUID()}`,uploadedById:'admin',uploadedByName:'Admin',expiresAt:new Date(Date.now()+300000),status:'ready'}})
    for(const [method,suffix,body] of [
      ['GET','',undefined],['POST','/upload',{kind:'passport',name:'x.pdf',size:100,contentType:'application/pdf'}],
      ['POST',`/${doc.reference}/complete`,{}],['GET',`/${doc.reference}/url`,undefined],
      ['PATCH',`/${doc.reference}/verification`,{verified:true}],['DELETE',`/${doc.reference}`,undefined],
    ] as const){
      expect((await call('/flyers/Doc%20Owner/documents'+suffix,method,body,'public')).status).toBe(401)
      expect((await call('/flyers/Doc%20Owner/documents'+suffix,method,body,'hub')).status).toBe(403)
      if(suffix && suffix!='/upload') expect((await call('/flyers/Other%20Owner/documents'+suffix,method,body)).status).toBe(404)
    }
    const listed=(await call('/flyers/Doc%20Owner/documents')).data.documents[0]
    expect(listed).toMatchObject({name:'passport.pdf',kind:'passport',verifiedAt:null})
    expect(listed).not.toHaveProperty('objectKey');expect(listed).not.toHaveProperty('stagingKey');expect(listed).not.toHaveProperty('flyerId')
  })

  it('validates flyer document reservations and does not expose unverified uploads', async () => {
    const storage=await import('../src/shared/r2')
    const sign=vi.spyOn(storage,'signUpload').mockResolvedValue('https://storage.invalid/upload')
    const finalize=vi.spyOn(storage,'finalizeUpload').mockRejectedValue((await import('../src/core/errors')).badRequest('Invalid file contents'))
    try {
      const flyer=await prisma.flyer.create({data:{name:'Upload Owner'}})
      const base='/flyers/Upload%20Owner/documents', valid={kind:'passport',name:'passport.pdf',contentType:'application/pdf',size:100}
      for(const change of [{kind:'invalid'},{name:''},{size:0},{size:10485761},{size:1.5},{contentType:'text/html'},{contentType:'video/mp4'},{shared:true}])
        expect((await call(base+'/upload','POST',{...valid,...change})).status).toBe(400)
      expect(sign).not.toHaveBeenCalled()
      const pending=(await call(base+'/upload','POST',valid)).data
      expect((await call(base)).data.documents).toEqual([])
      expect((await call(`${base}/${pending.reference}/url`)).status).toBe(404)
      expect((await call(`${base}/${pending.reference}/verification`,'PATCH',{verified:true})).status).toBe(400)
      expect((await call(`${base}/${pending.reference}/complete`,'POST')).status).toBe(400)
      expect((await prisma.flyerDocument.findUnique({where:{reference:pending.reference}})).status).toBe('pending')
      await prisma.flyerDocument.update({where:{reference:pending.reference},data:{expiresAt:new Date(Date.now()-1000)}})
      expect((await call(`${base}/${pending.reference}/complete`,'POST')).status).toBe(400)
      expect(finalize).toHaveBeenCalledTimes(1)
      await prisma.flyerDocument.createMany({data:Array.from({length:30},()=>({flyerId:flyer.id,reference:randomUUID(),kind:'other',name:'x.png',contentType:'image/png',size:10,stagingKey:`staging/${randomUUID()}`,objectKey:`media/${randomUUID()}`,uploadedById:'admin',uploadedByName:'Admin',status:'ready',expiresAt:new Date()}))})
      expect((await call(base+'/upload','POST',valid)).status).toBe(400)
    } finally {sign.mockRestore();finalize.mockRestore()}
  })

  it('retains private flyer files across rename/archive and verifies or removes exact files', async () => {
    const storage=await import('../src/shared/r2')
    const sign=vi.spyOn(storage,'signUpload').mockResolvedValue('https://storage.invalid/upload')
    const finalize=vi.spyOn(storage,'finalizeUpload').mockImplementation(async (row: { size: number; contentType: string }) => ({ size: row.size, contentType: row.contentType }))
    const download=vi.spyOn(storage,'signDownload').mockResolvedValue('https://storage.invalid/private-preview')
    try {
      await call('/flyers','POST',{firstName:'Review',lastName:'Owner'})
      let base='/flyers/Review%20Owner/documents'
      const first=(await call(base+'/upload','POST',{kind:'student_id',name:'student.png',contentType:'image/png',size:100})).data
      expect((await call(`${base}/${first.reference}/complete`,'POST')).status).toBe(200)
      expect((await call(`${base}/${first.reference}/complete`,'POST')).status).toBe(200)
      expect(finalize).toHaveBeenCalledTimes(1)
      expect(finalize).toHaveBeenCalledWith(expect.objectContaining({kind:'student_id'}),{allowPdf:true})
      expect((await call('/flyers/Review%20Owner')).data.flyer).toMatchObject({documentCount:1,verifiedDocumentCount:0,docStudentId:false})
      expect((await call(`${base}/${first.reference}/url`)).data.url).toBe('https://storage.invalid/private-preview')
      expect((await call(`${base}/${first.reference}/verification`,'PATCH',{verified:true})).status).toBe(200)
      const verified=(await call(base)).data.documents[0]
      expect(verified.verifiedByName).toBe('admin');expect(verified.verifiedAt).not.toBeNull()
      expect((await call('/flyers/Review%20Owner')).data.flyer).toMatchObject({verifiedDocumentCount:1,docStudentId:true})
      const second=(await call(base+'/upload','POST',{kind:'student_id',name:'student-back.pdf',contentType:'application/pdf',size:200})).data
      await call(`${base}/${second.reference}/complete`,'POST')
      expect((await call('/flyers/Review%20Owner')).data.flyer).toMatchObject({documentCount:2,verifiedDocumentCount:1})
      await call('/flyers/Review%20Owner','PATCH',{firstName:'Renamed'})
      base='/flyers/Renamed%20Owner/documents'
      expect((await call(base)).data.documents).toHaveLength(2)
      await call('/flyers/Renamed%20Owner/archive','POST',{archived:true})
      expect((await call(`${base}/${first.reference}/url`)).status).toBe(200)
      expect((await call('/flyers/Renamed%20Owner','DELETE')).status).toBe(400)
      await call(`${base}/${first.reference}/verification`,'PATCH',{verified:false})
      expect((await call('/flyers/Renamed%20Owner')).data.flyer.docStudentId).toBe(false)
      await call(`${base}/${first.reference}/verification`,'PATCH',{verified:true})
      expect((await call(`${base}/${first.reference}`,'DELETE')).status).toBe(200)
      expect((await call(`${base}/${first.reference}/url`)).status).toBe(404)
      expect((await call(`${base}/${first.reference}/complete`,'POST')).status).toBe(404)
      expect((await call(base)).data.documents).toHaveLength(1)
      expect((await call('/flyers/Renamed%20Owner')).data.flyer).toMatchObject({documentCount:1,verifiedDocumentCount:0,docStudentId:false})
      expect(await prisma.auditEvent.count({where:{actorId:'admin'}})).toBeGreaterThan(0)
    } finally {sign.mockRestore();finalize.mockRestore();download.mockRestore()}
  })

  it('defaults new links to tracking-only and rejects database keys as public capabilities', async () => {
    const created=await call('/shipments/SH-AUDIT/track-link','POST',{})
    expect(created.status).toBe(201)
    expect(await prisma.invoice.count()).toBe(0)
    const link=await prisma.publicLink.findFirst()
    expect(link.scope).toBe('tracking_only')
    expect(created.data.token).toMatch(/^[A-Za-z0-9_-]{22}$/)
    expect(Buffer.from(created.data.token,'base64url')).toHaveLength(32)
    expect(new URL(created.data.url).pathname).toBe('/t/'+created.data.token)
    expect(link.tokenHash).not.toBe(created.data.token)
    expect(link.tokenCiphertext).not.toContain(created.data.token)
    const page=await call(`/track/${created.data.token}`,'GET',undefined,'public')
    expect(page.data.shipment.includesInvoice).toBe(false)
    expect(page.data.shipment).not.toHaveProperty('receiptHistory')
    expect(page.headers.get('cache-control')).toBe('no-store')
    expect(page.headers.get('referrer-policy')).toBe('no-referrer')
    expect(page.headers.get('x-robots-tag')).toContain('noindex')
    for(const value of [shipment.id,shipment.code,shipment.trackToken,link.id,link.tokenHash,supplier.id]) {
      expect((await call('/track/'+value,'GET',undefined,'public')).status).toBe(404)
      expect((await app.request('/api/track/'+value+'/invoice.pdf')).status).toBe(404)
      expect((await call('/statements/'+value,'GET',undefined,'public')).status).toBe(404)
    }
    expect((await app.request(`/api/track/${created.data.token}/invoice.pdf`)).status).toBe(404)
    expect((await call(`/track/${created.data.token}/receipt-image/upload`,'POST',{name:'x.png',contentType:'image/png',size:20},'public')).status).toBe(404)
  })

  it('exposes independent public references instead of primary keys in tracking and statements', async () => {
    await issueInvoice()
    const link=(await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'})).data
    const trackPath=`/track/${link.token}`
    const storedMethod=await prisma.payMethod.findFirst()
    const method=(await call(trackPath,'GET',undefined,'public')).data.shipment.payMethods[0]
    expect(method.id).toBe(storedMethod.publicReference)
    expect(method.id).toMatch(/^[0-9a-f-]{36}$/)
    expect(method.id).not.toBe(storedMethod.id)
    expect((await call(trackPath+'/receipt','POST',{methodId:storedMethod.id,amount:100,txnRef:'PRIVATE-ID-REJECTED'},'public')).status).toBe(404)
    expect((await call(trackPath+'/receipt','POST',{methodId:method.id,amount:100,txnRef:'PUBLIC-REF-SHIP'},'public')).status).toBe(201)
    await call('/shipments/SH-AUDIT/receipt/reject','POST',{reason:'Please provide the bank reference'})
    const receipt=await prisma.receipt.findFirst()
    const month=shipment.createdAt.toISOString().slice(0,7)
    const statement=(await call('/suppliers/SUP-AUDIT/statement-link','POST',{month})).data
    expect((await call(`/statements/${statement.token}/receipt`,'POST',{methodId:storedMethod.id,amount:100,txnRef:'STMT-PRIVATE-ID'},'public')).status).toBe(400)
    expect((await call(`/statements/${statement.token}/receipt`,'POST',{methodId:method.id,amount:100,txnRef:'PUBLIC-REF-STMT'},'public')).status).toBe(201)
    const statementReceipt=await prisma.statementReceipt.findFirst()
    const ids=[shipment.id,supplier.id,storedMethod.id,receipt.id,statementReceipt.id,
      (await prisma.publicLink.findFirst()).id,(await prisma.statementLink.findFirst()).id,(await prisma.invoice.findFirst()).id,
      ...(await prisma.account.findMany()).map((a:any)=>a.id)]
    const tracking=(await call(trackPath,'GET',undefined,'public')).data
    const monthly=(await call(`/statements/${statement.token}`,'GET',undefined,'public')).data
    for(const payload of [tracking,monthly]) {
      const text=JSON.stringify(payload)
      for(const id of ids)expect(text).not.toContain(id)
      for(const field of ['shipmentId','supplierId','linkId','accountId','costId','reviewedById','reviewedBy','tokenHash','tokenCiphertext','stagingKey','objectKey'])expect(text).not.toContain('"'+field+'"')
    }
    const customerReceipt=tracking.shipment.receiptHistory[0]
    expect(customerReceipt.reference).toBe(receipt.reference)
    expect(customerReceipt).not.toHaveProperty('id')
    expect(customerReceipt).not.toHaveProperty('screenshot')
    expect(customerReceipt.reason).toBe('Please provide the bank reference')
    expect(monthly.statement.receiptHistory[0].reference).toBe(statementReceipt.reference)
    expect(monthly.statement.receiptHistory[0]).not.toHaveProperty('id')
    expect((await call(`/statements/${link.token}`,'GET',undefined,'public')).status).toBe(404)
    expect((await call(`/track/${statement.token}`,'GET',undefined,'public')).status).toBe(404)
  })

  it('revokes every public subroute and keeps media references scoped to their owning shipment',async()=>{
    const storage=await import('../src/shared/r2')
    const download=vi.spyOn(storage,'signDownload').mockResolvedValue('https://storage.invalid/media-random-reference')
    try {
      await issueInvoice()
      const a=(await call('/shipments/SH-AUDIT/track-link','POST',{scope:'invoice'})).data
      const other=await prisma.shipment.create({data:{code:'SH-OTHER-PRIVATE',supplierId:supplier.id,trackToken:'legacy-'+randomUUID()}})
      const b=(await call('/shipments/SH-OTHER-PRIVATE/track-link','POST',{})).data
      const media=await prisma.shipmentMedia.create({data:{shipmentId:shipment.id,name:'package.png',contentType:'image/png',size:10,stagingKey:`staging/${randomUUID()}`,objectKey:`media/${randomUUID()}`,status:'ready',shared:true,expiresAt:new Date(Date.now()+300000)}})
      const path=`/track/${a.token}`,wrong=`/track/${b.token}`
      const list=(await call(path+'/media','GET',undefined,'public')).data
      expect(list.media[0].reference).toBe(media.reference)
      expect(JSON.stringify(list)).not.toContain(media.id);expect(JSON.stringify(list)).not.toContain(shipment.id)
      expect((await call(`${path}/media/${media.reference}/url`,'GET',undefined,'public')).status).toBe(200)
      expect((await call(`${wrong}/media/${media.reference}/url`,'GET',undefined,'public')).status).toBe(404)
      expect((await call(wrong+'/media','GET',undefined,'public')).data.media).toEqual([])
      await call('/shipments/SH-AUDIT/track-link','DELETE')
      for(const suffix of ['', '/media', `/media/${media.reference}/url`, '/invoice.pdf'])expect((await app.request('/api'+path+suffix)).status).toBe(404)
      expect((await call(path+'/receipt-image/upload','POST',{name:'x.png',contentType:'image/png',size:10},'public')).status).toBe(404)
      expect((await call(path+'/receipt','POST',{methodId:'unavailable',amount:1,txnRef:'REVOKED-LINK'},'public')).status).toBe(404)
      expect(download).toHaveBeenCalledTimes(1)
      const month=shipment.createdAt.toISOString().slice(0,7)
      const statement=(await call('/suppliers/SUP-AUDIT/statement-link','POST',{month})).data
      await call('/suppliers/SUP-AUDIT/statement-link','DELETE')
      for(const [method,suffix,body] of [['GET','',undefined],['POST','/receipt-image/upload',{name:'x.png',contentType:'image/png',size:10}],['POST','/receipt',{methodId:'x',amount:1,txnRef:'REVOKED-STMT'}]] as const)
        expect((await call(`/statements/${statement.token}`+suffix,method,body,'public')).status).toBe(404)
      expect(await prisma.receiptUpload.count()).toBe(0)
      expect(await prisma.receipt.count()).toBe(0)
    } finally {download.mockRestore()}
  })

})