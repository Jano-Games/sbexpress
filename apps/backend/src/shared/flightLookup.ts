/**
 * Flight-schedule lookup for the Add flight form, backed by AeroDataBox
 * (RapidAPI). The free tier is ~800 requests/month, so answers are cached in
 * Redis; without a key the lookup serves deterministic, clearly-labeled
 * sample data so the flow stays testable without spending quota.
 */

import { config } from '../core/config'
import { HttpError, badRequest } from '../core/errors'
import { cacheGetJson, cacheSetJson } from '../core/redis'

const BASE_URL = 'https://aerodatabox.p.rapidapi.com'
const CACHE_TTL_SECONDS = 15 * 60

export const normalizeFlightNumber = (input: string): string => input.toUpperCase().replace(/\s+/g, '')

/**
 * An airline designator followed by 1-4 digits. The designator is two
 * characters of which at least one is a letter (`BS`, `9W`, `U2`) or a
 * three-letter ICAO code — requiring the letter stops a bare `325` being read
 * as airline "32", flight "5".
 */
const FLIGHT_NUMBER = /^(?:[A-Z]{2}|[A-Z]\d|\d[A-Z]|[A-Z]{3})\d{1,4}$/

export interface FlightLookupResult {
  found: boolean
  sample?: boolean
  flight?: {
    code: string
    airline: string | null
    from: { iata: string | null; city: string | null }
    to: { iata: string | null; city: string | null }
    /** Local wall-clock times, HH:mm — what the form fields store. */
    depTime: string | null
    arrTime: string | null
    status: string | null
  }
}

interface RawMovement {
  airport?: { iata?: string; municipalityName?: string }
  scheduledTime?: { utc?: string; local?: string }
  revisedTime?: { utc?: string; local?: string }
}

interface RawFlight {
  number?: string
  status?: string
  airline?: { name?: string }
  departure?: RawMovement
  arrival?: RawMovement
}

/** "2026-08-31 13:40+08:00" → "13:40". */
const localHhMm = (movement: RawMovement | undefined): string | null => {
  const local = movement?.revisedTime?.local ?? movement?.scheduledTime?.local
  return local?.match(/\d{2}:\d{2}/)?.[0] ?? null
}

function sampleResult(code: string): FlightLookupResult {
  return {
    found: true,
    sample: true,
    flight: {
      code,
      // Named so it is obvious in any payload or screenshot that these times
      // are invented — set AERODATABOX_RAPIDAPI_KEY for live schedules.
      airline: 'Mock Airways (sample data)',
      from: { iata: 'CTU', city: 'Chengdu' },
      to: { iata: 'DAC', city: 'Dhaka' },
      depTime: '13:40',
      arrTime: '17:25',
      status: 'Scheduled',
    },
  }
}

export async function lookupFlight(codeInput: string, date: string): Promise<FlightLookupResult> {
  const code = normalizeFlightNumber(codeInput)
  if (!FLIGHT_NUMBER.test(code)) throw badRequest(`"${codeInput}" is not a valid flight number`)

  if (!config.aerodataboxKey) return sampleResult(code)

  const cacheKey = `flightlookup:${code}:${date}`
  const cached = await cacheGetJson<FlightLookupResult>(cacheKey)
  if (cached) return cached

  const response = await fetch(`${BASE_URL}/flights/number/${code}/${date}?dateLocalRole=Both`, {
    headers: {
      'X-RapidAPI-Key': config.aerodataboxKey,
      'X-RapidAPI-Host': 'aerodatabox.p.rapidapi.com',
    },
    // A hanging provider must not hold the form open indefinitely.
    signal: AbortSignal.timeout(10_000),
  })

  // 404 means "no such flight that day" — a real answer, not a failure.
  if (response.status === 404) {
    const miss: FlightLookupResult = { found: false }
    await cacheSetJson(cacheKey, miss, 5 * 60)
    return miss
  }
  if (!response.ok) throw new HttpError(502, `Flight provider returned ${response.status}`)

  const payload = (await response.json()) as RawFlight[] | RawFlight
  const first = Array.isArray(payload) ? payload[0] : payload
  if (!first) {
    const miss: FlightLookupResult = { found: false }
    await cacheSetJson(cacheKey, miss, 5 * 60)
    return miss
  }

  const result: FlightLookupResult = {
    found: true,
    flight: {
      code: normalizeFlightNumber(first.number ?? code),
      airline: first.airline?.name ?? null,
      from: {
        iata: first.departure?.airport?.iata ?? null,
        city: first.departure?.airport?.municipalityName ?? null,
      },
      to: {
        iata: first.arrival?.airport?.iata ?? null,
        city: first.arrival?.airport?.municipalityName ?? null,
      },
      depTime: localHhMm(first.departure),
      arrTime: localHhMm(first.arrival),
      status: first.status ?? null,
    },
  }
  await cacheSetJson(cacheKey, result, CACHE_TTL_SECONDS)
  return result
}

