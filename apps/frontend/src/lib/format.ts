/** Formatting helpers and the design's chip color maps. */

export const fmtBdt = (n: number): string =>
  `BDT ${Number(n || 0).toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

export const fmtKg = (n: number): string => `${Math.round(n * 10) / 10} kg`;

/** '2026-08-31' → '31 Aug 2026'. */
export function fmtDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  return new Date(`${iso.slice(0, 10)}T00:00:00Z`).toLocaleDateString("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: "UTC",
  });
}

/** '2026-08-31' → '31 Aug'. */
export function fmtDayMonth(iso: string | null | undefined): string {
  if (!iso) return "—";
  return new Date(`${iso.slice(0, 10)}T00:00:00Z`).toLocaleDateString("en-GB", {
    day: "numeric",
    month: "short",
    timeZone: "UTC",
  });
}

/** ISO timestamp → '24 Aug 14:05'. */
export function fmtLogAt(iso: string): string {
  const d = new Date(iso);
  return `${d.toLocaleDateString("en-GB", { day: "numeric", month: "short", timeZone: "UTC" })} ${d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit", timeZone: "UTC" })}`;
}

export const deltaLabel = (delta: number | null): string =>
  delta === null ? "" : `Δ${delta > 0 ? "+" : ""}${delta}kg`;

export type ChipColors = { bg: string; fg: string };

const neutral = {
  bg: "var(--color-muted)",
  fg: "var(--color-muted-foreground)",
};
const blue = { bg: "var(--color-primary-soft)", fg: "var(--color-primary)" };
const green = { bg: "var(--color-success-soft)", fg: "var(--color-success)" };
const amber = { bg: "var(--color-warn-soft)", fg: "var(--color-warn)" };
const red = { bg: "var(--color-danger-soft)", fg: "var(--color-danger)" };
export const STATUS_CHIP: ChipColors[] = [
  neutral,
  blue,
  blue,
  blue,
  blue,
  blue,
  amber,
  amber,
  green,
];
export const PAY_CHIP: Record<string, ChipColors> = {
  paid: green,
  unpaid: red,
  cod: amber,
  monthly: blue,
  partial: amber,
};

export const PAY_LABEL: Record<string, string> = {
  paid: "Paid",
  unpaid: "Unpaid",
  cod: "COD",
  monthly: "Monthly",
  partial: "Partial",
};

export const FLIGHT_CHIP: Record<string, ChipColors> = {
  upcoming: blue,
  departed: amber,
  completed: neutral,
};
export const NOTICE_STYLE: Record<
  string,
  { bg: string; bd: string; fg: string }
> = {
  WEIGHT: { ...red, bd: "var(--color-border)" },
  FLIGHT: { ...blue, bd: "var(--color-border)" },
  DUE: { ...amber, bd: "var(--color-border)" },
};

/** Composes the supplier label the current role is allowed to see. */
export const supplierLabel = (code: string, name: string | null): string =>
  name ? `${code} · ${name}` : code;

/** Keep airline numbers separate from the internal booking reference. */
export const displayFlightCode = (code: string | null | undefined): string =>
  code ? code.replace(/-\d{8}-[a-z0-9]+$/i, "").replace(/\+/g, "-") : "—";
