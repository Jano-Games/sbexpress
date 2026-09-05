import { Hono } from 'hono'
import { z } from 'zod'
import { prisma } from '../core/db'
import { badRequest, notFound } from '../core/errors'
import { requireRole, type AppEnv } from './auth'
import { FLIGHT_LABEL } from '../shared/status'
import { num, isoDate } from '../shared/serialize'

/** Display convention across the app: plain "First Last". */
const composeName = (firstName: string, lastName: string): string =>
  `${firstName.trim()} ${lastName.trim()}`.trim()

function flyerDto(f: {
  name: string
  firstName: string
  lastName: string
  cnPhone: string
  cnWhatsapp: boolean
  bdPhone: string
  bdWhatsapp: boolean
  university: string
  batch: string
  program: string
  wechat: string
  cnAddress: string
  homeAddress: string
  emergencyContact: string
  docStudentId: boolean
  docVisa: boolean
  docAdmission: boolean
}) {
  return {
    name: f.name,
    firstName: f.firstName,
    lastName: f.lastName,
    cnPhone: f.cnPhone,
    cnWhatsapp: f.cnWhatsapp,
    bdPhone: f.bdPhone,
    bdWhatsapp: f.bdWhatsapp,
    university: f.university,
    batch: f.batch,
    program: f.program,
    wechat: f.wechat,
    cnAddress: f.cnAddress,
    homeAddress: f.homeAddress,
    emergencyContact: f.emergencyContact,
    docStudentId: f.docStudentId,
    docVisa: f.docVisa,
    docAdmission: f.docAdmission,
  }
}

const flyerFields = {
  firstName: z.string().min(1, 'First name required'),
  lastName: z.string().default(''),
  cnPhone: z.string().default('—'),
  cnWhatsapp: z.boolean().default(false),
  bdPhone: z.string().default('—'),
  bdWhatsapp: z.boolean().default(false),
  university: z.string().default('—'),
  batch: z.string().default(''),
  program: z.string().default('—'),
  wechat: z.string().default('—'),
  cnAddress: z.string().default('—'),
  homeAddress: z.string().default('—'),
  emergencyContact: z.string().default('—'),
}

const normalizeBatch = (batch: string): string =>
  batch.trim() ? `Batch ${batch.replace(/^Batch\s*/i, '').trim()}` : '—'

export const flyerRoutes = new Hono<AppEnv>()
  .get('/', requireRole('admin'), async (c) => {
    const flyers = await prisma.flyer.findMany({ orderBy: { createdAt: 'asc' } })
    return c.json({ flyers: flyers.map(flyerDto) })
  })

  .post('/', requireRole('admin'), async (c) => {
    const body = z
      .object({
        ...flyerFields,
        /** Optional flight to assign the new flyer to in the same step. */
        assignFlightCode: z.string().optional(),
      })
      .parse(await c.req.json())

    const name = composeName(body.firstName, body.lastName)
    const existing = await prisma.flyer.findUnique({ where: { name } })
    if (existing) throw badRequest(`Flyer ${name} already exists`)

    const flyer = await prisma.flyer.create({
      data: {
        name,
        firstName: body.firstName.trim(),
        lastName: body.lastName.trim(),
        cnPhone: body.cnPhone,
        cnWhatsapp: body.cnWhatsapp,
        bdPhone: body.bdPhone,
        bdWhatsapp: body.bdWhatsapp,
        university: body.university,
        batch: normalizeBatch(body.batch),
        program: body.program,
        wechat: body.wechat,
        cnAddress: body.cnAddress,
        homeAddress: body.homeAddress,
        emergencyContact: body.emergencyContact,
        docStudentId: true,
      },
    })

    if (body.assignFlightCode) {
      const flight = await prisma.flight.findUnique({ where: { code: body.assignFlightCode } })
      if (!flight) throw badRequest(`Unknown flight ${body.assignFlightCode}`)
      await prisma.flightFlyer.create({ data: { flightId: flight.id, flyerId: flyer.id } })
    }
    return c.json({ name: flyer.name }, 201)
  })

  .patch('/:name', requireRole('admin'), async (c) => {
    const flyer = await prisma.flyer.findUnique({ where: { name: c.req.param('name')! } })
    if (!flyer) throw notFound('Flyer not found')
    const body = z
      .object({
        ...flyerFields,
        docStudentId: z.boolean().optional(),
        docVisa: z.boolean().optional(),
        docAdmission: z.boolean().optional(),
      })
      .partial()
      .parse(await c.req.json())

    const firstName = (body.firstName ?? flyer.firstName).trim()
    const lastName = (body.lastName ?? flyer.lastName).trim()
    const name = composeName(firstName, lastName) || flyer.name
    if (name !== flyer.name) {
      const clash = await prisma.flyer.findUnique({ where: { name } })
      if (clash) throw badRequest(`Flyer ${name} already exists`)
    }
    const updated = await prisma.flyer.update({
      where: { id: flyer.id },
      data: {
        ...body,
        firstName,
        lastName,
        name,
        batch: body.batch === undefined ? undefined : normalizeBatch(body.batch),
      },
    })
    return c.json({ name: updated.name })
  })

  .delete('/:name', requireRole('admin'), async (c) => {
    const flyer = await prisma.flyer.findUnique({ where: { name: c.req.param('name')! } })
    if (!flyer) throw notFound('Flyer not found')
    // Flight assignments cascade away with the flyer.
    await prisma.flyer.delete({ where: { id: flyer.id } })
    return c.json({ ok: true })
  })

  .get('/:name', requireRole('admin'), async (c) => {
    const flyer = await prisma.flyer.findUnique({
      where: { name: c.req.param('name') },
      include: { flights: { include: { flight: { include: { shipments: true } } } } },
    })
    if (!flyer) throw notFound('Flyer not found')

    const flights = flyer.flights
      .map((x) => x.flight)
      .sort((a, b) => a.date.getTime() - b.date.getTime())
      .map((f) => ({
        code: f.code,
        date: isoDate(f.date),
        depTime: f.depTime,
        arrTime: f.arrTime,
        spaceKg: f.spaceKg,
        mobiles: f.mobiles,
        laptops: f.laptops,
        bookedKg: Math.round(f.shipments.reduce((a, s) => a + num(s.bookedKg), 0) * 10) / 10,
        status: f.status,
        statusLabel: FLIGHT_LABEL[f.status],
      }))

    const upcoming = flights.filter((f) => f.status === 'upcoming')
    const past = flights.filter((f) => f.status !== 'upcoming')

    return c.json({
      flyer: {
        ...flyerDto(flyer),
        flights,
        totalKg: Math.round(flights.reduce((a, f) => a + f.bookedKg, 0) * 10) / 10,
        nextFlight: upcoming[0] ?? null,
        lastFlight: past[past.length - 1] ?? null,
      },
    })
  })
