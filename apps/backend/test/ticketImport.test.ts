import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Hono, type Context, type Next } from 'hono'
import PDFDocument from 'pdfkit'
import type { AppEnv, Role } from '../src/modules/auth'

const db = vi.hoisted(() => ({ flyer: { findMany: vi.fn() } }))
vi.mock('../src/core/db', () => ({ prisma: db }))
vi.mock('../src/core/redis', () => ({ cacheInvalidate: vi.fn(), cacheGetJson: vi.fn(), cacheSetJson: vi.fn() }))
vi.mock('../src/shared/settings', () => ({ getSettings: vi.fn(async () => ({ threshold: 0.5 })) }))
vi.mock('../src/shared/flightLookup', () => ({ lookupFlight: vi.fn() }))
vi.mock('../src/shared/ledger', () => ({ creditPayment: vi.fn(), debitCash: vi.fn() }))
vi.mock('../src/modules/auth', () => ({ requireRole: (...roles: Role[]) => async (c: Context<AppEnv>, next: Next) => {
  if (!roles.includes(c.get('user').role)) return c.json({ error: 'Forbidden' }, 403)
  await next()
} }))
const { flightRoutes } = await import('../src/modules/flights')
const { handleError } = await import('../src/core/errors')
const { matchFlyers, parseTicketText, splitJourneys } = await import('../src/shared/ticketImport')

// Synthetic passenger and numbers; real tickets carry personal data.
const SEGMENTS: [string, string, string, string, string][] = [
  ['MU-5842', '9:00 PM, November 13, 2026,', 'Chengdu Tianfu International Airport T2', '10:30 PM, November 13, 2026,', 'Kunming Changshui International Airport'],
  ['MU-2035', '12:10 PM, November 14, 2026,', 'Kunming Changshui International Airport', '1:00 PM, November 14, 2026,', 'Hazrat Shahjalal International Airport'],
  ['MU-2036', '2:00 PM, November 23, 2026,', 'Hazrat Shahjalal International Airport', '6:20 PM, November 23, 2026,', 'Kunming Changshui International Airport'],
  ['MU-5843', '8:40 AM, November 24, 2026,', 'Kunming Changshui International Airport', '10:05 AM, November 24, 2026,', 'Chengdu Shuangliu International Airport T2'],
]

/** One table row per line, as unpdf reads the agency PDF. */
const rowLayout = [
  'DESH TRAVELER',
  '+88 01700000000',
  'Electronic Ticket',
  'Passenger Information',
  'Airline PNR Ticket Number',
  'TEST01 781-0000000001',
  'Itinerary Information',
  'Flight From To Info',
  ...SEGMENTS.flatMap(([code, dep, from, arr, to]) => [
    'China Eastern',
    `Airlines ${code}`,
    dep,
    from,
    arr,
    to,
    'Baggage : 02 Pcs',
    'Class :',
    'Duration :',
    'Status : Confirmed',
  ]),
  'Important Notice For Passengers',
  'Passenger Information Passport Number Frequent Flyer Number Date of Issue',
  'KHAN / MD ARIF HOSSAIN SD X01234567 24 October 2026',
]

/** One table cell per line, as other readers order the same page. */
const cellLayout = rowLayout.flatMap((line) =>
  line === 'Airline PNR Ticket Number'
    ? ['Airline PNR', 'Ticket Number']
    : line === 'TEST01 781-0000000001'
      ? ['TEST01', '781-0000000001']
      : line.startsWith('KHAN /')
        ? ['KHAN / MD ARIF HOSSAIN SD', 'X01234567', '24 October 2026']
        : [line],
)

function pdfOf(lines: string[]): Promise<string> {
  return new Promise((resolve) => {
    const doc = new PDFDocument({ size: 'A4', margin: 40 })
    const chunks: Buffer[] = []
    doc.on('data', (chunk: Buffer) => chunks.push(chunk))
    doc.on('end', () => resolve(Buffer.concat(chunks).toString('base64')))
    doc.fontSize(9)
    for (const line of lines) doc.text(line)
    doc.end()
  })
}

function appFor(role: Role) {
  const app = new Hono<AppEnv>()
  app.onError(handleError)
  app.use('*', async (c, next) => {
    c.set('user', { id: 'unit-test', name: 'Unit test', email: 'unit@example.invalid', role, roleLabel: role })
    await next()
  })
  return app.route('/', flightRoutes)
}

const post = (role: Role, body: unknown) =>
  appFor(role).request('/ticket', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })

beforeEach(() => {
  vi.clearAllMocks()
  db.flyer.findMany.mockResolvedValue([{ name: 'KHAN Arif Hossain' }, { name: 'RAHMAN Sumi' }])
})

