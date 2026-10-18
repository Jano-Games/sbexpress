# UI flow and BDT/CNY accounting — 2026-09-10

> Current behavior is described in [Flow audit fixes — 26 September](FLOW-FIXES-2026-09-26.md). The dated sections below record earlier iterations; draft/issued invoices, Pay later costs, receipt history, reversals, staff deactivation and delivery confirmations supersede the earlier immediate-finalization/payment behavior.


## Workspace flow

The desktop module bar organizes dashboard, shipments, flights, suppliers, flyers, finance, payment review, tasks and settings. On mobile, navigation opens in a drawer. Record lists use labeled cards and financial tables scroll within their section.

New shipment uses one sectioned page for supplier/dispatch, cargo, rates and billing review. An inline supplier form preserves the draft and selects the supplier it creates. Saving opens the created shipment. Product photos and packing videos are uploaded through Attachments after creation.

Shipment detail separates shipment information, hub handling, invoice/payments, costs/profit, attachments and history. The next-action panel explains the current step and blocks dispatch without the required flight/flyer, packing and last-mile details. Payments require selecting a receiving account. The implicit one-click Cash settlement was removed.

Flight detail separates route/cargo/flyers from ticket and flyer payments. Recorded ticket cost and ticket payment remain separate: selecting a fund explicitly settles the ticket. Customer credit/refunds and statement links remain under the supplier.

## Currency rules

Only BDT and CNY are supported. Combined reports, invoice liability, customer credit balances and profit calculations use BDT. Account balances remain in each account's native currency.

New monetary entries accept `money: {currency: "BDT" | "CNY", exchangeRate?: number}` alongside their amount fields. The rate means BDT per one source-currency unit. BDT always uses 1. Staff may enter the agreed CNY rate; otherwise the configured Settings rate is used. This is a manually managed rate, not a live FX feed.

Invoices, payments, expenses, receipts, flight costs, credit notes and refunds store original currency, original amount and the posting exchange rate. Entry conversion is rounded to two decimal places; inputs with fractional cents are rejected. Ledger details and shipment billing show original currency alongside BDT. PDF invoices use the invoice's saved denomination and rate. Account transfers retain both account amounts through the existing transfer model.

Shipment per-kg and per-piece pricing already support BDT/CNY; new shipments now also freeze their pricing rates so later reweighing does not use a newly changed global rate. Changing a shipment's descriptive details does not overwrite unchanged cost denomination snapshots. Per-piece defaults in Settings accept BDT or CNY input and are saved as BDT defaults; an individual shipment may override its currency/rate.

Public customers submit in the selected receiving account's currency. Their rate is supplied by the server and cannot be overridden. Approval posts using the receipt's saved rate, even if Settings changed after submission. Pending receipts do not count as verified cash. Payment methods created in Settings now explicitly choose BDT or CNY; changing a linked account's currency is refused.

## Review defects corrected

- Draft shipments with applied credit, receipts or payment history cannot be deleted.
- Flight deletion cannot erase ticket payments or create a fictitious cash refund.
- Password reset or role changes invalidate existing sessions. Older cached sessions without the password version require a fresh login.
- Login limits are scoped per normalized account, and public tracking/download/upload limits per public token, instead of shared global buckets.
- Unmounted/stale data requests cannot overwrite a newly opened screen.
- Shipment save no longer returns to the list after opening the new detail page.

## Database rollout

Apply `20260910000000_multicurrency_snapshots` before starting the new backend against an existing database. It adds snapshot columns and shipment pricing metadata without changing existing BDT ledger totals or native account balances. Existing monetary entries are backfilled as BDT because the previous input contract used BDT. Historical native account posting fields remain intact.

Older shipments have no recoverable agreed-rate snapshot. Their first subsequent pricing calculation uses the then-configured rate and stores it. Review legacy CNY agreements before reweighing; this migration does not invent historical FX rates.

