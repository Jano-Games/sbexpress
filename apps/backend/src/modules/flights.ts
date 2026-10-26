import { assertFlightCapacity } from '../shared/flightCapacity'
import { moneyBody, sourceFields, sourceAt, withSavedMoney } from '../shared/money'
import { Hono } from 'hono'
import { randomBytes } from 'node:crypto'
import { Prisma, type FlightStatus } from '@prisma/client'
import { z } from 'zod'
import { prisma } from '../core/db'
import { cacheInvalidate } from '../core/redis'
import { badRequest, notFound } from '../core/errors'
import { requireRole, type AppEnv } from './auth'
import { FLIGHT_LABEL } from '../shared/status'
import { effectiveBill, num, isoDate, shipmentRow, shipmentOperatingCosts } from '../shared/serialize'
import { getSettings } from '../shared/settings'
import { creditPayment, debitCash } from '../shared/ledger'
import { lookupFlight } from '../shared/flightLookup'
import { HUB_FLIGHT_DETAIL_INCLUDE, HUB_FLIGHT_INCLUDE, hubFlightDetail, hubFlightRow } from '../shared/hubFlights'
import { matchFlyers, parseTicketText, ticketText } from '../shared/ticketImport'

const INCLUDE = {
  expenses: true,
  flyers: { include: { flyer: true } },
  shipments: { include: { supplier: true, flight: true, receipts: true, expenses: true, costs: true, invoice: true } },
  legs: { orderBy: { order: 'asc' as const } },
} as const

// The directory only needs values used by summary. Full shipment relations
// remain on the detail route, where role-aware booking rows are returned.
const SUMMARY_INCLUDE = {
  expenses: { select: { category: true, amount: true } },
  flyers: { select: { contribution: true, paidAmount: true, flyer: { select: { name: true } } } },
  shipments: {
    select: {
      bookedKg: true,
      charge: true,
      customsTax: true,
      afterSalesFee: true,
      cnFare: true,
      bdFare: true,
      invoice: { select: { total: true } },
      expenses: { select: { costId:true,costField: true, category: true, amount: true } },
      costs:{select:{category:true,amount:true,voidedAt:true}},
    },
  },
  legs: {
    orderBy: { order: 'asc' as const },
    select: { source:true, code: true, date: true, fromIata: true, fromCity: true, toIata: true, toCity: true, depTime: true, arrTime: true },
  },
} as const

type FlightSummarySource = Prisma.FlightGetPayload<{ include: typeof SUMMARY_INCLUDE }>

interface LegInput {
  code: string
  fromIata: string
  fromCity: string
  toIata: string
  toCity: string
  depTime: string
  arrTime: string
}

const legSchema = z.object({
  source:z.enum(["manual","schedule","legacy","ticket"]).default("legacy"),
  code: z.string().min(2),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(),
  fromIata: z.string().default(''),
  fromCity: z.string().default(''),
  toIata: z.string().default(''),
  toCity: z.string().default(''),
  depTime: z.string().default('—'),
  arrTime: z.string().default('—'),
})

/**
 * An itinerary's identity comes from its segments: consecutive duplicate
 * numbers collapse (a one-stop flight keeps its number through the stop),
 * times span first departure to last arrival, and the via label names the
 * connection airports.
 */
function deriveFromLegs(legs: LegInput[]) {
  const codes = legs
    .map((l) => l.code.toUpperCase())
    .filter((code, i, all) => i === 0 || code !== all[i - 1])
  const stops = legs.slice(0, -1).map((l) => [l.toIata, l.toCity].filter(Boolean).join(' '))
  return {
    code: codes.join('+'),
    depTime: legs[0]!.depTime,
    arrTime: legs[legs.length - 1]!.arrTime,
    via: stops.length ? `Via ${stops.join(', ')}` : 'Direct',
  }
}

