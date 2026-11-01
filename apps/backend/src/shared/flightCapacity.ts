import { prisma } from '../core/db'
import { badRequest, notFound } from '../core/errors'

/** Called inside the agency mutation transaction, so concurrent bookings cannot overfill a flight. */
export async function assertFlightCapacity(flightId: string, incomingKg: number, excludeShipmentId?: string, capacityKg?: number) {
  const flight = await prisma.flight.findUnique({ where: { id: flightId }, select: { spaceKg: true } })
  if (!flight) throw notFound('Flight not found')
  const booked = await prisma.shipment.aggregate({
    where: { flightId, ...(excludeShipmentId ? { id: { not: excludeShipmentId } } : {}) },
    _sum: { bookedKg: true },
  })
  const capacity = capacityKg ?? flight.spaceKg
  const occupied = Number(booked._sum.bookedKg ?? 0)
  if (occupied + incomingKg > capacity + 0.000001) {
    // Lowering the capacity itself: say what is already booked.
    if (capacityKg !== undefined && incomingKg === 0) {
      const bookedKg = Math.round(occupied * 100) / 100
      throw badRequest(`${bookedKg} kg is already booked on this flight. The capacity cannot be less than that.`)
    }
    const free = Math.max(0, Math.round((capacity - occupied) * 100) / 100)
    throw badRequest('Flight capacity exceeded. Available: ' + free + ' kg. Choose another flight or update its confirmed baggage capacity first.')
  }
}
