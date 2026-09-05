# Sichuan Bangla Express (Mamun)

Chengdu → Dhaka air-freight-by-flyer suite, implemented from the approved
Claude Design canvas (`docs/design/sichuan-bangla-express.dc.html`). Student
flyers carry cargo on their checked-baggage allowance (44/52 kg + 2 mobiles +
1 laptop); the app runs the whole operation: flights, flyers, suppliers,
shipments through a nine-step pipeline, hub handling, finance, receipt review,
and public per-shipment tracking links.

pnpm monorepo:

| Folder           | Stack                                                        |
| ---------------- | ------------------------------------------------------------ |
| `apps/frontend/` | Vite · React 19 · Tailwind v4 · BEUI motion components       |
| `apps/backend/`  | Hono · Prisma 7 · Postgres · Redis (sessions, cache, limits) |

## Accounts & roles

Sign-in is email + password (argon2id hashes in the `User` table, bearer
sessions in Redis). Customers never log in — each shipment gets a public
`/t/<token>` tracking page with live status, payment rails and receipt upload.

Seeding initializes missing settings only. It never deletes existing data or creates demo passwords.
Suppliers, flyers, flights, shipments and accounts are created through the app. Create or update a staff account
(also works as a password reset):

```bash
pnpm --filter backend create-user <email> "<name>" <admin|hub> <password>
```

- **Admin** — everything: overview, shipments, flights, flyers, suppliers,
  finance, review queue, to-dos, settings.
- **Hub Manager** — Dhaka-side handling; sees supplier short codes only, no
  names, no cost/profit lines.

## Getting started

```bash
pnpm install
pnpm infra          # Postgres on 5435, Redis on 6382 (docker compose)
pnpm db:deploy      # apply tracked migrations (back up an existing database first)
pnpm db:seed        # initialize missing settings; preserve all existing data
pnpm dev            # turbo TUI: backend on :3002, frontend on :5178
```

`apps/backend/.env` ships with defaults that match docker-compose — nothing to
configure locally.

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
- Invoice lines, discounts and reasoned credits support partial payment. Credit notes can reduce paid bills, moving any excess to supplier credit. Supplier overpayments become credit, which can settle future bills or be refunded through a selected account. Invoice revisions are retained.
- Tracking link opens the sharing dialog: choose tracking or invoice, 1–90 day expiry and optionally a partial request amount. Finalize an invoice before sharing its invoice page. Revoke all links from the same dialog.
- Public tokens contain 256 random bits, are hashed at rest, and authorize only their shipment. Existing short links have been retired and must be reissued. Public GET and payment submission both enforce expiry and revocation.
- Customers submit the transferred amount and real transaction reference. Submission is not proof of payment: staff verify the bank/wallet transaction before approval. No external payment gateway is installed.
- Finance account names must be unambiguous. A payment rail's provider/bank name must match its receiving finance account (or use the single unambiguous Bank account). A missing account stops posting instead of silently choosing another one.
- Account transfers preserve both source and destination currency amounts, keep a history and do not affect profit. Money-in can be business income or owner capital. Capital affects cash but not profit. Manual expenses can select their paying account; flight purchases default to Cash.
- Cash flow, receivables and booked business results are separate views. CN/BD/customs cost fields are accrued costs. Use **Pay a recorded cost** on the shipment to settle them partially or fully from a chosen account. These settlements update cash and payables without counting the cost twice in profit. **Additional expense** is for a separate new cost. Shipment ticket allocation is an estimate based on booked weight; unallocated flight cost remains in overall results.

See [the audit and validation record](docs/AUDIT-2026-09-05.md) for changes, evidence and remaining product boundaries.

### Integration tests

The integration suite refuses any database except `mamun_audit_20260905`. Create that separate database on your local Postgres, apply migrations to it, then set `AUDIT_INTEGRATION=1`, `DATABASE_URL` pointing to it and `REDIS_URL` to an isolated Redis database before running `pnpm --filter backend test`. Fixtures clear only that dedicated audit database. The default `pnpm test` runs unit tests and skips the database suite.


### Customer accounts, statements and R2 media

Supplier detail includes advance/credit balances, credit allocation, partial refunds and expiring monthly statement links. Finalized invoice reductions use a credit note from Shipment detail; history is available there. Finance separates customer credit liabilities/refunds from business income/expenses and includes historical reconciliation. Flight detail allocates each flyer's contribution and receipts separately.

Photos/videos use a private R2 bucket with presigned upload/download URLs. See [R2 setup](docs/R2-SETUP.md) for environment variables, CORS, staging lifecycle, cleanup and live verification. Storage stays visibly unavailable until configured. Payment gateway and courier API integration require provider details; customer references still undergo manual verification.

Finance now has separate Summary, Ledger, Accounts & funds, and Statements sections. See [Finance workspace](docs/FINANCE-WORKSPACE.md) for behavior and validation.
