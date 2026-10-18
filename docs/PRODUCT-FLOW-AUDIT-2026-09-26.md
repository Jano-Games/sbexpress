# Product and flow audit — 26 September 2026

**Resolution update:** F01–F17 were implemented after this audit. See [the fix report](FLOW-FIXES-2026-09-26.md) for current behavior, migrations and validation. The findings below preserve the original pre-fix evidence.

The main issues are in business state and record handling, not decorative styling. The current screens generally load and fit a phone, but several normal actions produce inconsistent billing, misleading statuses, or incomplete history.

This audit found **17 actionable issues: 4 high-priority record/accounting defects and 13 workflow or control gaps**. Priorities below are recommendations; evidence distinguishes reproduced behavior from source-verified missing flows. Application code was not changed during this audit.

## Coverage and evidence

- Main application: `http://localhost:5178`, desktop 1440×1000 and mobile 390×844. **39 page/tab visits and 10 entry forms** covering dashboard, shipments and all detail tabs, flights, flyers, suppliers, billing, credit/refunds, statements, finance, payment review, tasks, settings/users, and the supplied public tracking link.
- No uncaught browser errors, HTTP errors, or document-level horizontal overflow in those visits. Tables and tab bars do scroll inside their containers; this is not a complete accessibility audit.
- **130 existing tests passed in 11 files**, including 71 integration tests, rerun for this audit. Passing tests do not cover all of the workflow problems below.
- Reproductions used a separate local Docker database, `mamun_flow_audit_20260926`, and Redis database 14. Existing suite used its own `mamun_audit_20260905` database and Redis database 15. No extra application server or preview port was started.
- Main-app browser scripts blocked non-authentication write requests. Note F09: the application's flight GET route itself performs a status update, so reading flights is not actually side-effect-free.
- Evidence files: [page checks](N:/Codex/review-mamun-20260910/flow-ui-audit-20260926.json), [remaining tabs and forms](N:/Codex/review-mamun-20260910/flow-ui-extra-20260926.json), [core reproductions](N:/Codex/review-mamun-20260910/flow-reproductions-20260926.json), [terms/history reproductions](N:/Codex/review-mamun-20260910/flow-extra-20260926.json), [unpriced invoice/pickup/currency checks](N:/Codex/review-mamun-20260910/flow-final-20260926.json).

## Findings

### F01 · P1 · Ordinary cost entry freezes the invoice before final weight is known

**Reproduced.** Create a 2 kg shipment at BDT 1,000/kg. Add a BDT 100 courier cost. This silently creates a finalized BDT 2,100 invoice. At the Bangladesh hub, weigh the cargo at 3 kg: the shipment's shipping charge becomes BDT 3,000, but the invoice still contains “2 kg × BDT 1,000” and the customer still owes BDT 2,100. There is no warning that the invoice now differs from the agreed per-kg calculation.

An existing manually agreed invoice may legitimately stay fixed. The defect is that **Add cost and Share link with invoice automatically finalize it**, without a clear pricing/finalization step or a later revision prompt. Another reproduced case: an intake with no weight or rate can publish a zero-value invoice and the public page says **Settled**, although no explicit free-of-charge decision was made.

**Change:** separate draft pricing, issued invoice, and paid state. Keep draft charges in sync; after issue, show an explicit revision decision when measured weight or rates change. Distinguish “price pending” from an intentionally zero-charge shipment.

Evidence: [automatic invoice creation](N:/CCD/Mamun/apps/backend/src/shared/shipmentBilling.ts:12), [sharing publishes invoice](N:/CCD/Mamun/apps/backend/src/shared/shipmentBilling.ts:30), [reweigh](N:/CCD/Mamun/apps/backend/src/modules/shipments.ts:341), [zero balance marked paid](N:/CCD/Mamun/apps/backend/src/modules/track.ts:117).

### F02 · P1 · A second payment overwrites the first receipt and disconnects its screenshot

**Reproduced.** Submit BDT 300 and approve it. Submit another BDT 400 against the same shipment. There is still only one receipt row: the original approved receipt now contains the new amount, reference, date, and pending status. The BDT 300 ledger payment survives, but its receipt record does not. A metadata-only screenshot fixture also confirmed that the previous image loses its receipt association when the next receipt is submitted without an image.

