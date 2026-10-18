import { useEffect, useRef, useState } from "react";
import { ImagePlus, X } from "lucide-react";
import { api } from "@/api/client";
import { Button } from "@/components/beui/button";

const types = ["image/jpeg", "image/png", "image/webp"];
type Attempt = {
  file: File;
  reference: string;
  uploadUrl: string;
  expiresAt: string;
  uploaded: boolean;
};

export function useReceiptScreenshot(base: string) {
  const [file, setFile] = useState<File | null>(null);
  const [url, setUrl] = useState("");
  const [error, setError] = useState("");
  const attempt = useRef<Attempt | null>(null);
  useEffect(() => {
    setFile(null);
    attempt.current = null;
    setError("");
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
    if (
      next &&
      (!types.includes(next.type) || !next.size || next.size > 5 * 1024 * 1024)
    ) {
      setError("Choose a JPG, PNG or WebP image up to 5 MB.");
      return;
    }
    attempt.current = null;
    setError("");
    setFile(next);
  }
  async function upload(): Promise<string | undefined> {
    if (!file) return undefined;
    if (
      !attempt.current ||
      attempt.current.file !== file ||
      Date.parse(attempt.current.expiresAt) <= Date.now()
    ) {
      const reservation = await api.post<Omit<Attempt, "file" | "uploaded">>(
        `${base}/receipt-image/upload`,
        {
          name: file.name,
          contentType: file.type,
          size: file.size,
        },
      );
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
        attempt.current = null;
        throw new Error(
          "Screenshot upload failed. Your image is still selected; please retry.",
        );
      }
      current.uploaded = true;
    }
    return current.reference;
  }
  return { file, url, error, select, upload, clear: () => select(null) };
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
            accept={types.join(",")}
            disabled={disabled}
            onChange={(event) => {
              entry.select(event.target.files?.[0] ?? null);
              event.target.value = "";
            }}
          />
        </div>
      </label>
      <p className="receipt-upload-help">
        Attach the payment confirmation from your bank or wallet. JPG, PNG or
        WebP · Up to 5 MB.
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
              {(entry.file.size / 1024).toFixed(0)} KB · Ready to submit
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
