import { Hono } from 'hono'
import type { Expense } from '@prisma/client'
import { z } from 'zod'
import { prisma } from '../core/db'
import { badRequest, notFound } from '../core/errors'
import { requireRole, type AppEnv } from './auth'
import { sourceAt, withSavedMoney } from '../shared/money'
import { changeCredit, money } from '../shared/customerCredit'
import { paymentStatus } from '../shared/serialize'
import { writeShipmentLog } from '../shared/actor'
import { refreshShipmentInvoice } from '../shared/shipmentBilling'

async function moveAccount(
  name: string | null,
  currency: string | null,
  amount: number,
) {
  if (!name || !currency || !Number.isFinite(amount))
    throw badRequest(
      'This historical entry has no complete account posting; reconcile it before reversing',
    )
  const matches = await prisma.account.findMany({
    where: { name, currency: currency as 'BDT' | 'CNY' },
  })
  if (matches.length !== 1)
    throw badRequest(
      'The original account is unavailable; restore or reconcile it first',
    )
  const account = matches[0]!
  if (money(Number(account.balance) + amount) < 0)
    throw badRequest(
      'Insufficient balance in the original account to reverse this entry',
    )
  await prisma.account.update({
    where: { id: account.id },
    data: { balance: { increment: amount } },
  })
}
const guard = (
  row: { reversalOfId: string | null; reversedAt: Date | null } | null,
) => {
  if (!row) throw notFound('Entry not found')
  if (row.reversalOfId || row.reversedAt)
    throw badRequest('This entry is already reversed or is itself a reversal')
}

/**
 * Offsets one expense with a negative twin and marks it reversed; posted money
 * goes back to its account. `allowUnposted` covers a pay-later flight cost,
 * which never left an account, so there is nothing to give back. The caller
 * records the LedgerReversal row.
 */
export async function reverseExpenseOffset(
  e: Expense,
  reason: string,
  { allowUnposted = false } = {},
): Promise<string> {
  guard(e)
  const posted = e.accountAmount !== null
  if (Number(e.amount) === 0 || (!posted && !allowUnposted))
    throw badRequest(
      'Choose an expense with a complete original account posting',
    )
  if (posted)
    await moveAccount(e.accountName, e.accountCurrency, Number(e.accountAmount))
  const offset = await prisma.expense.create({
    data: {
      ...sourceAt(-Number(e.amount), e),
      costId: e.costId,
      costField: e.costField,
      date: new Date(),
      category: e.category,
      amount: -Number(e.amount),
      reason: `Reversal: ${e.reason} — ${reason}`,
      shipmentId: e.shipmentId,
      flightId: e.flightId,
      accountName: posted ? e.accountName : null,
      accountCurrency: posted ? e.accountCurrency : null,
      accountAmount: posted ? -Number(e.accountAmount) : null,
      fxRate: posted ? e.fxRate : null,
      reversalOfId: e.id,
    },
  })
  await prisma.expense.update({
    where: { id: e.id },
    data: { reversedAt: new Date() },
  })
  if (e.shipmentId)
    await writeShipmentLog(
      e.shipmentId,
      `Cost payment reversed: BDT ${e.amount} — ${reason}. The recorded cost remains payable until cancelled or settled.`,
    )
  return offset.id
}

