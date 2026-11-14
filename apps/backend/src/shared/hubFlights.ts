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
import type { ReceivedGroup } from './receivedBy'
import { trackingView } from './flightTrackingView'

/** Extra facts the hub flight page shows, read alongside the flight. */
export interface HubFlightExtras {
  /** Face photos of the flyers, by flyer id. */
  flyerPhotos?: Map<string, string>
  receivedBy?: ReceivedGroup[]
  /** Photos of the phones and laptops in each order, by shipment id. */
  devicePhotos?: Map<string, HubDevicePhoto[]>
}

export interface HubDevicePhoto {
  reference: string
  /** "Mobile 1", "Laptop" … */
  label: string
}

interface DeviceMediaRow {
  shipmentId: string
  reference: string
  purpose: string
  deviceKey: string | null
}

/** Groups the device photos by order and names each one after its device. */
export function devicePhotoMap(rows: DeviceMediaRow[], pcsByShipment: Map<string, unknown>): Map<string, HubDevicePhoto[]> {
  const out = new Map<string, HubDevicePhoto[]>()
  for (const row of rows) {
    let label = row.deviceKey ?? 'Device'
    if (row.purpose === 'device_photo' && row.deviceKey) {
      const [item, unit] = row.deviceKey.split(':').map(Number)
      const items = pcsByShipment.get(row.shipmentId)
      const category = Array.isArray(items) ? (items[item ?? -1] as { category?: string } | undefined)?.category : undefined
      const count = Array.isArray(items) ? Number((items[item ?? -1] as { count?: number } | undefined)?.count ?? 0) : 0
      label = category ? (count > 1 ? `${category} ${(unit ?? 0) + 1}` : category) : 'Device'
    }
    const list = out.get(row.shipmentId) ?? []
    list.push({ reference: row.reference, label })
    out.set(row.shipmentId, list)
  }
  return out
}

const LEGS = {
  orderBy: { order: 'asc' as const },
  select: { code: true, fromIata: true, fromCity: true, toIata: true, toCity: true, depTime: true, arrTime: true, tracking: true },
} as const

export const HUB_FLIGHT_INCLUDE = {
  flyers: { select: { flyer: { select: { name: true } } } },
  shipments: { select: { bookedKg: true, weighedKg: true, status: true } },
  legs: LEGS,
} as const

export const HUB_FLIGHT_DETAIL_INCLUDE = {
  flyers: { select: { flyer: { select: { id: true, name: true, bdPhone: true } } } },
  shipments: {
    include: { supplier: true, flight: true, receipts: true, expenses: true, costs: true, flyer: { select: { name: true } } },
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
  airlineStatus: string | null
  trackedAt: Date | null
  flyers: { flyer: { name: string } }[]
  shipments: { bookedKg: Prisma.Decimal; weighedKg: Prisma.Decimal | null; status: ShipmentStatus }[]
  legs: { code: string; fromIata: string; fromCity: string; toIata: string; toCity: string; depTime: string; arrTime: string; tracking: Prisma.JsonValue | null }[]
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
    /** When it left and lands, from the airline; null until the airline was asked. */
    tracking: trackingView(f),
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
    flyers: { flyer: { id: string; name: string; bdPhone: string } }[]
    shipments: (ShipmentWithRelations & { flyer?: { name: string } | null })[]
  },
  threshold: number,
  today = new Date(),
  extras: HubFlightExtras = {},
) {
  return {
    ...hubFlightRow(f, today),
    flyerDetails: f.flyers.map(({ flyer }) => ({
      name: flyer.name,
      initial: flyer.name.charAt(0),
      bdPhone: flyer.bdPhone,
      photoRef: extras.flyerPhotos?.get(flyer.id) ?? null,
    })),
    shipments: f.shipments.map((s) => ({
      ...shipmentRowHub(s, threshold),
      /** Who carries it, and photos of its phones and laptops. */
      flyerName: s.flyer?.name ?? null,
      devicePhotos: extras.devicePhotos?.get(s.id) ?? [],
    })),
    /** Orders through customs and free of exceptions: one tap receives them. */
    readyToReceive: f.shipments.filter((s) => s.status === 'customs_cleared' && !s.exception).length,
    receivedBy: extras.receivedBy ?? [],
  }
}
