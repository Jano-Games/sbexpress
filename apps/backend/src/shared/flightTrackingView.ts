/**
 * Flight tracking as the app sees it: what each leg stored from the airline,
 * the airline's word for the whole trip, and the orders that did or did not
 * move when the flight left. Pure functions with no database or network, so
 * hub-safe serializers can use them.
 */

import type { FlightStatus, Prisma, ShipmentStatus } from '@prisma/client'
import { statusIndex } from './status'

/** What the airline said about one leg. Stored in FlightLeg.tracking. */
export interface LegTracking {
  /** AeroDataBox's word: Expected, Delayed, Departed, EnRoute, Arrived, Canceled… or NotFound. */
  status: string
  checkedAt: string
  /** Planned and latest times, UTC ISO. The latest is the actual time once it happened. */
  planDep: string | null
  planArr: string | null
  dep: string | null
  arr: string | null
  /** Local HH:mm at the airport for `dep` and `arr`. */
  depLocal: string | null
  arrLocal: string | null
  /** Minutes behind the plan; negative is early. */
  depLateMin: number | null
  arrLateMin: number | null
}

/** Who moved orders when the flight left. Stored in Flight.movedOrders. */
export interface MovedOrders {
  at: string
  /** "airline", or the staff member's name. */
  by: string
  codes: string[]
}

export type AirlineState = 'scheduled' | 'on_the_way' | 'landed' | 'cancelled' | 'none'

const LEFT = new Set(['Departed', 'EnRoute', 'Approaching', 'Arrived', 'Diverted'])

export const readTracking = (value: Prisma.JsonValue | null | undefined): LegTracking | null =>
  value && typeof value === 'object' && !Array.isArray(value) && typeof (value as { status?: unknown }).status === 'string'
    ? (value as unknown as LegTracking)
    : null

export const legLeft = (t: LegTracking | null) => Boolean(t && LEFT.has(t.status))
export const legLanded = (t: LegTracking | null) => t?.status === 'Arrived'
export const legCancelled = (t: LegTracking | null) => t?.status === 'Canceled'

/** The airline's word for the whole trip, from what each leg said. */
export function airlineState(tracks: (LegTracking | null)[]): AirlineState | null {
  const known = tracks.filter((t): t is LegTracking => t !== null)
  if (!known.length) return null
  if (known.some(legCancelled)) return 'cancelled'
  if (legLanded(tracks[tracks.length - 1] ?? null)) return 'landed'
  if (known.some(legLeft)) return 'on_the_way'
  if (known.every((t) => t.status === 'NotFound')) return 'none'
  return 'scheduled'
}

// --------------------------------------------------------------- what the app sees

export type LegState = 'waiting' | 'in_air' | 'landed' | 'cancelled' | 'unknown'

interface ViewLeg {
  code: string
  fromIata: string
  fromCity: string
  toIata: string
  toCity: string
  depTime: string
  arrTime: string
  tracking: Prisma.JsonValue | null
}

/**
 * Flight tracking for the app: the airline's word, when it was asked, when
 * the flight left and lands, and each leg. Null until the airline was asked.
 * Hub-safe: no money.
 */
export function trackingView(flight: { airlineStatus: string | null; trackedAt: Date | null; legs: ViewLeg[] }) {
  if (!flight.trackedAt || !flight.legs.length) return null
  const tracks = flight.legs.map((leg) => readTracking(leg.tracking))
  const laterLeft = (i: number) => tracks.slice(i + 1).some(legLeft)
  const legs = flight.legs.map((leg, i) => {
    const t = tracks[i] ?? null
    const state: LegState = legCancelled(t)
      ? 'cancelled'
      : legLanded(t) || laterLeft(i)
        ? 'landed'
        : legLeft(t)
          ? 'in_air'
          : !t || t.status === 'NotFound'
            ? 'unknown'
            : 'waiting'
    return {
      code: leg.code,
      fromIata: leg.fromIata,
      fromCity: leg.fromCity,
      toIata: leg.toIata,
      toCity: leg.toCity,
      plannedDep: leg.depTime,
      plannedArr: leg.arrTime,
      state,
      airlineStatus: t?.status ?? null,
      depLocal: t?.depLocal ?? null,
      arrLocal: t?.arrLocal ?? null,
      depLateMin: t?.depLateMin ?? null,
      arrLateMin: t?.arrLateMin ?? null,
    }
  })
  const first = legs[0]!
  const last = legs[legs.length - 1]!
  const leftLegs = legs.filter((leg) => leg.state === 'in_air' || leg.state === 'landed')
  const latest = leftLegs[leftLegs.length - 1]
  const state = flight.airlineStatus as AirlineState | null
  return {
    state,
    checkedAt: flight.trackedAt.toISOString(),
    left: leftLegs.length > 0,
    /** The first leg's take-off, once it left. */
    leftAt: leftLegs.length ? first.depLocal : null,
    leftLateMin: leftLegs.length ? first.depLateMin : null,
    /** The leg in the air or the last one that left: "left Shanghai 13:34". */
    lastLeft: latest ? { code: latest.code, iata: latest.fromIata, city: latest.fromCity, at: latest.depLocal } : null,
    landed: last.state === 'landed',
    /** The last leg's landing: expected, or actual once landed. */
    landsAt: last.arrLocal,
    landsLateMin: last.arrLateMin,
    plannedDep: first.plannedDep,
    plannedArr: last.plannedArr,
    nextCheck: state === 'on_the_way' ? 'after_landing' : state === 'scheduled' ? 'after_takeoff' : null,
    legs,
  }
}

/** Why an order on a flight that left is still before In transit. */
export type NotMovedReason = 'not_ready' | 'no_flyer' | 'exception' | 'ready'

/** Orders on a flight that left but are not on their way: someone should look at them. */
export function notMovedOrders(
  flight: { status: FlightStatus; flyerCount: number },
  shipments: readonly { code: string; status: ShipmentStatus; exception: string | null; flyerId: string | null; supplier: { name: string } }[],
) {
  if (flight.status === 'upcoming') return []
  return shipments
    .filter((s) => statusIndex(s.status) < statusIndex('in_transit'))
    .map((s) => ({
      code: s.code,
      customer: s.supplier.name,
      status: s.status,
      reason: (s.exception
        ? 'exception'
        : s.status !== 'ready_for_shipment'
          ? 'not_ready'
          : !s.flyerId && flight.flyerCount !== 1
            ? 'no_flyer'
            : 'ready') as NotMovedReason,
    }))
}

/** The moved-orders note stored on the flight, if any. */
export function readMovedOrders(value: Prisma.JsonValue | null): MovedOrders | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null
  const v = value as Record<string, unknown>
  return typeof v.at === 'string' && typeof v.by === 'string' && Array.isArray(v.codes)
    ? { at: v.at, by: v.by, codes: v.codes.filter((c): c is string => typeof c === 'string') }
    : null
}
