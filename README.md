# Sichuan Bangla Express (Mamun)

Chengdu → Dhaka air-freight-by-flyer suite with a consistent operations workspace. Student
flyers carry cargo on their checked-baggage allowance (44/52 kg + 2 mobiles +
1 laptop); the app runs the whole operation: flights, flyers, customers,
shipments through a nine-step pipeline, hub handling, finance, receipt review,
and public per-shipment tracking links.

pnpm monorepo:

| Folder           | Stack                                                        |
| ---------------- | ------------------------------------------------------------ |
| `apps/frontend/` | Vite · React 19 · Tailwind v4 · shared static UI components       |
| `apps/backend/`  | Hono · Prisma 7 · Postgres · Redis (sessions, cache, limits) |

## Accounts & roles

Sign-in is email + password (argon2id hashes in the `User` table, bearer
sessions in Redis). Customers never log in — each shipment gets a public
`/t/<token>` tracking page with live status, payment rails and receipt upload.

Seeding initializes missing settings only. It never deletes existing data or creates demo passwords.
Customers, flyers, flights, shipments and accounts are created through the app. Create or update a staff account
(also works as a password reset):

```bash
pnpm --filter backend create-user <email> "<name>" <admin|hub> <password>
```

- **Admin** — everything: overview, shipments, flights, flyers, customers,
  finance, review queue, to-dos, settings.
- **Hub Manager** — Dhaka-side handling; sees customer short codes only, no
  names, and no bill, rate, paid, due, or cost/profit fields. The hub API
  omits those keys. Hub is one trusted Dhaka role (no per-hub scope yet).

Photo uploads are re-encoded on the server so EXIF and GPS metadata are removed
before storage. PDF and video are copied as uploaded. There is no antivirus
scan; checks only confirm the file type. The API rejects HEIC. The browser
converts HEIC to JPEG and compresses photos to at most 2000px at quality 0.80
before the upload starts.

## Getting started

```bash
pnpm install
# First setup only: copy apps/backend/.env.example to apps/backend/.env
pnpm infra          # Postgres on 5435, Redis on 6382 (docker compose)
pnpm db:deploy      # apply tracked migrations (back up an existing database first)
pnpm db:seed        # initialize missing settings; preserve all existing data
pnpm dev            # turbo TUI: backend on :3002, frontend on :5178
```

`apps/backend/.env` is gitignored. Copy `.env.example` on first setup; its defaults
use Docker PostgreSQL at `localhost:5435/mamun_local` and Redis at `localhost:6382`.
The main app remains at `http://localhost:5178`, with its API on port 3002.
Existing Docker volumes are preserved by `pnpm infra`; changing `POSTGRES_DB`
does not create a new database in an existing volume. If upgrading an older
local stack that has no `mamun_local` database, create it once with
`docker compose exec postgres createdb -U postgres mamun_local`, then run
`pnpm db:deploy`. Do not use `infra:reset` to switch databases.

The September 26 local migration preserved the current users, shipments, invoices
and customer links in `mamun_local`; the older `sichuan-bangla` database was left
intact. Private snapshots and the previous environment configuration live under
`.local-backups/`, which is excluded from Git.

## Scripts

- `pnpm dev` / `dev:plain` / `dev:backend` / `dev:frontend`
- `pnpm build`, `pnpm typecheck`, `pnpm test`
- `pnpm infra` / `infra:down` / `infra:reset`
- `pnpm db:generate` / `db:push` / `db:migrate` / `db:deploy` / `db:studio` / `db:seed`

## Notes

- The design reference lives in `docs/design/` — screens, chip colors, demo
  data and business rules (ticket-share costing, weight-discrepancy alerts,
  monthly statements) all come from it.
- Money is Decimal end-to-end; the received ledger is a `Payment` table, and
  approving a receipt credits the matching account (bKash/bank/wallets, CNY
  converted at the configurable rate).
- Redis: bearer sessions, 10-second dashboard caches; public authorization is never cached (invalidated on
  writes), and rate limits on the public tracking endpoints.

## Audited workflow (September 2026)

