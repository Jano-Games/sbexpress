import { useEffect, useRef, useState } from "react";
import { Download, FileText } from "lucide-react";
import { getToken } from "@/api/client";
import { Button } from "@/components/beui/button";
import { SectionNotice } from "@/components/DesignSystem";

export function InvoicePdfActions({
  path,
  filename,
  showPreview = true,
}: {
  path: string;
  filename: string;
  showPreview?: boolean;
}) {
  const [url, setUrl] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const locked = useRef(false);
  useEffect(
    () => () => {
      if (url) URL.revokeObjectURL(url);
    },
    [url],
  );
  useEffect(() => {
    setUrl("");
    setError("");
  }, [path]);

  async function load(download: boolean) {
    if (locked.current) return;
    locked.current = true;
    setBusy(true);
    setError("");
    try {
      const token = getToken();
      const response = await fetch(
        `${import.meta.env.VITE_API_BASE_URL ?? ""}/api${path}`,
        {
          headers: token ? { Authorization: `Bearer ${token}` } : {},
          cache: "no-store",
        },
      );
      if (!response.ok) {
        const body = await response.json().catch(() => null);
        throw new Error(body?.error ?? "Could not generate PDF");
      }
      if (!response.headers.get("content-type")?.includes("application/pdf"))
        throw new Error("Invalid PDF response");
      const objectUrl = URL.createObjectURL(await response.blob());
      if (download) {
        const link = document.createElement("a");
        link.href = objectUrl;
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        link.remove();
        setTimeout(() => URL.revokeObjectURL(objectUrl), 60000);
      } else setUrl(objectUrl);
    } catch (error) {
      setError(error instanceof Error ? error.message : "Could not load PDF");
    } finally {
      locked.current = false;
      setBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-2">
        {showPreview && (
          <Button
            variant="secondary"
            disabled={busy}
            onClick={() => (url ? setUrl("") : void load(false))}
          >
            <FileText size={16} />
            {url ? "Close PDF" : "View PDF"}
          </Button>
        )}
        <Button
          variant="secondary"
          disabled={busy}
          onClick={() => void load(true)}
        >
          <Download size={16} />
          {busy ? "Generating PDF…" : "Download PDF"}
        </Button>
      </div>
      {error && <SectionNotice tone="danger">{error}</SectionNotice>}
      {showPreview && url && (
        <iframe
          title="Invoice PDF document"
          src={url}
          className="h-[560px] w-full rounded-md border border-border bg-card"
        />
      )}
    </div>
  );
}