For deployment, take a normal database backup, run `pnpm db:deploy`, generate the Prisma client if needed with `pnpm db:generate`, build, and restart the backend. On 2026-09-16, migration 20260910000000_multicurrency_snapshots was applied to the configured main application database at the user's request. Prisma reports all 21 migrations up to date. Code regression tests used separate local Postgres databases and isolated Redis database numbers.

## Earlier backend/currency validation

- 87 backend tests pass, including 59 dedicated database integration tests and five Redis recovery regression tests.
- TypeScript checks and production frontend/backend builds pass.
- Browser checks: three-step intake, draft back-navigation, saved-detail navigation, CNY invoice, CNY account payment, original/base amounts, desktop layouts and six primary pages at 390 px with no document-width overflow.
- Browser checks also passed for normal sign-in, public CNY payment submission, admin approval, native-currency history, flight contribution conversion and Settings currency selection; no JavaScript errors were observed.
- Additional regression coverage: saved receipt rate on approval, rate changes before reweighing, CNY expense/refund account postings, unsupported currencies, fractional cents, account currency locking, session revocation and protected deletion.

Use the main app at http://localhost:5178, with API port 3002. Separate sample preview services were stopped at the user's request. The configured database is hosted on Railway even though the frontend runs locally. Existing R2 storage, live flight-provider and other external integration configuration is still required for those provider-backed features; this change does not deploy or configure external services.

## Login recovery follow-up — 2026-09-16

A Redis outage could stop reconnection permanently after five attempts. A separate readiness flag could also remain false after a transient command error. The login limiter then returned false for an unavailable service and incorrectly displayed “Too many attempts” even when the account password was correct and its rate-limit bucket was empty.

Redis now keeps retrying with a capped delay, readiness follows the actual client connection state, and unavailable rate-limit storage returns HTTP 503 instead of pretending that an account exceeded its attempt limit. Real rate-limit exhaustion remains blocked. Five focused regression tests cover outage recovery, transient errors, unavailable storage and genuine throttling. The requested administrator login was verified through the main app UI at localhost:5178; both login and dashboard returned HTTP 200 after migration.

## Main application test dataset — 2026-09-16

At the user's request, additive sample records were inserted into the main database in one transaction. Existing business records and application settings were preserved. Names start with `[TEST]`, and shipment, supplier, flight and invoice codes start with `TEST-`. Alphabetic sample codes avoid changing normal shipment numbering.

The dataset contains 3 suppliers, 3 flyers, 3 flights, 9 shipments covering all nine workflow stages, 3 accounts (two BDT, one CNY), 5 invoices, 5 payment entries (three opening-capital entries and two customer payments), 4 expenses, 1 pending receipt, 3 tasks and 2 disabled payment methods. Fictional payment instructions are disabled. Test entries are included in the main reports.

CNY snapshots use the existing configured rate of 19.2 BDT per CNY. Sample account balances were reconciled against their native-currency payment and expense postings before commit. The `testDataset:20260916` setting stores a manifest of inserted record IDs; rerunning the same import returns the existing manifest instead of duplicating records.

A full local database export was blocked by automatic approval review because exporting all business data was outside the authorization for migration and sample records. No full backup was created by this task.

## Complete interface replacement — 2026-09-16

The main application at http://localhost:5178 uses one new design system throughout. The desktop shell has a brand/account header and horizontal module navigation; mobile uses a keyboard-accessible drawer. The stylesheet has been replaced instead of extending the prior theme. Every routed screen, public page and dialog has been reviewed and rebuilt against the same panels, form sections, tables, typography and button hierarchy.

### Screen organization

