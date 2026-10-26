import { financialSummary } from '../shared/financialSummary'
import { Hono } from 'hono'
import type { Prisma } from '@prisma/client'
import { prisma } from '../core/db'
import { cacheGetJson, cacheSetJson } from '../core/redis'
import { requireRole, type AppEnv } from './auth'
import { effectiveKg, weightDelta } from '../shared/compute'
import { effectiveBill, num, numOrNull, isoDate, shipmentOperatingCosts, shipmentRow } from '../shared/serialize'
import { syncHubTodos } from '../shared/hubTodos'
import { HUB_FLIGHT_INCLUDE, hubFlightRow } from '../shared/hubFlights'
import { getSettings, type AppSettings } from '../shared/settings'
import { usualCosts } from '../shared/shipmentCosts'
import { STATUS_LABEL, STATUS_ORDER } from '../shared/status'

const INCLUDE = { supplier: true, flight: true, receipts: true, expenses: true, costs: true, invoice: true } as const
const FLIGHT_INCLUDE = {
  flyers: { include: { flyer: true } },
  shipments: { include: { expenses: true, costs: true, invoice: true } },
} as const
type DashboardShipment = Prisma.ShipmentGetPayload<{ include: typeof INCLUDE }>
type DashboardFlight = Prisma.FlightGetPayload<{ include: typeof FLIGHT_INCLUDE }>

const DAY_MS = 86_400_000
/** An after-delivery bill counts as overdue a week after handover. */
const OVERDUE_DAYS = 7
const DHAKA_HUB_INDEX = STATUS_ORDER.indexOf('received_bd_hub')

const round2 = (value: number) => Math.round(value * 100) / 100
const dueOf = (s: DashboardShipment) => Math.max(0, round2(effectiveBill(s) - num(s.paidAmount)))

/** Charges minus shipment costs minus the part of the ticket the company pays. */
function flightProfit(f: DashboardFlight) {
  const revenue = round2(f.shipments.reduce((total, s) => total + effectiveBill(s), 0))
  const costs = round2(f.shipments.reduce((total, s) => total + shipmentOperatingCosts(s).total, 0))
  return { revenue, costs, profit: round2(revenue + num(f.fare) - num(f.actualCost) - costs) }
}

/** Shipments past the Dhaka hub that still lack one of the usual costs. */
function missingCostCount(f: DashboardFlight) {
  return f.shipments.filter(
    (s) => STATUS_ORDER.indexOf(s.status) >= DHAKA_HUB_INDEX && usualCosts(s).some((c) => c.amount === 0),
  ).length
}

/**
 * Money customers still owe, the way the business collects it: after-delivery
 * bills once the parcel is handed over, and one monthly bill per customer.
 */
