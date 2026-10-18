import { badRequest } from '../core/errors'

type Unit = { model?: string; serial?: string; serialPhotoRef?: string | null }
type Item = { category?: string; count?: number; rate?: number; currency?: string; units?: Unit[] }

/** Point one device unit at its IMEI photo without changing piece counts or rates. */
export function attachSerialPhoto(pcsItems: unknown, itemIndex: number, unitIndex: number, reference: string): { items: Item[]; previous: string | null } {
  if (!Array.isArray(pcsItems)) throw badRequest('This shipment has no device units')
  const items = (pcsItems as Item[]).map((item) => ({
    ...item,
    units: (item.units ?? []).map((unit) => ({ ...unit })),
  }))
  const item = items[itemIndex]
  const unit = item?.units?.[unitIndex]
  if (!item || !unit) throw badRequest('Device unit not found')
  const previous = typeof unit.serialPhotoRef === 'string' ? unit.serialPhotoRef : null
  unit.serialPhotoRef = reference
  return { items, previous }
}
