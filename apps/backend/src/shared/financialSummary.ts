import { shipmentCostItems } from './shipmentCosts'
import { isFlightCost, isUnpaidFlightCost } from './flightCosts'
import type { Flight, Prisma } from '@prisma/client'
import { prisma } from '../core/db'
import { badRequest } from '../core/errors'
import { effectiveBill, num, isoDate } from './serialize'
import { getSettings, type AppSettings } from './settings'
const monthOf = (d: Date): string => d.toISOString().slice(0, 7)
const monthLabel = (month: string): string => new Date(`${month}-01T00:00:00Z`).toLocaleDateString('en-GB', {month:'long',year:'numeric',timeZone:'UTC'})

type SummaryShipment = Prisma.ShipmentGetPayload<{ include: { invoice: true; expenses: true; costs: true } }>

/** A caller may share reads within this response; nothing is cached across requests. */
export interface FinancialSummarySnapshot {
  settings?: AppSettings | Promise<AppSettings>
  shipments?: SummaryShipment[] | Promise<SummaryShipment[]>
  flights?: Flight[] | Promise<Flight[]>
}

/** Shared cash, accrual profit and outstanding balances for all summaries. */
export async function financialSummary(period: string, snapshot: FinancialSummarySnapshot = {}) {
    const isMonth = /^\d{4}-\d{2}$/.test(period)
    if (!isMonth && period !== 'week' && period !== 'all') throw badRequest('period must be week, all or YYYY-MM')

    const now = new Date()
    const weekStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - ((now.getUTCDay() + 6) % 7)))
    const inPeriod = (d: Date): boolean =>
      period === 'all' ? true : period === 'week' ? d >= weekStart && d <= now : monthOf(d) === period
    const periodLabel =
      period === 'all'
        ? 'All time'
        : period === 'week'
          ? `This week (${weekStart.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', timeZone: 'UTC' })} – ${now.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', timeZone: 'UTC' })})`
          : monthLabel(period)
    const month = isMonth ? period : monthOf(new Date())

    const [settings, accounts, expenses, payments, monthlySuppliers, allShipments, allFlights, allRefunds, customerCredits, transfers] = await Promise.all([
      snapshot.settings ?? getSettings(),
      prisma.account.findMany({ orderBy: { createdAt: 'asc' }, include:{paymentMethod:true} }),
      prisma.expense.findMany({
        include: { shipment: { select: { code: true } }, flight: { select: { code: true } } },
        orderBy: { date: 'asc' },
      }),
      prisma.payment.findMany({ include: { shipment: { select: { code: true } } }, orderBy: { createdAt: 'asc' } }),
      isMonth ? prisma.supplier.findMany({ where: { OR:[{terms:'monthly'},{shipments:{some:{paymentTerms:'monthly'}}}] }, select: { id: true, code: true, name: true } }) : Promise.resolve([]),
      snapshot.shipments ?? prisma.shipment.findMany({ include: { invoice: true, expenses:true, costs:true } }),
      snapshot.flights ?? prisma.flight.findMany(),
      prisma.customerRefund.findMany({include:{supplier:{select:{code:true}}},orderBy:{createdAt:'desc'}}),
      prisma.supplier.aggregate({_sum:{creditBalance:true}}),
      prisma.fundTransfer.findMany({ orderBy: { createdAt: 'desc' }, take: 50 }),
    ])
    const refunds=allRefunds.filter(r=>inPeriod(r.createdAt))
    const refundTotal=refunds.reduce((a,r)=>a+num(r.amount),0)
    const openShipments = allShipments.filter((s) => s.invoice?.state==='issued' && !s.invoice.needsReview && effectiveBill(s) > num(s.paidAmount))

    const cashBdt = accounts.filter((a) => a.currency === 'BDT').reduce((a, x) => a + num(x.balance), 0)
    const cashCny = accounts.filter((a) => a.currency === 'CNY').reduce((a, x) => a + num(x.balance), 0)

    // A pay-later flight cost has not left any account yet: it is a payable, not cash out.
    const cashExpenses = expenses.filter((e) => !isUnpaidFlightCost(e))
    const expensesInMonth = cashExpenses.filter((e) => inPeriod(e.date))
    const paymentsInMonth = payments.filter((p) => inPeriod(p.date))
    const receivedInMonth = paymentsInMonth.reduce((a, p) => a + num(p.amount), 0)
    const expenseTotal = expensesInMonth.reduce((a, e) => a + num(e.amount), 0)

    // What customers still owe, across every not-fully-paid shipment.
    const receivableRemaining = openShipments.map((s) => Math.max(0, effectiveBill(s) - num(s.paidAmount)))
    const receivables = {
      total: Math.round(receivableRemaining.reduce((a, r) => a + r, 0) * 100) / 100,
      count: receivableRemaining.filter((r) => r > 0).length,
    }

    // ── Overall business results (accrual view): what the period's booked
    // business earned and cost, regardless of whether cash moved yet. ──
    const round2 = (n: number) => Math.round(n * 100) / 100
    const shipsIn = allShipments.filter((s) => inPeriod(s.createdAt))
    const flightsIn = allFlights.filter((f) => inPeriod(f.date))
    const billing = round2(shipsIn.reduce((a, s) => a + effectiveBill(s), 0))
    const fares = round2(flightsIn.reduce((a, f) => a + Math.max(0, num(f.actualCost) - num(f.agencyShare)), 0))
    // Full ticket cost comes from the flights themselves; ticket-category
    // expenses are the same money, so they're excluded from "other" below.
    const tickets = round2(flightsIn.reduce((a, f) => a + num(f.actualCost), 0))
    const cnTransport = round2(shipsIn.reduce((a, s) => a + num(s.cnFare), 0))
    const bdTransport = round2(shipsIn.reduce((a, s) => a + num(s.bdFare ?? null), 0))
    const customs = round2(shipsIn.reduce((a, s) => a + num(s.customsTax), 0))
    const cohortIds=new Set(shipsIn.map(s=>s.id))
    const legacyExtra=expenses.filter(e=>e.shipmentId && cohortIds.has(e.shipmentId) && !e.costField && !e.costId && !(e.category==='ticket'&&e.flightId)).reduce((sum,e)=>sum+num(e.amount),0)
    const shipmentExpenses=round2(shipsIn.reduce((sum,s)=>sum+(s.costs??[]).filter(c=>!c.voidedAt).reduce((n,c)=>n+num(c.amount),0),0)+legacyExtra)
    const shipmentCosts=round2(cnTransport+bdTransport+customs+shipmentExpenses)
    // Flight-linked rows are counted with their flight (ticket above, flight costs here), never as business expenses.
    const businessExpenses=round2(expensesInMonth.filter(e=>!e.shipmentId && !e.flightId).reduce((sum,e)=>sum+num(e.amount),0))
    // Flight costs, paid or not, belong to the period of their flight like the ticket; removed ones cancel out.
    const flightIdsIn=new Set(flightsIn.map(f=>f.id))
    const flightCosts=round2(expenses.filter(e=>isFlightCost(e) && flightIdsIn.has(e.flightId!)).reduce((sum,e)=>sum+num(e.amount),0))
    const otherExpenses=round2(shipmentExpenses+businessExpenses+flightCosts)
    const otherIncome = round2(paymentsInMonth.filter(p => p.kind === 'income').reduce((a,p) => a + num(p.amount), 0))
    const earned = round2(billing + fares + otherIncome)
    const totalCosts = round2(tickets + cnTransport + bdTransport + customs + otherExpenses)
    const results = {
      otherIncome,
      shipmentCosts,
      businessExpenses,
      flightCosts,
      shipmentCount: shipsIn.length,
      flightCount: flightsIn.length,
      billing,
      fares,
      earned,
      tickets,
      cnTransport,
      bdTransport,
      customs,
      otherExpenses,
      costs: totalCosts,
      profit: round2(earned - totalCosts),
      marginPct: earned > 0 ? Math.round(((earned - totalCosts) / earned) * 100) : null,
    }

    // Every month that has activity, newest first, plus the current one.
    const months = [
      ...new Set([monthOf(new Date()), ...allShipments.map(s=>monthOf(s.createdAt)), ...allFlights.map(f=>monthOf(f.date)), ...expenses.map((e) => monthOf(e.date)), ...payments.map((p) => monthOf(p.date))]),
    ].sort((a, b) => b.localeCompare(a))

    // Use the same invoice-first bill and per-shipment rounding as buildStatement,
    // without fetching the same supplier shipments again for every monthly account.
    const statements = monthlySuppliers.map(supplier => {
      const rows = allShipments.filter(shipment => shipment.supplierId === supplier.id && monthOf(shipment.createdAt) === month && shipment.invoice?.state==='issued' && !shipment.invoice.needsReview)
      const billed = rows.reduce((total, shipment) => total + effectiveBill(shipment), 0)
      const balance = rows.reduce((total, shipment) => total + Math.max(0, Math.round((effectiveBill(shipment) - num(shipment.paidAmount)) * 100) / 100), 0)
      return {
        code: supplier.code,
        name: `${supplier.name} (${supplier.code})`.replace(/ \(.*\)$/, ''),
        billed,
        paid: billed - balance,
        balance,
        shipmentCount: rows.length,
      }
    })

    return {
      transfers: transfers.map(t => ({ reference: t.reference, from: t.fromName, to: t.toName, fromCurrency: t.fromCurrency, toCurrency: t.toCurrency, amount: num(t.amount), receivedAmount: num(t.receivedAmount), note: t.note, at: t.createdAt.toISOString() })),
      recognitionBasis:"booking-cohort",
      period,
      periodLabel,
      months: months.map((m) => ({ value: m, label: monthLabel(m) })),
      rate: settings.rate,
      exchangeRates: settings.exchangeRates,
      cash: { bdt: cashBdt, cny: cashCny, worth: Math.round(cashBdt + cashCny * settings.rate) },
      invested: {
        bdt: settings.investBdt,
        cny: settings.investCny,
        worth: Math.round(settings.investBdt + settings.investCny * settings.rate),
      },
      received: receivedInMonth,
      expenses: expenseTotal,
      net: receivedInMonth - expenseTotal - refundTotal,
      refunded:refundTotal,
      customerCreditLiability:num(customerCredits._sum.creditBalance),
      refundRows:refunds.map(r=>({reference:r.reference,supplierCode:r.supplier.code,amount:num(r.amount),accountName:r.accountName,reason:r.reason,at:r.createdAt.toISOString()})),
      ticketPayables: allFlights.reduce((a,f)=>a+Math.max(0,num(f.actualCost)-expenses.filter(e=>e.flightId===f.id&&e.category==='ticket').reduce((t,e)=>t+num(e.amount),0)),0),
      ticketRefundReceivables: allFlights.reduce((a,f)=>a+Math.max(0,expenses.filter(e=>e.flightId===f.id&&e.category==='ticket').reduce((t,e)=>t+num(e.amount),0)-num(f.actualCost)),0),
      costPayables: round2(allShipments.reduce((sum,s)=>sum+shipmentCostItems(s).reduce((n,c)=>n+c.dueAmount,0),0)+expenses.filter(isUnpaidFlightCost).reduce((sum,e)=>sum+num(e.amount),0)),
      flyerReceivables: allFlights.reduce((a,f) => a + Math.max(0,num(f.actualCost)-num(f.agencyShare)-num(f.flyerPaidAmount)),0),
      capitalReceived: paymentsInMonth.filter(p => p.kind === 'capital').reduce((a,p) => a + num(p.amount),0),
      receivables,
      results,
      paymentRows: paymentsInMonth.map((p) => ({
        sourceCurrency:p.sourceCurrency,sourceAmount:num(p.sourceAmount),sourceFxRate:num(p.sourceFxRate),
        accountName:p.accountName, accountCurrency:p.accountCurrency, accountAmount:num(p.accountAmount), fxRate:num(p.fxRate), kind:p.kind,
        date: isoDate(p.date),
        method: p.method,
        reference: p.reference,
        shipmentCode: p.shipment?.code ?? null,
        amount: num(p.amount),
      })),
      accounts: accounts.map((a) => ({
        name: a.name,
        kind: a.kind,
        currency: a.currency,
        balance: num(a.balance),
        bank: a.paymentMethod?.kind === 'bank_account' ? {bankName:a.paymentMethod.bankName,accountNumber:a.paymentMethod.accountNumber,accountName:a.paymentMethod.accountName,branch:a.paymentMethod.branch,district:a.paymentMethod.district} : null,
        mobile: a.paymentMethod?.kind === 'mobile_banking' ? {provider:a.paymentMethod.provider,number:a.paymentMethod.number,label:a.paymentMethod.label} : null,
      })),
      expenseRows: expensesInMonth.map((e) => ({
        sourceCurrency:e.sourceCurrency,sourceAmount:num(e.sourceAmount),sourceFxRate:num(e.sourceFxRate),
        accountName:e.accountName, accountCurrency:e.accountCurrency, accountAmount:num(e.accountAmount), fxRate:num(e.fxRate),
        date: isoDate(e.date),
        category: e.category,
        amount: num(e.amount),
        reason: e.reason,
        shipmentCode: e.shipment?.code ?? null,
        flightCode: e.flight?.code ?? null,
      })),
      statements,
    }

}