async function collectSheet(ships: DashboardShipment[]) {
  const today = new Date(new Date().toISOString().slice(0, 10))
  const month = today.toISOString().slice(0, 7)
  const afterDelivery = ships.filter((s) => s.paymentTerms !== 'monthly' && !s.freeOfCharge && dueOf(s) > 0)
  const handedOver = afterDelivery
    .filter((s) => s.status === 'delivered')
    .map((s) => {
      const at = s.handedOverAt ?? s.createdAt
      const days = Math.max(0, Math.floor((today.getTime() - new Date(at.toISOString().slice(0, 10)).getTime()) / DAY_MS))
      return {
        code: s.code,
        supplierCode: s.supplier.code,
        supplierName: s.supplier.name,
        supplierPhone: s.supplier.phone,
        amount: dueOf(s),
        deliveredOn: isoDate(at),
        days,
        overdue: days > OVERDUE_DAYS,
      }
    })
    .sort((a, b) => b.days - a.days || a.code.localeCompare(b.code))
  const comingSoon = afterDelivery
    .filter((s) => s.status === 'out_for_delivery' || s.status === 'ready_for_last_mile')
    .map((s) => ({
      code: s.code,
      supplierCode: s.supplier.code,
      supplierName: s.supplier.name,
      amount: dueOf(s),
      status: s.status,
      statusLabel: STATUS_LABEL[s.status],
    }))

  const monthly = new Map<string, { code: string; name: string; phone: string; billed: number; paid: number; due: number; shipments: number }>()
  for (const s of ships) {
    if (s.paymentTerms !== 'monthly' || s.invoice?.state !== 'issued' || s.invoice.needsReview) continue
    if (!s.createdAt.toISOString().startsWith(month)) continue
    const bill = effectiveBill(s)
    const row = monthly.get(s.supplierId) ?? { code: s.supplier.code, name: s.supplier.name, phone: s.supplier.phone, billed: 0, paid: 0, due: 0, shipments: 0 }
    row.billed = round2(row.billed + bill)
    row.paid = round2(row.paid + Math.min(bill, num(s.paidAmount)))
    row.due = round2(row.due + dueOf(s))
    row.shipments += 1
    monthly.set(s.supplierId, row)
  }
  const links = monthly.size
    ? await prisma.statementLink.findMany({
        where: { month, supplierId: { in: [...monthly.keys()] }, revokedAt: null },
        orderBy: { createdAt: 'desc' },
        select: { supplierId: true, createdAt: true, expiresAt: true },
      })
    : []
  const customers = [...monthly.entries()]
    .map(([supplierId, row]) => {
      const link = links.find((l) => l.supplierId === supplierId)
      return {
        ...row,
        linkSentOn: link ? isoDate(link.createdAt) : null,
        linkActive: Boolean(link && link.expiresAt > new Date()),
      }
    })
    .sort((a, b) => b.due - a.due || a.name.localeCompare(b.name))

  return {
    today: isoDate(today),
    afterDelivery: {
      handedOver,
      comingSoon,
      due: round2(handedOver.reduce((sum, row) => sum + row.amount, 0)),
      overdueCount: handedOver.filter((row) => row.overdue).length,
    },
    monthly: {
      month,
      monthLabel: new Date(`${month}-01T00:00:00Z`).toLocaleDateString('en-GB', { month: 'long', year: 'numeric', timeZone: 'UTC' }),
      customers,
      due: round2(customers.reduce((sum, row) => sum + row.due, 0)),
    },
  }
}

const CACHE_TTL_SECONDS = 10

interface Notice {
  tag: 'WEIGHT' | 'FLIGHT' | 'DUE'
  text: string
}