describe('ticket text parsing', () => {
  for (const [layout, lines] of [['row', rowLayout], ['cell', cellLayout]] as const) {
    it(`reads the ${layout} layout into two journeys`, () => {
      const ticket = parseTicketText(lines.join('\n'))
      expect(ticket).toMatchObject({
        agency: 'DESH TRAVELER',
        passenger: 'KHAN / MD ARIF HOSSAIN SD',
        pnr: 'TEST01',
        ticketNumber: '781-0000000001',
        issuedOn: '2026-10-24',
      })
      expect(JSON.stringify(ticket)).not.toContain('X01234567')
      expect(ticket.journeys.map((j) => [j.direction, j.date, j.legs.map((l) => l.code).join('+')])).toEqual([
        ['to_bangladesh', '2026-11-13', 'MU5842+MU2035'],
        ['from_bangladesh', '2026-11-23', 'MU2036+MU5843'],
      ])
      expect(ticket.journeys[0]!.legs[0]).toMatchObject({
        source: 'ticket',
        airline: 'China Eastern Airlines',
        fromIata: 'TFU',
        fromCity: 'Chengdu',
        toIata: 'KMG',
        depTime: '21:00',
        arrTime: '22:30',
      })
      expect(ticket.journeys[0]!.legs[1]).toMatchObject({ toIata: 'DAC', toCity: 'Dhaka', depTime: '12:10', arrTime: '13:00' })
      expect(ticket.journeys[1]!.legs[1]).toMatchObject({ toIata: 'CTU', depTime: '08:40' })
    })
  }

  it('keeps a long stopover as its own journey', () => {
    const leg = (date: string, from: string, to: string, dep: string, arr: string) =>
      ({ source: 'ticket' as const, code: 'MU1', airline: '', date, arrDate: date, fromIata: from, fromCity: '', toIata: to, toCity: '', depTime: dep, arrTime: arr, status: 'Confirmed' })
    expect(splitJourneys([leg('2026-11-14', 'KMG', 'DAC', '12:00', '13:00'), leg('2026-11-10', 'CTU', 'KMG', '09:00', '10:00')])
      .map((j) => j.direction)).toEqual(['other', 'to_bangladesh'])
  })

  it('suggests flyers by shared name parts and ignores titles', () => {
    expect(matchFlyers('KHAN / MD ARIF HOSSAIN SD', [{ name: 'KHAN Arif Hossain' }, { name: 'KHAN Rafi' }, { name: 'MD SD' }]))
      .toEqual([{ name: 'KHAN Arif Hossain', score: 1 }])
    expect(matchFlyers(null, [{ name: 'KHAN Arif Hossain' }])).toEqual([])
  })
})

describe('POST /flights/ticket', () => {
  it('turns an uploaded PDF into flight drafts and a flyer suggestion', async () => {
    const response = await post('admin', { file: await pdfOf(rowLayout) })
    expect(response.status).toBe(200)
    const body = await response.json() as {
      ticket: Record<string, unknown>
      flyerMatches: { name: string }[]
      journeys: { direction: string; legs: { code: string }[] }[]
    }
    expect(body.ticket).toEqual({
      agency: 'DESH TRAVELER',
      passenger: 'KHAN / MD ARIF HOSSAIN SD',
      pnr: 'TEST01',
      ticketNumber: '781-0000000001',
      issuedOn: '2026-10-24',
    })
    expect(body.flyerMatches.map((m) => m.name)).toEqual(['KHAN Arif Hossain'])
    expect(body.journeys.map((j) => j.legs.map((l) => l.code).join('+'))).toEqual(['MU5842+MU2035', 'MU2036+MU5843'])
    expect(JSON.stringify(body)).not.toContain('X01234567')
    expect(db.flyer.findMany).toHaveBeenCalledWith({ where: { archivedAt: null }, select: { name: true } })
  })

  it('explains files it cannot use', async () => {
    const notPdf = await post('admin', { file: Buffer.from('hello').toString('base64') })
    expect(notPdf.status).toBe(400)
    expect(await notPdf.json()).toMatchObject({ error: 'This file is not a PDF' })
    const noSegments = await post('admin', { file: await pdfOf(['Hotel booking', 'Room 12']) })
    expect(noSegments.status).toBe(400)
    expect(await noSegments.json()).toMatchObject({ error: expect.stringContaining('No flight segments') })
  })

  it('is admin-only', async () => {
    expect((await post('hub', { file: 'JVBERi0=' })).status).toBe(403)
  })
})
