import { useEffect, useState } from "react";
import { api } from "@/api/client";
import type { SupplierSummary } from "@/api/types";
import { Modal } from "@/components/Modal";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/beui/select";
import { useToast } from "@/components/beui/toast";
import { Field } from "@/components/ui";
import { FormActions, FormGrid, FormSection } from "@/components/DesignSystem";

const blank = (v: string) => (v === "—" ? "" : v);

export function AddSupplierModal({
  open,
  onClose,
  onDone,
  editing,
}: {
  open: boolean;
  onClose: () => void;
  /** Receives the created or updated supplier code. */
  onDone: (code?: string) => void;
  /** When set, the modal edits this supplier instead of adding a new one. */
  editing?: SupplierSummary;
}) {
  const { showToast } = useToast();
  const [busy, setBusy] = useState(false);
  const [nextCode, setNextCode] = useState("");
  const [form, setForm] = useState({
    code: "",
    name: "",
    phone: "",
    address: "",
    terms: "instant",
  });

  useEffect(() => {
    if (!open) return;
    if (editing) {
      setForm({
        code: editing.code,
        name: editing.name,
        phone: blank(editing.phone),
        address: blank(editing.address),
        terms: editing.terms,
      });
      return;
    }
    setForm({ code: "", name: "", phone: "", address: "", terms: "instant" });
    api
      .get<{ code: string }>("/suppliers/next-code")
      .then((r) => setNextCode(r.code))
      .catch(() => undefined);
    // Refreshing the same record must not overwrite the open draft.
    // Reinitialize only when opened again or switched to a different record.
  }, [open, editing?.code]);

  const submit = async () => {
    if (busy) return;
    if (!form.name.trim()) {
      showToast({ title: "Name required", status: "error" });
      return;
    }
    setBusy(true);
    try {
      const payload = {
        code: form.code.trim() || undefined,
        name: form.name.trim(),
        phone: form.phone || "—",
        address: form.address || "—",
        terms: form.terms,
      };
      if (editing) {
        const r = await api.patch<{ code: string }>(
          `/suppliers/${editing.code}`,
          payload,
        );
        showToast({ title: "Customer updated", status: "success" });
        onDone(r.code);
      } else {
        const result = await api.post<{ code: string }>("/suppliers", payload);
        showToast({ title: "Customer added", status: "success" });
        onDone(result.code);
      }
      onClose();
    } catch (e) {
      showToast({
        title: e instanceof Error ? e.message : "Failed",
        status: "error",
      });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal open={open} onClose={onClose}>
      <h2 data-dialog-title className="text-xl font-semibold">
        {editing ? "Edit customer" : "Add customer"}
      </h2>
      <p className="mt-2 mb-6 text-sm text-muted-foreground">
        {editing
          ? `Update the contact and billing details for ${editing.code}.`
          : "Create a customer account for shipments and billing."}
      </p>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          void submit();
        }}
        className="space-y-6"
      >
        <FormSection
          title="Account details"
          description="The customer name is required. Leave the code blank to generate one automatically."
        >
          <FormGrid>
            <Input
              label="Customer name"
              placeholder="e.g. Rahim Traders"
              required
              value={form.name}
              onChange={(v) => setForm((f) => ({ ...f, name: v }))}
            />
            <Input
              label="Customer code"
              placeholder={
                editing ? "e.g. SUP-014" : nextCode || "Assigned automatically"
              }
              value={form.code}
              onChange={(v) => setForm((f) => ({ ...f, code: v }))}
            />
          </FormGrid>
        </FormSection>
        <FormSection title="Contact and billing">
          <FormGrid>
            <Input
              label="Phone number"
              type="tel"
              placeholder="+880"
              value={form.phone}
              onChange={(v) => setForm((f) => ({ ...f, phone: v }))}
            />
            <Field label="Payment terms">
              <Select
                value={form.terms}
                onValueChange={(v) => setForm((f) => ({ ...f, terms: v }))}
              >
                <SelectTrigger aria-label="Payment terms">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="instant">Instant payment</SelectItem>
                  <SelectItem value="monthly">Monthly billing</SelectItem>
                </SelectContent>
              </Select>
            </Field>
          </FormGrid>
          <div className="mt-4">
            <Input
              label="Delivery address"
              placeholder="Street, area and city"
              value={form.address}
              onChange={(v) => setForm((f) => ({ ...f, address: v }))}
            />
          </div>
        </FormSection>
        <FormActions>
          <Button variant="secondary" disabled={busy} onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" disabled={busy}>
            {busy ? "Saving…" : editing ? "Save changes" : "Add customer"}
          </Button>
        </FormActions>
      </form>
    </Modal>
  );
}