- Dashboard: active shipments, a work queue, next departure, financial activity and links to shipment stages.
- Shipments: searchable register with stage, supplier and date filters. Booking is one sectioned page for supplier/dispatch, cargo, shipping charges and billing review. Inline supplier creation selects the new supplier and preserves the draft.
- Shipment record: details, handling/delivery, billing, costs, attachments and activity. Payments, credit, cost entry, invoice editing and sharing use focused dialogs.
- Flights: itinerary, cargo manifest, assigned flyers and costs/payments. Flight booking and editing use structured route, capacity, flyer and payment sections.
- Suppliers: profile, shipments, payments/invoices, credit/refunds and statements.
- Flyers: profile, document checklist and flight/settlement history.
- Finance: overview, transaction ledger, accounts, statements and profit/loss. Account forms cover cash, mobile and bank accounts; income, expense and transfer forms have explicit account and currency fields.
- Review: a receipt queue and selected receipt verification details, including source amount, saved rate and BDT amount.
- Tasks: a conventional task list with native labeled checkboxes.
- Settings: general defaults, shipping rates and payment methods. Category and payment-method creation/editing use focused dialogs.
- Hub: a processing register for incoming cargo and outstanding handling tasks.
- Public tracking and statements: clean customer documents with status/details, billing and payment sections. Invoice documents, PDF controls and the generated PDF itself follow the same neutral design. The PDF preserves saved currencies, rates, Unicode text and repeating page headers.

BDT/CNY entry, saved exchange rates, native account balances and BDT reports are preserved. No financial API or database schema was changed for this interface replacement.

### Static UI and accessibility

Removed the animation dependency, old motion primitives, count-up component and easing library. There are no motion imports, transition/animation classes, gradients or shadow effects in the frontend source. Color is limited to the shared palette and meaningful statuses.

Dropdowns close on Tab/focus exit and retain arrow-key selection. Category/flyer suggestions support Enter/Space and keep Escape inside the picker. Dialogs trap focus and announce their live heading. Mobile navigation closes on selection/Escape and releases its focus/scroll lock when resized to desktop. Tables either become labeled record cards or scroll inside their own container.

### Validation for this replacement

- Frontend and backend type checking and production builds pass.
- Main-app sign-in was tested with the existing administrator account.
- The integrated sweep covered 38 main-screen views at 1440 px and 390 px with no document-width overflow or running animations. A separate finance/public run checked all five finance tabs, action dialogs, review, tasks and anonymous customer pages. An unnecessary background lookup of synthetic flight references found during the sweep was fixed and verified separately.
- Keyboard checks cover select exit, suggestion activation, modal Escape/focus return and mobile navigation resizing. Inline supplier selection was checked using a mocked create response and real directory data; no supplier was added by that check.
- An actual temporary CNY booking retained its draft through an inline form, saved the agreed rate and expected BDT total, then was deleted. No payment or credit was posted.
- Finance action dialogs were exercised without posting money. Settings/partner dialogs were exercised without saving account or configuration changes.
- Anonymous customer tracking/statements and invoice PDFs were tested. The real invoice viewer blob has a valid PDF signature; BDT and CNY documents were downloaded, rendered and inspected. A multi-page in-memory fixture also verifies long invoices without database mutations. Generated one-day links used test records with no pre-existing active links; the generated links were revoked afterward.
- Browser checks did not exercise live flight-provider lookup, external attachment storage or a separate hub-user login. Their existing API/permission contracts remain intact.

Validation scripts and screenshots are under N:\\Codex\\review-mamun-20260910. Earlier backend/currency regression results below the currency documentation belong to the prior implementation pass; this design pass did not rerun database integration tests against the main database.

## Loading and shipment status follow-up — 2026-09-20

The loading improvements share concurrent GETs, retain a recent in-memory page snapshot while revalidating, and invalidate reads after writes and session changes. Navigation keeps the application shell mounted. Menu badges use role-scoped counts, dashboard queries reuse one response snapshot, and flight lists select only the relations needed for their summaries. Financial totals continue to be read fresh from the server. Closed money-entry dialogs avoid unnecessary exchange-rate requests; edit forms preserve drafts across background refreshes.

The shipment detail status panel now shows its exact operational status and next checkpoint above a connected five-milestone journey. Completed milestones use checkmarks, the current milestone uses a blue icon, and upcoming milestones remain neutral. Delivered shipments show all five milestones as completed. Flight, carrying flyer and weight sit in a separate metadata footer. The journey is horizontal on larger screens and vertical on mobile, with no motion or decorative effects. This is a display change; the nine status transitions and permission rules are unchanged.

