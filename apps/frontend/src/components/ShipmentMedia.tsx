import { useEffect, useRef, useState, type FormEvent } from 'react'
import { api } from '@/api/client'
import { useFetch } from '@/state/useFetch'
import { Button } from '@/components/beui/button'
import { Card } from '@/components/ui'

type Item = { reference: string; name: string; contentType: string; size: number; shared: boolean }
type Props = { code?: string; token?: string; admin?: boolean }
type UploadAttempt = { file: File; reference: string; uploadUrl: string; uploaded: boolean }
const acceptedTypes = ['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/webm']

export function ShipmentMedia(props: Props) {
  return <MediaPanel key={props.token ?? props.code} {...props} />
}

function MediaPanel({ code, token, admin = false }: Props) {
  const base = token ? `/track/${token}` : `/shipments/${code}`
  const { data, error, reload } = useFetch<{ configured?: boolean; media: Item[] }>(`${base}/media`)
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const [notice, setNotice] = useState('')
  const [preview, setPreview] = useState<{ url: string; type: string } | null>(null)
  const [selected, setSelected] = useState<File | null>(null)
  const [localUrl, setLocalUrl] = useState<string | null>(null)
  const locked = useRef(false)
  const attempt = useRef<UploadAttempt | null>(null)

  useEffect(() => {
    if (!selected) { setLocalUrl(null); return }
    const url = URL.createObjectURL(selected)
    setLocalUrl(url)
    return () => URL.revokeObjectURL(url)
  }, [selected])

  async function run(fn: () => Promise<unknown>) {
    if (locked.current) return
    locked.current = true
    setBusy(true)
    setMessage('')
    setNotice('')
    try { await fn(); await reload() }
    catch (e) { setMessage(e instanceof Error ? e.message : 'Failed') }
    finally { locked.current = false; setBusy(false) }
  }

  function select(file: File | undefined) {
    if (!file || locked.current) return
    setMessage('')
    setNotice('')
    if (!acceptedTypes.includes(file.type)) {
      setMessage('Choose a JPEG, PNG, WebP, MP4 or WebM file.')
      return
    }
    const limit = (file.type.startsWith('video/') ? 100 : 10) * 1024 * 1024
    if (file.size === 0 || file.size > limit) {
      setMessage(`Choose a non-empty file under ${limit / 1048576} MB.`)
      return
    }
    attempt.current = null
    setSelected(file)
  }

  function submit(event: FormEvent) {
    event.preventDefault()
    if (!selected || token || locked.current) return
    const file = selected
    void run(async () => {
      // Reserve storage only after explicit submission. Keep a completed PUT
      // across retries so a failed completion request does not upload twice.
      if (!attempt.current || attempt.current.file !== file) {
        const reservation = await api.post<{ reference: string; uploadUrl: string }>(`${base}/media/upload`, {
          name: file.name, contentType: file.type, size: file.size,
        })
        attempt.current = { file, ...reservation, uploaded: false }
      }
      const current = attempt.current
      if (!current.uploaded) {
        const response = await fetch(current.uploadUrl, { method: 'PUT', headers: { 'Content-Type': file.type }, body: file })
        if (!response.ok) {
          // A rejected/expired URL needs a fresh reservation on the next submit.
          attempt.current = null
          throw new Error('Upload failed. Your file is still selected; please try again.')
        }
        current.uploaded = true
      }
      await api.post(`${base}/media/${current.reference}/complete`)
      attempt.current = null
      setSelected(null)
      setNotice('Attachment uploaded. It is private until shared.')
    })
  }

  if (token && !data?.media.length) return null
  return <Card className="my-4 p-5">
    <h3 className="font-bold">Photos & videos</h3>
    {!token && <>
      <p className="my-2 text-sm text-muted-foreground">Photos up to 10 MB; videos up to 100 MB. Attachments are private until shared.</p>
      {data?.configured === false ? <p className="text-sm">Storage setup is pending.</p> : <form onSubmit={submit} className="my-4 rounded-xl border border-dashed border-border bg-background p-4">
        <label className="block text-sm font-medium">Select photo or video
          <input className="my-2 block w-full text-sm" type="file" accept={acceptedTypes.join(',')} disabled={busy} onChange={e => { const file = e.target.files?.[0]; e.target.value = ''; select(file) }} />
        </label>
        <p className="text-xs text-muted-foreground">Selecting a file only creates a preview. Submit below to upload it.</p>
        {selected && <div className="mt-4">
          <p className="break-all text-sm font-medium">{selected.name} · {(selected.size / 1048576).toFixed(1)} MB</p>
          {localUrl && (selected.type.startsWith('video/')
            ? <video src={localUrl} controls preload="metadata" className="my-3 max-h-64 w-full rounded-lg" />
            : <img src={localUrl} alt="Selected attachment preview" className="my-3 max-h-64 w-full rounded-lg object-contain" />)}
          <div className="mt-3 flex flex-wrap gap-2">
            <Button type="submit" disabled={busy}>{busy ? 'Uploading…' : 'Upload attachment'}</Button>
            <Button type="button" variant="secondary" disabled={busy} onClick={() => { setSelected(null); attempt.current = null; setMessage(''); setNotice('') }}>Remove selection</Button>
          </div>
        </div>}
      </form>}
    </>}
    {(error || message) && <p role="alert" className="text-sm text-red-700">{message || error}</p>}
    {notice && <p role="status" className="text-sm text-success">{notice}</p>}
    {busy && <p role="status">Working…</p>}
    {data?.media.map(m => <div key={m.reference} className="flex flex-wrap items-center gap-2 border-b py-3 text-sm">
      <span className="flex-1 break-all">{m.name} · {(m.size / 1048576).toFixed(1)} MB</span>
      <Button disabled={busy} variant="secondary" onClick={() => void run(async () => { const x = await api.get<{ url: string }>(`${base}/media/${m.reference}/url`); setPreview({ url: x.url, type: m.contentType }) })}>View</Button>
      {admin && !token && <>
        <Button disabled={busy} variant="secondary" onClick={() => void run(() => api.patch(`${base}/media/${m.reference}`, { shared: !m.shared }))}>{m.shared ? 'Make private' : 'Share on tracking'}</Button>
        <Button disabled={busy} variant="danger-outline" onClick={() => void run(async () => { await api.delete(`${base}/media/${m.reference}`); setPreview(null) })}>Remove</Button>
      </>}
    </div>)}
    {preview && <div className="mt-3">{preview.type.startsWith('video/') ? <video src={preview.url} controls className="max-h-96 w-full" /> : <img src={preview.url} alt="Shipment attachment" className="max-h-96 w-full object-contain" />}<p className="text-xs text-muted-foreground">Preview links expire after two minutes. Select View again to refresh.</p></div>}
  </Card>
}
