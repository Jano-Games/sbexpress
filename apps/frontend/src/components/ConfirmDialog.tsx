import { useState, type ReactNode } from "react";
import { Modal } from "@/components/Modal";
import { Button } from "@/components/beui/button";

export function ConfirmDialog({
  open,
  onClose,
  title,
  body,
  confirmLabel = "Delete",
  onConfirm,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  body?: ReactNode;
  confirmLabel?: string;
  onConfirm: () => Promise<void> | void;
}) {
  const [busy, setBusy] = useState(false);

  return (
    <Modal
      open={open}
      onClose={() => {
        if (!busy) onClose();
      }}
      className="max-w-[400px]"
    >
      <h2 className="text-xl font-semibold">{title}</h2>
      {body ? (
        <div className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
          {body}
        </div>
      ) : null}
      <div className="form-actions">
        <Button variant="secondary" onClick={onClose} disabled={busy}>
          Cancel
        </Button>
        <Button
          variant="danger"
          disabled={busy}
          onClick={() => {
            setBusy(true);
            void Promise.resolve(onConfirm()).finally(() => {
              setBusy(false);
              onClose();
            });
          }}
        >
          {busy ? "Working…" : confirmLabel}
        </Button>
      </div>
    </Modal>
  );
}
