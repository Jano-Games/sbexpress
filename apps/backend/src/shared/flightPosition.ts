/**
 * Track: where a flight in the air is right now, from AeroDataBox with the
 * aircraft position. The monthly allowance is small, so one answer is kept for
 * 15 minutes per flight, a flight can be refreshed at most 6 times a day, and
 * all flights together at most TRACK_DAILY_CALLS times a day. Without a key
 * the server answers with clearly marked sample data so the screen can be
 * tried without spending anything.
 */

import type { Prisma } from '@prisma/client'
import { cacheGetJson, cacheSetJson, redis } from '../core/redis'
import { flightDataKey, normalizeFlightNumber, providerFetch } from './flightLookup'
import { legCancelled, legLanded, legLeft, readTracking } from './flightTrackingView'

const MINUTE = 60_000

export const POSITION = {
  /** One answer per flight is kept this long; Refresh waits for it to pass. */
  freshMs: 15 * MINUTE,
  perFlightPerDay: 6,
  dailyCalls: Number(process.env.TRACK_DAILY_CALLS) || 24,
}

/** Where the usual airports are, for drawing the whole route. */
export const AIRPORTS: Record<string, [number, number]> = {
  DAC: [23.8431, 90.3978], CGP: [22.2496, 91.8133], ZYL: [24.9632, 91.8668],
  CTU: [30.5785, 103.9471], TFU: [30.3125, 104.4417], KMG: [25.1019, 102.9292], CAN: [23.3924, 113.2988],
  SZX: [22.6393, 113.8107], PVG: [31.1443, 121.8083], SHA: [31.1979, 121.3363], PEK: [40.0799, 116.6031],
  PKX: [39.5098, 116.4105], HKG: [22.308, 113.9185], XIY: [34.4471, 108.7516], CKG: [29.7192, 106.6417],
  WUH: [30.7838, 114.2081], CSX: [28.1892, 113.2196], NNG: [22.6083, 108.1724], XMN: [24.544, 118.1277],
  HGH: [30.2295, 120.4344], NKG: [31.742, 118.862], YIW: [29.3447, 120.0322],
  BKK: [13.69, 100.7501], KUL: [2.7456, 101.7099], SIN: [1.3644, 103.9915], CCU: [22.6547, 88.4467],
  RGN: [16.9073, 96.1332], KTM: [27.6966, 85.3591], DEL: [28.5562, 77.1], DXB: [25.2532, 55.3657],
}

export interface TrackPlace {
  iata: string
  city: string
  lat: number | null
  lon: number | null
}

export interface FlightPosition {
  /** The flight number of the leg in the air, e.g. MU2039. */
  legCode: string
  from: TrackPlace
  to: TrackPlace
  /** Every airport on the trip in order, for the route line. */
  route: TrackPlace[]
  position: {
    lat: number
    lon: number
    altitudeM: number | null
    speedKmh: number | null
    headingDeg: number | null
    reportedAt: string | null
  } | null
  /** Local landing time at the leg's airport and minutes late, when known. */
  landsAt: string | null
  arrLateMin: number | null
  /** 0–100 along the leg, from the distance flown. */
  progress: number | null
  checkedAt: string
  sample: boolean
}

export interface PositionAnswer {
  inAir: boolean
  track: FlightPosition | null
  /** When Refresh can ask again, and how many refreshes this flight has left today. */
  nextRefreshAt: string | null
  refreshesLeft: number
  /** Why there is no fresh answer: 'limit' (used up today) or 'unavailable' (the airline has no position). */
  note: 'limit' | 'unavailable' | null
}

interface LegSource {
  code: string
  date: Date | null
  fromIata: string
  fromCity: string
  toIata: string
  toCity: string
  tracking: Prisma.JsonValue | null
}

export interface PositionFlightSource {
  id: string
  date: Date
  status: string
  airlineStatus: string | null
  legs: LegSource[]
}

const place = (iata: string, city: string, lat?: number | null, lon?: number | null): TrackPlace => {
  const known = AIRPORTS[iata.trim().toUpperCase()]
  return { iata, city: city || iata, lat: lat ?? known?.[0] ?? null, lon: lon ?? known?.[1] ?? null }
}

/** The leg in the air now: the first that has left and not landed, else the first not landed. */
export function currentLeg(legs: LegSource[]): LegSource | null {
  const tracks = legs.map((leg) => readTracking(leg.tracking))
  const inAir = legs.findIndex((_, i) => legLeft(tracks[i]!) && !legLanded(tracks[i]!))
  if (inAir >= 0) return legs[inAir]!
  const next = legs.findIndex((_, i) => !legLanded(tracks[i]!) && !legCancelled(tracks[i]!))
  return next >= 0 ? legs[next]! : null
}