function summary(f: FlightSummarySource) {
  const revenue = f.shipments.reduce((total, shipment) => total + effectiveBill(shipment), 0)
  const shipmentCosts = f.shipments.reduce((costs, shipment) => {
    const next = shipmentOperatingCosts(shipment)
    costs.cnTransport += next.cnTransport
    costs.courier += next.courier
    costs.customs += next.customs
    costs.other += next.other
    return costs
  }, { cnTransport: 0, courier: 0, customs: 0, other: 0 })
  const totalShipmentCosts = Object.values(shipmentCosts).reduce((total, cost) => total + cost, 0)
  const bookedKg = Math.round(f.shipments.reduce((a, s) => a + num(s.bookedKg), 0) * 100) / 100
  return {
    sourceCurrency:f.sourceCurrency, sourceFxRate:num(f.sourceFxRate), sourceAmount:num(f.sourceAmount),
    code: f.code,
    date: isoDate(f.date),
    depTime: f.depTime,
    arrTime: f.arrTime,
    via: f.via,
    fare: num(f.fare),
    actualCost: num(f.actualCost),
    ticketPaid: f.expenses.filter(e=>e.category==='ticket').reduce((a,e)=>a+num(e.amount),0),
    ticketDue: Math.max(0,num(f.actualCost)-f.expenses.filter(e=>e.category==='ticket').reduce((a,e)=>a+num(e.amount),0)),
    ticketRefundDue: Math.max(0,f.expenses.filter(e=>e.category==='ticket').reduce((a,e)=>a+num(e.amount),0)-num(f.actualCost)),
    agencyShare: num(f.agencyShare),
    flyerPaidAmount: num(f.flyerPaidAmount),
    settlements:f.flyers.map(x=>({name:x.flyer.name,contribution:num(x.contribution),paidAmount:num(x.paidAmount)})),
    unallocatedFlyerPaid:Math.max(0,num(f.flyerPaidAmount)-f.flyers.reduce((a,x)=>a+num(x.paidAmount),0)),
    flyerDue: Math.max(0, num(f.actualCost) - num(f.agencyShare) - num(f.flyerPaidAmount)),
    shipmentCosts,
    totalShipmentCosts,
    margin: Math.round((revenue + num(f.fare) - num(f.actualCost) - totalShipmentCosts) * 100) / 100,
    spaceKg: f.spaceKg,
    mobiles: f.mobiles,
    laptops: f.laptops,
    bookedKg,
    leftKg: Math.round((f.spaceKg - bookedKg) * 100) / 100,
    scheduleNeedsConfirmation:f.status==='upcoming'&&f.date<new Date(new Date().toISOString().slice(0,10)),
    status: f.status,
    statusLabel: FLIGHT_LABEL[f.status],
    flyers: f.flyers.map((x) => x.flyer.name),
    shipmentCount: f.shipments.length,
    revenue,
    legs: f.legs.map((l) => ({
      source:l.source,code: l.code,
      date: l.date ? isoDate(l.date) : null,
      fromIata: l.fromIata,
      fromCity: l.fromCity,
      toIata: l.toIata,
      toCity: l.toCity,
      depTime: l.depTime,
      arrTime: l.arrTime,
    })),
  }
}

