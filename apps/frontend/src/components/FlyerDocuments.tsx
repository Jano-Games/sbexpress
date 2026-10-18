import { useEffect, useRef, useState, type FormEvent } from "react";
import {
  CheckCircle2,
  FileText,
  Plus,
  ShieldCheck,
  Upload,
  ZoomIn,
  ZoomOut,
} from "lucide-react";
import { api } from "@/api/client";
import { useFetch } from "@/state/useFetch";
import { Button } from "@/components/beui/button";
import { Panel, FormActions, SectionNotice } from "@/components/DesignSystem";
import { ErrorBlock, LoadingBlock } from "@/components/ui";
import { Modal } from "@/components/Modal";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { fmtDate } from "@/lib/format";

const kinds = [
  {
    value: "passport",
    label: "Passport",
    description: "Identity page and any additional pages.",
  },
  {
    value: "visa",
    label: "Visa / residence permit",
    description: "Visa or current residence documentation.",
  },
  {
    value: "student_id",
    label: "Student ID",
    description: "Front and back of the student identification card.",
  },
  {
    value: "admission",
    label: "Admission / JW document",
    description: "Admission letter and supporting study documents.",
  },
  {
    value: "other",
    label: "Other documents",
    description: "Additional documents for this traveler.",
  },
] as const;
type Kind = (typeof kinds)[number]["value"];
type Document = {
  reference: string;
  kind: Kind;
  name: string;
  contentType: string;
  size: number;
  createdAt: string;
  uploadedByName: string;
  verifiedAt: string | null;
  verifiedByName: string | null;
};
type Attempt = {
  file: File;
  kind: Kind;
  reference: string;
  uploadUrl: string;
  expiresAt: string;
  uploaded: boolean;
};
const accepted = ["image/jpeg", "image/png", "image/webp", "application/pdf"];
const fileSize = (size: number) =>
  size < 1048576
    ? `${Math.max(1, Math.round(size / 1024))} KB`
    : `${(size / 1048576).toFixed(1)} MB`;