This does **not** prove the underlying image file is deleted. It proves that the normal receipt history can no longer retrieve that proof through its original association.

**Change:** keep one immutable receipt submission per transfer, with its own screenshot, status, reviewer, and linked ledger payment. Allow multiple submissions per shipment; restrict only simultaneous pending submissions where needed.

Evidence: [receipt upsert](N:/CCD/Mamun/apps/backend/src/modules/shipments.ts:635), [one receipt per shipment](N:/CCD/Mamun/apps/backend/prisma/schema.prisma:338).

### F03 · P1 · Deleting a flyer bypasses the protection on paid settlements

**Reproduced with a flyer that has no assigned shipments.** A flyer owes BDT 1,000 and has paid BDT 300. Removing them from the flight correctly fails because settlement history exists. Deleting their profile succeeds and cascades away the flight/flyer relation. The flight still has BDT 300 received, but its settlements list is empty and the amount becomes “unallocated”; the BDT 700 balance loses its named owner.

Shipment foreign keys do protect flyers who still have assigned shipments. They do not protect this ticket-only settlement case.

**Change:** archive used flyers. Apply the same financial/history checks to profile deletion as flight removal; preserve named settlement ownership.

Evidence: [profile deletion](N:/CCD/Mamun/apps/backend/src/modules/flyers.ts:152), [guarded flight removal](N:/CCD/Mamun/apps/backend/src/modules/flights.ts:394), [cascading relation](N:/CCD/Mamun/apps/backend/prisma/schema.prisma:245).

### F04 · P1 · Monthly profit puts a charge and its matching cost in different months

**Reproduced.** An August shipment bills BDT 2,000. Adding a BDT 100 billable cost in September changes August billing/profit to BDT 2,100, while September shows BDT 100 expense and zero matching billing, producing BDT -100 profit. All-time profit remains BDT 2,000, but the monthly picture changes inconsistently.

The report uses shipment creation dates for the current invoice total and expense dates for new costs. Reopening an earlier month therefore rewrites its income without matching the associated new cost.

**Change:** choose and document one revenue/cost recognition policy. Store dated charge/revision events and matching costs, or use an explicitly defined shipment-cohort report. Keep cash-flow reporting separate.

Evidence: [period selection and billing](N:/CCD/Mamun/apps/backend/src/shared/financialSummary.ts:72), [cost period](N:/CCD/Mamun/apps/backend/src/shared/financialSummary.ts:85).

### F05 · P2 · Add cost cannot record an unpaid bill

**Reproduced; missing workflow.** Adding BDT 100 immediately decreases Cash from BDT 10,000 to BDT 9,900 and records paid BDT 100 / remaining BDT 0. An account is mandatory. New courier, packaging, or customs bills cannot be recorded now and settled later. Partial cost payment exists only for older fixed cost fields.

The cost dialog does explain that saving pays the cost; the gap is that there is no alternative for a real unpaid expense. Consolidating China/Dhaka courier costs into one list was correct and should remain.

**Change:** one Add cost flow with “Paid now” or “Pay later”; show payable amount and accept later partial settlements. Preserve the requested invoice breakdown without making cost recognition and payment the same action.

Evidence: [unconditional account debit](N:/CCD/Mamun/apps/backend/src/modules/shipments.ts:453), [cost form](N:/CCD/Mamun/apps/frontend/src/components/ShipmentCosts.tsx:390).

### F06 · P2 · Payment terms and payment progress overwrite each other

**Reproduced.** A COD shipment becomes `unpaid` after adding a cost. Selecting “Monthly billing” on a new shipment for an instant-billing supplier saves `unpaid`, although that option is available in the form. `cod`, `monthly`, `partial`, and `paid` share the same field, so collecting money or changing a bill can erase how the customer was meant to pay.

**Change:** store payment terms independently from settlement status. Either permit a visible per-shipment override or lock the field to supplier terms with an explanation; never silently ignore the selection.

