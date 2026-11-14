/**
 * Flight tracking. The server asks the airline (AeroDataBox) how a flight is
 * going soon after each leg's planned take-off and soon after the last leg's
 * planned landing, then moves the flight's status forward: the first leg
 * leaving makes it Departed, the last leg landing makes it Completed. It never
 * moves a flight back, and a cancellation changes nothing by itself.
 *
 * The free plan has a small monthly allowance, so the server asks only at
 * those points, a few times a day in total (FLIGHT_TRACKING_DAILY_CALLS), and
 * only for flights from the last few days.
 */

import { randomUUID } from 'node:crypto'
import type { FlightStatus, Prisma } from '@prisma/client'
import { atomicMutation, prisma } from '../core/db'
import { cacheInvalidate, redis } from '../core/redis'
import { writeShipmentLog } from './actor'
import { flightDataKey, normalizeFlightNumber, providerFetch } from './flightLookup'
import { STATUS_LABEL } from './status'
import { airlineState, legCancelled, legLanded, readTracking, type LegTracking, type MovedOrders } from './flightTrackingView'

import { noticeFlightCancelled, noticeFlightStatus } from './flightNotices'
export { airlineState, readTracking, type LegTracking } from './flightTrackingView'

const MINUTE = 60_000
const HOUR = 60 * MINUTE
const DAY = 24 * HOUR

export const TRACKING = {
  /** Asks this long after a leg's take-off and after the last leg's landing. */
  afterTakeoffMin: 40,
  afterLandingMin: 30,
  /** A flight still not landed with nothing else to wait for is asked again this much later. */
  retryHours: 3,
  /** At most this many checks per flight and date. */
  maxChecks: 8,
  /** Flights older than this many days are not asked about. */
  windowDays: 3,
  intervalMs: 5 * MINUTE,
  /** Provider calls per day, across all flights. */
  dailyCalls: Number(process.env.FLIGHT_TRACKING_DAILY_CALLS) || 8,
}

const FLIGHT_RANK: Record<FlightStatus, number> = { upcoming: 0, departed: 1, completed: 2 }

// --------------------------------------------------------------- planned times

/** Minutes east of UTC for airports on the usual routes; others fall back by side. */
const AIRPORT_OFFSET: Record<string, number> = {
  DAC: 360, CGP: 360, ZYL: 360, CXB: 360, JSR: 360,
  BKK: 420, DMK: 420, HAN: 420, SGN: 420, RGN: 390,
  CCU: 330, DEL: 330, BOM: 330, MAA: 330, BLR: 330, CMB: 330, KTM: 345,
  DXB: 240, AUH: 240, SHJ: 240, MCT: 240, DOH: 180, KWI: 180, RUH: 180, JED: 180, IST: 180,
}
const CHINA = 480
const BANGLADESH = 360
const offsetOf = (iata: string, fallback: number): number => AIRPORT_OFFSET[iata.trim().toUpperCase()] ?? (iata.trim() ? CHINA : fallback)

/** "2026-11-20" + "09:40" at UTC+8 → the instant, or null without a time. */
function instant(day: string, time: string, offsetMin: number): number | null {
  const match = /^(\d{1,2}):(\d{2})/.exec(time.trim())
  if (!match) return null
  return Date.parse(`${day}T00:00:00Z`) + (Number(match[1]) * 60 + Number(match[2]) - offsetMin) * MINUTE
}

const isoDay = (date: Date): string => date.toISOString().slice(0, 10)

export interface TrackLegSource {
  id: string
  code: string
  date: Date | null
  fromIata: string
  toIata: string
  depTime: string
  arrTime: string
  tracking: Prisma.JsonValue | null
}

export interface TrackFlightSource {
  id: string
  code: string
  date: Date
  status: FlightStatus
  airlineStatus: string | null
  trackedAt: Date | null
  trackChecks: number
  legs: TrackLegSource[]
}

