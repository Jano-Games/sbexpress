/**
 * In-app notifications: one row per crucial step, shown under the bell in the
 * app. Push to phones (Firebase) comes later and reads the same rows; see
 * docs/notifications.md for the events, who gets each one and its words.
 *
 * Sending never fails the work that caused it: a notification that cannot be
 * written is logged and dropped.
 */

import { Prisma, type UserRole } from '@prisma/client'
import { prisma } from '../core/db'

export const NOTIFICATION_EVENTS = [
  'flight_new',
  'flight_changed',
  'flight_tomorrow',
  'flight_departed',
  'flight_soon',
  'flight_landed',
  'flight_cancelled',
  'flight_date_passed',
  'orders_received',
  'sort_waiting',
  'sort_sent_back',
  'sort_approved',
  'delivered',
  'problem',
] as const

export type NotificationEvent = (typeof NOTIFICATION_EVENTS)[number]

export type NotificationParams = Record<string, string | number | null>

export interface NotificationInput {
  event: NotificationEvent
  roles: UserRole[]
  title: string
  body: string
  params?: NotificationParams
  flightCode?: string | null
  shipmentCode?: string | null
  customerCode?: string | null
  /** The same key is sent once; a repeat is quietly skipped. */
  dedupeKey?: string | null
}

/** Writes one notification. Returns false when it was a repeat or could not be written. */
export async function notify(input: NotificationInput): Promise<boolean> {
  try {
    if (input.dedupeKey) {
      const seen = await prisma.notification.findUnique({ where: { dedupeKey: input.dedupeKey }, select: { id: true } })
      if (seen) return false
    }
    await prisma.notification.create({
      data: {
        event: input.event,
        roles: input.roles,
        title: input.title,
        body: input.body,
        params: (input.params ?? {}) as Prisma.InputJsonValue,
        flightCode: input.flightCode ?? null,
        shipmentCode: input.shipmentCode ?? null,
        customerCode: input.customerCode ?? null,
        dedupeKey: input.dedupeKey ?? null,
      },
    })
    return true
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') return false
    console.error(`[notify] ${input.event} not written:`, error instanceof Error ? error.message : error)
    return false
  }
}

// --------------------------------------------------------------- words

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

/** "2026-11-14" → "Sat 14 Nov". */
export function dayLabel(iso: string): string {
  const d = new Date(`${iso.slice(0, 10)}T00:00:00Z`)
  if (Number.isNaN(d.getTime())) return iso
  return `${DAYS[d.getUTCDay()]} ${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]}`
}

/** "MU2039-20261114-ab12cd" → "MU2039": the number people know the flight by. */
export const flightNumber = (code: string): string => code.replace(/-\d{8}-[0-9a-z]+$/i, '')

const plural = (n: number, one: string, many = `${one}s`) => `${n} ${n === 1 ? one : many}`
export const orders = (n: number) => plural(n, 'order')
const at = (time: string | null | undefined) => (time && /^\d{1,2}:\d{2}/.test(time) ? ` at ${time.slice(0, 5)}` : '')

/** Whole days from today (Dhaka) to the given date; 0 is today. */
export function daysUntil(iso: string, now = new Date()): number {
  const dhakaToday = new Date(now.getTime() + 6 * 3_600_000).toISOString().slice(0, 10)
  return Math.round((Date.parse(`${iso.slice(0, 10)}T00:00:00Z`) - Date.parse(`${dhakaToday}T00:00:00Z`)) / 86_400_000)
}

function inDays(days: number): string {
  if (days <= 0) return 'today'
  if (days === 1) return 'tomorrow'
  return `in ${days} days`
}

export interface FlightFacts {
  code: string
  /** Landing date in Dhaka, ISO day. */
  arrDate: string
  arrTime: string | null
  depTime?: string | null
  from?: string | null
  orders: number
  flyers?: string[]
}

const FLIGHT_ROLES: UserRole[] = ['admin', 'hub']