function buildNotices(role: 'admin' | 'hub', settings: AppSettings, ships: DashboardShipment[], flights: DashboardFlight[]): Notice[] {
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
    const monthly = new Map<string, { name: string; code: string; due: number }>()
    for (const shipment of ships) {
      if (shipment.paymentTerms !== 'monthly' || shipment.invoice?.state!=='issued' || shipment.invoice.needsReview || !shipment.createdAt.toISOString().startsWith(month)) continue
      const supplier = shipment.supplier
      const account = monthly.get(supplier.id) ?? { name: supplier.name, code: supplier.code, due: 0 }
      account.due += Math.max(0, effectiveBill(shipment) - num(shipment.paidAmount))
      monthly.set(supplier.id, account)
    }
    for (const sup of monthly.values()) {
      const due = sup.due
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
  .get('/counts', requireRole('admin', 'hub'), async (c) => {
    const role = c.get('user').role
    if (role === 'hub') {
      await syncHubTodos()
      const openTodoCount = await prisma.todo.count({ where: { role: 'hub', done: false } })
      return c.json({ reviewCount: 0, openTodoCount })
    }
    const [shipmentReceipts, statementReceipts, openTodoCount] = await Promise.all([
      prisma.receipt.count({ where: { status: 'pending' } }),
      prisma.statementReceipt.count({ where: { status: 'pending' } }),
      prisma.todo.count({ where: { role: 'admin', done: false } }),
    ])
    return c.json({ reviewCount: shipmentReceipts + statementReceipts, openTodoCount })
  })
  .get('/overview', requireRole('admin'), async (c) => {

    // Materialize each Prisma promise once, then reuse that response snapshot in
    // both the financial summary and notices instead of repeating remote reads.
    const settingsRead = getSettings()
    const shipmentsRead = Promise.resolve(prisma.shipment.findMany({ include: INCLUDE, orderBy: { code: 'asc' } }))
    const flightsRead = Promise.resolve(prisma.flight.findMany({ include: FLIGHT_INCLUDE }))
    const [settings, money, ships, flights, todos, flyers] = await Promise.all([
      settingsRead,
      financialSummary('week', { settings: settingsRead, shipments: shipmentsRead, flights: flightsRead }),
      shipmentsRead,
      flightsRead,
      prisma.todo.findMany({ where: { role: 'admin', done: false } }),
      prisma.flyer.findMany({
        where: { archivedAt: null },
        select: { name: true, docStudentId: true, docVisa: true, docAdmission: true },
        orderBy: { createdAt: 'desc' },
      }),
    ])
    // Travel documents every active flyer should have on file.
    const flyersMissingDocs = flyers
      .map((f) => ({
        name: f.name,
        missing: [
          ...(f.docStudentId ? [] : ['student_id']),
          ...(f.docVisa ? [] : ['visa']),
          ...(f.docAdmission ? [] : ['admission']),
        ],
      }))
      .filter((f) => f.missing.length > 0)

    // "This week" = the current calendar week, Monday through today.
    const now = new Date()
    const weekStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - ((now.getUTCDay() + 6) % 7)))
    const reviewCount = ships.filter((s) => s.receipts.some(r => r.status === 'pending')).length
    const stageCounts: Record<string, number> = Object.fromEntries(STATUS_ORDER.map(status => [status, 0]))
    for (const shipment of ships) stageCounts[shipment.status] = (stageCounts[shipment.status] ?? 0) + 1

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
        ...flightProfit(f),
        missingCostCount: missingCostCount(f),
      }))
    const collect = await collectSheet(ships)

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
      notices: buildNotices('admin', settings, ships, flights),
      flights: flightRows,
      flyersMissingDocs: flyersMissingDocs.slice(0, 10),
      flyersMissingDocsCount: flyersMissingDocs.length,
      collect: {
        afterDeliveryDue: collect.afterDelivery.due,
        afterDeliveryCount: collect.afterDelivery.handedOver.length,
        overdueCount: collect.afterDelivery.overdueCount,
        monthlyDue: collect.monthly.due,
        monthlyCustomers: collect.monthly.customers.filter((row) => row.due > 0).length,
        month: collect.monthly.month,
        monthLabel: collect.monthly.monthLabel,
      },
      stageCounts,
      activeShipmentCount: ships.filter(s => s.status !== 'delivered').length,
      activeShipments: ships
        .filter((s) => s.status !== 'delivered')
        .sort((a,b) => b.createdAt.getTime() - a.createdAt.getTime() || b.code.localeCompare(a.code))
        .slice(0, 8)
        .map((s) => shipmentRow(s, 'admin', settings.threshold)),
    }
    return c.json(payload)
  })

  /** The "Get paid" list: who to collect from now, and this month's monthly bills. */
  .get('/collect', requireRole('admin'), async (c) => {
    const ships = await prisma.shipment.findMany({ include: INCLUDE, orderBy: { code: 'asc' } })
    return c.json(await collectSheet(ships))
  })

  .get('/hub', requireRole('hub'), async (c) => {
    const cached = await cacheGetJson<object>('dashboard:hub')
    if (cached) return c.json(cached)

    await syncHubTodos()
    const [settings, ships, todos, flights, arriving] = await Promise.all([
      getSettings(),
      prisma.shipment.findMany({ include: INCLUDE, orderBy: { code: 'asc' } }),
      prisma.todo.findMany({ where: { role: 'hub', done: false } }),
      prisma.flight.findMany({ where: { status: 'upcoming' }, include: FLIGHT_INCLUDE, orderBy: { date: 'asc' } }),
      prisma.flight.findMany({ where: { status: { in: ['upcoming', 'departed'] } }, include: HUB_FLIGHT_INCLUDE, orderBy: { date: 'asc' }, take: 5 }),
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
      notices: buildNotices('hub', settings, ships, flights),
      toProcess: atHub.map((s) => shipmentRow(s, 'hub', settings.threshold)),
      upcomingFlights: arriving.map((f) => hubFlightRow(f)),
    }
    await cacheSetJson('dashboard:hub', payload, CACHE_TTL_SECONDS)
    return c.json(payload)
  })
