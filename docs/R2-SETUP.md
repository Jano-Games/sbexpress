# Private photo/video storage

Set R2_ACCOUNT_ID, R2_BUCKET, R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY in apps/backend/.env or your server secret manager. Restart the backend after changing credentials. The bucket must remain private: disable r2.dev and public custom-domain access. Use a bucket-scoped Object Read & Write token. Do not put credentials in frontend environment variables.

Configure bucket CORS for your exact frontend origins, for example:

```json
[{"AllowedOrigins":["http://localhost:5178","https://YOUR-PRODUCTION-DOMAIN"],"AllowedMethods":["PUT","GET","HEAD"],"AllowedHeaders":["Content-Type","Content-Length","Range","x-amz-*"],"ExposeHeaders":["ETag","Content-Length","Content-Range"],"MaxAgeSeconds":300}]
```

Replace the production placeholder. Add a eight-day lifecycle deletion rule for the `staging/` prefix only. Never apply that rule to `media/`.

Staff request a five-minute presigned PUT URL. JPEG, PNG and WebP photos are limited to 10 MB; MP4/WebM videos to 100 MB; at most 50 current attachments per shipment. Content type and length are signed. After upload the backend checks size, declared type and file signature, then copies the ETag-validated upload to an immutable random key. Replaying an upload URL cannot replace the accepted attachment. This signature check is not antivirus scanning or video transcoding.

Attachments start private. Only admins can share them on customer tracking pages. Public metadata and download issuance require a live shipment token and a shared attachment belonging to that shipment. Download URLs last at most two minutes and never outlive the parent link's remaining validity at issuance. Revoking a link or making a file private prevents new downloads; already issued URLs can remain usable until their short expiry. Object keys and public media references are independent random values, not database IDs.

Use Shipment detail → Photos & videos to upload, preview, share or remove. Click View again if the preview expires.

Cleanup, from apps/backend:

```powershell
pnpm exec tsx --env-file-if-exists=.env scripts/cleanup-media.ts
pnpm exec tsx --env-file-if-exists=.env scripts/cleanup-media.ts --execute
```

The first command only reports. The second deletes expired staging objects, abandoned uploads and removed attachments using database-owned random keys. It never deletes ready final attachments. The app now runs the same cleanup daily when MEDIA_CLEANUP_ENABLED=true, with a seven-day grace period after reservation expiry or removal. Ready final files and accepted receipts stay intact; Settings shows the last completed run. Avoid scheduling a duplicate job. The staging lifecycle also cleans upload replays after finalization.

Live verification remains required after credentials/CORS are configured: upload one photo and video, preview as staff, share via a fresh tracking link, verify private/revoked files cannot obtain a fresh download URL, and check a URL after expiry.

References: [R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/), [AWS SDK v3](https://developers.cloudflare.com/r2/examples/aws/aws-sdk-js-v3/), [CORS](https://developers.cloudflare.com/r2/buckets/cors/).


## Customer payment screenshots

Shipment tracking and monthly statement payment forms accept an optional JPG, PNG or WebP screenshot up to 5 MB. This uses the same private R2 bucket and existing browser CORS policy. A live customer link reserves a five-minute upload, scoped to that exact link and receipt type. After the browser PUT, receipt submission verifies file size, type and signature and promotes the evidence to an immutable object. Screenshot attachment and the pending receipt commit in one transaction; neither credits a payment automatically.

Only an authenticated admin can request a two-minute screenshot URL. The payment review panel, shipment billing and customer statement receipt history offer image previews. Screenshot keys and link hashes are excluded from customer responses and review metadata. Existing receipts without images remain valid. Apply migration `20260920120000_receipt_screenshots` before running this version.

The existing cleanup command now also removes expired screenshot staging objects and abandoned reservations. It preserves accepted final receipt screenshots, including evidence on approved or rejected receipts.

On 2026-09-20, actual browser PUT and private GET were verified from the main local app at `http://localhost:5178` for shipment and statement submissions. The temporary test records and their R2 objects were removed afterward. This does not verify a future production origin's CORS configuration.
