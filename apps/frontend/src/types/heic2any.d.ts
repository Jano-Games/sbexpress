/** Browser-only HEIC converter. The published types import missing files, so the app declares the call it actually uses. */
export default function heic2any(options: {
  blob: Blob
  toType?: string
  quality?: number
  multiple?: boolean
}): Promise<Blob | Blob[]>
