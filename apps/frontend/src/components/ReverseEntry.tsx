import { useState } from "react";
import { api } from "@/api/client";
import { Modal } from "./Modal";
import { Button } from "./beui/button";
import { Input } from "./beui/input";
import { FormActions, SectionNotice } from "./DesignSystem";
export function ReverseEntry({
  kind,
  id,
  onChanged,
  label = "Reverse entry",
}: {
  kind: string;
  id: string;
  onChanged: () => unknown;
  label?: string;
}) {
  const [open, setOpen] = useState(false),
    [reason, setReason] = useState(""),
    [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  async function save() {
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      await api.post("/finance/reverse", { kind, id, reason: reason.trim() });
      setOpen(false);
      setReason("");
      await onChanged();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not reverse entry");
    } finally {
      setBusy(false);
    }
  }
  return (
    <>
      <Button
        size="sm"
        variant="secondary"
        onClick={() => {
          setError("");
          setOpen(true);
        }}
      >
        {label}
      </Button>
      <Modal
        open={open}
        onClose={() => {
          if (!busy) setOpen(false);
        }}
      >
        <h2 data-dialog-title className="text-xl font-semibold">
          Reverse financial entry
        </h2>
        <p className="my-4 text-sm text-muted-foreground">
          Use this to correct an entry mistake or a money movement that has
          actually been undone. The original stays in history and a linked
          opposite entry is added using its saved account amounts and exchange
          rate.
        </p>
        {kind === "expense" && (
          <SectionNotice>
            The cost remains payable after its payment is reversed. Cancel an
            incorrect shipment cost from Costs after reversing its payments.
          </SectionNotice>
        )}
        <form
          className="mt-4 space-y-4"
          onSubmit={(e) => {
            e.preventDefault();
            void save();
          }}
        >
          <Input
            label="Reason for reversal"
            value={reason}
            onChange={setReason}
            required
            disabled={busy}
          />
          {error && (
            <div role="alert">
              <SectionNotice tone="danger">{error}</SectionNotice>
            </div>
          )}
          <FormActions>
            <Button
              variant="secondary"
              disabled={busy}
              onClick={() => setOpen(false)}
            >
              Keep entry
            </Button>
            <Button type="submit" disabled={busy || reason.trim().length < 3}>
              {busy ? "Reversing…" : "Confirm reversal"}
            </Button>
          </FormActions>
        </form>
      </Modal>
    </>
  );
}