Evidence: [creation ignores selected monthly term](N:/CCD/Mamun/apps/backend/src/modules/shipments.ts:176), [cost recomputes status](N:/CCD/Mamun/apps/backend/src/shared/shipmentBilling.ts:26), [form choices](N:/CCD/Mamun/apps/frontend/src/modals/NewShipmentModal.tsx:27).

### F07 · P2 · Delivery booking is hard to correct and misrepresents pickup

**Reproduced.** Save a courier reference, then correct a typo: the second request fails with “Confirm packing before booking the courier” because the first save already moved the shipment to Out for Delivery. Scheduling **Hub pickup** also changes status to Out for Delivery before anyone collects it. The UI only offers Pathao, Steadfast, and Hub pickup.

**Change:** separate booking, dispatch, and handover. Allow a logged reference correction/rebooking; offer configurable courier services. Pickup should be “Ready for collection” followed by confirmed handover, with the actual collection record.

Evidence: [booking/status gate](N:/CCD/Mamun/apps/backend/src/modules/shipments.ts:380), [fixed choices and disabled correction](N:/CCD/Mamun/apps/frontend/src/screens/ShipmentDetail.tsx:476).

### F08 · P2 · Flight assignment has no normal unassign action, but permits historical reassignment

**Reproduced at API level and verified in the form.** Once assigned, the optional flight picker has no clear/unassign action. Omitting the flight in PATCH leaves the old assignment; `null` is rejected. At the same time, a delivered shipment can be reassigned to a different completed flight through the ordinary edit endpoint.

The delivered-state reproduction used a prepared isolated fixture to exercise the edit rule; it was not a complete physical delivery simulation.

**Change:** allow explicit unassign/reassign before dispatch. Later corrections need a distinct action, reason, and history that preserves the original journey.

Evidence: [assignment schema](N:/CCD/Mamun/apps/backend/src/modules/shipments.ts:198), [ungated reassignment](N:/CCD/Mamun/apps/backend/src/modules/shipments.ts:225), [optional value omitted on submit](N:/CCD/Mamun/apps/frontend/src/modals/NewShipmentModal.tsx:366).

### F09 · P2 · Viewing a past flight marks it Completed without operational confirmation

**Reproduced.** Create an Upcoming flight dated yesterday, then GET its details. The stored state changes to Completed. A delayed, cancelled, or unconfirmed flight is treated as having flown simply because the calendar advanced. This can also remove it from upcoming-flight selectors.

**Change:** scheduled date and actual status must be separate. Show “Schedule passed—confirmation needed” until a person or trusted flight update confirms departure/arrival. Reads should not infer completion.

Evidence: [automatic completion](N:/CCD/Mamun/apps/backend/src/modules/flights.ts:92), [GET invokes it](N:/CCD/Mamun/apps/backend/src/modules/flights.ts:158).

### F10 · P2 · Payment review and automatic tasks disagree

**Reproduced.** Approve a receipt: it leaves Payment review, but its automatic “Review ... receipt” task stays open. Submitting and rejecting another receipt leaves a second open task. Staff must separately clear tasks for work already completed, and the task count overstates the pending workload.

**Change:** derive review tasks from pending receipts, or link each task to its receipt and close it automatically on approval/rejection. Avoid independent copies of the same work item.

Evidence: [task creation](N:/CCD/Mamun/apps/backend/src/modules/shipments.ts:641), [approval/rejection](N:/CCD/Mamun/apps/backend/src/modules/shipments.ts:598), [independent task toggles](N:/CCD/Mamun/apps/backend/src/modules/todos.ts:31).

### F11 · P2 · A rejected customer payment gets no useful explanation

**Reproduced.** After rejection, the database says `rejected`, but the customer response only returns `showPay:true` and `showPending:false`. There is no submitted reference, rejected status, or reason in the public response. The payment form reappears, which can look as though the submission disappeared.

**Change:** require an appropriate rejection reason and show the submitted transfer, decision, and next action. Make clear whether to correct proof or contact support; do not imply the customer must send money again.

Evidence: [generic rejection](N:/CCD/Mamun/apps/backend/src/modules/shipments.ts:609), [public status flags](N:/CCD/Mamun/apps/backend/src/modules/track.ts:117).

