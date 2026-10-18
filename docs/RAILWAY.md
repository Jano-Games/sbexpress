# Railway deployment

The repository-root Dockerfile builds the frontend and backend into one service. The frontend and API share one origin. The local development application remains on port 5178; no second preview is needed.

1. Deploy the repository root with its Dockerfile and railway.json. Add Railway PostgreSQL and Redis services and reference their DATABASE_URL and REDIS_URL in this application. Do not copy the local localhost database URLs into Railway.
2. Generate a Railway HTTPS domain. Set PUBLIC_TRACK_BASE_URL and ALLOWED_ORIGINS to its exact HTTPS origin. Railway provides PORT; the application binds to 0.0.0.0 in production.
3. Set LINK_ENCRYPTION_KEY to the existing stable server-side key when migrating existing saved links, or a new random 32-byte hex key for a completely fresh database. Keep it out of source control. Configure the four R2 variables from apps/backend/.env.example, and allow the deployed origin in the private bucket's CORS rules (GET, PUT, HEAD; Content-Type). Keep the bucket private.
4. Set MEDIA_CLEANUP_ENABLED=true for daily cleanup of expired unfinished uploads and removed files after a seven-day grace period. Ready final files and accepted payment evidence are retained. The standalone cleanup CLI still defaults to dry-run.
5. Pre-deploy runs tracked Prisma migrations; it never runs the demo seed or resets data. On an empty database, create the first administrator using the create-user script and a private strong password. Do not publish the local test password.
6. Enable Railway database/volume backups and verify a restore for the deployed environment. The compose backup container protects only the local Docker database.
7. Check /api/health, sign-in, customer tracking, invoice PDF, a fictional payment screenshot and a fictional flyer document from the HTTPS origin. Check Railway/proxy access-log settings so full bearer URLs under /t/, /s/, /api/track/ and /api/statements/ are not retained. Application code has no request-URL logger.

The application sends no-store/referrer protections for customer pages, adds CSP/frame protections to built frontend HTML, and does not publish source maps. A healthy deployment requires PostgreSQL and Redis to respond. File storage credentials are not proven merely by the health check.

References: [Railway config as code](https://docs.railway.com/config-as-code/reference), [pre-deploy commands](https://docs.railway.com/deployments/pre-deploy-command), [health checks](https://docs.railway.com/deployments/healthchecks), [Hono static files](https://hono.dev/docs/getting-started/nodejs#serve-static-files).
