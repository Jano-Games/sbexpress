# Flow audit fixes — 26 September 2026

All 17 actionable findings from the product-flow audit have been addressed in the main application at **http://localhost:5178**. The changes cover business rules, the screens that expose them, and regression tests. No additional preview app was created.

## What changed

| Finding | Implemented behavior | Verification |
|---|---|---|
| F01 · Invoice lifecycle | Sharing or adding a cost prepares a draft. Automatic drafts follow shipment pricing; manual agreements require review. Issued totals stay fixed until an explicit revision. Unissued/review invoices cannot receive allocations, appear as settled, or enter payable statements. Zero-value issuance requires confirmation. | Draft/repricing/manual-agreement/free-charge tests; real invoice preview and revision form. |
| F02 · Receipt retention | Each submitted transfer gets its own receipt, screenshot association and linked ledger payment. Earlier partial-payment submissions remain visible. | Two successive receipts, retained proof metadata, review decisions and payment reversal tested. |
| F03 · Flyer history | Archive/restore replaces deleting used profiles. Deletion checks financial and assignment history. Existing settlements keep their named owner. | Ticket-only paid settlement survives archive; unsafe deletion rejected. |
| F04 · Report periods | Booking profitability assigns shipment charges and their accrued costs to the same shipment booking month. Actual cash movements follow payment dates. | August booking / September cost payment regression; dashboard and Finance agreement. |
| F05 · Unpaid costs | Add cost defaults to Pay later. Paid now requires an account. Later full or partial settlement does not create another cost or customer charge. Incorrect costs can be cancelled after reversing their payments. | BDT/CNY accrual, partial settlement, overpayment protection, reversal and cancellation; real mobile form. |
| F06 · Payment terms | Invoice/COD/monthly terms are independent of unpaid/partial/paid progress. New shipments inherit the selected account's usual terms, with an explicit override. | Terms survive payment and can be changed without rewriting settlement status. |
| F07 · Last-mile handling | Booking, dispatch and handover are separate confirmations. Pickup stays ready for collection. Custom couriers and logged reference corrections are supported. | Booking/correction/dispatch/handover and pickup guards tested. |
| F08 · Flight assignment | Clear/reassign is available before dispatch. Later journey corrections need the dedicated action and a reason. Unchanged archived historical assignments remain editable. | Pre-dispatch unassign and protected historical assignment regression. |
| F09 · Flight status | Reads never complete a flight. A passed departure date displays a confirmation notice until status is explicitly updated. | Repeated detail/directory/dashboard reads leave the stored status unchanged. |
| F10 · Review tasks | Automatic tasks link to receipts and close on approval/rejection. They take staff to Payment review and cannot be independently checked off. | Task creation and automatic completion tested; main Tasks screen checked. |
| F11 · Rejection feedback | A reason is mandatory. Public shipment/statement pages retain the submission and explain the decision, including that rejection does not itself mean sending more money. | Required reason and public history tested; real review form checked. |
| F12 · Account history | Supplier Account activity combines payments, advances, applied credit and refunds. BDT/CNY source amounts, stored rates and BDT equivalents stay visible. Credit history also retains native currency. | Native CNY advance/refund and allocation tests; supplier views checked. |
| F13 · Money corrections | Authorized Reverse entry appends a linked offset with a reason. Original account amounts/rates are used; cash, allocation, customer credit and payables update atomically. Available in Finance, shipment payments/cost details and supplier activity. | Replay/double-reversal protection, insufficient-funds rollback, payments, costs, ticket refunds, customer refunds, transfers and credit allocation tested. |
| F14 · Staff access | Settings → Users offers Deactivate/Reactivate. Old sessions remain invalid after reactivation. Self-deactivation/last-admin protections and historical records remain. | Authentication/session tests; real deactivation confirmation checked. |
| F15 · Named activity | Shipment logs record the authenticated person. Settings → Team activity records staff ID/name, action, submitted values and relevant previous values; secrets are redacted. | Named events and password redaction tested; activity page checked. |
| F16 · Exceptions | Manage shipment supports hold, failed delivery, cancellation, return, loss, resume and earlier-checkpoint correction with reasons. Financial records remain separate and preserved. | Role restrictions, blocked progression on hold, resume and checkpoint correction tested; real action dialog checked. |
| F17 · Manual flight entry | Lookup is optional. Manually entered airport, date and time segments keep their provenance label. Replacing an existing itinerary remains an explicit choice. | Stored provenance/status tests and browser simulation of an empty lookup result. |

Mobile Finance transactions now keep the amount, currency, account and date visible together. Shipment costs are consistently admin-only. The existing Supplier terminology and capacity warnings remain; these were policy questions in the audit, not confirmed duplicate records or automatic hard limits.

## Current workflow

Shipment intake → flight/cargo assignment → transport checkpoints → Dhaka weighing and packing → review charges and issue invoice → book courier or collection → confirm actual dispatch/handover. Exceptions preserve the journey and allow a documented correction.

Cost recognition and cash settlement are separate. Customer advances stay available as credit until a reviewed invoice can receive an allocation. Issued invoice changes, credits, payment proofs and reversals retain history. Reports use BDT; native transactions support BDT and CNY only.

## Migration and preservation

The main database is the local Docker PostgreSQL database `mamun_local` at localhost:5435. Additive migrations `20260926110000_complete_business_flows` and `20260926120000_manual_flight_source` were tested on the isolated local test database, then deployed to the main database. Existing invoices remain issued/manual; existing expense payments are linked to backfilled accrued costs without rebilling them. Existing saved customer links keep their scope and tokens.

Before changes, a PostgreSQL dump and source snapshot were saved under `.local-backups/flow-fixes-20260926-1790419200339/`. The main database was not reset or reseeded. Financial regression mutations ran in `mamun_audit_20260905` with isolated Redis database 15. Main-app browser verification did not post payments or alter shipment records.

## Verification

- 145 tests passed across 11 files, including the added flow and money regressions.
- Backend/frontend TypeScript checks passed. Both production builds passed.
- 34 main-app desktop/mobile views: no JavaScript errors, failed HTTP responses or document-level horizontal overflow.
- Eight additional main-app form/layout checks: invoice revision, cost payment timing, shipment exception, rejection feedback, staff access, manual itinerary, financial reversal and mobile ledger.
- Evidence is retained under `N:/Codex/review-mamun-20260910/`: `flow-suite-final.log`, `flow-typecheck-final.log`, `flow-build-final.log`, `flow-ui-fixed-20260926.json`, `flow-ui-forms-fixed.json` and the `fixed-*.png` screenshots.

## Limits of the result

Receipt records overwritten before this fix cannot be reconstructed from the current database alone. Surviving records and screenshots are preserved, and all new submissions remain separate. Historical staff logs without a stored person ID cannot be attributed retroactively; named recording applies to new actions.

Booking profitability is a live operational estimate, not a closed-month accounting ledger: later pricing revisions can change the original booking cohort. Historical postings without a complete account association require reconciliation before reversal. Tests cover controlled screenshot storage and metadata; this pass did not transfer real money, call couriers or upload new customer images to external storage.
