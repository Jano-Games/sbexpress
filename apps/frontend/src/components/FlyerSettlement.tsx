import { useState } from "react";
import { api } from "@/api/client";
import { CurrencyFields, useMoneyEntry } from "@/components/MoneyInput";
import { Input } from "@/components/beui/input";
import { Button } from "@/components/beui/button";
import {
  DetailGrid,
  FormActions,
  Panel,
  SectionNotice,
} from "@/components/DesignSystem";
import { EmptyState } from "@/components/Workspace";
import { fmtBdt } from "@/lib/format";

type SettlementRow = { name: string; contribution: number; paidAmount: number };

export function FlyerSettlement({
  code,
  rows,
  legacy,
  onSaved,
}: {
  code: string;
  rows: SettlementRow[];
  legacy: number;
  onSaved: () => void;
}) {
  const entry = useMoneyEntry();
  const [draft, setDraft] = useState(
    rows.map((row) => ({
      ...row,
      contribution: String(row.contribution),
      legacyPaid: "0",
    })),
  );
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const totalContribution = draft.reduce(
    (sum, row) => sum + (Number(row.contribution) || 0),
    0,
  );
  const received = rows.reduce((sum, row) => sum + row.paidAmount, 0);

  async function save() {
    if (busy) return;
    if (
      !entry.valid ||
      draft.some(
        (row) =>
          !Number.isFinite(Number(row.contribution)) ||
          Number(row.contribution) < 0 ||
          !Number.isFinite(Number(row.legacyPaid)) ||
          Number(row.legacyPaid) < 0,
      )
    ) {
      setError("Enter valid, non-negative amounts and an exchange rate.");
      return;
    }
    setBusy(true);
    setError("");
    try {
      await api.post(`/flights/${encodeURIComponent(code)}/settlements`, {
        ...entry.meta,
        allocations: draft.map((row) => ({
          name: row.name,
          contribution: Number(row.contribution),
          legacyPaid: Number(row.legacyPaid),
        })),
      });
      onSaved();
    } catch (e) {
      setError(
        e instanceof Error ? e.message : "Settlement could not be saved.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <Panel
      title="Flyer contribution allocation"
      description="Set each flyer’s share of the ticket. Payments already received are shown in BDT."
    >
      {!rows.length ? (
        <EmptyState
          title="No flyers assigned"
          description="Assign a flyer to this flight before allocating contributions."
        />
      ) : (
        <form
          onSubmit={(event) => {
            event.preventDefault();
            void save();
          }}
          className="space-y-5"
        >
          {legacy > 0 && (
            <SectionNotice tone="warning">
              {fmtBdt(legacy)} of earlier receipts have no flyer assigned. Enter
              each flyer’s share in Previously received to allocate those
              receipts.
            </SectionNotice>
          )}
          <CurrencyFields
            disabled={busy}
            entry={{
              ...entry,
              setCurrency: (currency) => {
                const nextRate =
                  currency === "BDT" ? 1 : Number(entry.rateText);
                if (!(nextRate > 0)) return;
                setDraft((current) =>
                  current.map((row) => ({
                    ...row,
                    contribution: String(
                      Math.round(
                        (entry.toBdt(Number(row.contribution)) / nextRate) *
                          100,
                      ) / 100,
                    ),
                    legacyPaid: String(
                      Math.round(
                        (entry.toBdt(Number(row.legacyPaid)) / nextRate) * 100,
                      ) / 100,
                    ),
                  })),
                );
                entry.setCurrency(currency);
              },
            }}
          />
          <div className="divide-y divide-border">
            {draft.map((row, index) => (
              <div
                key={row.name}
                className="grid items-end gap-4 py-4 sm:grid-cols-2 lg:grid-cols-3"
              >
                <div>
                  <p className="text-sm font-medium">{row.name}</p>
                  <p className="mt-1 text-xs text-muted-foreground">
                    Received {fmtBdt(row.paidAmount)}
                  </p>
                </div>
                <Input
                  label={`Contribution for ${row.name} (${entry.currency})`}
                  inputMode="decimal"
                  value={row.contribution}
                  disabled={busy}
                  onChange={(value) =>
                    setDraft((current) =>
                      current.map((item, i) =>
                        i === index ? { ...item, contribution: value } : item,
                      ),
                    )
                  }
                />
                {legacy > 0 && (
                  <Input
                    label={`Previously received for ${row.name} (${entry.currency})`}
                    inputMode="decimal"
                    value={row.legacyPaid}
                    disabled={busy}
                    onChange={(value) =>
                      setDraft((current) =>
                        current.map((item, i) =>
                          i === index ? { ...item, legacyPaid: value } : item,
                        ),
                      )
                    }
                  />
                )}
              </div>
            ))}
          </div>
          <DetailGrid
            items={[
              {
                label: "Allocated contribution · BDT",
                value: fmtBdt(entry.toBdt(totalContribution)),
              },
              { label: "Received and assigned · BDT", value: fmtBdt(received) },
            ]}
          />
          {error && (
            <div role="alert">
              <SectionNotice tone="danger">{error}</SectionNotice>
            </div>
          )}
          <FormActions>
            <Button type="submit" disabled={busy || !entry.valid}>
              {busy ? "Saving…" : "Save contribution allocation"}
            </Button>
          </FormActions>
        </form>
      )}
    </Panel>
  );
}
