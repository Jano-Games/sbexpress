/**
 * Reads an agency e-ticket PDF into flight drafts. Nothing is saved here: the
 * admin reviews, edits or drops each draft before the flights are created.
 *
 * Built against the DESH TRAVELER e-ticket layout (passenger table, PNR and
 * ticket number, one itinerary row per segment). Text is matched after
 * collapsing whitespace, so it works whether the PDF reader emits one table
 * cell or one table row per line.
 */

import { extractText, getDocumentProxy } from 'unpdf'
import { badRequest } from '../core/errors'

export interface TicketLeg {
  source: 'ticket'
  code: string
  airline: string
  date: string
  fromIata: string
  fromCity: string
  toIata: string
  toCity: string
  depTime: string
  arrTime: string
  arrDate: string
  status: string
}

export type JourneyDirection = 'to_bangladesh' | 'from_bangladesh' | 'other'

export interface TicketJourney {
  direction: JourneyDirection
  date: string
  legs: TicketLeg[]
}

export interface ParsedTicket {
  agency: string | null
  passenger: string | null
  pnr: string | null
  ticketNumber: string | null
  issuedOn: string | null
  journeys: TicketJourney[]
}

const MONTHS = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december']

/** Airport names as agencies print them; the city is what the itinerary shows. */
const AIRPORTS: [RegExp, string, string][] = [
  [/chengdu\s+tianfu/i, 'TFU', 'Chengdu'],
  [/chengdu|shuangliu/i, 'CTU', 'Chengdu'],
  [/kunming|changshui/i, 'KMG', 'Kunming'],
  [/shahjalal|dhaka/i, 'DAC', 'Dhaka'],
  [/shah\s+amanat|chattogram|chittagong/i, 'CGP', 'Chattogram'],
  [/osmani|sylhet/i, 'ZYL', 'Sylhet'],
  [/cox'?s\s+bazar/i, 'CXB', "Cox's Bazar"],
  [/guangzhou|baiyun/i, 'CAN', 'Guangzhou'],
  [/shenzhen|bao'?an/i, 'SZX', 'Shenzhen'],
  [/chongqing|jiangbei/i, 'CKG', 'Chongqing'],
  [/hongqiao/i, 'SHA', 'Shanghai'],
  [/shanghai|pudong/i, 'PVG', 'Shanghai'],
  [/daxing/i, 'PKX', 'Beijing'],
  [/beijing/i, 'PEK', 'Beijing'],
  [/xi'?an|xianyang/i, 'XIY', "Xi'an"],
  [/urumqi|diwopu/i, 'URC', 'Urumqi'],
  [/hong\s+kong/i, 'HKG', 'Hong Kong'],
  [/kolkata|netaji/i, 'CCU', 'Kolkata'],
  [/kathmandu|tribhuvan/i, 'KTM', 'Kathmandu'],
  [/bangkok|suvarnabhumi/i, 'BKK', 'Bangkok'],
  [/kuala\s+lumpur/i, 'KUL', 'Kuala Lumpur'],
  [/singapore|changi/i, 'SIN', 'Singapore'],
]

const BANGLADESH = new Set(['DAC', 'CGP', 'ZYL', 'CXB', 'JSR', 'RJH', 'SPD', 'BZL'])

/** Two segments belong to one journey when the connection is a day or less. */
const MAX_CONNECTION_HOURS = 24

const SEGMENT = new RegExp(
  [
    '([A-Z0-9]{2})\\s?-\\s?(\\d{1,4})\\s+',
    '(\\d{1,2}:\\d{2}\\s?[AP]M),\\s*([A-Za-z]+\\s+\\d{1,2},\\s*\\d{4}),?\\s*(.+?)\\s+',
    '(\\d{1,2}:\\d{2}\\s?[AP]M),\\s*([A-Za-z]+\\s+\\d{1,2},\\s*\\d{4}),?\\s*(.+?)\\s+',
    'Baggage\\s*:.*?Status\\s*:\\s*([A-Za-z]+)',
  ].join(''),
  'g',
)

function clock(value: string): string {
  const [, h, m, half] = /^(\d{1,2}):(\d{2})\s?([AP]M)$/i.exec(value.trim()) ?? []
  if (!h || !m || !half) return '—'
  const hour = (Number(h) % 12) + (half.toUpperCase() === 'PM' ? 12 : 0)
  return `${String(hour).padStart(2, '0')}:${m}`
}

function isoDay(value: string): string | null {
  const [, month, day, year] = /^([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})$/.exec(value.trim()) ?? []
  const index = MONTHS.indexOf((month ?? '').toLowerCase())
  if (index < 0 || !day || !year) return null
  return `${year}-${String(index + 1).padStart(2, '0')}-${day.padStart(2, '0')}`
}

/** "24 October 2026" → 2026-10-24. */
function isoDayFirst(value: string): string | null {
  const [, day, month, year] = /^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$/.exec(value.trim()) ?? []
  const index = MONTHS.indexOf((month ?? '').toLowerCase())
  if (index < 0 || !day || !year) return null
  return `${year}-${String(index + 1).padStart(2, '0')}-${day.padStart(2, '0')}`
}

export function airportFor(name: string): { iata: string; city: string } {
  const cleaned = name.replace(/\s+T\d+$/i, '').trim()
  for (const [pattern, iata, city] of AIRPORTS) if (pattern.test(cleaned)) return { iata, city }
  return { iata: '', city: cleaned }
}

/** At most two words before "Airlines", so table headers are not swallowed. */
const AIRLINE_HINT = /((?:[A-Z][A-Za-z-]+\s+){0,2}(?:Airlines?|Airways))\s*$/

function legsFrom(text: string): TicketLeg[] {
  const legs: TicketLeg[] = []
  let previousEnd = 0
  for (const match of text.matchAll(SEGMENT)) {
    const [whole, carrier, number, depTime, depDate, fromName, arrTime, arrDate, toName, status] = match
    const date = isoDay(depDate!)
    const arrival = isoDay(arrDate!)
    if (!date || !arrival) continue
    const before = text.slice(previousEnd, match.index)
    previousEnd = match.index + whole.length
    const from = airportFor(fromName!)
    const to = airportFor(toName!)
    legs.push({
      source: 'ticket',
      code: `${carrier}${number}`.toUpperCase(),
      airline: AIRLINE_HINT.exec(before)?.[1]?.trim() ?? '',
      date,
      fromIata: from.iata,
      fromCity: from.city,
      toIata: to.iata,
      toCity: to.city,
      depTime: clock(depTime!),
      arrTime: clock(arrTime!),
      arrDate: arrival,
      status: status!,
    })
  }
  return legs
}

const stamp = (date: string, time: string) => new Date(`${date}T${/^\d{2}:\d{2}$/.test(time) ? time : '00:00'}:00Z`).getTime()

/** Splits segments into journeys wherever the stopover is longer than a day. */
export function splitJourneys(legs: TicketLeg[]): TicketJourney[] {
  const ordered = [...legs].sort((a, b) => stamp(a.date, a.depTime) - stamp(b.date, b.depTime))
  const groups: TicketLeg[][] = []
  for (const leg of ordered) {
    const current = groups[groups.length - 1]
    const last = current?.[current.length - 1]
    const gapHours = last ? (stamp(leg.date, leg.depTime) - stamp(last.arrDate, last.arrTime)) / 3_600_000 : Infinity
    if (current && gapHours <= MAX_CONNECTION_HOURS) current.push(leg)
    else groups.push([leg])
  }
  return groups.map((group) => {
    const start = group[0]!
    const end = group[group.length - 1]!
    const direction: JourneyDirection = BANGLADESH.has(end.toIata) && !BANGLADESH.has(start.fromIata)
      ? 'to_bangladesh'
      : BANGLADESH.has(start.fromIata) && !BANGLADESH.has(end.toIata)
        ? 'from_bangladesh'
        : 'other'
    return { direction, date: start.date, legs: group }
  })
}

export function parseTicketText(raw: string): ParsedTicket {
  const text = raw.replace(/\s+/g, ' ').trim()
  const references = /Airline PNR\s+Ticket Number\s+([A-Z0-9]{5,8})\s+(\d{3}-?\d{6,11})/i.exec(text)
  const passenger = /Date of Issue\s+([A-Z][A-Z' .-]*\/[A-Z' .-]+?)\s+(?:[A-Z]{1,2}\d{6,8}\s+)?(\d{1,2}\s+[A-Za-z]+\s+\d{4})/.exec(text)
  const agency = /^([A-Z][A-Z&.' -]{2,60}?)\s+\+?\d[\d -]{6,}/.exec(text)
  return {
    agency: agency?.[1]?.trim() ?? null,
    passenger: passenger?.[1]?.replace(/\s*\/\s*/, ' / ').trim() ?? null,
    pnr: references?.[1] ?? /\bPNR\s*:?\s*([A-Z0-9]{6})\b/i.exec(text)?.[1] ?? null,
    ticketNumber: references?.[2] ?? /\b(\d{3}-\d{10})\b/.exec(text)?.[1] ?? null,
    issuedOn: passenger?.[2] ? isoDayFirst(passenger[2]) : null,
    journeys: splitJourneys(legsFrom(text)),
  }
}

const TITLES = new Set(['MR', 'MRS', 'MS', 'MISS', 'MSTR', 'MD', 'MST', 'SD', 'DR'])

export const nameTokens = (name: string) =>
  name
    .toUpperCase()
    .split(/[^A-Z]+/)
    .filter((token) => token.length > 1 && !TITLES.has(token))

/** Existing flyers that look like the ticket's passenger, best first. */
export function matchFlyers(passenger: string | null, flyers: { name: string }[]) {
  if (!passenger) return []
  const wanted = new Set(nameTokens(passenger))
  if (!wanted.size) return []
  return flyers
    .map((flyer) => {
      const tokens = nameTokens(flyer.name)
      const shared = tokens.filter((token) => wanted.has(token)).length
      return { name: flyer.name, score: tokens.length ? shared / Math.max(tokens.length, wanted.size) : 0, shared }
    })
    .filter((row) => row.shared >= Math.min(2, wanted.size))
    .sort((a, b) => b.score - a.score)
    .slice(0, 3)
    .map(({ name, score }) => ({ name, score: Math.round(score * 100) / 100 }))
}

const MAX_TICKET_BYTES = 700 * 1024

/** Text of an uploaded PDF, sent as base64 in a JSON body. */
export async function ticketText(base64: string): Promise<string> {
  const bytes = Buffer.from(base64.replace(/^data:application\/pdf;base64,/, ''), 'base64')
  if (!bytes.length) throw badRequest('Choose a ticket PDF')
  if (bytes.length > MAX_TICKET_BYTES) throw badRequest('Ticket PDF is too large (max 700 KB)')
  if (bytes.subarray(0, 5).toString('latin1') !== '%PDF-') throw badRequest('This file is not a PDF')
  try {
    const pdf = await getDocumentProxy(new Uint8Array(bytes))
    const { text } = await extractText(pdf, { mergePages: true })
    return text
  } catch {
    throw badRequest('Could not read this PDF')
  }
}
