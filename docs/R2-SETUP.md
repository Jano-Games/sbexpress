# Private photo/video storage

Set R2_ACCOUNT_ID, R2_BUCKET, R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY in apps/backend/.env or your server secret manager. Restart the backend after changing credentials. The bucket must remain private: disable r2.dev and public custom-domain access. Use a bucket-scoped Object Read & Write token. Do not put credentials in frontend environment variables.

Configure bucket CORS for your exact frontend origins, for example:

```json
[{"AllowedOrigins":["http://localhost:5178","https://YOUR-PRODUCTION-DOMAIN"],"AllowedMethods":["PUT","GET","HEAD"],"AllowedHeaders":["Content-Type","Content-Length","Range","x-amz-*"],"ExposeHeaders":["ETag","Content-Length","Content-Range"],"MaxAgeSeconds":300}]
```

Replace the production placeholder. Add a one-day lifecycle deletion rule for the `staging/` prefix only. Never apply that rule to `media/`.

Staff request a five-minute presigned PUT URL. JPEG, PNG and WebP photos are limited to 10 MB; MP4/WebM videos to 100 MB; at most 50 current attachments per shipment. Content type and length are signed. After upload the backend checks size, declared type and file signature, then copies the ETag-validated upload to an immutable random key. Replaying an upload URL cannot replace the accepted attachment. This signature check is not antivirus scanning or video transcoding.

Attachments start private. Only admins can share them on customer tracking pages. Public metadata and download issuance require a live shipment token and a shared attachment belonging to that shipment. Download URLs last at most two minutes and never outlive the parent link's remaining validity at issuance. Revoking a link or making a file private prevents new downloads; already issued URLs can remain usable until their short expiry. Object keys and public media references are independent random values, not database IDs.

Use Shipment detail → Photos & videos to upload, preview, share or remove. Click View again if the preview expires.

Cleanup, from apps/backend:

```powershell
pnpm exec tsx --env-file-if-exists=.env scripts/cleanup-media.ts
pnpm exec tsx --env-file-if-exists=.env scripts/cleanup-media.ts --execute
```

The first command only reports. The second deletes expired staging objects, abandoned uploads and removed attachments using database-owned random keys. It never deletes ready final attachments. Run it through your deployment's job scheduler when configuring hosting. The staging lifecycle also cleans upload replays after finalization.

Live verification remains required after credentials/CORS are configured: upload one photo and video, preview as staff, share via a fresh tracking link, verify private/revoked files cannot obtain a fresh download URL, and check a URL after expiry.

References: [R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/), [AWS SDK v3](https://developers.cloudflare.com/r2/examples/aws/aws-sdk-js-v3/), [CORS](https://developers.cloudflare.com/r2/buckets/cors/).
