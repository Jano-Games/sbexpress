# Local readiness — 12 October 2026

## Completed

- Repaired Docker's stale network attachment without removing the existing database volume. PostgreSQL, Redis and the new automatic backup container are healthy. Main app runs at localhost:5178 with API port 3002, both local. Database and Redis ports now bind only to loopback.
- Added server-enforced flight kg capacity checks to creation, weight increases, reassignment, historical assignment corrections and flight capacity edits. Safe reductions/unassignment remain possible for legacy overbookings. Concurrent bookings cannot consume the same remaining allowance. The form explains and blocks over-capacity bookings, including fractional kg.
- Replaced customer-facing Supplier labels with Customer across navigation, forms, tables and API error messages, preserving existing identifiers and internal routes. New named activity uses Customer. Historical audit text is retained.
- Added a Settings business setup guide, including whether the CNY rate was explicitly saved, receiving accounts, enabled customer payment methods and team access. No business account numbers or exchange rates were invented.
- Added automatic local daily PostgreSQL backups, health reporting, and a restore verification command. Latest dump successfully restored to an isolated temporary database: 33 tables, one user, 27 completed migrations. The main database was untouched.
- Enabled daily upload cleanup after explicit approval of the seven-day retention rule. Expired unfinished uploads and removed files only become eligible after seven days; ready final files and accepted payment evidence are retained. Each candidate is rechecked under the same transaction lock as upload completion. A renewable Redis lease prevents multiple API instances from routinely duplicating the job. First actual local run: zero staging objects and zero records removed.
- Dashboard response keeps the full active count and only the latest eight shipment rows, eliminating an unnecessary full directory from the overview response.
- Closed an old Dhaka-fare endpoint that still let hub staff change a hidden cost; it is now admin-only like the current cost flow.
- Added a Railway-ready multi-stage Dockerfile, private-file exclusions, migration/health configuration, and same-origin built frontend serving. Deep-link refresh, private-file blocking, video-capable CSP, referrer protection and disabled production source maps are covered. No external deployment was performed.
- Updated Hono to patched 4.13.13 and pinned affected Prisma CLI transitive dependencies: deepmerge-ts 8.0.0, mysql2 3.23.1, fast-uri 3.1.8. Prisma configuration uses plain objects; generation, migration status, tests and Linux image build verify the override. Production dependency audit: zero reported advisories.

## Validation

- 166 tests pass across 13 files. Added coverage includes concurrent overbooking, editing/reassignment, safe historical corrections, setup permissions, recent dashboard rows/full counts, legacy cost authorization, cleanup retention/ready-file protection, and production routing.
- Backend and frontend type checks pass. Both production builds pass. Linux Docker image builds and runs as a non-root user.
- Main-app login and nine read endpoints pass. Browser check: 20 checks covering login, nine desktop/mobile screens, Customer labels and business setup navigation; no JavaScript/server errors or page overflow.
- Isolated real-form browser flow: over-capacity error at 5.01 kg, successful 5 kg booking against 5 kg capacity, saved assignment, customer labels and mobile billing; six checks pass without browser errors.
- Container smoke: nine checks pass for startup/database/Redis health, built HTML/JS, private-file blocking, public and named-record deep links, CSP and absence of private environment/backups in the image. No extra host port or public preview was opened.
- Performance workload: 2,000 fictional shipments with 2,000 invoices, costs and payments, 10 concurrent requests, 30 requests per route. Main business data was never used for these mutations. Fixtures were removed afterward. Detailed before/after results are in the evidence files below. This bounded local API check is not a production throughput guarantee or a penetration test.

## Data and remaining operator inputs

Main local DB still has one administrator and the user's one flyer. Customers, shipments, documents, invoices, receipts, payments and expenses remain empty. Only maintenance status settings were added. No test money or sample business records were inserted into the main database.

The actual business CNY rate, receiving bank/wallet details and any additional staff must be entered by the operator in Settings/Finance. The current displayed default rate is clearly marked unconfirmed. Railway domain/variables, R2 production-origin CORS, cloud backup and platform log configuration remain deployment steps for the user, as requested. Local database backups do not protect against loss of the entire local disk and do not contain R2 objects or the server encryption key.

Automatic cleanup's initial approval review was resolved by explicit user approval of the seven-day rule. No cleanup authorization is pending.

## Evidence

Under N:/Codex/: mamun-tests-final-20261012.log, mamun-types-final-20261012.log, mamun-build-final-20261012.log, mamun-audit-final-20261012.json, mamun-browser-20261012.json, mamun-flow-browser-20261012.json, mamun-container-smoke-20261012.log, mamun-main-verify-20261012.json, mamun-load-before-20261012.json, mamun-load-20261012.json and mamun-docker-final-20261012.log.

Backup evidence: .local-backups/automatic/restore-verification.json. Backups remain private and excluded from both Git and Docker builds.

Sources for security/deployment decisions: [DeepmergeTS advisory](https://github.com/advisories/GHSA-ggr8-5vv4-36mx), [v8 behavior changes](https://github.com/RebeccaStevens/deepmerge-ts/releases/tag/v8.0.0), [Railway configuration](https://docs.railway.com/config-as-code/reference), [Hono static serving](https://hono.dev/docs/getting-started/nodejs#serve-static-files).

Final local workload results (30 requests per route, concurrency 10):

| Route | Median | 95th percentile | Largest response |
| --- | ---: | ---: | ---: |
| Shipment directory | 933 ms | 1,510 ms | 1,115 KB |
| Customer directory | 790 ms | 1,267 ms | 1 KB |
| Finance summary | 1,089 ms | 1,840 ms | 498 KB |
| Dashboard overview | 1,743 ms | 1,980 ms | 5 KB |
| Navigation counts | 9 ms | 14 ms | under 1 KB |

The previous dashboard response was 1,116 KB for the same dataset. The improved response preserves the full active count and recent rows. These are in-process API timings with real local PostgreSQL/Redis, not end-to-end internet latency; no claim is made about higher production volumes.