### F12 · P2 · Original currency disappears from supplier-level history

**Reproduced.** A CNY 10 payment at rate 20 is stored correctly as CNY 10 / BDT 200, but Supplier → Payments exposes only BDT 200. A CNY 5 refund is stored with its original currency and rate, but the supplier credit/refund response omits those fields, and the credit UI does not render the separate refund records. A customer advance is also absent from the supplier's payment list because that list only includes payments linked to shipments; the advance appears in Credit history instead.

BDT reporting is correct. Losing the original amount from transaction detail is the inconsistency; the main finance ledger does retain currency detail.

**Change:** one supplier account activity view including payments, advances, applied credit, and refunds. Show original BDT/CNY amount plus its saved BDT equivalent and exchange rate, with links to shipment allocations.

Evidence: [supplier payment serializer](N:/CCD/Mamun/apps/backend/src/modules/suppliers.ts:165), [credit/refund serializer](N:/CCD/Mamun/apps/backend/src/modules/customerAccounts.ts:16), [credit-only table](N:/CCD/Mamun/apps/frontend/src/components/CustomerCredit.tsx:227).

### F13 · P2 · Posted money has no supported mistake-correction flow

**Source/UI verified gap.** Finance offers new receipts, expenses, transfers and customer-credit refunds, but no linked reversal for a wrongly entered payment, paying account, or expense. Shipment cost details offer inspection and remaining payment, not correction. Positive-only amount validation prevents a simple negative compensating entry. A credit note changes the customer's bill; it is not a reversal of an incorrect expense or receipt.

**Change:** add authorized “Reverse entry” with a reason and a linked offset, then optionally re-enter correctly. Update cash, invoice allocation, payable, and reports together; preserve the original entry rather than deleting it.

Evidence: [finance mutations](N:/CCD/Mamun/apps/backend/src/modules/finance.ts:133), [read-only ledger API](N:/CCD/Mamun/apps/backend/src/modules/financeLedger.ts:9), [shipment financial mutations](N:/CCD/Mamun/apps/backend/src/modules/shipments.ts:407).

### F14 · P2 · Users can be added but cannot be deactivated

**Source/UI verified gap.** Settings → Users provides Add, Edit, and Password actions. There is no active/inactive field or disable action for a departing employee. Resetting the password does invalidate existing sessions, so there is a workaround; it is not a clear access-lifecycle control.

**Change:** add Deactivate/Reactivate, revoke sessions on deactivation, and preserve the existing last-admin protection. Retain historical user references instead of deleting staff records.

Evidence: [user model](N:/CCD/Mamun/apps/backend/prisma/schema.prisma:103), [available user operations](N:/CCD/Mamun/apps/backend/src/modules/userSettings.ts:33).

### F15 · P2 · Activity records show a role instead of the person

**Source verified and visible in reproduced logs.** Shipment activity records “Admin” or “Hub” for changes, and several payment/review actions hard-code “Admin”. After adding multiple staff accounts, the activity screen cannot identify which person changed a price, shipment, or receipt. Financial request deduplication has an actor ID in some cases, but that is not a complete, user-visible audit trail.

**Change:** record stable user ID and a name snapshot for operational and financial events; record before/after values and correction reasons where relevant.

Evidence: [actor reduced to role](N:/CCD/Mamun/apps/backend/src/modules/shipments.ts:33), [shipment log model](N:/CCD/Mamun/apps/backend/prisma/schema.prisma:325).

### F16 · P2 · The shipment flow only supports successful forward progress

**Source/UI verified operational gap.** The status model has nine forward stages. There is no normal on-hold, cancelled, failed-delivery, returned, or lost state, nor a supported correction of an accidentally confirmed checkpoint. Delete is correctly restricted once financial activity exists, so it cannot stand in for cancellation.

**Change:** keep the simple normal journey, and add an explicit Exceptions action with reason, responsible person, and recovery/return steps. Define separately what happens to charges and refunds; cancellation must preserve the shipment's records.