/** Each leg's planned take-off and landing. The airline's plan wins once known. */
export function plannedTimes(flight: Pick<TrackFlightSource, 'date' | 'legs'>): { dep: number; arr: number }[] {
  let previous: number | null = null
  return flight.legs.map((leg, index) => {
    const t = readTracking(leg.tracking)
    const day = isoDay(leg.date ?? flight.date)
    const last = index === flight.legs.length - 1
    let dep = t?.planDep ? Date.parse(t.planDep) : instant(day, leg.depTime, offsetOf(leg.fromIata, CHINA))
    // Without a time, the day's evening in China: one late check rather than none.
    dep ??= instant(day, '20:00', CHINA)!
    // A later leg with no date of its own leaves after the one before it.
    if (!leg.date && !t?.planDep && previous !== null) while (dep < previous) dep += DAY
    let arr = t?.planArr ? Date.parse(t.planArr) : instant(day, leg.arrTime, offsetOf(leg.toIata, last ? BANGLADESH : CHINA))
    if (arr === null) arr = dep + 4 * HOUR
    else if (!t?.planArr) while (arr <= dep) arr += DAY
    previous = arr
    return { dep, arr }
  })
}

/** When the server wants to ask about this flight: after each take-off, after the landing. */
export function checkPoints(flight: TrackFlightSource): number[] {
  const plans = plannedTimes(flight)
  if (!plans.length) return []
  const points = flight.legs.map((leg, i) => {
    const t = readTracking(leg.tracking)
    return (t?.dep ? Date.parse(t.dep) : plans[i]!.dep) + TRACKING.afterTakeoffMin * MINUTE
  })
  const last = readTracking(flight.legs[flight.legs.length - 1]!.tracking)
  points.push((last?.arr ? Date.parse(last.arr) : plans[plans.length - 1]!.arr) + TRACKING.afterLandingMin * MINUTE)
  const asked = flight.trackedAt?.getTime()
  const state = flight.airlineStatus
  // Still waiting on a flight the airline knows about, with nothing left to wait for: ask again later.
  if (asked !== undefined && (state === 'scheduled' || state === 'on_the_way') && points.every((p) => p <= asked)) {
    points.push(asked + TRACKING.retryHours * HOUR)
  }
  return points
}

/** True when a check point has come since the last time the airline was asked. */
export function isDue(flight: TrackFlightSource, now: number): boolean {
  if (flight.status === 'completed' || flight.trackChecks >= TRACKING.maxChecks) return false
  if (flight.airlineStatus === 'cancelled' || flight.airlineStatus === 'landed') return false
  if (!flight.legs.length) return false
  const asked = flight.trackedAt?.getTime() ?? Number.NEGATIVE_INFINITY
  return checkPoints(flight).some((p) => p > asked && p <= now)
}

// --------------------------------------------------------------- the airline

interface RawTime { utc?: string; local?: string }
interface RawMovement {
  scheduledTime?: RawTime
  revisedTime?: RawTime
  runwayTime?: RawTime
  predictedTime?: RawTime
}
interface RawFlight {
  status?: string
  departure?: RawMovement
  arrival?: RawMovement
}

/** "2026-11-20 01:52Z" → ISO, or null. */
function utcIso(value: string | undefined): string | null {
  if (!value) return null
  const at = Date.parse(value.trim().replace(' ', 'T'))
  return Number.isFinite(at) ? new Date(at).toISOString() : null
}

function movement(m: RawMovement | undefined) {
  const plan = m?.scheduledTime
  const latest = m?.revisedTime ?? m?.runwayTime ?? m?.predictedTime ?? plan
  const planAt = utcIso(plan?.utc)
  const latestAt = utcIso(latest?.utc)
  return {
    plan: planAt,
    at: latestAt,
    local: latest?.local?.match(/\d{2}:\d{2}/)?.[0] ?? null,
    late: planAt && latestAt ? Math.round((Date.parse(latestAt) - Date.parse(planAt)) / MINUTE) : null,
  }
}

/** Turns one AeroDataBox flight into what a leg stores. */
export function legTracking(raw: RawFlight | null, checkedAt: Date): LegTracking {
  if (!raw) {
    return { status: 'NotFound', checkedAt: checkedAt.toISOString(), planDep: null, planArr: null, dep: null, arr: null, depLocal: null, arrLocal: null, depLateMin: null, arrLateMin: null }
  }
  const dep = movement(raw.departure)
  const arr = movement(raw.arrival)
  return {
    status: raw.status || 'Unknown',
    checkedAt: checkedAt.toISOString(),
    planDep: dep.plan,
    planArr: arr.plan,
    dep: dep.at,
    arr: arr.at,
    depLocal: dep.local,
    arrLocal: arr.local,
    depLateMin: dep.late,
    arrLateMin: arr.late,
  }
}