export const correctionRoutes = new Hono<AppEnv>().post(
  '/reverse',
  requireRole('admin'),
  async (c) => {
    const b = z
      .object({
        kind: z.enum(['payment', 'expense', 'refund', 'transfer', 'credit']),
        id: z.string().min(1),
        reason: z.string().trim().min(3).max(500),
      })
      .parse(await c.req.json())
    const u = c.get('user')
    if (
      await prisma.ledgerReversal.findUnique({
        where: { kind_recordId: { kind: b.kind, recordId: b.id } },
      })
    )
      throw badRequest('This entry has already been reversed')
    let offsetId = ''
    if (b.kind === 'payment') {
      const p = await prisma.payment.findUnique({
        where: { id: b.id },
        include: {
          shipment: { include: { invoice: true } },
          receipt: true,
          statementReceipt: true,
        },
      })
      guard(p)
      if (!p || Number(p.amount) <= 0)
        throw badRequest('Choose an original positive payment')
      if (p.accountAmount === null)
        throw badRequest(
          'Reconcile the original account posting before reversing',
        )
      await moveAccount(
        p.accountName,
        p.accountCurrency,
        -Number(p.accountAmount),
      )
      if (p.shipment) {
        const s = p.shipment,
          remaining = money(
            Math.max(0, Number(s.paidAmount) - Number(p.amount)),
          ),
          released = money(Math.max(0, Number(p.amount) - Number(s.paidAmount)))
        if (released)
          await withSavedMoney(p, () =>
            changeCredit(
              s.supplierId,
              -released,
              'payment-reversal',
              b.reason,
              s.code,
            ),
          )
        await prisma.shipment.update({
          where: { id: s.id },
          data: {
            paidAmount: remaining,
            payStatus: paymentStatus({ ...s, paidAmount: remaining }),
          },
        })
        await writeShipmentLog(
          s.id,
          `Payment reversed: BDT ${p.amount} from ${p.accountName} — ${b.reason}`,
        )
      } else if (p.kind === 'customer-credit') {
        if (!p.supplierId)
          throw badRequest(
            'Identify the customer for this historical advance before reversing',
          )
        await withSavedMoney(p, () =>
          changeCredit(
            p.supplierId!,
            -Number(p.amount),
            'payment-reversal',
            b.reason,
          ),
        )
      } else if (p.kind === 'flyer') {
        if (!p.flightId || !p.flyerId)
          throw badRequest(
            'Allocate this historical flyer receipt to its flyer before reversing',
          )
        const member = await prisma.flightFlyer.findUnique({
          where: {
            flightId_flyerId: { flightId: p.flightId, flyerId: p.flyerId },
          },
        })
        if (!member || Number(member.paidAmount) < Number(p.amount))
          throw badRequest('The flyer settlement needs reconciliation first')
        await prisma.flightFlyer.update({
          where: {
            flightId_flyerId: { flightId: p.flightId, flyerId: p.flyerId },
          },
          data: { paidAmount: { decrement: p.amount } },
        })
        await prisma.flight.update({
          where: { id: p.flightId },
          data: { flyerPaidAmount: { decrement: p.amount } },
        })
      }
      const offset = await prisma.payment.create({
        data: {
          ...sourceAt(-Number(p.amount), p),
          date: new Date(),
          method: p.method,
          amount: -Number(p.amount),
          reference: `Reversal of ${p.reference}: ${b.reason}`,
          kind: p.kind,
          shipmentId: p.shipmentId,
          supplierId: p.supplierId,
          flightId: p.flightId,
          flyerId: p.flyerId,
          accountName: p.accountName,
          accountCurrency: p.accountCurrency,
          accountAmount: -Number(p.accountAmount),
          fxRate: p.fxRate,
          reversalOfId: p.id,
        },
      })
      offsetId = offset.id
      await prisma.payment.update({
        where: { id: p.id },
        data: { reversedAt: new Date() },
      })
      if (p.receiptId)
        await prisma.receipt.update({
          where: { id: p.receiptId },
          data: {
            reviewReason: `Payment credit reversed: ${b.reason}. Contact support before making another transfer.`,
          },
        })
      if (p.statementReceiptId)
        await prisma.statementReceipt.update({
          where: { id: p.statementReceiptId },
          data: {
            reviewReason: `A payment allocation was reversed: ${b.reason}. Contact support before making another transfer.`,
          },
        })
    } else if (b.kind === 'expense') {
      const e = await prisma.expense.findUnique({ where: { id: b.id } })
      guard(e)
      offsetId = await reverseExpenseOffset(e!, b.reason)
    } else if (b.kind === 'refund') {
      const r = await prisma.customerRefund.findUnique({ where: { id: b.id } })
      guard(r)
      if (!r || Number(r.amount) <= 0)
        throw badRequest('Choose an original refund')
      await moveAccount(
        r.accountName,
        r.accountCurrency,
        Number(r.accountAmount),
      )
      await withSavedMoney(r, () =>
        changeCredit(
          r.supplierId,
          Number(r.amount),
          'refund-reversal',
          b.reason,
        ),
      )
      const offset = await prisma.customerRefund.create({
        data: {
          ...sourceAt(-Number(r.amount), r),
          supplierId: r.supplierId,
          amount: -Number(r.amount),
          reason: `Reversal: ${b.reason}`,
          accountName: r.accountName,
          accountCurrency: r.accountCurrency,
          accountAmount: -Number(r.accountAmount),
          fxRate: r.fxRate,
          reversalOfId: r.id,
        },
      })
      offsetId = offset.id
      await prisma.customerRefund.update({
        where: { id: r.id },
        data: { reversedAt: new Date() },
      })
    } else if (b.kind === 'transfer') {
      const t = await prisma.fundTransfer.findUnique({ where: { id: b.id } })
      guard(t)
      if (!t) throw notFound('Transfer not found')
      await moveAccount(t.toName, t.toCurrency, -Number(t.receivedAmount))
      await moveAccount(t.fromName, t.fromCurrency, Number(t.amount))
      const offset = await prisma.fundTransfer.create({
        data: {
          reference: crypto.randomUUID(),
          fromName: t.toName,
          toName: t.fromName,
          fromCurrency: t.toCurrency,
          toCurrency: t.fromCurrency,
          amount: t.receivedAmount,
          receivedAmount: t.amount,
          note: `Reversal: ${b.reason}`,
          reversalOfId: t.id,
        },
      })
      offsetId = offset.id
      await prisma.fundTransfer.update({
        where: { id: t.id },
        data: { reversedAt: new Date() },
      })
    } else {
      const credit = await prisma.customerCredit.findUnique({
        where: { id: b.id },
      })
      if (!credit || credit.kind !== 'applied' || !credit.shipmentCode)
        throw badRequest(
          'Only a credit allocation can be reversed here; revise invoices through Billing',
        )
      const s = await prisma.shipment.findFirst({
          where: { code: credit.shipmentCode, supplierId: credit.supplierId },
          include: { invoice: true },
        }),
        amount = -Number(credit.amount)
      if (!s || amount <= 0 || Number(s.paidAmount) < amount)
        throw badRequest(
          'Reconcile subsequent invoice changes before reversing this credit allocation',
        )
      const offset = await withSavedMoney(credit, () =>
        changeCredit(
          credit.supplierId,
          amount,
          'application-reversal',
          b.reason,
          s.code,
        ),
      )
      offsetId = offset.id
      await prisma.shipment.update({
        where: { id: s.id },
        data: {
          paidAmount: { decrement: amount },
          payStatus: paymentStatus({
            ...s,
            paidAmount: money(Number(s.paidAmount) - amount),
          }),
        },
      })
      await writeShipmentLog(
        s.id,
        `Credit allocation reversed: BDT ${amount} — ${b.reason}`,
      )
    }
    const reversal = await prisma.ledgerReversal.create({
      data: {
        kind: b.kind,
        recordId: b.id,
        offsetId,
        reason: b.reason,
        actorId: u.id,
        actorName: u.name,
      },
    })
    return c.json({ ok: true, reference: reversal.id })
  },
)

export const costCorrectionRoutes = new Hono<AppEnv>().post(
  '/:code/costs/:id/void',
  requireRole('admin'),
  async (c) => {
    const { reason } = z
      .object({ reason: z.string().trim().min(3).max(500) })
      .parse(await c.req.json())
    const cost = await prisma.shipmentCost.findFirst({
      where: {
        id: c.req.param('id')!,
        shipment: { code: c.req.param('code')! },
      },
      include: { expenses: true },
    })
    if (!cost || cost.voidedAt)
      throw badRequest('This cost is not available to cancel')
    if (money(cost.expenses.reduce((sum, e) => sum + Number(e.amount), 0)) > 0)
      throw badRequest(
        'Reverse the recorded cost payments in Finance before cancelling this cost',
      )
    await prisma.shipmentCost.update({
      where: { id: cost.id },
      data: { voidedAt: new Date(), voidReason: reason },
    })
    await refreshShipmentInvoice(
      cost.shipmentId,
      `Cost cancelled: ${reason}`,
      true,
    )
    await writeShipmentLog(
      cost.shipmentId,
      `Cost cancelled: ${cost.name} — ${reason}`,
    )
    return c.json({ ok: true })
  },
)
