import { useEffect, useRef, useState, type FormEvent } from "react";
import { api } from "@/api/client";
import { useFetch } from "@/state/useFetch";
import { Button } from "@/components/beui/button";
import { Panel, FormActions, SectionNotice } from "@/components/DesignSystem";
import { Modal } from "@/components/Modal";

type Item = {
  reference: string;
  name: string;
  contentType: string;
  size: number;
  shared: boolean;
};
type Props = { code?: string; token?: string; admin?: boolean };
type UploadAttempt = {
  file: File;
  reference: string;
  uploadUrl: string;
  uploaded: boolean;
};
const acceptedTypes = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "video/mp4",
  "video/webm",
];

export function ShipmentMedia(props: Props) {
  return <MediaPanel key={props.token ?? props.code} {...props} />;
}

function MediaPanel({ code, token, admin = false }: Props) {
  const base = token ? `/track/${token}` : `/shipments/${code}`;
  const { data, error, reload } = useFetch<{
    configured?: boolean;
    media: Item[];
  }>(`${base}/media`);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [notice, setNotice] = useState("");
  const [preview, setPreview] = useState<{ url: string; type: string } | null>(
    null,
  );
  const [selected, setSelected] = useState<File | null>(null);
  const [localUrl, setLocalUrl] = useState<string | null>(null);
  const locked = useRef(false);
  const attempt = useRef<UploadAttempt | null>(null);

  useEffect(() => {
    if (!selected) {
      setLocalUrl(null);
      return;
    }
    const url = URL.createObjectURL(selected);
    setLocalUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [selected]);

  async function run(fn: () => Promise<unknown>) {
    if (locked.current) return;
    locked.current = true;
    setBusy(true);
    setMessage("");
    setNotice("");
    try {
      await fn();
      await reload();
    } catch (e) {
      setMessage(e instanceof Error ? e.message : "Failed");
    } finally {
      locked.current = false;
      setBusy(false);
    }
  }

  function select(file: File | undefined) {
    if (!file || locked.current) return;
    setMessage("");
    setNotice("");
    if (!acceptedTypes.includes(file.type)) {
      setMessage("Choose a JPEG, PNG, WebP, MP4 or WebM file.");
      return;
    }
    const limit = (file.type.startsWith("video/") ? 100 : 10) * 1024 * 1024;
    if (file.size === 0 || file.size > limit) {
      setMessage(`Choose a non-empty file under ${limit / 1048576} MB.`);
      return;
    }
    attempt.current = null;
    setSelected(file);
  }

  function submit(event: FormEvent) {
    event.preventDefault();
    if (!selected || token || locked.current) return;
    const file = selected;
    void run(async () => {
      // Reserve storage only after explicit submission. Keep a completed PUT
      // across retries so a failed completion request does not upload twice.
      if (!attempt.current || attempt.current.file !== file) {
        const reservation = await api.post<{
          reference: string;
          uploadUrl: string;
        }>(`${base}/media/upload`, {
          name: file.name,
          contentType: file.type,
          size: file.size,
        });
        attempt.current = { file, ...reservation, uploaded: false };
      }
      const current = attempt.current;
      if (!current.uploaded) {
        const response = await fetch(current.uploadUrl, {
          method: "PUT",
          headers: { "Content-Type": file.type },
          body: file,
        });
        if (!response.ok) {
          // A rejected/expired URL needs a fresh reservation on the next submit.
          attempt.current = null;
          throw new Error(
            "Upload failed. Your file is still selected; please try again.",
          );
        }
        current.uploaded = true;
      }
      await api.post(`${base}/media/${current.reference}/complete`);
      attempt.current = null;
      setSelected(null);
      setNotice("Attachment uploaded. It is private until shared.");
    });
  }

  if (token && !data?.media.length) return null;
  return (
    <div className="space-y-5">
      {!token && (
        <Panel
          title="Upload an attachment"
          description="Add photos or packing videos. Files remain private until you share them on tracking."
        >
          {data?.configured === false ? (
            <SectionNotice>
              Attachment storage is not configured yet.
            </SectionNotice>
          ) : (
            <form onSubmit={submit} className="space-y-4">
              <label className="block text-xs font-medium text-muted-foreground">
                Photo or video
                <input
                  className="mt-2 block w-full rounded-md border border-border bg-card px-3 py-2 text-sm text-foreground file:mr-4 file:rounded file:border-0 file:bg-muted file:px-3 file:py-1 file:text-sm"
                  type="file"
                  accept={acceptedTypes.join(",")}
                  disabled={busy}
                  onChange={(event) => {
                    const file = event.target.files?.[0];
                    event.target.value = "";
                    select(file);
                  }}
                />
              </label>
              <p className="text-xs text-muted-foreground">
                JPEG, PNG or WebP up to 10 MB. MP4 or WebM up to 100 MB.
              </p>
              {selected && (
                <div className="rounded-md border border-border p-4">
                  <p className="break-all text-sm font-medium">
                    {selected.name}
                  </p>
                  <p className="mt-1 text-xs text-muted-foreground">
                    {(selected.size / 1048576).toFixed(1)} MB · Ready to upload
                  </p>
                  {localUrl &&
                    (selected.type.startsWith("video/") ? (
                      <video
                        src={localUrl}
                        controls
                        preload="metadata"
                        className="mt-4 max-h-64 w-full rounded-md"
                      />
                    ) : (
                      <img
                        src={localUrl}
                        alt="Selected attachment"
                        className="mt-4 max-h-64 w-full rounded-md object-contain"
                      />
                    ))}
                  <FormActions>
                    <Button
                      type="button"
                      variant="secondary"
                      disabled={busy}
                      onClick={() => {
                        setSelected(null);
                        attempt.current = null;
                        setMessage("");
                        setNotice("");
                      }}
                    >
                      Clear selection
                    </Button>
                    <Button type="submit" disabled={busy}>
                      {busy ? "Uploading…" : "Upload attachment"}
                    </Button>
                  </FormActions>
                </div>
              )}
            </form>
          )}
        </Panel>
      )}
      {(error || message) && (
        <SectionNotice tone="danger">{message || error}</SectionNotice>
      )}
      {notice && <SectionNotice tone="success">{notice}</SectionNotice>}
      <Panel
        title={token ? "Photos & videos" : "Saved attachments"}
        description={
          token
            ? undefined
            : "View files and manage their visibility on the customer tracking page."
        }
      >
        {data?.media.length ? (
          <div className="divide-y divide-border">
            {data.media.map((item) => (
              <div
                key={item.reference}
                className="flex flex-wrap items-center justify-between gap-4 py-4 first:pt-0 last:pb-0"
              >
                <div className="min-w-0 flex-1">
                  <p className="break-all text-sm font-medium">{item.name}</p>
                  <p className="mt-1 text-xs text-muted-foreground">
                    {item.contentType.startsWith("video/") ? "Video" : "Image"}{" "}
                    · {(item.size / 1048576).toFixed(1)} MB
                    {!token &&
                      ` · ${item.shared ? "Visible on tracking" : "Private"}`}
                  </p>
                </div>
                <div className="flex flex-wrap gap-2">
                  <Button
                    disabled={busy}
                    variant="secondary"
                    onClick={() =>
                      void run(async () => {
                        const result = await api.get<{ url: string }>(
                          `${base}/media/${item.reference}/url`,
                        );
                        setPreview({ url: result.url, type: item.contentType });
                      })
                    }
                  >
                    View
                  </Button>
                  {admin && !token && (
                    <>
                      <Button
                        disabled={busy}
                        variant="secondary"
                        onClick={() =>
                          void run(() =>
                            api.patch(`${base}/media/${item.reference}`, {
                              shared: !item.shared,
                            }),
                          )
                        }
                      >
                        {item.shared ? "Make private" : "Share on tracking"}
                      </Button>
                      <Button
                        disabled={busy}
                        variant="danger-outline"
                        onClick={() =>
                          void run(async () => {
                            await api.delete(`${base}/media/${item.reference}`);
                            setPreview(null);
                          })
                        }
                      >
                        Remove
                      </Button>
                    </>
                  )}
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p className="py-4 text-sm text-muted-foreground">
            {data
              ? "No attachments have been uploaded."
              : "Loading attachments…"}
          </p>
        )}
        {busy && (
          <p role="status" className="mt-3 text-sm text-muted-foreground">
            Working…
          </p>
        )}
      </Panel>
      <Modal
        open={preview !== null}
        onClose={() => setPreview(null)}
        className="max-w-4xl"
      >
        <h2 className="mb-5 text-xl font-semibold">Shipment attachment</h2>
        {preview &&
          (preview.type.startsWith("video/") ? (
            <video src={preview.url} controls className="max-h-[60vh] w-full" />
          ) : (
            <img
              src={preview.url}
              alt="Shipment attachment"
              className="max-h-[60vh] w-full object-contain"
            />
          ))}
        <p className="mt-4 text-xs text-muted-foreground">
          Preview links expire after two minutes. Close this window and choose
          View again to refresh.
        </p>
      </Modal>
    </div>
  );
}
