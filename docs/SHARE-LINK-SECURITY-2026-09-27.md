# Shareable link security — 27 September 2026

The tracking and statement links already used cryptographically random bearer tokens. This pass removed internal receipt IDs from public responses, replaced ID-derived payment-method keys with independent public references, and made new links tracking-only unless invoice access is explicitly requested. Existing saved link tokens and scopes are preserved. No main-database test records were created.

Scope: customer tracking, monthly statements, invoice PDFs, shared shipment media, payment proof upload and private flyer document access. This is a targeted review of sharing boundaries, not a claim that every aspect of the application is vulnerability-free. The security-best-practices skill and its React/general frontend references informed the checks; Hono authorization was verified directly in this application's code and tests.

## Findings and resolution

### S01 — Medium: implicit invoice access on new API-issued links — fixed

Previously the link creation API defaulted to the legacy `tracking` scope, which includes invoices, although the current UI explicitly selected tracking-only. An API caller omitting scope could unintentionally expose billing. New requests now default to `tracking_only`; PDF access, billing data and payment proof submission remain unavailable until invoice scope is selected. Existing legacy links keep their previously granted access.

Evidence: `apps/backend/src/modules/shipments.ts:618`; scope check: `apps/backend/src/shared/publicLinks.ts:16`.

### S02 — Low: internal receipt identifiers and staff metadata in customer history — fixed

Tracking used the same receipt serializer as the admin UI, exposing its primary key. Statements also returned `id: r.id` and reviewer names. Those IDs did not themselves authorize protected access, but were unnecessary disclosure. Both public surfaces now use an explicit field allowlist and separate random receipt references. Internal IDs, reviewer identity and private screenshot metadata are absent. Admin history retains the information it needs.

Evidence: `apps/backend/src/shared/receiptHistory.ts:39`; consumers: `apps/backend/src/modules/track.ts:119`, `apps/backend/src/modules/statements.ts:92`.

### S03 — Low: public payment keys derived from internal IDs — replaced

The previous SHA-256 payment-method key concealed the raw primary key; no practical recovery or authorization bypass was established. It is now an independent random UUID stored as `PayMethod.publicReference`. Public payment selection and validation use that reference; a database primary key is rejected. The public response's historical `id` field name is retained for compatibility, but its value is this separate reference.

Evidence: `apps/backend/prisma/schema.prisma:498`, `apps/backend/src/modules/track.ts:30`, `apps/backend/src/modules/statements.ts:102`.

## Verified sharing controls

- Tracking and statement URLs contain 32 random bytes encoded as 43 base64url characters. They are not generated from primary keys, customer codes or shipment codes. Access lookup verifies a SHA-256 digest, expiry and revocation.
- Saved links can be retrieved by admins using the existing AES-256-GCM encrypted token copy; plaintext tokens are not stored. Tampering tests remain passing.
- Tracking and statement token namespaces are resolved independently. Knowing a shipment ID, supplier ID, link row ID or token digest does not grant public access.
- Invoice scope is enforced on the server for public invoice PDFs, payment data and proof upload. Issued/reviewed invoice requirements remain in force.
- Shared media uses a random file reference, is looked up within the authorized shipment, and must be ready and explicitly shared. A reference from another shipment is rejected.
- Payment screenshots and flyer documents remain admin-only. A tracking link does not authorize those private previews.
- API responses use `Cache-Control: no-store` and `Referrer-Policy: no-referrer`. API `X-Robots-Tag` and page robots metadata request no indexing. Robots instructions are advisory, not an authorization mechanism.
- Business references such as shipment codes and invoice numbers remain visible where appropriate. They cannot replace the secret token to authorize public access.

## Limits and operating rules

A customer link is a bearer capability: anyone who receives the full link can use its permitted scope until expiry or revocation. Share only with the intended customer. Revocation blocks subsequent API access; it cannot erase information already viewed or downloaded. An already-issued storage URL can remain usable until its short expiry, at most two minutes and no longer than the remaining customer-link lifetime. No additional flyer-document sharing capability was introduced.

Production still needs the existing HTTPS configuration and suitable reverse-proxy logging rules: avoid retaining full secret-bearing `/t/`, `/s/`, `/api/track/` and `/api/statements/` URLs in access logs. This pass verified the local main application; it did not configure an external deployment or its logs.

## Validation and migration

- 153 tests passed across 11 files, including primary-key rejection, nested public response checks, default scope, token namespace separation, cross-shipment media access and revocation of all public subroutes. Existing expiry, ciphertext-tampering, proof ownership and flyer-document permission tests passed.
- Backend/frontend type checks and both production builds passed.
- Anonymous browser checks passed for tracking, monthly receipt history, mobile layouts, invoice PDFs, tracking-only restrictions, robots/referrer metadata and revoked-link feedback, without JavaScript errors.
- Main application login and read endpoints passed after automatic backend reload.
- Additive migration `20260927020000_public_references` was tested on the isolated local audit database, then deployed to `localhost:5435/mamun_local` after a backup. Record counts and saved-link fingerprints were unchanged.
- Evidence: `N:/Codex/review-mamun-20260910/public-security-tests.log`, `public-security-types.log`, `public-security-build.log`, `public-security-browser.json` and `public-security-migration.json`.
