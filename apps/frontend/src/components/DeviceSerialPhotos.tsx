import { useState } from "react";
import { api } from "@/api/client";
import type { PcsItem } from "@/api/types";
import { Button } from "@/components/beui/button";
import { Panel, SectionNotice } from "@/components/DesignSystem";
import { Modal } from "@/components/Modal";
import { nativeMoney } from "@/components/MoneyInput";
import { prepareUploadFile, transferUpload } from "@/lib/uploadFile";

const accept = "image/jpeg,image/png,image/webp,image/heic,image/heif,.heic,.heif";

export function DeviceSerialPhotos({
  code,
  items,
  showRates,
  onChanged,
}: {
  code: string;
  items: PcsItem[];
  showRates: boolean;
  onChanged: () => Promise<unknown>;
}) {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [preview, setPreview] = useState<string | null>(null);
  if (!items.length) return null;
  const missing = items.reduce(
    (count, item) => count + item.units.filter((unit) => !unit.serialPhotoRef).length,
    0,
  );

  async function upload(itemIndex: number, unitIndex: number, file: File | undefined) {
    if (!file || busy) return;
    setBusy(true);
    setMessage("");
    try {
      const prepared = await prepareUploadFile(file, { maxBytes: 10 * 1024 * 1024 });
      await transferUpload({
        file: prepared,
        reserve: (ready) =>
          api.post<{ reference: string; uploadUrl: string }>(`/shipments/${code}/device-photo`, {
            itemIndex,
            unitIndex,
            name: ready.name,
            contentType: ready.type,
            size: ready.size,
          }),
        complete: (reference) => api.post(`/shipments/${code}/device-photo/${reference}/complete`),
      });
      await onChanged();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not upload the device photo.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Panel
      title={showRates ? "Items billed per piece" : "Devices"}
      description="Each device can keep its own IMEI or serial photo. A missing photo is a warning only."
    >
      {missing > 0 && (
        <SectionNotice tone="warning">
          {missing === 1
            ? "1 device is missing an IMEI or serial photo."
            : `${missing} devices are missing an IMEI or serial photo.`}{" "}
          Weighing, packing and delivery are not blocked.
        </SectionNotice>
      )}
      {message && (
        <div className="mt-4">
          <SectionNotice tone="danger">{message}</SectionNotice>
        </div>
      )}
      <div className="mt-4 space-y-6">
        {items.map((item, itemIndex) => (
          <section key={`${item.category}-${itemIndex}`} className="space-y-3">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <h3 className="text-sm font-semibold">{item.category}</h3>
              <p className="text-xs text-muted-foreground">
                {item.count} {item.count === 1 ? "unit" : "units"}
                {showRates && item.rate !== undefined
                  ? ` · ${nativeMoney(item.rate, item.currency)} per piece`
                  : ""}
              </p>
            </div>
            <ul className="divide-y divide-border rounded-md border border-border">
              {item.units.map((unit, unitIndex) => (
                <li key={unitIndex} className="flex flex-wrap items-center justify-between gap-3 p-3">
                  <div className="min-w-0">
                    <p className="text-sm font-medium">
                      {unit.model || `Item ${unitIndex + 1}`}
                    </p>
                    <p className="mt-1 break-all text-xs text-muted-foreground">
                      {unit.serial || "No serial typed"} · {unit.serialPhotoRef ? "Photo attached" : "No photo"}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {unit.serialPhotoRef && (
                      <Button
                        variant="secondary"
                        disabled={busy}
                        onClick={() =>
                          void api
                            .get<{ url: string }>(`/shipments/${code}/media/${unit.serialPhotoRef}/url`)
                            .then((result) => setPreview(result.url))
                            .catch((error: unknown) =>
                              setMessage(error instanceof Error ? error.message : "Could not open the photo."),
                            )
                        }
                      >
                        View photo
                      </Button>
                    )}
                    <label className="control-button button-secondary button-md cursor-pointer">
                      {busy ? "Working…" : unit.serialPhotoRef ? "Replace photo" : "Add photo"}
                      <input
                        className="hidden"
                        type="file"
                        accept={accept}
                        disabled={busy}
                        aria-label={`IMEI or serial photo for ${item.category} item ${unitIndex + 1}`}
                        onChange={(event) => {
                          const file = event.target.files?.[0];
                          event.target.value = "";
                          void upload(itemIndex, unitIndex, file);
                        }}
                      />
                    </label>
                  </div>
                </li>
              ))}
            </ul>
          </section>
        ))}
      </div>
      <Modal open={preview !== null} onClose={() => setPreview(null)} className="max-w-4xl">
        <h2 className="mb-5 text-xl font-semibold">IMEI / serial photo</h2>
        {preview && (
          <img src={preview} alt="IMEI or serial photo" className="max-h-[60vh] w-full object-contain" />
        )}
        <p className="mt-4 text-xs text-muted-foreground">
          This photo stays with staff. It is not shown on the customer tracking page.
        </p>
      </Modal>
    </Panel>
  );
}