export function FlyerDocuments({ name }: { name: string }) {
  const base = `/flyers/${encodeURIComponent(name)}/documents`;
  const { data, error, reload } = useFetch<{
    configured: boolean;
    documents: Document[];
  }>(base);
  const [uploadOpen, setUploadOpen] = useState(false);
  const [kind, setKind] = useState<Kind>("passport");
  const [file, setFile] = useState<File | null>(null);
  const [localUrl, setLocalUrl] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [actionError, setActionError] = useState("");
  const [uploadError, setUploadError] = useState("");
  const [preview, setPreview] = useState<Document | null>(null);
  const [previewUrl, setPreviewUrl] = useState("");
  const [previewError, setPreviewError] = useState("");
  const [previewRevision, setPreviewRevision] = useState(0);
  const [zoom, setZoom] = useState(false);
  const [removing, setRemoving] = useState<Document | null>(null);
  const attempt = useRef<Attempt | null>(null);
  const lock = useRef(false);
  useEffect(() => {
    if (!file) {
      setLocalUrl("");
      return;
    }
    const url = URL.createObjectURL(file);
    setLocalUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);
  useEffect(() => {
    setPreviewUrl("");
    setPreviewError("");
    setZoom(false);
    if (!preview) return;
    let active = true;
    api
      .get<{ url: string }>(
        `${base}/${preview.reference}/url?refresh=${previewRevision}`,
      )
      .then((result) => {
        if (active) setPreviewUrl(result.url);
      })
      .catch((e) => {
        if (active)
          setPreviewError(
            e instanceof Error ? e.message : "Could not load document",
          );
      });
    return () => {
      active = false;
    };
  }, [base, preview?.reference, previewRevision]);

  function openUpload(value: Kind) {
    setKind(value);
    setFile(null);
    attempt.current = null;
    setUploadError("");
    setUploadOpen(true);
  }
  function selectFile(selected?: File) {
    if (!selected) return;
    setUploadError("");
    attempt.current = null;
    setFile(null);
    if (!accepted.includes(selected.type)) {
      setUploadError("Choose a JPEG, PNG, WebP or PDF file.");
      return;
    }
    if (!selected.size || selected.size > 10 * 1048576) {
      setUploadError("Choose a non-empty file, 10 MB or smaller.");
      return;
    }
    if (selected.name.length > 180) {
      setUploadError("Shorten the file name to 180 characters or fewer.");
      return;
    }
    setFile(selected);
  }
  async function upload(event: FormEvent) {
    event.preventDefault();
    if (!file || lock.current) return;
    lock.current = true;
    setBusy(true);
    setUploadError("");
    setMessage("");
    try {
      if (
        !attempt.current ||
        attempt.current.file !== file ||
        attempt.current.kind !== kind ||
        (!attempt.current.uploaded &&
          Date.parse(attempt.current.expiresAt) <= Date.now())
      ) {
        const result = await api.post<
          Omit<Attempt, "file" | "kind" | "uploaded">
        >(`${base}/upload`, {
          kind,
          name: file.name,
          contentType: file.type,
          size: file.size,
        });
        attempt.current = { ...result, file, kind, uploaded: false };
      }
      const current = attempt.current;
      if (!current.uploaded) {
        const result = await fetch(current.uploadUrl, {
          method: "PUT",
          headers: { "Content-Type": file.type },
          body: file,
        });
        if (!result.ok) {
          attempt.current = null;
          throw new Error(
            "Upload failed. Your file is still selected; try again.",
          );
        }
        current.uploaded = true;
      }
      try {
        await api.post(`${base}/${current.reference}/complete`);
      } catch (e) {
        // Reuse the same reservation after a lost response; renew only when expired.
        if (Date.parse(current.expiresAt) <= Date.now()) attempt.current = null;
        throw e;
      }
      attempt.current = null;
      setFile(null);
      setUploadOpen(false);
      setMessage(
        "Document uploaded. Open the preview to check it before marking it verified.",
      );
      await reload();
    } catch (e) {
      setUploadError(
        e instanceof Error ? e.message : "Upload failed. Try again.",
      );
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }
  async function verifyDocument() {
    if (!preview || lock.current) return;
    lock.current = true;
    setBusy(true);
    setPreviewError("");
    try {
      await api.patch(`${base}/${preview.reference}/verification`, {
        verified: !preview.verifiedAt,
      });
      setMessage(
        preview.verifiedAt
          ? "Document marked as needing review."
          : "Document verified.",
      );
      setPreview(null);
      await reload();
    } catch (e) {
      setPreviewError(
        e instanceof Error ? e.message : "Could not update verification",
      );
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }
  if (!data)
    return error ? (
      <ErrorBlock message={error} />
    ) : (
      <LoadingBlock label="Loading documents…" />
    );
  return (
    <div className="space-y-5">
      <Panel
        title="Traveler documents"
        description="Upload each document, then open it to review and verify. You can keep multiple pages or files in each category."
        actions={
          <Button
            disabled={!data.configured || busy}
            onClick={() => openUpload("passport")}
          >
            <Plus size={16} /> Upload document
          </Button>
        }
      >
        <p className="flex items-center gap-2 text-sm text-muted-foreground">
          <ShieldCheck size={18} className="shrink-0" /> Private to
          administrators. These files are never included in customer tracking
          links.
        </p>
        {!data.configured && (
          <div className="mt-4">
            <SectionNotice>
              Document storage is not configured. Contact the administrator to
              enable uploads.
            </SectionNotice>
          </div>
        )}
      </Panel>
      {(error || actionError || message) && (
        <SectionNotice tone={error || actionError ? "danger" : "success"}>
          {error || actionError || message}
        </SectionNotice>
      )}
      {kinds.map((category) => {
        const rows = data.documents.filter((d) => d.kind === category.value);
        return (
          <Panel
            key={category.value}
            title={category.label}
            description={category.description}
            actions={
              <Button
                variant="secondary"
                size="sm"
                disabled={!data.configured || busy}
                aria-label={`Upload ${category.label}`}
                onClick={() => openUpload(category.value)}
              >
                <Upload size={14} /> Add file
              </Button>
            }
          >
            {!rows.length ? (
              <p className="text-sm text-muted-foreground">
                No files uploaded.
              </p>
            ) : (
              <div className="divide-y divide-border">
                {rows.map((doc) => (
                  <div
                    key={doc.reference}
                    className="flex flex-col gap-3 py-3 first:pt-0 last:pb-0 sm:flex-row sm:items-center sm:justify-between"
                  >
                    <div className="flex min-w-0 gap-3">
                      <FileText
                        size={20}
                        className="mt-1 shrink-0 text-muted-foreground"
                      />
                      <div className="min-w-0">
                        <button
                          type="button"
                          disabled={busy}
                          className="break-all text-left text-sm font-medium text-primary underline-offset-4 hover:underline"
                          onClick={() => {
                            setPreview(doc);
                            setPreviewRevision((n) => n + 1);
                          }}
                        >
                          {doc.name}
                        </button>
                        <p className="mt-1 text-xs text-muted-foreground">
                          {fileSize(doc.size)} · {fmtDate(doc.createdAt)} ·
                          Uploaded by {doc.uploadedByName}
                        </p>
                        <p
                          className={`mt-1 text-xs ${doc.verifiedAt ? "text-success" : "text-muted-foreground"}`}
                        >
                          {doc.verifiedAt
                            ? `Verified by ${doc.verifiedByName} · ${fmtDate(doc.verifiedAt)}`
                            : "Awaiting review"}
                        </p>
                      </div>
                    </div>
                    <div className="flex shrink-0 gap-2">
                      <Button
                        size="sm"
                        variant="secondary"
                        disabled={busy}
                        onClick={() => {
                          setPreview(doc);
                          setPreviewRevision((n) => n + 1);
                        }}
                      >
                        Preview
                      </Button>
                      <Button
                        size="sm"
                        variant="danger-outline"
                        disabled={busy}
                        onClick={() => setRemoving(doc)}
                      >
                        Remove
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </Panel>
        );
      })}
      <Modal
        open={uploadOpen}
        onClose={() => {
          if (!busy) setUploadOpen(false);
        }}
        className="max-w-xl"
      >
        <h2 data-dialog-title className="text-xl font-semibold">
          Upload document
        </h2>
        <p className="mt-2 mb-5 text-sm text-muted-foreground">
          {name} · JPEG, PNG, WebP or PDF, up to 10 MB per file.
        </p>
        <form onSubmit={upload} className="space-y-4">
          <label className="block text-sm font-medium">
            Document type
            <select
              className="mt-2 block w-full rounded-md border border-border bg-card px-3 py-2"
              value={kind}
              disabled={busy}
              onChange={(e) => {
                setKind(e.target.value as Kind);
                attempt.current = null;
              }}
            >
              {kinds.map((k) => (
                <option key={k.value} value={k.value}>
                  {k.label}
                </option>
              ))}
            </select>
          </label>
          <label className="block text-sm font-medium">
            Choose file
            <input
              type="file"
              accept={accepted.join(",")}
              disabled={busy}
              className="mt-2 block w-full min-w-0 rounded-md border border-border bg-card p-3 text-sm file:mr-3 file:rounded file:border-0 file:bg-muted file:px-3 file:py-1"
              onChange={(e) => {
                selectFile(e.target.files?.[0]);
                e.target.value = "";
              }}
            />
          </label>
          {file && (
            <div className="rounded-md border border-border p-3">
              <p className="break-all text-sm font-medium">{file.name}</p>
              <p className="mt-1 text-xs text-muted-foreground">
                {fileSize(file.size)}
              </p>
              {localUrl && file.type.startsWith("image/") && (
                <img
                  src={localUrl}
                  alt="Selected document"
                  className="mt-3 max-h-48 w-full object-contain"
                />
              )}
              {file.type === "application/pdf" && (
                <p className="mt-3 text-sm text-muted-foreground">
                  PDF selected. Preview will be available after upload.
                </p>
              )}
            </div>
          )}
          {uploadError && (
            <div role="alert">
              <SectionNotice tone="danger">{uploadError}</SectionNotice>
            </div>
          )}
          <FormActions>
            <Button
              variant="secondary"
              disabled={busy}
              onClick={() => setUploadOpen(false)}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={busy || !file}>
              {busy ? "Uploading…" : "Upload file"}
            </Button>
          </FormActions>
        </form>
      </Modal>
      <Modal
        open={!!preview}
        onClose={() => {
          if (!busy) setPreview(null);
        }}
        className="max-w-5xl"
      >
        <h2 data-dialog-title className="break-all text-xl font-semibold">
          {preview?.name}
        </h2>
        <p className="mt-2 mb-4 text-sm text-muted-foreground">
          {kinds.find((k) => k.value === preview?.kind)?.label} ·{" "}
          {preview?.verifiedAt
            ? `Verified by ${preview.verifiedByName}`
            : "Check the file before marking it verified."}
        </p>
        {previewError && (
          <div role="alert" className="mb-4">
            <SectionNotice tone="danger">{previewError}</SectionNotice>
            <Button
              variant="secondary"
              size="sm"
              className="mt-2"
              onClick={() => setPreviewRevision((n) => n + 1)}
            >
              Reload preview
            </Button>
          </div>
        )}
        {!previewUrl && !previewError && (
          <LoadingBlock label="Loading private preview…" />
        )}
        {previewUrl &&
          (preview?.contentType === "application/pdf" ? (
            <iframe
              title={`Document preview: ${preview.name}`}
              src={previewUrl}
              className="h-[55vh] w-full rounded-md border border-border"
            />
          ) : (
            <div className="max-h-[55vh] overflow-auto rounded-md border border-border bg-muted p-3">
              <img
                src={previewUrl}
                alt={preview?.name}
                onError={() =>
                  setPreviewError(
                    "The preview could not load. Reload it to get a fresh link.",
                  )
                }
                className={
                  zoom ? "max-w-none" : "max-h-[50vh] w-full object-contain"
                }
              />
            </div>
          ))}
        <div className="mt-4 flex flex-wrap items-center gap-3">
          {previewUrl && (
            <a
              href={previewUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="text-sm font-medium text-primary underline"
            >
              Open original / save file
            </a>
          )}
          {previewUrl && preview?.contentType !== "application/pdf" && (
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setZoom((v) => !v)}
            >
              {zoom ? <ZoomOut size={15} /> : <ZoomIn size={15} />}
              {zoom ? "Fit image" : "Actual size"}
            </Button>
          )}
        </div>
        <FormActions>
          <Button
            variant="secondary"
            disabled={busy}
            onClick={() => setPreview(null)}
          >
            Close preview
          </Button>
          <Button
            disabled={busy || !previewUrl || !!previewError}
            onClick={() => void verifyDocument()}
          >
            <CheckCircle2 size={16} />
            {busy
              ? "Saving…"
              : preview?.verifiedAt
                ? "Mark as needing review"
                : "Mark verified"}
          </Button>
        </FormActions>
      </Modal>
      <ConfirmDialog
        open={!!removing}
        onClose={() => setRemoving(null)}
        title="Remove this document?"
        body={
          <>
            Remove <strong className="break-all">{removing?.name}</strong> from
            this flyer’s documents. Its verification will no longer count. You
            can upload a replacement.
          </>
        }
        confirmLabel="Remove document"
        onConfirm={async () => {
          if (!removing || lock.current) return;
          lock.current = true;
          setBusy(true);
          setMessage("");
          setActionError("");
          try {
            await api.delete(`${base}/${removing.reference}`);
            await reload();
            setMessage("Document removed.");
          } catch (e) {
            setActionError(
              e instanceof Error ? e.message : "Could not remove document",
            );
          } finally {
            lock.current = false;
            setBusy(false);
          }
        }}
      />
    </div>
  );
}
