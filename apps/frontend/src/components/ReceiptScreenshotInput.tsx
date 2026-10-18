import { useEffect, useRef, useState } from "react";
import { ImagePlus, X } from "lucide-react";
import { api } from "@/api/client";
import { Button } from "@/components/beui/button";
import { prepareUploadFile, transferUpload } from "@/lib/uploadFile";

const accept = "image/jpeg,image/png,image/webp,image/heic,image/heif,.heic,.heif";

export function useReceiptScreenshot(base: string) {
  const [file, setFile] = useState<File | null>(null);
  const [url, setUrl] = useState("");
  const [error, setError] = useState("");
  const [preparing, setPreparing] = useState(false);
  const selection = useRef(0);
  useEffect(() => {
    selection.current += 1;
    setFile(null);
    setError("");
    setPreparing(false);
  }, [base]);
  useEffect(() => {
    if (!file) {
      setUrl("");
      return;
    }
    const next = URL.createObjectURL(file);
    setUrl(next);
    return () => URL.revokeObjectURL(next);
  }, [file]);
  function select(next: File | null) {
    const mine = ++selection.current;
    setError("");
    if (!next) {
      setFile(null);
      setPreparing(false);
      return;
    }
    setPreparing(true);
    void prepareUploadFile(next, { maxBytes: 5 * 1024 * 1024 })
      .then((prepared) => {
        if (selection.current === mine) setFile(prepared);
      })
      .catch((reason: unknown) => {
        if (selection.current !== mine) return;
        setFile(null);
        setError(reason instanceof Error ? reason.message : "Could not prepare that image.");
      })
      .finally(() => {
        if (selection.current === mine) setPreparing(false);
      });
  }
  async function upload(): Promise<string | undefined> {
    if (preparing) throw new Error("The screenshot is still being prepared.");
    if (!file) return undefined;
    return transferUpload({
      file,
      reserve: (ready) =>
        api.post<{ reference: string; uploadUrl: string }>(
          `${base}/receipt-image/upload`,
          { name: ready.name, contentType: ready.type, size: ready.size },
        ),
      complete: async () => undefined,
    });
  }
  return { file, url, error, preparing, select, upload, clear: () => select(null) };
}

export function ReceiptScreenshotInput({
  entry,
  disabled = false,
}: {
  entry: ReturnType<typeof useReceiptScreenshot>;
  disabled?: boolean;
}) {
  return (
    <div className="receipt-upload">
      <label className="receipt-upload-label">
        <span>
          Payment screenshot <small>Optional</small>
        </span>
        <div className="receipt-upload-control">
          <ImagePlus size={20} aria-hidden="true" />
          <span className="receipt-upload-action">
            {entry.file ? "Replace screenshot" : "Choose screenshot"}
          </span>
          <input
            className="receipt-upload-file"
            type="file"
            aria-label="Payment screenshot"
            accept={accept}
            disabled={disabled}
            onChange={(event) => {
              entry.select(event.target.files?.[0] ?? null);
              event.target.value = "";
            }}
          />
        </div>
      </label>
      <p className="receipt-upload-help">
        Optional. Payment can be submitted without a screenshot. JPG, PNG, WebP
        or HEIC photos are compressed before upload, up to 5 MB.
      </p>
      {entry.error && (
        <p className="text-sm text-danger" role="alert">
          {entry.error}
        </p>
      )}
      {entry.file && (
        <div className="receipt-upload-selection">
          {entry.url && (
            <img src={entry.url} alt="Selected payment screenshot" />
          )}
          <div>
            <strong>{entry.file.name}</strong>
            <span>
              {entry.preparing
                ? "Preparing image…"
                : `${(entry.file.size / 1024).toFixed(0)} KB · Ready to submit`}
            </span>
          </div>
          <Button
            variant="ghost"
            size="icon"
            disabled={disabled}
            aria-label="Remove payment screenshot"
            onClick={entry.clear}
          >
            <X size={16} />
          </Button>
        </div>
      )}
    </div>
  );
}
