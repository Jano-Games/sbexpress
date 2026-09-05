import { financialSummary } from '../shared/financialSummary'
import { Hono } from 'hono'
import { prisma } from '../core/db'
import { cacheGetJson, cacheSetJson } from '../core/redis'
import { requireRole, type AppEnv } from './auth'
import { autoCompletePastFlights } from './flights'
import { effectiveKg, weightDelta } from '../shared/compute'
import { effectiveBill, num, numOrNull, isoDate, shipmentRow } from '../shared/serialize'
import { getSettings } from '../shared/settings'

const INCLUDE = { supplier: true, flight: true, receipt: true, expenses: true, invoice: true } as const

const CACHE_TTL_SECONDS = 10

interface Notice {
  tag: 'WEIGHT' | 'FLIGHT' | 'DUE'
  text: string
}

async function buildNotices(role: 'admin' | 'hub'): Promise<Notice[]> {
  const settings = await getSettings()
  const [ships, flights] = await Promise.all([
    prisma.shipment.findMany({ include: INCLUDE }),
    prisma.flight.findMany({ include: { flyers: { include: { flyer: true } }, shipments: true } }),
  ])

  const notices: Notice[] = []
  for (const s of ships) {
    const delta = weightDelta(num(s.bookedKg), numOrNull(s.weighedKg), settings.threshold)
    if (delta !== null) {
      const label = role === 'hub' ? s.supplier.code : `${s.supplier.code} · ${s.supplier.name}`
      const sign = delta > 0 ? '+' : ''
      notices.push({
        tag: 'WEIGHT',
        text: `${s.code} (${label}) weighed ${num(s.weighedKg)} kg vs ${num(s.bookedKg)} kg booked — Δ${sign}${delta}kg`,
      })
    }
  }

  const next = flights
    .filter((f) => f.status === 'upcoming')
    .sort((a, b) => a.date.getTime() - b.date.getTime())[0]
  if (next) {
    const booked = next.shipments.reduce((a, s) => a + num(s.bookedKg), 0)
    const left = Math.round((next.spaceKg - booked) * 10) / 10
    const flyers = next.flyers.map((x) => x.flyer.name).join(', ') || 'no flyer yet'
    const dateLabel = next.date.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'short', timeZone: 'UTC' })
    notices.push({ tag: 'FLIGHT', text: `${next.code} departs ${dateLabel} — ${left} kg space left. Flyer: ${flyers}` })
  }

  if (role === 'admin') {
    const month = new Date().toISOString().slice(0, 7)
    const monthly = await prisma.supplier.findMany({
      where: { terms: 'monthly' },
      include: { shipments: { include: { invoice: true } } },
    })
    for (const sup of monthly) {
      const due = sup.shipments
        .filter((s) => s.createdAt.toISOString().startsWith(month))
        .reduce((a, s) => a + Math.max(0, effectiveBill(s) - num(s.paidAmount)), 0)
      if (due > 0) {
        const cycleEnd = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() + 1, 0))
        const closeLabel = cycleEnd.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', timeZone: 'UTC' })
        notices.push({
          tag: 'DUE',
          text: `Billing cycle closes ${closeLabel} — ${sup.name} (${sup.code}) balance ৳${due.toLocaleString('en-IN')} outstanding`,
        })
      }
    }
  }
  return notices
}

