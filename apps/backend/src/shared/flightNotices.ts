/**
 * Flight notifications: the facts a notification needs about a flight, the
 * status changes (left, landed, cancelled) and the timed reminders (lands in
 * 24 hours, lands in 1 hour, date passed with no update). The reminders run
 * every few minutes on one server; they read only our own data, so they need
 * no flight-data key and spend nothing.
 */

import { randomUUID } from 'node:crypto'
import type { FlightStatus, Prisma } from '@prisma/client'
import { prisma } from '../core/db'
import { redis } from '../core/redis'
import { readTracking } from './flightTrackingView'
import { plannedTimes } from './flightTracking'
import {
  flightCancelledNote,
  flightChangedNote,
  flightNewNote,
  flightDatePassedNote,
  flightDepartedNote,
  flightLandedNote,
  flightSoonNote,
  flightTomorrowNote,
  notify,
  type FlightFacts,
} from './notifications'

const MINUTE = 60_000
const HOUR = 60 * MINUTE
const DHAKA = 6 * HOUR

const isoDay = (date: Date): string => date.toISOString().slice(0, 10)
const dhakaDay = (instant: number): string => new Date(instant + DHAKA).toISOString().slice(0, 10)
const hhmm = (instant: number): string => new Date(instant + DHAKA).toISOString().slice(11, 16)

export const FACTS_SELECT = {
  id: true,
  code: true,
  date: true,
  depTime: true,
  arrTime: true,
  status: true,
  airlineStatus: true,
  legs: {
    orderBy: { order: 'asc' as const },
    select: { id: true, code: true, date: true, fromIata: true, fromCity: true, toIata: true, depTime: true, arrTime: true, tracking: true },
  },
  flyers: { select: { flyer: { select: { name: true } } } },
  _count: { select: { shipments: true } },
} as const

export type FactsSource = Prisma.FlightGetPayload<{ select: typeof FACTS_SELECT }>

/** When the flight lands in Dhaka: the airline's latest time once known, else the plan. */
export function landingInstant(f: Pick<FactsSource, 'date' | 'legs'>): number | null {
  if (!f.legs.length) return null
  const last = readTracking(f.legs[f.legs.length - 1]!.tracking)
  if (last?.arr) return Date.parse(last.arr)
  const plans = plannedTimes({ date: f.date, legs: f.legs })
  return plans[plans.length - 1]?.arr ?? null
}

/** The facts the flight notifications are written from. */
export function flightFacts(f: FactsSource): FlightFacts {
  const land = landingInstant(f)
  const first = f.legs[0]
  const firstTrack = first ? readTracking(first.tracking) : null
  const lastTrack = f.legs.length ? readTracking(f.legs[f.legs.length - 1]!.tracking) : null
  const plannedArr = /^\d{1,2}:\d{2}/.test(f.arrTime) ? f.arrTime : null
  return {
    code: f.code,
    arrDate: land !== null ? dhakaDay(land) : isoDay(f.date),
    arrTime: lastTrack?.arrLocal ?? (land !== null && f.legs.length ? hhmm(land) : plannedArr),
    depTime: firstTrack?.depLocal ?? (/^\d{1,2}:\d{2}/.test(f.depTime) ? f.depTime : null),
    from: first ? first.fromCity || first.fromIata || null : null,
    orders: f._count.shipments,
    flyers: f.flyers.map((x) => x.flyer.name),
  }
}

export async function loadFlightFacts(id: string): Promise<FactsSource | null> {
  return prisma.flight.findUnique({ where: { id }, select: FACTS_SELECT })
}

const key = (f: { id: string; date: Date }, what: string) => `flight:${f.id}:${isoDay(f.date)}:${what}`

/** After a status change: tells both teams the flight left or landed. Never throws. */
export async function noticeFlightStatus(flightId: string, next: FlightStatus, moved: number): Promise<void> {
  try {
    const f = await loadFlightFacts(flightId)
    if (!f) return
    const facts = flightFacts(f)
    if (next === 'departed') await notify(flightDepartedNote(facts, moved, key(f, 'departed')))
    if (next === 'completed') {
      // Straight from Upcoming to Landed still says it left, so the moved orders are told.
      if (moved) await notify(flightDepartedNote(facts, moved, key(f, 'departed')))
      await notify(flightLandedNote(facts, key(f, 'landed')))
    }
  } catch (error) {
    console.error('[notify] flight status:', error instanceof Error ? error.message : error)
  }
}