/** Takes one of today's provider calls; false once the day's allowance is used. */
async function takeCall(now: Date): Promise<boolean> {
  const key = `flighttrack:calls:${isoDay(now)}`
  const used = await redis.incr(key)
  if (used === 1) await redis.expire(key, 2 * 86400)
  return used <= TRACKING.dailyCalls
}

/** What the airline says about one flight number on the day it leaves; null when it has nothing. */
async function askAirline(code: string, day: string): Promise<RawFlight | null> {
  const response = await providerFetch(`/flights/number/${code}/${day}?dateLocalRole=Departure&withAircraftImage=false&withLocation=false`, flightDataKey())
  if (response.status === 404 || response.status === 204) return null
  if (!response.ok) throw new Error(`Flight provider returned ${response.status}`)
  const payload = (await response.json().catch(() => null)) as RawFlight[] | RawFlight | null
  const rows = Array.isArray(payload) ? payload : payload ? [payload] : []
  return rows.find((row) => row.departure?.scheduledTime?.local?.startsWith(day)) ?? rows[0] ?? null
}

// --------------------------------------------------------------- status and orders

/**
 * Moves the flight's orders that are ready for shipment to In transit. An
 * order with no carrying flyer gets the flight's only flyer; with several
 * flyers it is left for a person to sort out.
 */
async function moveReadyOrders(flightId: string, by: string): Promise<string[]> {
  const [orders, members] = await Promise.all([
    prisma.shipment.findMany({
      where: { flightId, status: 'ready_for_shipment', exception: null },
      select: { id: true, code: true, flyerId: true },
      orderBy: { code: 'asc' },
    }),
    prisma.flightFlyer.findMany({ where: { flightId }, select: { flyerId: true } }),
  ])
  const onlyFlyer = members.length === 1 ? members[0]!.flyerId : null
  const moved: string[] = []
  for (const order of orders) {
    const flyerId = order.flyerId ?? onlyFlyer
    if (!flyerId) continue
    await prisma.shipment.update({ where: { id: order.id }, data: { status: 'in_transit', flyerId } })
    await writeShipmentLog(order.id, `Status → ${STATUS_LABEL.in_transit}`, by === 'airline' ? 'Flight tracking' : by)
    moved.push(order.code)
  }
  return moved
}

/**
 * Sets a flight's status and says who did it. Leaving "upcoming" (to Departed
 * or straight to Completed) moves the orders ready for shipment to In transit.
 * Returns the moved order codes.
 */
export async function setFlightStatus(
  flight: { id: string; status: FlightStatus },
  next: FlightStatus,
  by: string,
  now = new Date(),
): Promise<string[]> {
  if (next === flight.status) return []
  const leaving = flight.status === 'upcoming'
  const moved = leaving ? await moveReadyOrders(flight.id, by) : []
  const movedOrders: MovedOrders | undefined = leaving ? { at: now.toISOString(), by, codes: moved } : undefined
  await prisma.flight.update({
    where: { id: flight.id },
    data: {
      status: next,
      statusSetBy: by,
      statusSetAt: now,
      ...(movedOrders ? { movedOrders: movedOrders as unknown as Prisma.InputJsonValue } : {}),
    },
  })
  if (FLIGHT_RANK[next] > FLIGHT_RANK[flight.status]) await noticeFlightStatus(flight.id, next, moved.length)
  return moved
}

// --------------------------------------------------------------- one check

const TRACK_INCLUDE = { legs: { orderBy: { order: 'asc' as const } } } as const