export const isInAir = (f: PositionFlightSource): boolean =>
  f.status === 'departed' || (f.status === 'upcoming' && f.airlineStatus === 'on_the_way')

/** Great-circle distance in km. */
function km(a: [number, number], b: [number, number]): number {
  const rad = Math.PI / 180
  const dLat = (b[0] - a[0]) * rad
  const dLon = (b[1] - a[1]) * rad
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a[0] * rad) * Math.cos(b[0] * rad) * Math.sin(dLon / 2) ** 2
  return 6371 * 2 * Math.asin(Math.min(1, Math.sqrt(h)))
}

export function progressOf(from: TrackPlace, to: TrackPlace, at: { lat: number; lon: number } | null): number | null {
  if (!at || from.lat === null || from.lon === null || to.lat === null || to.lon === null) return null
  const total = km([from.lat, from.lon], [to.lat, to.lon])
  if (total < 1) return null
  const left = km([at.lat, at.lon], [to.lat, to.lon])
  return Math.max(0, Math.min(100, Math.round((1 - left / total) * 100)))
}

interface RawLocation {
  lat?: number
  lon?: number
  altitude?: { meter?: number }
  pressureAltitude?: { meter?: number }
  groundSpeed?: { kmPerHour?: number }
  trueTrack?: { deg?: number }
  reportedAtUtc?: string
}
interface RawEnd {
  airport?: { iata?: string; municipalityName?: string; location?: { lat?: number; lon?: number } }
  scheduledTime?: { utc?: string; local?: string }
  revisedTime?: { utc?: string; local?: string }
  predictedTime?: { utc?: string; local?: string }
}
interface RawFlight {
  status?: string
  location?: RawLocation
  departure?: RawEnd
  arrival?: RawEnd
}

const localTime = (end: RawEnd | undefined): string | null => {
  const value = end?.revisedTime?.local ?? end?.predictedTime?.local ?? end?.scheduledTime?.local
  return value ? (/(\d{2}:\d{2})/.exec(value)?.[1] ?? null) : null
}
const utcMs = (value: string | undefined): number | null => {
  if (!value) return null
  const ms = Date.parse(value.replace(' ', 'T').replace(/Z?$/, 'Z'))
  return Number.isNaN(ms) ? null : ms
}

/** Turns the airline's answer into what the Track screen shows. */
export function readPosition(raw: RawFlight | null, leg: LegSource, legs: LegSource[], now: Date): FlightPosition {
  const depLoc = raw?.departure?.airport?.location
  const arrLoc = raw?.arrival?.airport?.location
  const from = place(leg.fromIata, leg.fromCity, depLoc?.lat, depLoc?.lon)
  const to = place(leg.toIata, leg.toCity, arrLoc?.lat, arrLoc?.lon)
  const loc = raw?.location
  const position =
    loc && typeof loc.lat === 'number' && typeof loc.lon === 'number'
      ? {
          lat: loc.lat,
          lon: loc.lon,
          altitudeM: Math.round(loc.altitude?.meter ?? loc.pressureAltitude?.meter ?? 0) || null,
          speedKmh: loc.groundSpeed?.kmPerHour !== undefined ? Math.round(loc.groundSpeed.kmPerHour) : null,
          headingDeg: loc.trueTrack?.deg !== undefined ? Math.round(loc.trueTrack.deg) : null,
          reportedAt: loc.reportedAtUtc ? new Date(utcMs(loc.reportedAtUtc) ?? now.getTime()).toISOString() : null,
        }
      : null
  const planned = utcMs(raw?.arrival?.scheduledTime?.utc)
  const latest = utcMs(raw?.arrival?.revisedTime?.utc ?? raw?.arrival?.predictedTime?.utc)
  const route: TrackPlace[] = []
  for (const l of legs) {
    if (!route.length) route.push(place(l.fromIata, l.fromCity))
    route.push(place(l.toIata, l.toCity))
  }
  for (const r of route) {
    if (r.iata === from.iata && from.lat !== null) Object.assign(r, { lat: from.lat, lon: from.lon })
    if (r.iata === to.iata && to.lat !== null) Object.assign(r, { lat: to.lat, lon: to.lon })
  }
  return {
    legCode: leg.code,
    from,
    to,
    route,
    position,
    landsAt: localTime(raw?.arrival),
    arrLateMin: planned !== null && latest !== null ? Math.round((latest - planned) / MINUTE) : null,
    progress: progressOf(from, to, position),
    checkedAt: now.toISOString(),
    sample: false,
  }
}