Validation: frontend typecheck and production build passed; backend typecheck and 27 pure regression tests passed without database integration tests. Main-app browser checks covered Pending, Ready for Shipment, Customs Cleared, Out for Delivery and Delivered at 1440, 768 and 390 pixels (15 views), with the expected current/completed states, no horizontal overflow, no running animations and no JavaScript errors. Screenshots and the read-only browser script are in N:\Codex\review-mamun-20260910.

## Shipment billing workspace — 2026-09-20

The shipment Billing tab now uses a three-column balance summary followed by an invoice register and payment history table. The invoice register displays the saved number, issue date, payment status, original currency/rate and BDT total. Invoice numbers and Preview buttons open a dedicated read-only document; editing remains a separate action. The preview uses the invoice's saved issue date, line items, discount, notes and currency snapshot, with a PDF download action. BDT totals remain visible for CNY documents, including a compact dual-currency amount layout on mobile. Empty invoice/payment states and customer receipt review links are preserved. Preview data loads only when opened.

Validation: frontend typecheck and production build passed. Eight main-app views covered desktop/mobile BDT and CNY invoices, a shipment without an invoice, and a shipment with a recorded payment. Invoice number keyboard activation, explicit Preview, separate Edit/Create, existing payment/credit dialogs, Escape/focus return and a real PDF download were checked. A simulated failed preview recovered through Try again. No horizontal page/modal overflow or JavaScript errors were found; the mobile CNY preview fits both currencies without table scrolling. All browser checks avoided business-data writes. Reports and screenshots are in N:\Codex\review-mamun-20260910 (billing-review.json and billing-final-check.json).


## Receipt evidence and review — 2026-09-20

Payment review now presents the customer screenshot beside a structured payment summary: original amount, BDT credit amount, saved CNY rate, receiving account, copyable transaction reference and submission date. The receipt queue marks which submissions have images. Click the thumbnail to open a focus-trapped image dialog with fit/actual-size controls; opening and closing it does not refetch an already loaded preview. The layout stacks on mobile and supports image-load retry and receipts without screenshots.

Both public shipment and monthly statement payment forms accept optional JPG/PNG/WebP screenshots up to 5 MB. Customers can see, replace or remove their selection. Failed uploads/submissions keep the selected file for retry; already uploaded content is reused while its reservation remains valid. Invoice currencies, saved rates and financial approval rules are unchanged. Billing links target the selected receipt directly, and screenshots remain available from shipment billing and statement receipt history after review.

Storage metadata is added by migration `20260920120000_receipt_screenshots`, applied to the main database and isolated audit database. Uploads are scoped to a live customer link, validated and copied into private immutable storage before acceptance. Admin-only preview URLs expire after two minutes. No receipt is approved merely because an image was attached.

Validation: frontend/backend types and frontend production build passed. The isolated local audit suite passed 111 tests, covering scope/role restrictions, reservation limits, invalid image metadata, storage verification failures, transactional rollback, receipt approvals and existing currency/financial behavior. Actual browser uploads to R2 and admin previews passed on the main app for both shipment and statement receipts. Temporary records/images were removed and no main-app payment was approved. Separate mocked-response browser checks cover CNY form metadata, upload/submission retry, oversized selection, preview recovery, mobile zoom and keyboard focus return. Screenshots and reports are in `N:\Codex\review-mamun-20260910`.


## Saved invoice links and automatic payment balance — 2026-09-20

The **Share link** dialog includes an **Include invoice** checkbox. The shipment action starts unchecked; sharing from the invoice editor starts checked. Unchecked links show shipment tracking without invoice or payment access. Checked links show the invoice total, paid amount, amount due and itemized breakdown, and save a missing invoice from the already entered shipment charges. A saved invoice's custom lines and discount remain unchanged. Included invoices use the full remaining balance, which updates after payments or invoice changes; there is no separate requested-payment/currency entry.

