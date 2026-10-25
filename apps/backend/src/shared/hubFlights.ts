/**
 * Hub-safe flight DTOs. The Dhaka hub plans its day around what is arriving,
 * so it sees schedule, flyers, weight and the shipment manifest. Ticket fare,
 * actual cost, agency share, flyer contributions and booking revenue never
 * leave the server for this role: those keys are absent, not null, matching
 * ShipmentRowHub.
 */

import type { FlightStatus, Prisma, ShipmentStatus } from '@prisma/client'
import { effectiveKg } from './compute'
import { isoDate, num, numOrNull, shipmentRowHub, type ShipmentWithRelations } from './serialize'
import { FLIGHT_LABEL, statusIndex } from './status'

const LEGS = {
  orderBy: { order: 'asc' as const },
  select: { fromIata: true, fromCity: true, toIata: true, toCity: true },
} as const

export const HUB_FLIGHT_INCLUDE = {
  flyers: { select: { flyer: { select: { name: true } } } },
  shipments: { select: { bookedKg: true, weighedKg: true, status: true } },
  legs: LEGS,
} as const

export const HUB_FLIGHT_DETAIL_INCLUDE = {
  flyers: { select: { flyer: { select: { name: true, bdPhone: true } } } },
  shipments: {
    include: { supplier: true, flight: true, receipts: true, expenses: true, costs: true },
    orderBy: { code: 'asc' as const },
  },
  legs: LEGS,
} as const

interface HubFlightSource {
  code: string
  date: Date
  depTime: string
  arrTime: string
  via: string
  status: FlightStatus
  flyers: { flyer: { name: string } }[]
  shipments: { bookedKg: Prisma.Decimal; weighedKg: Prisma.Decimal | null; status: ShipmentStatus }[]
  legs: { fromIata: string; fromCity: string; toIata: string; toCity: string }[]
}

const place = (city: string, iata: string): string | null => city || iata || null

/** One schedule row: when it lands, who carries it and how much is on board. */
export function hubFlightRow(f: HubFlightSource, today = new Date()) {
  const first = f.legs[0]
  const last = f.legs[f.legs.length - 1]
  const kg = f.shipments.reduce((total, s) => total + effectiveKg(num(s.bookedKg), numOrNull(s.weighedKg)), 0)
  return {
    code: f.code,
    date: isoDate(f.date),
    depTime: f.depTime,
    arrTime: f.arrTime,
    via: f.via,
    from: first ? place(first.fromCity, first.fromIata) : null,
    to: last ? place(last.toCity, last.toIata) : null,
    status: f.status,
    statusLabel: FLIGHT_LABEL[f.status],
    scheduleNeedsConfirmation: f.status === 'upcoming' && f.date < new Date(today.toISOString().slice(0, 10)),
    flyers: f.flyers.map((x) => x.flyer.name),
    shipmentCount: f.shipments.length,
    kg: Math.round(kg * 10) / 10,
    receivedCount: f.shipments.filter((s) => statusIndex(s.status) >= statusIndex('received_bd_hub')).length,
  }
}

export type HubFlightRow = ReturnType<typeof hubFlightRow>

/** The schedule row plus flyer contacts and the hub view of every booking on board. */
export function hubFlightDetail(
  f: Omit<HubFlightSource, 'flyers' | 'shipments'> & {
    flyers: { flyer: { name: string; bdPhone: string } }[]
    shipments: ShipmentWithRelations[]
  },
  threshold: number,
  today = new Date(),
) {
  return {
    ...hubFlightRow(f, today),
    flyerDetails: f.flyers.map(({ flyer }) => ({ name: flyer.name, initial: flyer.name.charAt(0), bdPhone: flyer.bdPhone })),
    shipments: f.shipments.map((s) => shipmentRowHub(s, threshold)),
  }
}