export const flightRoutes = new Hono<AppEnv>()
  .get('/', requireRole('admin'), async (c) => {
    const flights = await prisma.flight.findMany({ include: SUMMARY_INCLUDE, orderBy: { date: 'asc' } })
    return c.json({ flights: flights.map(summary) })
  })

  // Registered before the '/:code' routes so "lookup" is never read as a code.
  .get('/lookup', requireRole('admin'), async (c) => {
    const { code, date } = z
      .object({
        code: z.string().min(2, 'Flight no required'),
        date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date required'),
      })
      .parse({ code: c.req.query('code'), date: c.req.query('date') })
    return c.json(await lookupFlight(code, date))
  })

  // Reads an e-ticket PDF into reviewable flight drafts. Nothing is stored:
  // neither the file nor the passport number leaves this request.
  .post('/ticket', requireRole('admin'), async (c) => {
    const { file } = z.object({ file: z.string().min(1, 'Choose a ticket PDF') }).parse(await c.req.json())
    const parsed = parseTicketText(await ticketText(file))
    if (!parsed.journeys.length) throw badRequest('No flight segments found in this PDF. Enter the flight manually.')
    const flyers = await prisma.flyer.findMany({ where: { archivedAt: null }, select: { name: true } })
    return c.json({
      ticket: {
        agency: parsed.agency,
        passenger: parsed.passenger,
        firstName: parsed.firstName,
        lastName: parsed.lastName,
        pnr: parsed.pnr,
        ticketNumber: parsed.ticketNumber,
        issuedOn: parsed.issuedOn,
      },
      flyerMatches: matchFlyers(parsed.passenger, flyers),
      journeys: parsed.journeys,
    })
  })

  // Hub-safe schedule without ticket or booking money. Also registered before
  // '/:code' so "hub" is never read as a flight code.
  .get('/hub', requireRole('admin', 'hub'), async (c) => {
    const [upcoming, arrived] = await Promise.all([
      prisma.flight.findMany({ where: { status: { in: ['upcoming', 'departed'] } }, include: HUB_FLIGHT_INCLUDE, orderBy: { date: 'asc' } }),
      prisma.flight.findMany({ where: { status: 'completed' }, include: HUB_FLIGHT_INCLUDE, orderBy: { date: 'desc' }, take: 10 }),
    ])
    return c.json({ upcoming: upcoming.map((f) => hubFlightRow(f)), arrived: arrived.map((f) => hubFlightRow(f)) })
  })

  .get('/hub/:code', requireRole('admin', 'hub'), async (c) => {
    const [flight, settings] = await Promise.all([
      prisma.flight.findUnique({ where: { code: c.req.param('code') }, include: HUB_FLIGHT_DETAIL_INCLUDE }),
      getSettings(),
    ])
    if (!flight) throw notFound('Flight not found')
    return c.json({ flight: hubFlightDetail(flight, settings.threshold) })
  })

  .post('/', requireRole('admin'), async (c) => {
    const body = z
      .object({
        code: z.string().min(2, 'Flight no required'),
        flyerNames: z.array(z.string().min(1)).min(1, 'Pick at least one flyer'),
        date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date required'),
        depTime: z.string().default('—'),
        arrTime: z.string().default('—'),
        agencyShare: z.number().min(0).default(0),
        actualCost: z.number().min(0).default(0),
        accountName: z.string().trim().min(1).max(200).optional(),
        spaceKg: z.number().int().min(0).default(44),
        mobiles: z.number().int().min(0).default(2),
        laptops: z.number().int().min(0).default(1),
        /** Connection itineraries: ordered segments override code/times/via. */
        legs: z.array(legSchema).optional(),
      })
      .parse(moneyBody(await c.req.json(), ['actualCost', 'agencyShare']))

    if (body.agencyShare > body.actualCost) throw badRequest('Agency share cannot exceed actual ticket cost')
    const names = [...new Set(body.flyerNames)]
    const flyers = await prisma.flyer.findMany({ where: { name: { in: names }, archivedAt:null } })
    if (flyers.length !== names.length) {
      const found = new Set(flyers.map((f) => f.name))
      throw badRequest(`Unknown flyer ${names.find((n) => !found.has(n))}`)
    }

    const derived = body.legs?.length ? deriveFromLegs(body.legs) : null
    const airlineCode = derived?.code ?? body.code.toUpperCase()
    // A flight number repeats every day and can carry more than one ticket booking.
    const code = `${airlineCode}-${body.date.replaceAll('-', '')}-${randomBytes(3).toString('hex')}`

    const flight = await prisma.flight.create({
      data: {
        code,
        date: new Date(body.date),
        depTime: derived?.depTime ?? body.depTime,
        arrTime: derived?.arrTime ?? body.arrTime,
        via: derived?.via ?? 'Direct',
        agencyShare: new Prisma.Decimal(body.agencyShare),
        fare: new Prisma.Decimal(body.actualCost).minus(body.agencyShare),
        ...sourceFields(body.actualCost),
        actualCost: new Prisma.Decimal(body.actualCost),
        spaceKg: body.spaceKg,
        mobiles: body.mobiles,
        laptops: body.laptops,
        flyers: { create: flyers.map((f) => ({ flyerId: f.id, contribution:flyers.length===1?body.actualCost-body.agencyShare:0 })) },
        legs: body.legs?.length
          ? { create: body.legs.map((l, order) => ({ ...l, code: l.code.toUpperCase(), date: l.date ? new Date(l.date) : null, order })) }
          : { create: [{ order: 0, code: airlineCode, date: new Date(body.date), depTime: body.depTime, arrTime: body.arrTime }] },
      },
    })
    // Buying the ticket is money out — record it in the expense ledger so the
    // cash flow matches reality without a second manual entry.
    if (body.actualCost > 0 && body.accountName) {
      const posted=await debitCash(body.actualCost, body.accountName)
      await prisma.expense.create({data:{...sourceFields(body.actualCost),date:new Date(),category:'ticket',amount:body.actualCost,reason:`${code} ticket — ${names.join(', ')}`,flightId:flight.id,...posted}})
    }
    await cacheInvalidate('dashboard')
    return c.json({ code }, 201)
  })

  .get('/:code', requireRole('admin'), async (c) => {
    const [flight, settings] = await Promise.all([
      prisma.flight.findUnique({ where: { code: c.req.param('code') }, include: INCLUDE }),
      getSettings(),
    ])
    if (!flight) throw notFound('Flight not found')
    const flyers = flight.flyers.map((x) => ({
      name: x.flyer.name,
      bdPhone: x.flyer.bdPhone,
      initial: x.flyer.name.charAt(0),
    }))
    return c.json({
      flight: {
        ...summary(flight),
        flyerDetails: flyers,
        bookings: flight.shipments.map((s) => shipmentRow(s, 'admin', settings.threshold)),
      },
    })
  })

  .patch('/:code', requireRole('admin'), async (c) => {
    const flight = await prisma.flight.findUnique({ where: { code: c.req.param('code')! } })
    if (!flight) throw notFound('Flight not found')
    const body = z
      .object({
        code: z.string().min(2).optional(),
        date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
        depTime: z.string().optional(),
        arrTime: z.string().optional(),
        via: z.string().optional(),
        agencyShare: z.number().min(0).optional(),
        actualCost: z.number().min(0).optional(),
        accountName: z.string().trim().min(1).max(200).optional(),
        spaceKg: z.number().int().min(0).optional(),
        mobiles: z.number().int().min(0).optional(),
        laptops: z.number().int().min(0).optional(),
        status: z.enum(['upcoming', 'departed', 'completed']).optional(),
        /** When present, replaces the leg list and re-derives code/times/via. */
        legs: z.array(legSchema).optional(),
      })
      .parse(moneyBody(await c.req.json(), ['actualCost', 'agencyShare']))

    if (body.spaceKg !== undefined && body.spaceKg !== flight.spaceKg) await assertFlightCapacity(flight.id, 0, undefined, body.spaceKg)
    const derived = body.legs?.length ? deriveFromLegs(body.legs) : null
    // Keep the booking reference stable when itinerary details change.
    const newCode = flight.code
    if (newCode && newCode !== flight.code) {
      const clash = await prisma.flight.findUnique({ where: { code: newCode } })
      if (clash) throw badRequest(`Flight ${newCode} already exists`)
    }
    const actualCost = body.actualCost ?? num(flight.actualCost)
    const agencyShare = body.agencyShare ?? num(flight.agencyShare)
    if (agencyShare > actualCost || actualCost - agencyShare < num(flight.flyerPaidAmount)) throw badRequest('Ticket split cannot be less than flyer payments already received')
    const members=await prisma.flightFlyer.findMany({where:{flightId:flight.id}})
    if(members.length>1 && (actualCost!==num(flight.actualCost)||agencyShare!==num(flight.agencyShare)))for(const m of members)await prisma.flightFlyer.update({where:{flightId_flyerId:{flightId:flight.id,flyerId:m.flyerId}},data:{contribution:m.paidAmount}})
    if(members.length===1)await prisma.flightFlyer.update({where:{flightId_flyerId:{flightId:flight.id,flyerId:members[0]!.flyerId}},data:{contribution:actualCost-agencyShare}})
    const updated = await prisma.flight.update({
      where: { id: flight.id },
      data: {
        code: newCode,
        date: body.date ? new Date(body.date) : undefined,
        depTime: derived?.depTime ?? body.depTime,
        arrTime: derived?.arrTime ?? body.arrTime,
        via: derived?.via ?? body.via,
        agencyShare: new Prisma.Decimal(agencyShare),
        fare: new Prisma.Decimal(actualCost).minus(agencyShare),
        ...(body.actualCost !== undefined ? sourceFields(actualCost) : {}),
        actualCost: body.actualCost !== undefined ? new Prisma.Decimal(body.actualCost) : undefined,
        spaceKg: body.spaceKg,
        mobiles: body.mobiles,
        laptops: body.laptops,
        status: body.status as FlightStatus | undefined,
        legs:
          body.legs === undefined
            ? undefined
            : {
                deleteMany: {},
                create: body.legs.map((l, order) => ({ ...l, code: l.code.toUpperCase(), date: l.date ? new Date(l.date) : null, order })),
              },
      },
    })
    // Saving the booking/cost alone never moves money. A selected account
    // settles the remaining payable, or records an actually received refund.
    if (body.accountName) {
      const tickets=await prisma.expense.findMany({where:{flightId:flight.id,category:'ticket'}})
      const delta=actualCost-tickets.reduce((total,e)=>total+num(e.amount),0)
      if(delta!==0){
        const posted=await debitCash(delta,body.accountName)
        await prisma.expense.create({data:{...sourceFields(delta),date:new Date(),category:'ticket',amount:delta,reason:`${flight.code} ticket ${delta>0?'payment':'refund'}`,flightId:flight.id,...posted}})
      }
    }
    await cacheInvalidate('dashboard')
    return c.json({ code: updated.code })
  })

  .delete('/:code', requireRole('admin'), async (c) => {
    const flight = await prisma.flight.findUnique({
      where: { code: c.req.param('code')! },
      include: { shipments: { select: { code: true } } },
    })
    if (!flight) throw notFound('Flight not found')
    // A flight's economics feed every booking's ticket share — refuse to pull
    // the rug out from under existing shipments.
    if (flight.shipments.length > 0) {
      throw badRequest(`${flight.code} has ${flight.shipments.length} booking(s) — move or delete them first`)
    }
    if (num(flight.actualCost) > 0 || num(flight.flyerPaidAmount) > 0) throw badRequest('Flight has financial history; deleting it would invent a cash refund')
    // Only flights without financial history may be removed.
    const tickets = await prisma.expense.findMany({ where: { flightId: flight.id, category: 'ticket' } })
    if (tickets.length || await prisma.payment.count({ where: { flightId: flight.id } })) throw badRequest('Flight has payment or refund history and cannot be deleted')
    await prisma.flight.delete({ where: { id: flight.id } })
    await cacheInvalidate('dashboard')
    return c.json({ ok: true })
  })

  .post('/:code/payments', requireRole('admin'), async (c) => {
    const b = z.object({ amount: z.number().positive().multipleOf(0.01), method: z.string().trim().min(1).max(100),flyerName:z.string().optional() }).parse(moneyBody(await c.req.json(), ['amount']))
    const f = await prisma.flight.findUnique({ where: { code: c.req.param('code')! },include:{flyers:{include:{flyer:true}}} })
    if (!f) throw notFound('Flight not found')
    const due = new Prisma.Decimal(f.actualCost).minus(f.agencyShare).minus(f.flyerPaidAmount)
    if (due.lt(b.amount)) throw badRequest('Amount exceeds flyer balance')
    if(Math.round(f.flyers.reduce((a,x)=>a+num(x.contribution),0)*100)!==Math.round((num(f.actualCost)-num(f.agencyShare))*100))throw badRequest('Allocate the full contribution split before recording a flyer payment')
    const member=b.flyerName?f.flyers.find(x=>x.flyer.name===b.flyerName):f.flyers.length===1?f.flyers[0]:undefined
    if(!member)throw badRequest('Select the flyer paying and allocate their contribution first')
    if(b.amount>num(member.contribution)-num(member.paidAmount))throw badRequest('Amount exceeds this flyer’s allocated balance')
    await prisma.flightFlyer.update({where:{flightId_flyerId:{flightId:f.id,flyerId:member.flyerId}},data:{paidAmount:{increment:b.amount}}})
    await creditPayment(b.method, b.amount, `${f.code} flyer ${member.flyer.name}`, undefined, 'flyer', f.id, {flyerId:member.flyerId})
    await prisma.flight.update({ where: { id: f.id }, data: { flyerPaidAmount: { increment: b.amount } } })
    return c.json({ ok: true }, 201)
  })

  .post('/:code/settlements',requireRole('admin'),async c=>{
    const b=z.object({allocations:z.array(z.object({name:z.string(),contribution:z.number().nonnegative().multipleOf(0.01),legacyPaid:z.number().nonnegative().multipleOf(0.01).default(0)})).min(1)}).parse(moneyBody(await c.req.json(), ['allocations']))
    const f=await prisma.flight.findUnique({where:{code:c.req.param('code')!},include:{flyers:{include:{flyer:true}}}})
    if(!f)throw notFound('Flight not found')
    if(b.allocations.length!==f.flyers.length||new Set(b.allocations.map(x=>x.name)).size!==f.flyers.length)throw badRequest('Include every flyer exactly once')
    const round=(n:number)=>Math.round(n*100)/100
    if(round(b.allocations.reduce((a,x)=>a+x.contribution,0))!==round(num(f.actualCost)-num(f.agencyShare)))throw badRequest('Contributions must add up to actual cost minus agency share')
    const legacy=round(num(f.flyerPaidAmount)-f.flyers.reduce((a,x)=>a+num(x.paidAmount),0))
    if(round(b.allocations.reduce((a,x)=>a+x.legacyPaid,0))!==legacy)throw badRequest('Allocate all previously unattributed receipts exactly once')
    for(const x of b.allocations){const member=f.flyers.find(m=>m.flyer.name===x.name);if(!member)throw badRequest('Unknown flyer');const paid=round(num(member.paidAmount)+x.legacyPaid);if(paid>x.contribution)throw badRequest('Contribution cannot be below received amount');await prisma.flightFlyer.update({where:{flightId_flyerId:{flightId:f.id,flyerId:member.flyerId}},data:{contribution:x.contribution,paidAmount:paid}})}
    return c.json({ok:true})
  })

  .post('/:code/flyers', requireRole('admin'), async (c) => {
    const { name } = z.object({ name: z.string().min(1) }).parse(await c.req.json())
    const flight = await prisma.flight.findUnique({ where: { code: c.req.param('code') } })
    if (!flight) throw notFound('Flight not found')
    const flyer = await prisma.flyer.findUnique({ where: { name } })
    if (!flyer || flyer.archivedAt) throw badRequest('Choose an active flyer')
    await prisma.flightFlyer.upsert({
      where: { flightId_flyerId: { flightId: flight.id, flyerId: flyer.id } },
      update: {},
      create: { flightId: flight.id, flyerId: flyer.id },
    })
    return c.json({ ok: true })
  })

  .delete('/:code/flyers/:name', requireRole('admin'), async (c) => {
    const flight = await prisma.flight.findUnique({ where: { code: c.req.param('code') } })
    if (!flight) throw notFound('Flight not found')
    const flyer = await prisma.flyer.findUnique({ where: { name: c.req.param('name') } })
    if (!flyer) throw notFound('Flyer not found')
    if (await prisma.shipment.count({where:{flightId:flight.id,flyerId:flyer.id}})) throw badRequest('Reassign this flyer’s shipments first')
    const member=await prisma.flightFlyer.findUnique({where:{flightId_flyerId:{flightId:flight.id,flyerId:flyer.id}}})
    if(member&&(num(member.paidAmount)>0||num(member.contribution)>0))throw badRequest('Flyer has settlement history or an allocated contribution')
    await prisma.flightFlyer.deleteMany({ where: { flightId: flight.id, flyerId: flyer.id } })
    return c.json({ ok: true })
  })