/** A new flight was added: the hub plans for it. */
export function flightNewNote(f: FlightFacts, now = new Date()): NotificationInput {
  const number = flightNumber(f.code)
  const days = daysUntil(f.arrDate, now)
  const parts = [
    ...(f.orders ? [orders(f.orders)] : []),
    ...(f.flyers?.length ? [`${f.flyers.length === 1 ? 'flyer' : 'flyers'} ${f.flyers.join(', ')}`] : []),
  ].join(', ')
  const tail = parts ? ` ${parts.charAt(0).toUpperCase()}${parts.slice(1)}.` : ''
  return {
    event: 'flight_new',
    roles: ['hub'],
    title: `New flight ${number}`,
    body: `New flight ${number}. Lands in Dhaka ${dayLabel(f.arrDate)}${at(f.arrTime)}, ${inDays(days)}.${tail}`,
    params: { flight: number, date: f.arrDate, arrTime: f.arrTime, days, orders: f.orders, flyers: f.flyers?.join(', ') ?? '' },
    flightCode: f.code,
  }
}

/** The date or landing time changed. */
export function flightChangedNote(f: FlightFacts): NotificationInput {
  const number = flightNumber(f.code)
  return {
    event: 'flight_changed',
    roles: ['hub'],
    title: `${number} changed`,
    body: `${number} now lands in Dhaka ${dayLabel(f.arrDate)}${at(f.arrTime)}.`,
    params: { flight: number, date: f.arrDate, arrTime: f.arrTime },
    flightCode: f.code,
  }
}

/** About a day before landing. Says today or tomorrow by the Dhaka date. */
export function flightTomorrowNote(f: FlightFacts, key: string, now = new Date()): NotificationInput {
  const number = flightNumber(f.code)
  const days = Math.max(0, daysUntil(f.arrDate, now))
  const when = days === 0 ? 'today' : 'tomorrow'
  return {
    event: 'flight_tomorrow',
    roles: FLIGHT_ROLES,
    title: `${number} lands ${when}`,
    body: `${number} lands ${when}${at(f.arrTime)}. ${orders(f.orders)}.`,
    params: { flight: number, date: f.arrDate, arrTime: f.arrTime, orders: f.orders, days },
    flightCode: f.code,
    dedupeKey: key,
  }
}

export function flightDepartedNote(f: FlightFacts, moved: number, key: string): NotificationInput {
  const number = flightNumber(f.code)
  const left = f.from ? `${number} left ${f.from}${at(f.depTime)}.` : `${number} has left${at(f.depTime)}.`
  const landing = f.arrTime ? ` Lands in Dhaka${at(f.arrTime)}.` : ''
  const movedText = moved ? ` ${orders(moved)} ${moved === 1 ? 'is' : 'are'} In transit.` : ''
  return {
    event: 'flight_departed',
    roles: FLIGHT_ROLES,
    title: `${number} has left`,
    body: `${left}${landing}${movedText}`,
    params: { flight: number, from: f.from ?? null, depTime: f.depTime ?? null, arrTime: f.arrTime, moved },
    flightCode: f.code,
    dedupeKey: key,
  }
}

export function flightSoonNote(f: FlightFacts, key: string): NotificationInput {
  const number = flightNumber(f.code)
  return {
    event: 'flight_soon',
    roles: FLIGHT_ROLES,
    title: `${number} lands in 1 hour`,
    body: `${number} lands in about 1 hour${at(f.arrTime)}.`,
    params: { flight: number, arrTime: f.arrTime },
    flightCode: f.code,
    dedupeKey: key,
  }
}

export function flightLandedNote(f: FlightFacts, key: string): NotificationInput {
  const number = flightNumber(f.code)
  return {
    event: 'flight_landed',
    roles: FLIGHT_ROLES,
    title: `${number} landed`,
    body: `${number} landed in Dhaka${at(f.arrTime)}. ${orders(f.orders)} to receive.`,
    params: { flight: number, arrTime: f.arrTime, orders: f.orders },
    flightCode: f.code,
    dedupeKey: key,
  }
}

export function flightCancelledNote(f: FlightFacts, day: string, key: string): NotificationInput {
  const number = flightNumber(f.code)
  return {
    event: 'flight_cancelled',
    roles: FLIGHT_ROLES,
    title: `${number} cancelled by the airline`,
    body: `The airline cancelled ${number} on ${dayLabel(day)}. Nothing was changed here.`,
    params: { flight: number, date: day },
    flightCode: f.code,
    dedupeKey: key,
  }
}

