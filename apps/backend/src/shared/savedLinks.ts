import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto'
import { HttpError } from '../core/errors'
import { config } from '../core/config'
import { tokenHash, validToken, linkIncludesInvoice } from './publicLinks'

function key() {
  const value = process.env.LINK_ENCRYPTION_KEY ?? ''
  if (!/^[a-f0-9]{64}$/i.test(value)) throw new HttpError(503, 'Saved customer links are not configured')
  return Buffer.from(value, 'hex')
}
/** Public access still verifies a digest; reversible copies are admin-only and encrypted at rest. */
export function sealLinkToken(token: string) {
  const iv = randomBytes(12), cipher = createCipheriv('aes-256-gcm', key(), iv)
  cipher.setAAD(Buffer.from(tokenHash(token)))
  const encrypted = Buffer.concat([cipher.update(token, 'utf8'), cipher.final()])
  return ['v1', iv.toString('base64url'), cipher.getAuthTag().toString('base64url'), encrypted.toString('base64url')].join('.')
}
export function openLinkToken(ciphertext: string | null, digest: string): string | null {
  if (!ciphertext) return null
  try {
    const [version, iv, tag, encrypted] = ciphertext.split('.')
    if (version !== 'v1' || !iv || !tag || !encrypted) return null
    const decipher = createDecipheriv('aes-256-gcm', key(), Buffer.from(iv, 'base64url'))
    decipher.setAAD(Buffer.from(digest)); decipher.setAuthTag(Buffer.from(tag, 'base64url'))
    const token = Buffer.concat([decipher.update(Buffer.from(encrypted, 'base64url')), decipher.final()]).toString('utf8')
    return validToken(token) && tokenHash(token) === digest ? token : null
  } catch { return null }
}
export function savedLink(row: {id:string;tokenCiphertext:string|null;tokenHash:string;createdAt:Date;expiresAt:Date;revokedAt:Date|null;scope?:string}, page: 't' | 's') {
  const status = row.revokedAt ? 'revoked' : row.expiresAt <= new Date() ? 'expired' : 'active'
  const token = openLinkToken(row.tokenCiphertext, row.tokenHash)
  return { ...(page === 't' ? {includesInvoice:linkIncludesInvoice(row.scope ?? 'tracking')} : {}), id: row.id, createdAt: row.createdAt.toISOString(), expiresAt: row.expiresAt.toISOString(), status,
    url: token ? `${config.publicTrackBaseUrl}/${page}/${token}` : null }
}
