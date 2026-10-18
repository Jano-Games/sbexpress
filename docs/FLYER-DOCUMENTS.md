# Flyer documents — 27 September 2026

Use Flyers → open a flyer → Documents. Registering a flyer from the directory opens this tab directly. Profile forms direct staff here for document uploads and review.

## Behavior

- Categories: Passport, NID, Visa / residence permit, Student ID, Admission / JW document, Ticket, and Other documents. Multiple files/pages can be kept in each category. Ticket and NID stay on this admin-only router. Hub staff cannot upload identity documents.
- JPEG, PNG, WebP and PDF are supported, up to 10 MB per file and 30 active or unexpired pending files per flyer. Images are re-encoded on promote so EXIF and GPS do not remain. There is no antivirus scan.
- Files upload to the configured private R2 storage. Completion checks the expected size, content type and file signature before promoting the staged object to an immutable private key. This checks the file format, not document authenticity or malware.
- Admin-only previews use expiring signed URLs. Image previews support fit/actual size; PDFs use the browser viewer. Open original / save file is available. No document endpoint exists on customer tracking pages.
- Upload and verification are separate. Staff open a document and choose Mark verified, or return it to Needs review. Uploader and reviewer names/times are retained. New flyers start with no verified documents; profile checkboxes cannot bypass review.
- Directory and profile counts reflect stored files and their verification. Old checklist-only flags do not count as uploaded or verified evidence. All-files-reviewed does not assert that every possible travel document is present.
- Renaming or archiving a flyer retains documents. Removing a file takes it out of active lists and verification counts. Fresh preview requests stop immediately; previously issued URLs expire within two minutes. Unused profile deletion is blocked while stored document records remain.
- The existing cleanup-media script includes expired pending and removed flyer documents. Its dry run reports candidates; --execute removes their stored content and rows after the grace period. No recurring job was created by this change.

## Migration and validation

Additive migration: `20260927010000_flyer_documents`. Main local database was backed up before deployment; existing records were not reset or reseeded.

- 150 tests across 11 files passed, including admin/hub/public permissions, ownership, upload limits, failed/expired completion, idempotent completion, PDF signatures, verification, rename/archive and removal.
- Backend/frontend type checks and both production builds passed.
- Browser checks used the main frontend with an in-process backend and the isolated local audit database. Real fictional PNG/PDF files were uploaded to the configured private storage, previewed and removed after testing. Verification, reload persistence, validation feedback and mobile overflow checks passed. No test records were added to the main database.
- Evidence: `N:/Codex/review-mamun-20260910/flyer-docs-tests.log`, `flyer-documents-browser.json`, `flyer-documents-desktop.png`, `flyer-documents-mobile.png`, and `flyer-documents-build.log`.

October 12 update: daily cleanup is now enabled locally after explicit approval, with a seven-day grace period. Its first run found zero eligible objects. See LOCAL-READINESS-2026-10-12.md.