- Intake can precede flight assignment. Assign a carrying flyer on the selected flight before dispatch.
- Flight booking references are distinct from the repeating airline flight number. Agency share is entered explicitly; flyer contribution = actual ticket cost − agency share. Record actual flyer receipts on the flight page.
- At the BD hub: receive, weigh (0 for device-only cargo), confirm package count, then enter the real courier or pickup reference. Measured weight updates the draft bill; a finalized invoice remains the explicit billing agreement until edited.
- Invoice lines, discounts and reasoned credits support partial payment. Credit notes can reduce paid bills, moving any excess to customer credit. Customer overpayments become credit, which can settle future bills or be refunded through a selected account. Invoice revisions are retained.
- **Settings → Users** lets administrators add staff accounts, edit names/emails/roles and reset passwords. Roles use the existing Administrator and Hub manager permissions. New passwords must have 8–128 characters; password/role changes invalidate existing sessions. Changing your own password requires the current password and signs you out. Your own role cannot be changed from this screen.
- **Share link** opens the sharing dialog. Tracking is included by default; select **Include invoice** to add the itemized bill, balance and payment options. Choose a 1–90 day expiry. Including an invoice saves one from existing shipment charges if needed. Saved links remain available to copy/open after reload, with their invoice inclusion setting, expiry and revocation status. No separate requested amount is entered. Revoke all links from the same dialog.
- Public tokens contain 256 random bits and authorize only their shipment. Authorization uses a stored SHA-256 digest; an AES-256-GCM encrypted copy lets admins retrieve saved links after closing the dialog or reloading. Configure a stable server-only `LINK_ENCRYPTION_KEY` (32 random bytes as 64 hex characters, see `.env.example`) and preserve it across deployments. Public GET and payment submission enforce expiry and revocation. Earlier digest-only links remain valid but cannot be recovered for copying; generate a new saved link.
- Customers submit the transferred amount and real transaction reference. Submission is not proof of payment: staff verify the bank/wallet transaction before approval. No external payment gateway is installed.
- Finance account names must be unambiguous. A payment rail's provider/bank name must match its receiving finance account (or use the single unambiguous Bank account). A missing account stops posting instead of silently choosing another one.
- Account transfers preserve both source and destination currency amounts, keep a history and do not affect profit. Money-in can be business income or owner capital. Capital affects cash but not profit. Manual expenses can select their paying account; flight ticket payments require an explicitly selected fund.
- Cash flow, receivables and booked business results are separate views. Each shipment has one **Costs → Add cost** flow for courier, packaging, customs or any named cost. Saving defaults to Pay later; choose Pay now only when money has actually left the selected account. Customer-billed additions enter the draft invoice, while settlement pays an existing cost without rebilling it. Earlier CN/BD/customs costs remain in the same register; use their row-level **Pay** action for partial or full settlement. Settlements update cash and payables without adding another expense or invoice charge. Shipment ticket allocation is an estimate based on booked weight; unallocated flight cost remains in overall results.

See [the audit and validation record](docs/AUDIT-2026-09-05.md) for changes, evidence and remaining product boundaries.

### Integration tests

The integration suite refuses any database except `mamun_audit_20260905`. Create that separate database on your local Postgres, apply migrations to it, then set `AUDIT_INTEGRATION=1`, `DATABASE_URL` pointing to it and `REDIS_URL` to an isolated Redis database before running `pnpm --filter backend test`. Fixtures clear only that dedicated audit database. The default `pnpm test` runs unit tests and skips the database suite.


### Customer accounts, statements and R2 media

Customer detail includes advance/credit balances, credit allocation, partial refunds and expiring monthly statement links. Finalized invoice reductions use a credit note from Shipment detail; history is available there. Finance separates customer credit liabilities/refunds from business income/expenses and includes historical reconciliation. Flight detail allocates each flyer's contribution and receipts separately.

Photos/videos use a private R2 bucket with presigned upload/download URLs. See [R2 setup](docs/R2-SETUP.md) for environment variables, CORS, staging lifecycle, cleanup and live verification. Storage stays visibly unavailable until configured. Payment gateway and courier API integration require provider details; customer references still undergo manual verification.

Finance now has separate Summary, Ledger, Accounts & funds, and Statements sections. See [Finance workspace](docs/FINANCE-WORKSPACE.md) for behavior and validation.


### UI flow and BDT/CNY

The workspace now provides guided shipment intake, separate handling/billing/cost sections and original-currency snapshots with BDT reports. See [UI flow and currency rollout](docs/UI-FLOW-AND-CURRENCIES.md) for behavior, migration requirements and validation.

## Local operation and Railway preparation (12 October 2026)

- Main app: http://localhost:5178. Start Docker Desktop, run `pnpm infra`, then `pnpm dev:plain`. The project exposes PostgreSQL/Redis only on 127.0.0.1.
- `pnpm infra` also starts a daily local PostgreSQL backup container. Completed dumps are kept in `.local-backups/automatic/`. No automatic backup deletion is configured. The container retries failures hourly and reports unhealthy when the last success is too old.
- `pnpm backup:verify` restores the newest backup into a separate randomly named local database, checks the schema/users/migrations, and removes only that verification database. It never overwrites the main database. Preserve the server environment/link encryption key separately; database dumps do not include R2 files or environment secrets.
- `MEDIA_CLEANUP_ENABLED=true` enables daily housekeeping. Expired unfinished uploads and explicitly removed files are eligible only after seven days. Ready files and accepted payment proof remain. The cleanup CLI defaults to dry-run; failures retry hourly. Settings shows the last completed run.
- Settings → General now shows business setup: confirm the actual CNY rate, add real receiving accounts/payment instructions, and manage staff. No invented payment details are seeded.
- Booking or reassignment beyond a flight's confirmed kg capacity is blocked. Confirm extra baggage and increase the flight capacity first, or select another flight. Capacity cannot be reduced below assigned weight; existing legacy overbookings can still be reduced or unassigned. Concurrent bookings share a database transaction lock.
- Customer labels are consistent across screens; existing codes, internal schema names and /suppliers API URLs remain compatible.
- [Railway deployment guide](docs/RAILWAY.md) covers the single-service Docker build, migration command, HTTPS origin, R2 CORS and backup configuration. No remote deployment was performed.
- [Latest verification report](docs/LOCAL-READINESS-2026-10-12.md).