/** "mu5842 + MU2035" or "MU5842, MU2035" → ["MU5842", "MU2035"]. */
export const splitFlightNumbers = (input: string): string[] =>
  input
    .split(/[+,]/)
    .map(normalizeFlightNumber)
    .filter(Boolean)

export interface RouteLeg {
  code: string
  /** The day the leg was found on; a connection may leave the next day. */
  date: string
  found: boolean
  airline: string | null
  fromIata: string
  fromCity: string
  toIata: string
  toCity: string
  depTime: string | null
  arrTime: string | null
  status: string | null
}

export interface RouteLookupResult {
  /** False when the server has no flight data key: nothing is looked up. */
  configured: boolean
  /** Every leg was found on the schedule. */
  found: boolean
  legs: RouteLeg[]
  /** Numbers not found on the schedule that day or the next. */
  missing: string[]
  depTime: string | null
  arrTime: string | null
  via: string | null
}

const MAX_ROUTE_LEGS = 4

const nextDay = (date: string): string => {
  const day = new Date(`${date}T00:00:00Z`)
  day.setUTCDate(day.getUTCDate() + 1)
  return day.toISOString().slice(0, 10)
}

const routeLeg = (code: string, date: string, result: FlightLookupResult): RouteLeg => {
  const flight = result.found ? result.flight : undefined
  return {
    code,
    date,
    found: Boolean(flight),
    airline: flight?.airline ?? null,
    fromIata: flight?.from.iata ?? '',
    fromCity: flight?.from.city ?? '',
    toIata: flight?.to.iata ?? '',
    toCity: flight?.to.city ?? '',
    depTime: flight?.depTime ?? null,
    arrTime: flight?.arrTime ?? null,
    status: flight?.status ?? null,
  }
}

/**
 * Schedule times for a direct flight or a connection typed as
 * "MU5842+MU2035". Each later leg is looked up on the day the previous leg
 * was found, then the next day, since a connection often leaves overnight.
 * Without a flight data key nothing is invented: `configured` is false.
 */
export async function lookupRoute(codeInput: string, date: string): Promise<RouteLookupResult> {
  const codes = splitFlightNumbers(codeInput)
  if (!codes.length) throw badRequest('Enter the airline flight number')
  if (codes.length > MAX_ROUTE_LEGS) throw badRequest(`A connection can have at most ${MAX_ROUTE_LEGS} flights`)
  const invalid = codes.find((code) => !FLIGHT_NUMBER.test(code))
  if (invalid) throw badRequest(`"${invalid}" is not a valid flight number`)

  if (!config.aerodataboxKey) {
    return { configured: false, found: false, legs: [], missing: [], depTime: null, arrTime: null, via: null }
  }

  const legs: RouteLeg[] = []
  let day = date
  for (const [index, code] of codes.entries()) {
    let leg = routeLeg(code, day, await lookupFlight(code, day))
    if (!leg.found && index > 0) {
      const later = nextDay(day)
      const retry = routeLeg(code, later, await lookupFlight(code, later))
      if (retry.found) leg = retry
    }
    if (leg.found) day = leg.date
    legs.push(leg)
  }

  const stops = legs
    .slice(0, -1)
    .map((leg) => [leg.toIata, leg.toCity].filter(Boolean).join(' '))
    .filter(Boolean)
  return {
    configured: true,
    found: legs.every((leg) => leg.found),
    legs,
    missing: legs.filter((leg) => !leg.found).map((leg) => leg.code),
    depTime: legs[0]!.depTime,
    arrTime: legs[legs.length - 1]!.arrTime,
    via: legs.length > 1 ? (stops.length ? `Via ${stops.join(', ')}` : null) : 'Direct',
  }
}