/** A new flight, or a new day or landing time for one that has not left. Never throws. */
export async function noticeFlightPlan(flightId: string, kind: 'new' | 'changed'): Promise<void> {
  try {
    const f = await loadFlightFacts(flightId)
    if (!f) return
    const facts = flightFacts(f)
    await notify(kind === 'new' ? flightNewNote(facts) : flightChangedNote(facts))
  } catch (error) {
    console.error(`[notify] flight ${kind}:`, error instanceof Error ? error.message : error)
  }
}

/** The airline says the flight is cancelled. Never throws. */
export async function noticeFlightCancelled(flightId: string): Promise<void> {
  try {
    const f = await loadFlightFacts(flightId)
    if (!f) return
    await notify(flightCancelledNote(flightFacts(f), isoDay(f.date), key(f, 'cancelled')))
  } catch (error) {
    console.error('[notify] flight cancelled:', error instanceof Error ? error.message : error)
  }
}

// --------------------------------------------------------------- reminders

/** Which reminders are due for one flight now. Pure, for the job and the tests. */
export function dueReminders(f: Pick<FactsSource, 'date' | 'legs' | 'status' | 'airlineStatus'>, now: number): ('tomorrow' | 'soon' | 'passed')[] {
  if (f.status === 'completed' || f.airlineStatus === 'cancelled' || f.airlineStatus === 'landed') return []
  const due: ('tomorrow' | 'soon' | 'passed')[] = []
  const land = landingInstant(f)
  if (land !== null) {
    if (now >= land - 24 * HOUR && now < land - 2 * HOUR) due.push('tomorrow')
    if (now >= land - HOUR && now < land) due.push('soon')
  }
  // Still Upcoming the day after its date, and the airline never said it left.
  const leftByAirline = f.airlineStatus === 'on_the_way'
  if (f.status === 'upcoming' && !leftByAirline && dhakaDay(now) > isoDay(f.date)) due.push('passed')
  return due
}

/** Sends the reminders that are due. Returns how many were written. */
export async function runFlightReminders(now = new Date()): Promise<number> {
  const today = Date.parse(`${dhakaDay(now.getTime())}T00:00:00Z`)
  const flights = await prisma.flight.findMany({
    where: {
      status: { in: ['upcoming', 'departed'] },
      date: { gte: new Date(today - 3 * 24 * HOUR), lte: new Date(today + 2 * 24 * HOUR) },
    },
    select: FACTS_SELECT,
  })
  let sent = 0
  for (const f of flights) {
    const due = dueReminders(f, now.getTime())
    if (!due.length) continue
    const facts = flightFacts(f)
    for (const what of due) {
      const note =
        what === 'tomorrow'
          ? flightTomorrowNote(facts, key(f, 'tomorrow'), now)
          : what === 'soon'
            ? flightSoonNote(facts, key(f, 'soon'))
            : flightDatePassedNote(f.code, isoDay(f.date), key(f, 'passed'))
      if (await notify(note)) sent++
    }
  }
  return sent
}

/** Runs the reminders every five minutes, one server at a time. */
export function startFlightReminders(): () => void {
  if (process.env.FLIGHT_REMINDERS === 'off') return () => {}
  let running = false
  let stopped = false
  const tick = async () => {
    if (running || stopped) return
    running = true
    const token = randomUUID()
    const lock = 'flightnotify:lock'
    let acquired = false
    try {
      acquired = (await redis.set(lock, token, 'EX', 240, 'NX')) === 'OK'
      if (!acquired) return
      const sent = await runFlightReminders()
      if (sent) console.log(`[notify] sent ${sent} flight reminder(s)`)
    } catch (error) {
      console.error('[notify] reminders failed:', error instanceof Error ? error.message : error)
    } finally {
      if (acquired) await redis.eval("if redis.call('get',KEYS[1]) == ARGV[1] then return redis.call('del',KEYS[1]) end return 0", 1, lock, token).catch(() => {})
      running = false
    }
  }
  const timer = setInterval(() => void tick(), 5 * MINUTE)
  timer.unref()
  void tick()
  return () => {
    stopped = true
    clearInterval(timer)
  }
}
