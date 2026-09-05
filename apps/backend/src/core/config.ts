/**
 * Environment configuration, validated once at boot.
 *
 * Postgres and Redis are hard requirements — this API is the system of
 * record, and sessions live in Redis. Starting without either would let the
 * app accept a shipment capture and lose it.
 */

function required(name: string): string {
  const value = process.env[name]
  if (!value) {
    throw new Error(
      `Missing required environment variable ${name}. Copy .env.example to .env for local development.`,
    )
  }
  return value
}

function optional(name: string, fallback = ''): string {
  return process.env[name] ?? fallback
}

function list(value: string | undefined): string[] {
  return value ? value.split(',').map((s) => s.trim()).filter(Boolean) : []
}

const nodeEnv = optional('NODE_ENV', 'development')

export const config = {
  nodeEnv,
  isProduction: nodeEnv === 'production',
  port: Number(optional('PORT', '3002')),
  appName: optional('APP_NAME', 'Sichuan Bangla Express'),

  databaseUrl: required('DATABASE_URL'),
  redisUrl: required('REDIS_URL'),

  /** Base URL used when composing customer tracking links. */
  publicTrackBaseUrl: optional('PUBLIC_TRACK_BASE_URL', 'http://localhost:5178'),

  /**
   * AeroDataBox (RapidAPI) key for the flight-schedule lookup in the Add
   * flight form. Absent key → the lookup serves clearly-labeled sample data.
   */
  aerodataboxKey: optional('AERODATABOX_RAPIDAPI_KEY'),

  /** Browser origins allowed to call the API. */
  allowedOrigins: list(process.env.ALLOWED_ORIGINS),
} as const

if (config.isProduction) {
  const publicUrl = new URL(config.publicTrackBaseUrl)
  if (publicUrl.protocol !== 'https:' || publicUrl.hostname === 'localhost') throw new Error('Production requires an HTTPS PUBLIC_TRACK_BASE_URL')
  if (!config.allowedOrigins.length) throw new Error('Production requires explicit ALLOWED_ORIGINS')
}