export function flightDatePassedNote(code: string, day: string, key: string): NotificationInput {
  const number = flightNumber(code)
  return {
    event: 'flight_date_passed',
    roles: ['admin'],
    title: `Confirm ${number}`,
    body: `${number} was due on ${dayLabel(day)}. The airline has no update. Confirm what happened.`,
    params: { flight: number, date: day },
    flightCode: code,
    dedupeKey: key,
  }
}

export function ordersReceivedNote(code: string, count: number, by: string): NotificationInput {
  const number = flightNumber(code)
  return {
    event: 'orders_received',
    roles: ['admin'],
    title: `${number} received`,
    body: `${by} received ${orders(count)} from ${number} at the Dhaka hub.`,
    params: { flight: number, count, by },
    flightCode: code,
  }
}

export interface SortFacts {
  flightCode: string
  /** The customer code (the hub never sees names). */
  customerCode: string
  /** The customer's name, for the admin only. */
  customerName?: string
  orders: number
  kg?: number
  partner?: string | null
  by: string
  note?: string
}

export function sortWaitingNote(f: SortFacts): NotificationInput {
  const number = flightNumber(f.flightCode)
  const who = f.customerName ?? f.customerCode
  return {
    event: 'sort_waiting',
    roles: ['admin'],
    title: `Approve ${who}`,
    body: `${f.by} sorted ${who} from ${number}: ${orders(f.orders)}, ${f.kg ?? 0} kg. Waiting for approval.`,
    params: { flight: number, customer: who, orders: f.orders, kg: f.kg ?? 0, by: f.by },
    flightCode: f.flightCode,
    customerCode: f.customerCode,
  }
}

export function sortSentBackNote(f: SortFacts): NotificationInput {
  const number = flightNumber(f.flightCode)
  return {
    event: 'sort_sent_back',
    roles: ['hub'],
    title: `${f.customerCode} sent back`,
    body: `${f.customerCode} from ${number} sent back by ${f.by}: ${f.note ?? ''}`.trim(),
    params: { flight: number, customer: f.customerCode, note: f.note ?? '', by: f.by },
    flightCode: f.flightCode,
    customerCode: f.customerCode,
  }
}

export function sortApprovedNote(f: SortFacts): NotificationInput {
  const number = flightNumber(f.flightCode)
  const pickup = f.partner === 'Hub pickup'
  return {
    event: 'sort_approved',
    roles: ['hub'],
    title: `${f.customerCode} approved`,
    body: pickup
      ? `${f.customerCode} from ${number} approved. ${orders(f.orders)} ready for pickup at the hub.`
      : `${f.customerCode} from ${number} approved. ${orders(f.orders)} In delivery with ${f.partner ?? 'the courier'}.`,
    params: { flight: number, customer: f.customerCode, orders: f.orders, partner: f.partner ?? null, by: f.by },
    flightCode: f.flightCode,
    customerCode: f.customerCode,
  }
}

export function deliveredNote(f: SortFacts): NotificationInput {
  const number = flightNumber(f.flightCode)
  const who = f.customerName ?? f.customerCode
  return {
    event: 'delivered',
    roles: ['admin'],
    title: `${who} delivered`,
    body: `${f.by} confirmed ${orders(f.orders)} of ${who} from ${number} delivered.`,
    params: { flight: number, customer: who, orders: f.orders, by: f.by },
    flightCode: f.flightCode,
    customerCode: f.customerCode,
  }
}

const PROBLEM_WORDS: Record<string, string> = {
  on_hold: 'is on hold',
  cancelled: 'was cancelled',
  delivery_failed: 'could not be delivered',
  returned: 'was returned',
  lost: 'is lost',
}

/** An order got an exception: the other team needs to know. */
export function problemNote(code: string, type: string, reason: string, by: string, byRole: UserRole): NotificationInput {
  return {
    event: 'problem',
    roles: byRole === 'hub' ? ['admin'] : ['hub'],
    title: `Problem with ${code}`,
    body: `${code} ${PROBLEM_WORDS[type] ?? type.replaceAll('_', ' ')}: ${reason} (${by})`,
    params: { order: code, type, reason, by },
    shipmentCode: code,
  }
}
