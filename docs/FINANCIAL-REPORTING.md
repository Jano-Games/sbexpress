# Financial reporting and corrections

Current policy: 26 September 2026. Dashboard and Finance use `shared/financialSummary.ts` so that balances, cash flow, booking profitability and payables use the same calculation.

## Invoice and collection states

Shipment pricing starts as an estimate. Sharing a link with Include invoice or recording a cost can create a **draft**, without making it payable. Automatic drafts follow weight/rates/costs; manually agreed drafts are flagged for review when those inputs change.

An administrator reviews the breakdown and issues the invoice explicitly. An issued agreement keeps its published total when shipment inputs change, and receives a Needs review flag. A reasoned revision records the changed agreement and clears that flag. A zero-value invoice needs an explicit free-of-charge decision. Lowering a paid invoice releases excess received money to customer credit rather than losing it.

Only reviewed, issued invoices can receive shipment payments or customer-credit allocations. Supplier-level receipts first settle those invoices, oldest first; any unallocated amount remains customer credit. Draft and review balances are excluded from payable monthly statements and receivables. Invoice/COD/monthly terms do not change when settlement becomes partial or paid.

## Accrued costs and cash

Shipment → Costs → Add cost is the shared workflow for courier, customs, packaging, transport and other shipment costs. A customer-visible cost name appears in the invoice breakdown. Optional categories classify the cost; private legacy expense reasons are not published as invoice lines.

Pay later creates an accrued cost without debiting an account. Paid now creates the cost and its payment in one transaction. Pay on an existing row records a full or partial settlement without adding a second cost or customer charge. Original amount, currency, exchange rate and actual account posting are retained. BDT and CNY are supported; combined reports are in BDT.

Existing geographic cost fields are shown alongside migrated individual costs in one register. Settlement expenses linked to either kind are cash movements, not additional profitability costs. Voiding an unpaid incorrect cost preserves it in history and updates draft pricing or flags an issued invoice for review.

## Booking profitability and periods

This report is explicitly labelled **Booking profitability**. It remains a live operational view rather than a closed-period accounting statement.

- Shipment estimates/issued charges and all matching accrued shipment costs follow the shipment's booking month, including additions entered later. A September payment for an August shipment changes September cash flow, while the cost belongs to the August shipment cohort.
- Ticket agreements and flyer contributions follow the flight date.
- Other business income and standalone business expenses, including salary and rent, follow their transaction dates.
- Cash receipts, expense settlements and refunds follow actual posting dates. Internal transfers move between accounts and do not create profit. Owner capital increases funds but is excluded from profit.

Booking profit = shipment billing + agreed flyer contributions + other business income − full ticket costs − accrued shipment costs − standalone business expenses. Draft pricing makes this provisional. Customer credit refunds reduce cash without subtracting profit again.

Flight profit covers that flight's shipments and ticket. Shipment ticket allocation is an estimate using booked weight and capacity. Unused capacity remains a cost at flight/business level. These scopes intentionally differ.

## Corrections and evidence

Reverse entry requires administrator access and a reason. It retains the original and creates a linked opposite entry, using saved account amounts and rates. Payment reversal reduces its invoice allocation; credit/advance/refund reversal updates the customer liability; expense payment reversal restores the relevant payable; transfer reversal restores both accounts. It never silently deletes the original record or revalues it at today's exchange rate. Repeated requests are deduplicated, and balance failures roll back the whole operation. Incomplete historical account postings must be reconciled first.

Every receipt submission retains its own screenshot association, reference, reviewer, decision and linked payment. Approval/rejection closes its automatic task. Customers can see earlier submissions and rejection explanations. Screenshots remain private; previews are available only to administrators through expiring URLs. New named staff events appear under Settings → Team activity; secrets are redacted.

Public PDF downloads require an issued, reviewed invoice and an unexpired link with invoice access. Admin draft PDFs are clearly marked as not payable. PDF, screen preview and customer breakdown share the same invoice lines and saved currency rate. The backend build includes the licensed Bengali font assets required by PDFKit.

## Verification and migration

145 tests in 11 files, backend/frontend type checks and both production builds passed. Coverage includes period matching, accrual/partial settlement, invoice review, CNY snapshots, receipt retention, reversals, duplicate requests, rollback and customer credit. Main-app page and form checks passed on desktop and mobile. See [the flow fix report](FLOW-FIXES-2026-09-26.md) for evidence and limits.

The two September 26 migrations are additive and deployed to the backed-up local Docker main database. Existing invoices remain issued/manual and existing costs are linked without rebilling. Old overwritten receipt contents and unidentified historical staff actions cannot be recovered merely by migrating the current database.
