import { HttpError } from '../core/errors'
import { rateLimit } from '../core/redis'

/** Photos get a longer reservation so a compressed phone image can finish uploading. */
export const IMAGE_RESERVATION_SECONDS = 15 * 60
export const FILE_RESERVATION_SECONDS = 5 * 60
export const STAFF_UPLOADS_PER_MINUTE = 30

export function reservationSeconds(contentType: string): number {
  return contentType.startsWith('image/') ? IMAGE_RESERVATION_SECONDS : FILE_RESERVATION_SECONDS
}

/** Per-staff cap on upload reservations. Public receipt uploads keep their own link limits. */
export async function assertStaffUploadBudget(userId: string): Promise<void> {
  if (!await rateLimit(`staff-upload:${userId}`, STAFF_UPLOADS_PER_MINUTE)) {
    throw new HttpError(429, 'Too many uploads; try again in a minute')
  }
}
