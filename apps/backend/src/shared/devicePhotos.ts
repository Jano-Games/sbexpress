import { badRequest } from '../core/errors'

type Unit = { model?: string; serial?: string; serialPhotoRef?: string | null; photoRef?: string | null; customerCode?: string | null }
type Item = { category?: string; count?: number; rate?: number; currency?: string; units?: Unit[] }

/** Which photo of a device piece: its IMEI or serial label, or the piece itself. */
export type UnitPhotoField = 'serialPhotoRef' | 'photoRef'

/** Point one device unit at a photo without changing piece counts or rates. */
export function attachUnitPhoto(
  pcsItems: unknown,
  itemIndex: number,
  unitIndex: number,
  reference: string,
  field: UnitPhotoField,
): { items: Item[]; previous: string | null } {
  if (!Array.isArray(pcsItems)) throw badRequest('This shipment has no device units')
  const items = (pcsItems as Item[]).map((item) => ({
    ...item,
    units: (item.units ?? []).map((unit) => ({ ...unit })),
  }))
  const item = items[itemIndex]
  const unit = item?.units?.[unitIndex]
  if (!item || !unit) throw badRequest('Device unit not found')
  const previous = typeof unit[field] === 'string' ? (unit[field] as string) : null
  unit[field] = reference
  return { items, previous }
}

/** Point one device unit at its IMEI photo. */
export function attachSerialPhoto(pcsItems: unknown, itemIndex: number, unitIndex: number, reference: string) {
  return attachUnitPhoto(pcsItems, itemIndex, unitIndex, reference, 'serialPhotoRef')
}

/** Set (or clear) the customer who ordered one device piece. */
export function setUnitCustomer(pcsItems: unknown, itemIndex: number, unitIndex: number, customerCode: string | null) {
  if (!Array.isArray(pcsItems)) throw badRequest('This shipment has no device units')
  const items = (pcsItems as Item[]).map((item) => ({
    ...item,
    units: (item.units ?? []).map((unit) => ({ ...unit })),
  }))
  const unit = items[itemIndex]?.units?.[unitIndex]
  if (!unit) throw badRequest('Device unit not found')
  const previous = typeof unit.customerCode === 'string' ? unit.customerCode : null
  if (customerCode) unit.customerCode = customerCode
  else delete unit.customerCode
  return { items, previous, unit }
}