Generated links are listed with creation date, expiry, status, Copy and Open actions. They remain available after closing the dialog, navigation, reload and subsequent sessions. Expired and revoked links remain in history; revocation still blocks customer access. The same persistence and invoice-derived balance replace manual requested amounts on monthly statement sharing. Older digest-only links cannot be reconstructed; the history explains that a new saved link is needed to copy it again.

Migration `20260920140000_saved_customer_links` adds nullable encrypted token fields to shipment and statement links. Existing token digests and authorization remain in place. The main backend's gitignored `.env` now contains a generated server-only `LINK_ENCRYPTION_KEY`; preserve this key across deployment/restarts. It is not exposed to customers, browser bundles or logs. Admin-only list endpoints return share URLs and status metadata, not ciphertext or digests.

Invoice breakdowns now show stored weight × rate and per-piece charges when they reconcile with the original amount, along with billed additions, customs, credits and discounts. Preview, public page and PDF share the same calculation. CNY customer invoices display the saved denomination/rate plus BDT equivalents. Admin invoice preview now includes verified payments and remaining due.

Validation: 122 tests passed against the isolated local audit database, including encrypted token recovery/tamper checks, repeat link retrieval, role restrictions, automatic invoice creation, transaction rollback, itemized totals, updates after payment and revocation. Main-app browser checks cover generation, close/reopen, reload persistence, CNY breakdown, PDF download, statement link persistence and desktop/mobile layouts. Tests create only labeled temporary records and remove their links, invoices, revisions and shipments afterward; no real payment is posted. Reports and screenshots are in `N:\Codex\review-mamun-20260910` (`saved-links-check.json`).


Optional invoice validation: 123 tests pass, including omitted financial fields, blocked PDF/receipt/screenshot endpoints, no invoice creation for tracking-only links, independent scope per saved link and compatibility with earlier links. Type checks and production build passed. Main-app browser checks at localhost:5178 confirmed both checkbox modes, saved history after reload, PDF access only when included and desktop/mobile layouts. Temporary records were removed and no payment was posted. Evidence: `N:\Codex\review-mamun-20260910\include-invoice-check.json`.


## Shipment cost flow simplification — 2026-09-24

- **Costs → Add cost** is the single place for any shipment expense. Removed fixed China/customs inputs from Edit shipment and the Dhaka transport input from Handling. New entries have a customer-visible cost name, BDT/CNY amount and paying account; optional categories stay collapsed.
- One register shows amounts, payments and remaining balances, with Details and row-level Pay for earlier outstanding costs. Existing records stay intact; settlements do not duplicate costs or customer charges. Finance and flight reports use consistent shipment-cost totals instead of geographic fixed rows. Finance's general expense form points to this shipment flow and flight ticket payments.
- Newly created invoices from cost entry retain the shipment's CNY denomination/rate. Explicit cost names appear in invoice breakdowns, while earlier private expense notes stay private. Paid shipment edits no longer present editable payment statuses, and unchanged edits omit payment status and legacy costs from the request.
- Account/currency lookups are deferred until a payment/cost dialog opens; a small admin accounts endpoint replaces loading all Finance data. Mobile tables stay within their scroll container and form controls have explicit accessible labels.

Validation: 125 tests pass against the isolated `mamun_audit_20260905` database, including mixed historical/new costs, partial settlements, idempotency, invoice naming/privacy, currency/account snapshots, grouped reports and account permissions. Type checking and production builds pass. Main-app screens were checked read-only; browser form submissions used intercepted in-memory fixtures with all other non-login writes blocked. Desktop/mobile forms, cost details, invoice preview and Finance navigation passed with no JavaScript errors or document overflow. Automatic approval review rejected a proposed main-database financial fixture test; no such fixture or financial write was executed. Evidence: `N:\Codex\review-mamun-20260910\shipment-cost-flow-check.json`.
