# Website UI/UX audit — 5 September 2026

## Scope and changes

Reviewed all 17 screen templates, shared navigation, creation forms, and key interactions. Changes are implemented in the frontend.

| Page | Layout and usability improvements |
| --- | --- |
| Login | Responsive brand/sign-in layout, semantic heading, required fields, accessible error message |
| Business overview | Consistent page header, shipment shortcut, meaningful empty states, keyboard-accessible record links |
| Hub overview | Clear processing context and headings, responsive queue, keyboard-accessible shipment links |
| Shipments | Summary, status/supplier/date filters, search, pagination, desktop table and compact cards; financial columns shown only to admins |
| Shipment detail | Identity and pipeline first; separate Overview & processing, Photos & videos, Invoice history sections; responsive columns |
| Flights | Searchable booking list, capacity and flyer-balance columns, summary, compact cards and pagination |
| Flight detail | Responsive itinerary/manifest/settlement columns, semantic heading, accessible shipment links |
| Flyers | Registry summary, contact/document search, readable compact cards and pagination |
| Flyer detail | Responsive profile and travel history, clear heading, accessible flight links and empty state |
| Suppliers | Account summary, terms/outstanding balance, search and pagination, mobile cards |
| Supplier detail | Persistent account identity; Overview & payments, Credit & refunds, Statements & links; direct statement-section URLs |
| Finance | Retained the preceding summary/ledger/accounts/reconciliation/statements redesign; checked responsive layouts and updated shared dialog behavior |
| Payment review | Separate queue counts, readable payment references, clear verification instruction, disabled duplicate actions while processing |
| Tasks | Open/completed/all filters, summary, prominent new-task form, accessible completion controls and pending feedback |
| Settings | General, Shipping rates, Payment methods sections; explicit saves for operating values and rates; labeled controls and responsive forms |
| Public tracking/invoice | Responsive branding, meaningful unavailable-link state, readable payment summary and semantic shipment heading |
| Public monthly statement | Agency identity, readable account details, contained invoice table scrolling, clear unavailable-link state |

Shared changes: sticky desktop navigation; mobile menu; skip-to-content link; visible keyboard focus; dialog names, focus containment, focus restoration, Escape and explicit close controls; mobile form spacing and input sizing. Hidden dropdown options are excluded from modal focus traversal. Tables use compact record cards below the wide-screen breakpoint, with contained horizontal scrolling where a ledger/table is necessary.

Restricted frontend routes redirect staff to their role dashboard. Backend permission enforcement remains in place. Hub shipment detail no longer requests admin-only account data. Screen code is loaded on demand; the main production JavaScript bundle decreased from approximately 632 KB to 444 KB before compression.

## Verification

- TypeScript checks passed for frontend and backend.
- Production build passed; the previous oversized-chunk warning is resolved through route splitting.
- Existing regression suite: 54/54 tests passed, including 31 security/financial integration checks.
- All 13 admin routes checked at 320, 390, 768, and 1440 px. No page-level horizontal overflow remained.
- Hub dashboard/list/detail, login, public tracking, public statement, and invalid public links checked at 390 and 1440 px.
- Shipment, flight, flyer, and supplier dialogs checked at both desktop and phone sizes, including accessible naming, initial focus, focus containment and Escape dismissal.
- Detail and settings section navigation checked; supplier statement deep link checked.
- Search/no-results/clear, shipment status/reset, task creation/completion/filter, and explicit settings save/reload checked.
- Final compact-phone/tablet pass recorded no uncaught browser exceptions.
- Visual inspection included desktop dashboard, mobile shipment detail, payment settings, and public tracking/payment layout.

## Test isolation and limits

Browser mutations and integration fixtures used only database `mamun_audit_20260905` and Redis database 15. Operational data was not used for test mutations; no schema or migration reset was performed. Public payment-provider transfers, real courier dispatch, and live R2 uploads were not executed for this UI audit. Browser checks used Chromium/Edge viewport emulation, not physical iOS/Android devices. The existing pg concurrent-query deprecation warning remains a backend maintenance item; tests passed.