Evidence: [status model](N:/CCD/Mamun/apps/backend/prisma/schema.prisma:37), [advance-only route](N:/CCD/Mamun/apps/backend/src/modules/shipments.ts:325), [main journey](N:/CCD/Mamun/apps/backend/src/shared/status.ts:4).

### F17 · P2 · Add flight stops when schedule lookup has no result

**Verified with a browser simulation of `found:false`; no external service outage was claimed.** The form shows “No flight found for that number on that date,” but offers no manual segment entry. Creating a new flight requires at least one segment. A real ticket unavailable in the lookup service therefore cannot be entered through the normal UI.

**Change:** keep lookup as a convenience and provide manual flight number, date, origin/destination, and times, with a “manually entered” label. Later lookup must not silently overwrite confirmed ticket details.

Evidence: [mandatory segments](N:/CCD/Mamun/apps/frontend/src/modals/AddFlightModal.tsx:299), [lookup-only itinerary UI](N:/CCD/Mamun/apps/frontend/src/modals/AddFlightModal.tsx:379), [browser evidence](N:/Codex/review-mamun-20260910/flight-lookup-no-result.json).

## Decisions to make explicit, rather than treating them as confirmed bugs

1. **Capacity policy:** the form already warns about excess weight, but the API accepted a 50 kg shipment on a 5 kg flight, returning -45 kg remaining. If excess baggage is permitted, require a recorded override and related cost. Otherwise block it. Do not remove an intentional operational exception without deciding the policy.
2. **Who records hub costs:** new Costs UI is admin-only, while the expense endpoint still permits Hub. The hub response hides costs and its account directory is forbidden. If hub staff must record courier/packaging bills, give them a limited cost-entry flow without exposing profit or whole-company accounts. If admin-only is intended, align the API and help text.
3. **Supplier versus customer:** the same account is called Supplier in navigation and Customer in billing/receipts. Choose terminology that matches the business relationship, or label the role explicitly; avoid renaming a real supplier relationship blindly.
4. **Mobile financial tables:** the page fits the viewport, but amount/account columns require horizontal scrolling. Prioritize amount, currency, and reference in mobile rows, with secondary details expandable. [Observed mobile ledger](N:/Codex/review-mamun-20260910/audit-flow-mobile-18.png).
5. **Duplicate access points are not automatically duplicate data:** Finance account creation and Settings payment-method setup share linked accounts; shipment billing and supplier billing serve different scopes. Keep both where useful, with one underlying ledger and clear labels. The actual duplicate work is F10's independent task copy.

## Recommended flow and repair order

**Shipment:** intake → cargo/flight assignment → dispatch → hub weight and packing → reviewed charges → issued invoice → delivery booking → dispatch or collection → completed. Exceptions branch from the appropriate checkpoint rather than forcing a false forward stage.

**Money:** record a cost or customer charge → record/allocate money separately → retain each proof submission → review once → update ledger, invoice balance, and related tasks together. BDT is the report currency; each transaction retains its original BDT/CNY amount and saved rate.

1. Address F01–F04 first: invoice integrity, proof retention, settlement deletion, and report periods.
2. Then fix F05–F13: payment terms, payable/correction flows, dispatch edits, assignment rules, review feedback, and complete account history.
3. Finish F14–F17 and the explicit policy decisions: staff lifecycle, identifiable activity, exception paths, and manual flight entry.

## Verification limits

This was a functional/product-flow audit of the current local app and source, not a penetration test or a load test. The small local dataset loaded in roughly a second per checked route including the browser's idle wait; that does not establish performance at production volume. Real payment transfers, actual courier delivery, live flight-provider outages, and new external image uploads were not performed. Existing screenshot tests use controlled storage behavior; the overwritten-image finding was verified using database metadata. No claim is made that every business edge case has been exhausted.

Reproduction scripts are retained in `N:/Codex/review-mamun-20260910/`: `flow-audit-runner.mjs`, `flow-reproduce.mts`, `flow-extra.mts`, `flow-final.mts`, `flow-ui-audit.cjs`, `flow-ui-extra.cjs`, and `flight-no-result.cjs`. The runner validates its isolated database target. Run the base reproduction before the extra scripts, which depend on its fixtures.
