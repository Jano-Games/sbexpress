import { prisma } from '../core/db'
import { badRequest } from '../core/errors'
import { effectiveBill, num, isoDate } from './serialize'
import { getSettings } from './settings'
import { buildStatement } from '../modules/suppliers'
const monthOf = (d: Date): string => d.toISOString().slice(0, 7)
const monthLabel = (month: string): string => new Date(`${month}-01T00:00:00Z`).toLocaleDateString('en-GB', {month:'long',year:'numeric',timeZone:'UTC'})

/** Shared cash, accrual profit and outstanding balances for all summaries. */
export async function financialSummary(period: string) {
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

    const [settings, accounts, expenses, payments, monthlySuppliers, allShipments, allFlights] = await Promise.all([
      getSettings(),
      prisma.account.findMany({ orderBy: { createdAt: 'asc' }, include:{paymentMethod:true} }),
      prisma.expense.findMany({
        include: { shipment: { select: { code: true } }, flight: { select: { code: true } } },
        orderBy: { date: 'asc' },
      }),
      prisma.payment.findMany({ include: { shipment: { select: { code: true } } }, orderBy: { createdAt: 'asc' } }),
      prisma.supplier.findMany({ where: { terms: 'monthly' }, select: { code: true } }),
      prisma.shipment.findMany({ include: { invoice: true, expenses:true } }),
      prisma.flight.findMany(),
    ])
    const allRefunds=await prisma.customerRefund.findMany({include:{supplier:{select:{code:true}}},orderBy:{createdAt:'desc'}})
    const refunds=allRefunds.filter(r=>inPeriod(r.createdAt))
    const refundTotal=refunds.reduce((a,r)=>a+num(r.amount),0)
    const customerCredits=await prisma.supplier.aggregate({_sum:{creditBalance:true}})
    const openShipments = allShipments.filter((s) => effectiveBill(s) > num(s.paidAmount))

    const cashBdt = accounts.filter((a) => a.currency === 'BDT').reduce((a, x) => a + num(x.balance), 0)
    const cashCny = accounts.filter((a) => a.currency === 'CNY').reduce((a, x) => a + num(x.balance), 0)

    const expensesInMonth = expenses.filter((e) => inPeriod(e.date))
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
    const otherExpenses = round2(
      expensesInMonth.filter((e) => !e.costField && !(e.category === 'ticket' && e.flightId)).reduce((a, e) => a + num(e.amount), 0),
    )
    const otherIncome = round2(paymentsInMonth.filter(p => p.kind === 'income').reduce((a,p) => a + num(p.amount), 0))
    const earned = round2(billing + fares + otherIncome)
    const totalCosts = round2(tickets + cnTransport + bdTransport + customs + otherExpenses)
    const results = {
      otherIncome,
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
      ...new Set([monthOf(new Date()), ...expenses.map((e) => monthOf(e.date)), ...payments.map((p) => monthOf(p.date))]),
    ].sort((a, b) => b.localeCompare(a))

    // Statements are a month-end billing artifact — only for month periods.
    const statements = isMonth ? await Promise.all(monthlySuppliers.map((s) => buildStatement(s.code, month))) : []

    return {
      transfers: (await prisma.fundTransfer.findMany({ orderBy: { createdAt: 'desc' }, take: 50 })).map(t => ({ reference: t.reference, from: t.fromName, to: t.toName, fromCurrency: t.fromCurrency, toCurrency: t.toCurrency, amount: num(t.amount), receivedAmount: num(t.receivedAmount), note: t.note, at: t.createdAt.toISOString() })),
      period,
      periodLabel,
      months: months.map((m) => ({ value: m, label: monthLabel(m) })),
      rate: settings.rate,
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
      costPayables: allShipments.reduce((total,s)=>total+(['cnFare','bdFare','customsTax'] as const).reduce((a,field)=>a+Math.max(0,num(s[field])-s.expenses.filter(e=>e.costField===field).reduce((v,e)=>v+num(e.amount),0)),0),0),
      flyerReceivables: allFlights.reduce((a,f) => a + Math.max(0,num(f.actualCost)-num(f.agencyShare)-num(f.flyerPaidAmount)),0),
      capitalReceived: paymentsInMonth.filter(p => p.kind === 'capital').reduce((a,p) => a + num(p.amount),0),
      receivables,
      results,
      paymentRows: paymentsInMonth.map((p) => ({
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
        accountName:e.accountName, accountCurrency:e.accountCurrency, accountAmount:num(e.accountAmount), fxRate:num(e.fxRate),
        date: isoDate(e.date),
        category: e.category,
        amount: num(e.amount),
        reason: e.reason,
        shipmentCode: e.shipment?.code ?? null,
        flightCode: e.flight?.code ?? null,
      })),
      statements: statements.map((s, i) => ({
        code: monthlySuppliers[i]!.code,
        name: s.to.replace(/ \(.*\)$/, ''),
        billed: s.lines.reduce((a, l) => a + l.amount, 0),
        paid: s.lines.reduce((a, l) => a + l.amount, 0) - s.total,
        balance: s.total,
        shipmentCount: s.lines.length,
      })),
    }

}
