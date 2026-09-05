import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'prisma/config'

// Prisma 7 dropped the automatic dotenv load that Prisma 6 did, so the CLI
// sees an empty connection URL unless we load it here. `process.loadEnvFile`
// is built into Node (>= 20.6) — no dotenv dependency needed.
//
// It does NOT overwrite variables already present in the environment, so an
// explicitly exported `DATABASE_URL` still wins over .env.
try {
  process.loadEnvFile(resolve(dirname(fileURLToPath(import.meta.url)), '.env'))
} catch {
  // No .env — expected on a host that injects real variables.
}

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    seed: 'tsx prisma/seed.ts',
  },
  datasource: {
    url: process.env.DATABASE_URL ?? '',
  },
})