/** Sample answer without a key: the plane two thirds of the way along the leg. */
export function samplePosition(leg: LegSource, legs: LegSource[], now: Date): FlightPosition {
  const base = readPosition(null, leg, legs, now)
  const { from, to } = base
  if (from.lat === null || from.lon === null || to.lat === null || to.lon === null) return { ...base, sample: true }
  const t = 0.64
  const lat = from.lat + (to.lat - from.lat) * t
  const lon = from.lon + (to.lon - from.lon) * t
  const heading = Math.round((Math.atan2(to.lon - from.lon, to.lat - from.lat) * 180) / Math.PI + 360) % 360
  const position = { lat, lon, altitudeM: 10670, speedKmh: 812, headingDeg: heading, reportedAt: now.toISOString() }
  return { ...base, position, progress: progressOf(from, to, position), sample: true }
}

const day = (now: Date) => now.toISOString().slice(0, 10)
const cacheKey = (flightId: string) => `flightpos:${flightId}`
const countKey = (flightId: string, now: Date) => `flightpos:count:${flightId}:${day(now)}`

async function usedToday(flightId: string, now: Date): Promise<number> {
  const raw = await redis.get(countKey(flightId, now))
  return Number(raw) || 0
}

/** Takes one refresh for this flight and one call from the shared allowance. */
async function takeRefresh(flightId: string, now: Date): Promise<boolean> {
  const mine = countKey(flightId, now)
  const used = await redis.incr(mine)
  if (used === 1) await redis.expire(mine, 2 * 86400)
  if (used > POSITION.perFlightPerDay) return false
  const all = `flightpos:calls:${day(now)}`
  const calls = await redis.incr(all)
  if (calls === 1) await redis.expire(all, 2 * 86400)
  return calls <= POSITION.dailyCalls
}

async function askPosition(leg: LegSource, flightDate: Date): Promise<RawFlight | null> {
  const code = normalizeFlightNumber(leg.code)
  const legDay = (leg.date ?? flightDate).toISOString().slice(0, 10)
  const response = await providerFetch(`/flights/number/${code}/${legDay}?dateLocalRole=Departure&withAircraftImage=false&withLocation=true`, flightDataKey())
  if (response.status === 404 || response.status === 204) return null
  if (!response.ok) throw new Error(`Flight provider returned ${response.status}`)
  const payload = (await response.json().catch(() => null)) as RawFlight[] | RawFlight | null
  const rows = Array.isArray(payload) ? payload : payload ? [payload] : []
  return rows.find((row) => row.departure?.scheduledTime?.local?.startsWith(legDay)) ?? rows[0] ?? null
}

/**
 * Where the flight is. Opening Track shows the kept answer, or asks once when
 * there is none; `refresh` asks again when the kept one is 15 minutes old and
 * the day's refreshes are not used up.
 */
export async function flightPosition(f: PositionFlightSource, refresh: boolean, now = new Date()): Promise<PositionAnswer> {
  const leg = currentLeg(f.legs)
  if (!isInAir(f) || !leg) return { inAir: false, track: null, nextRefreshAt: null, refreshesLeft: 0, note: null }
  const kept = await cacheGetJson<FlightPosition>(cacheKey(f.id))
  const used = await usedToday(f.id, now)
  const left = () => Math.max(0, POSITION.perFlightPerDay - used)
  const nextAt = (track: FlightPosition | null) =>
    track ? new Date(Date.parse(track.checkedAt) + POSITION.freshMs).toISOString() : null
  const stale = !kept || now.getTime() - Date.parse(kept.checkedAt) >= POSITION.freshMs
  if (kept && (!refresh || !stale)) return { inAir: true, track: kept, nextRefreshAt: nextAt(kept), refreshesLeft: left(), note: null }
  if (!flightDataKey()) {
    const track = samplePosition(leg, f.legs, now)
    return { inAir: true, track, nextRefreshAt: nextAt(track), refreshesLeft: POSITION.perFlightPerDay, note: null }
  }
  if (!(await takeRefresh(f.id, now))) {
    return { inAir: true, track: kept, nextRefreshAt: null, refreshesLeft: 0, note: 'limit' }
  }
  const track = readPosition(await askPosition(leg, f.date), leg, f.legs, now)
  await cacheSetJson(cacheKey(f.id), track, 24 * 3600)
  return {
    inAir: true,
    track,
    nextRefreshAt: nextAt(track),
    refreshesLeft: Math.max(0, POSITION.perFlightPerDay - used - 1),
    note: track.position ? null : 'unavailable',
  }
}
