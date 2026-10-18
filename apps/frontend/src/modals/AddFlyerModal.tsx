import { useEffect, useState } from "react";
import { api } from "@/api/client";
import type { Flyer } from "@/api/types";
import { Modal } from "@/components/Modal";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import { useToast } from "@/components/beui/toast";
import {
  FormActions,
  FormGrid,
  FormSection,
  SectionNotice,
} from "@/components/DesignSystem";

const blank = (v: string) => (v === "—" ? "" : v);

const EMPTY = {
  firstName: "",
  lastName: "",
  cnPhone: "",
  bdPhone: "",
  university: "",
  batch: "",
  program: "",
  wechat: "",
  cnAddress: "",
  homeAddress: "",
  emergencyContact: "",
};

/** "Ashikur Rahman" typed in a search box → { firstName: 'Ashikur', lastName: 'Rahman' }. */
function splitPrefill(query: string): { firstName: string; lastName: string } {
  const tokens = query.trim().split(/\s+/);
  if (tokens.length < 2) return { firstName: tokens[0] ?? "", lastName: "" };
  return {
    firstName: tokens.slice(0, -1).join(" "),
    lastName: tokens[tokens.length - 1]!,
  };
}

export function AddFlyerModal({
  open,
  onClose,
  onDone,
  prefillName,
  assignFlightCode,
  editing,
}: {
  open: boolean;
  onClose: () => void;
  onDone: (name: string) => void;
  prefillName?: string;
  assignFlightCode?: string;
  /** When set, the modal edits this flyer instead of registering a new one. */
  editing?: Flyer;
}) {
  const { showToast } = useToast();
  const [busy, setBusy] = useState(false);
  const [form, setForm] = useState(EMPTY);
  const [cnWhatsapp, setCnWhatsapp] = useState(false);
  const [bdWhatsapp, setBdWhatsapp] = useState(false);

  useEffect(() => {
    if (!open) return;
    if (editing) {
      setForm({
        firstName: editing.firstName,
        lastName: editing.lastName,
        cnPhone: blank(editing.cnPhone),
        bdPhone: blank(editing.bdPhone),
        university: blank(editing.university),
        batch: blank(editing.batch).replace(/^Batch\s*/i, ""),
        program: blank(editing.program),
        wechat: blank(editing.wechat),
        cnAddress: blank(editing.cnAddress),
        homeAddress: blank(editing.homeAddress),
        emergencyContact: blank(editing.emergencyContact),
      });
      setCnWhatsapp(editing.cnWhatsapp);
      setBdWhatsapp(editing.bdWhatsapp);
    } else {
      setForm({ ...EMPTY, ...(prefillName ? splitPrefill(prefillName) : {}) });
      setCnWhatsapp(false);
      setBdWhatsapp(false);
    }
    // Refreshing the same record must not overwrite the open draft.
    // Reinitialize only when opened again or switched to a different record.
  }, [open, prefillName, editing?.name]);

  const set = (key: keyof typeof form) => (value: string) =>
    setForm((f) => ({ ...f, [key]: value }));

  const submit = async () => {
    if (!form.firstName.trim()) {
      showToast({ title: "First name required", status: "error" });
      return;
    }
    setBusy(true);
    try {
      const payload = {
        firstName: form.firstName.trim(),
        lastName: form.lastName.trim(),
        cnPhone: form.cnPhone || "—",
        cnWhatsapp,
        bdPhone: form.bdPhone || "—",
        bdWhatsapp,
        university: form.university || "—",
        batch: form.batch,
        program: form.program || "—",
        wechat: form.wechat || "—",
        cnAddress: form.cnAddress || "—",
        homeAddress: form.homeAddress || "—",
        emergencyContact: form.emergencyContact || "—",
      };
      if (editing) {
        const r = await api.patch<{ name: string }>(
          `/flyers/${encodeURIComponent(editing.name)}`,
          payload,
        );
        showToast({ title: "Flyer updated", status: "success" });
        onDone(r.name);
      } else {
        const r = await api.post<{ name: string }>("/flyers", {
          ...payload,
          assignFlightCode,
        });
        showToast({
          title: assignFlightCode
            ? "Flyer registered & assigned to flight"
            : "Flyer registered",
          status: "success",
        });
        onDone(r.name);
      }
      onClose();
      setForm(EMPTY);
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
    <Modal open={open} onClose={onClose} className="max-w-3xl">
      <h2 data-dialog-title className="text-xl font-semibold">
        {editing ? "Edit flyer" : "Register flyer"}
      </h2>
      <p className="mt-2 mb-6 text-sm text-muted-foreground">
        {editing
          ? `Update the profile for ${editing.name}.`
          : "Add contact and travel information. First name is required."}
      </p>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          void submit();
        }}
        className="space-y-6"
      >
        {assignFlightCode && !editing && (
          <SectionNotice>
            This flyer will be assigned to flight {assignFlightCode}.
          </SectionNotice>
        )}
        <FormSection title="Personal information">
          <FormGrid>
            <Input
              label="First name"
              required
              placeholder="e.g. Ashikur"
              value={form.firstName}
              onChange={set("firstName")}
            />
            <Input
              label="Last name"
              placeholder="e.g. Rahman"
              value={form.lastName}
              onChange={set("lastName")}
            />
          </FormGrid>
        </FormSection>
        <FormSection title="Contact information">
          <FormGrid>
            <div>
              <Input
                label="China phone"
                type="tel"
                placeholder="+86"
                value={form.cnPhone}
                onChange={set("cnPhone")}
              />
              <label className="mt-3 flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={cnWhatsapp}
                  onChange={(event) => setCnWhatsapp(event.target.checked)}
                />{" "}
                WhatsApp on China phone
              </label>
            </div>
            <div>
              <Input
                label="Bangladesh phone"
                type="tel"
                placeholder="+880"
                value={form.bdPhone}
                onChange={set("bdPhone")}
              />
              <label className="mt-3 flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={bdWhatsapp}
                  onChange={(event) => setBdWhatsapp(event.target.checked)}
                />{" "}
                WhatsApp on Bangladesh phone
              </label>
            </div>
            <Input
              label="WeChat ID"
              placeholder="WeChat username"
              value={form.wechat}
              onChange={set("wechat")}
            />
            <Input
              label="Emergency contact"
              placeholder="Name, relationship and phone"
              value={form.emergencyContact}
              onChange={set("emergencyContact")}
            />
          </FormGrid>
        </FormSection>
        <FormSection title="Education">
          <FormGrid>
            <Input
              label="University"
              placeholder="University name"
              value={form.university}
              onChange={set("university")}
            />
            <Input
              label="Program"
              placeholder="e.g. MBBS"
              value={form.program}
              onChange={set("program")}
            />
            <Input
              label="Batch"
              placeholder="e.g. 2025"
              value={form.batch}
              onChange={set("batch")}
            />
          </FormGrid>
        </FormSection>
        <FormSection title="Addresses">
          <FormGrid>
            <Input
              label="Address in China"
              placeholder="Building, campus and city"
              value={form.cnAddress}
              onChange={set("cnAddress")}
            />
            <Input
              label="Address in Bangladesh"
              placeholder="Street, area and city"
              value={form.homeAddress}
              onChange={set("homeAddress")}
            />
          </FormGrid>
        </FormSection>
        <SectionNotice>
          Upload passport, visa and other files in the flyer’s Documents tab
          after saving. Review each uploaded file there to mark it verified.
        </SectionNotice>
        <FormActions>
          <Button variant="secondary" disabled={busy} onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" disabled={busy}>
            {busy ? "Saving…" : editing ? "Save changes" : "Register flyer"}
          </Button>
        </FormActions>
      </form>
    </Modal>
  );
}
