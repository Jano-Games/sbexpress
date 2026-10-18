import { useEffect, useState } from "react";
import {
  Expand,
  ImageOff,
  Image as ImageIcon,
  ZoomIn,
  ZoomOut,
} from "lucide-react";
import { api } from "@/api/client";
import type { ReceiptScreenshotMeta } from "@/api/types";
import { Modal } from "@/components/Modal";
import { Button } from "@/components/beui/button";

export function ReceiptScreenshot({
  screenshot,
  compact = false,
}: {
  screenshot: ReceiptScreenshotMeta | null | undefined;
  compact?: boolean;
}) {
  const [url, setUrl] = useState("");
  const [error, setError] = useState("");
  const [open, setOpen] = useState(false);
  const [zoom, setZoom] = useState(false);
  const [revision, setRevision] = useState(0);
  const shouldLoad = Boolean(screenshot && (!compact || open));
  useEffect(() => {
    setUrl("");
    setError("");
    setZoom(false);
    if (!screenshot || !shouldLoad) return;
    let active = true;
    api
      .get<{ url: string }>(`/review/screenshots/${screenshot.reference}/url`)
      .then((result) => {
        if (active) setUrl(result.url);
      })
      .catch((e) => {
        if (active)
          setError(
            e instanceof Error ? e.message : "Could not load screenshot",
          );
      });
    return () => {
      active = false;
    };
  }, [screenshot?.reference, shouldLoad, revision]);
  const failedImage = () =>
    setError("The screenshot could not be loaded. Reload it to try again.");
  const feedback = error ? (
    <div className="receipt-image-feedback">
      <ImageOff size={28} />
      <p role="alert">{error}</p>
      <Button
        variant="secondary"
        size="sm"
        onClick={() => setRevision((n) => n + 1)}
      >
        Reload screenshot
      </Button>
    </div>
  ) : (
    <div className="receipt-image-feedback" role="status">
      Loading screenshot…
    </div>
  );
  if (compact && !screenshot)
    return <span className="text-xs text-muted-foreground">No screenshot</span>;
  return (
    <>
      {compact ? (
        <Button variant="secondary" size="sm" onClick={() => setOpen(true)}>
          <ImageIcon size={15} />
          View screenshot
        </Button>
      ) : (
        <section className="receipt-evidence" aria-label="Payment screenshot">
          <header>
            <h3>Payment screenshot</h3>
            {screenshot && <span>Customer attachment</span>}
          </header>
          {!screenshot ? (
            <div className="receipt-image-empty">
              <ImageOff size={32} strokeWidth={1.5} aria-hidden="true" />
              <strong>No screenshot attached</strong>
              <p>
                This receipt was submitted with a transaction reference only.
              </p>
            </div>
          ) : error || !url ? (
            feedback
          ) : (
            <button
              className="receipt-image-thumbnail"
              type="button"
              onClick={() => setOpen(true)}
              aria-label="Open payment screenshot"
            >
              <img
                src={url}
                alt="Customer payment screenshot"
                onError={failedImage}
              />
              <span>
                <Expand size={16} />
                Click to enlarge
              </span>
            </button>
          )}
          {screenshot && (
            <footer>
              <span>{screenshot.name}</span>
              <span>{(screenshot.size / 1024).toFixed(0)} KB</span>
            </footer>
          )}
        </section>
      )}
      <Modal
        open={open}
        onClose={() => setOpen(false)}
        className="max-w-5xl receipt-image-modal"
      >
        <h2 data-dialog-title>Payment screenshot</h2>
        <p className="receipt-image-filename">{screenshot?.name}</p>
        {error || !url ? (
          feedback
        ) : (
          <>
            <div
              className={`receipt-lightbox-scroll ${zoom ? "actual-size" : ""}`}
            >
              <img
                src={url}
                alt="Full payment screenshot"
                onError={failedImage}
              />
            </div>
            <div className="receipt-lightbox-actions">
              <Button
                variant="secondary"
                onClick={() => setZoom((value) => !value)}
              >
                {zoom ? <ZoomOut size={16} /> : <ZoomIn size={16} />}
                {zoom ? "Fit image" : "Actual size"}
              </Button>
              <Button variant="secondary" onClick={() => setOpen(false)}>
                Close preview
              </Button>
            </div>
          </>
        )}
      </Modal>
    </>
  );
}
