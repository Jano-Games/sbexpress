import type { FlightStatus, PayStatus, ShipmentStatus } from '@prisma/client'

/** The nine-step pipeline in order. Index = progress. */
export const STATUS_ORDER: ShipmentStatus[] = [
  'pending',
  'received_cn_hub',
  'ready_for_shipment',
  'in_transit',
  'customs_cleared',
  'received_bd_hub',
  'ready_for_last_mile',
  'out_for_delivery',
  'delivered',
]

export const STATUS_LABEL: Record<ShipmentStatus, string> = {
  pending: 'Pending',
  received_cn_hub: 'Received at CN Hub',
  ready_for_shipment: 'Ready for Shipment',
  in_transit: 'In Transit',
  customs_cleared: 'Customs Cleared',
  received_bd_hub: 'Received at BD Hub',
  ready_for_last_mile: 'Ready for Last Mile',
  out_for_delivery: 'Out for Delivery',
  delivered: 'Delivered',
}

export const statusIndex = (s: ShipmentStatus): number => STATUS_ORDER.indexOf(s)

export const PAY_LABEL: Record<PayStatus, string> = {
  paid: 'Paid',
  unpaid: 'Unpaid',
  cod: 'COD',
  monthly: 'Monthly',
  partial: 'Partial',
}

export const FLIGHT_LABEL: Record<FlightStatus, string> = {
  upcoming: 'Upcoming',
  departed: 'Departed',
  completed: 'Completed',
}
