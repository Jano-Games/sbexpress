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