/** Asks the airline about the legs that should have left by now, and applies the answer. */
export async function checkFlight(flight: TrackFlightSource, now: Date): Promise<{ calls: number; status: FlightStatus } | null> {
  const plans = plannedTimes(flight)
  const ask = flight.legs.filter((leg, i) => {
    const t = readTracking(leg.tracking)
    if (legLanded(t) || legCancelled(t)) return false
    return (t?.dep ? Date.parse(t.dep) : plans[i]!.dep) <= now.getTime()
  })
  const answers = new Map<string, LegTracking>()
  let calls = 0
  for (const leg of ask) {
    if (!(await takeCall(now))) break
    calls++
    const day = isoDay(leg.date ?? flight.date)
    const code = normalizeFlightNumber(leg.code)
    answers.set(leg.id, legTracking(await askAirline(code, day), now))
  }
  if (ask.length && !answers.size) return null

  return atomicMutation(async () => {
    // A person may have moved the flight while the airline was asked.
    const fresh = await prisma.flight.findUnique({ where: { id: flight.id }, include: TRACK_INCLUDE })
    if (!fresh || isoDay(fresh.date) !== isoDay(flight.date)) return null
    const legIds = fresh.legs.map((leg) => leg.id).join(',')
    if (legIds !== flight.legs.map((leg) => leg.id).join(',')) return null
    for (const [id, tracking] of answers) {
      await prisma.flightLeg.update({ where: { id }, data: { tracking: tracking as unknown as Prisma.InputJsonValue } })
    }
    const tracks = fresh.legs.map((leg) => answers.get(leg.id) ?? readTracking(leg.tracking))
    const state = airlineState(tracks)
    if (state === 'cancelled' && fresh.airlineStatus !== 'cancelled') await noticeFlightCancelled(fresh.id)
    await prisma.flight.update({
      where: { id: fresh.id },
      data: { airlineStatus: state, trackedAt: now, trackChecks: { increment: 1 } },
    })
    const next: FlightStatus | null = state === 'landed' ? 'completed' : state === 'on_the_way' ? 'departed' : null
    let status = fresh.status
    if (next && FLIGHT_RANK[next] > FLIGHT_RANK[fresh.status]) {
      await setFlightStatus(fresh, next, 'airline', now)
      status = next
    }
    return { calls, status }
  })
}

/** Checks every flight that is due. Returns how many were checked. */
export async function trackDueFlights(now = new Date()): Promise<number> {
  const today = Date.parse(`${isoDay(now)}T00:00:00Z`)
  const flights = await prisma.flight.findMany({
    where: {
      status: { in: ['upcoming', 'departed'] },
      date: { gte: new Date(today - TRACKING.windowDays * DAY), lte: new Date(today + DAY) },
      trackChecks: { lt: TRACKING.maxChecks },
      OR: [{ airlineStatus: null }, { airlineStatus: { notIn: ['cancelled', 'landed'] } }],
    },
    include: TRACK_INCLUDE,
    orderBy: { date: 'asc' },
  })
  let checked = 0
  for (const flight of flights) {
    if (!isDue(flight, now.getTime())) continue
    try {
      const result = await checkFlight(flight, now)
      if (result) checked++
    } catch (error) {
      console.error(`[tracking] ${flight.code} check failed:`, error instanceof Error ? error.message : error)
    }
  }
  if (checked) {
    await cacheInvalidate('dashboard')
    await cacheInvalidate('track')
  }
  return checked
}

/**
 * Runs the checks every few minutes, one server at a time. On by default in
 * production when the flight data key is set; FLIGHT_TRACKING=on|off decides
 * elsewhere, so a development server does not spend the shared allowance.
 */
export function startFlightTracking(): () => void {
  const setting = process.env.FLIGHT_TRACKING ?? (process.env.NODE_ENV === 'production' ? 'on' : 'off')
  if (!flightDataKey() || setting !== 'on') return () => {}
  let running = false
  let stopped = false
  const tick = async () => {
    if (running || stopped) return
    running = true
    const token = randomUUID()
    const key = 'flighttrack:lock'
    let acquired = false
    try {
      acquired = (await redis.set(key, token, 'EX', 240, 'NX')) === 'OK'
      if (!acquired) return
      const checked = await trackDueFlights()
      if (checked) console.log(`[tracking] checked ${checked} flight(s)`)
    } catch (error) {
      console.error('[tracking] run failed:', error instanceof Error ? error.message : error)
    } finally {
      if (acquired) await redis.eval("if redis.call('get',KEYS[1]) == ARGV[1] then return redis.call('del',KEYS[1]) end return 0", 1, key, token).catch(() => {})
      running = false
    }
  }
  const timer = setInterval(() => void tick(), TRACKING.intervalMs)
  timer.unref()
  void tick()
  return () => {
    stopped = true
    clearInterval(timer)
  }
}