export const dashboardRoutes = new Hono<AppEnv>()
  .get('/overview', requireRole('admin'), async (c) => {
    await autoCompletePastFlights()

    const [settings, money, ships, flights, todos] = await Promise.all([
      getSettings(),
      financialSummary('week'),
      prisma.shipment.findMany({ include: INCLUDE, orderBy: { code: 'asc' } }),
      prisma.flight.findMany({ include: { flyers: { include: { flyer: true } }, shipments: true } }),
      prisma.todo.findMany({ where: { role: 'admin', done: false } }),
    ])

    // "This week" = the current calendar week, Monday through today.
    const now = new Date()
    const weekStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - ((now.getUTCDay() + 6) % 7)))
    const reviewCount = ships.filter((s) => s.receipt?.status === 'pending').length

    const upcoming = flights
      .filter((f) => f.status === 'upcoming')
      .sort((a, b) => a.date.getTime() - b.date.getTime())[0]
    const upcomingBooked = upcoming ? upcoming.shipments.reduce((a, s) => a + num(s.bookedKg), 0) : 0

    const flightRows = flights
      .slice()
      .sort((a, b) =>
        a.status === 'upcoming' && b.status !== 'upcoming'
          ? -1
          : b.status === 'upcoming' && a.status !== 'upcoming'
            ? 1
            : a.date.getTime() - b.date.getTime(),
      )
      .map((f) => ({
        code: f.code,
        date: isoDate(f.date),
        flyers: f.flyers.map((x) => x.flyer.name),
        bookedKg: Math.round(f.shipments.reduce((a, s) => a + num(s.bookedKg), 0) * 10) / 10,
        spaceKg: f.spaceKg,
        status: f.status,
        shipmentCount: f.shipments.length,
      }))

    const payload = {
      weekLabel: `${weekStart.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', timeZone: 'UTC' })} – ${now.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', timeZone: 'UTC' })}`,
      todayLabel: new Date().toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'short', year: 'numeric' }),
      rate: settings.rate,
      cash: money.cash,
      received: money.received,
      expenses: money.expenses,
      refunded: money.refunded,
      net: money.net,
      profit: money.results.profit,
      capitalReceived: money.capitalReceived,
      unpaid: money.receivables.total,
      flyerReceivables: money.flyerReceivables,
      payables: money.ticketPayables + money.costPayables,
      reviewCount,
      openTodoCount: todos.length,
      nextFlight: upcoming
        ? {
            code: upcoming.code,
            date: isoDate(upcoming.date),
            bookedKg: Math.round(upcomingBooked * 10) / 10,
            spaceKg: upcoming.spaceKg,
          }
        : null,
      notices: await buildNotices('admin'),
      flights: flightRows,
      activeShipments: ships
        .filter((s) => s.status !== 'delivered')
        .map((s) => shipmentRow(s, 'admin', settings.threshold)),
    }
    return c.json(payload)
  })

  .get('/hub', requireRole('hub'), async (c) => {
    await autoCompletePastFlights()
    const cached = await cacheGetJson<object>('dashboard:hub')
    if (cached) return c.json(cached)

    const [settings, ships, todos, flights] = await Promise.all([
      getSettings(),
      prisma.shipment.findMany({ include: INCLUDE, orderBy: { code: 'asc' } }),
      prisma.todo.findMany({ where: { role: 'hub', done: false } }),
      prisma.flight.findMany({ where: { status: 'upcoming' }, include: { shipments: true }, orderBy: { date: 'asc' } }),
    ])

    const statusIdx = (s: (typeof ships)[number]) =>
      ['pending', 'received_cn_hub', 'ready_for_shipment', 'in_transit', 'customs_cleared', 'received_bd_hub', 'ready_for_last_mile', 'out_for_delivery', 'delivered'].indexOf(s.status)

    const atHub = ships.filter((s) => statusIdx(s) >= 5 && statusIdx(s) < 8)
    const inTransit = ships.filter((s) => statusIdx(s) === 3 || statusIdx(s) === 4)
    const nextFlight = flights[0]

    const payload = {
      todayLabel: new Date().toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' }),
      atHubCount: atHub.length,
      incoming: {
        kg: Math.round(inTransit.reduce((a, s) => a + effectiveKg(num(s.bookedKg), numOrNull(s.weighedKg)), 0) * 10) / 10,
        count: inTransit.length,
        flightCode: nextFlight?.code ?? null,
        flightDate: nextFlight ? isoDate(nextFlight.date) : null,
      },
      openTodoCount: todos.length,
      notices: await buildNotices('hub'),
      toProcess: atHub.map((s) => shipmentRow(s, 'hub', settings.threshold)),
    }
    await cacheSetJson('dashboard:hub', payload, CACHE_TTL_SECONDS)
    return c.json(payload)
  })
