import type { CSSProperties, ReactNode } from "react";
import { QRCodeSVG } from "qrcode.react";
import {
  Check,
  Package,
  Warehouse,
  Plane,
  Truck,
  PackageCheck,
} from "lucide-react";
import { cn } from "@/lib/utils";
import {
  displayFlightCode,
  fmtBdt,
  STATUS_CHIP,
  type ChipColors,
} from "@/lib/format";

export function Chip({
  colors,
  children,
  className,
}: {
  colors: ChipColors;
  children: ReactNode;
  className?: string;
}) {
  return (
    <span
      className={cn("status-badge", className)}
      style={{ background: colors.bg, color: colors.fg }}
    >
      {children}
    </span>
  );
}

export function StatusChip({
  index,
  label,
  className,
}: {
  index: number;
  label: string;
  className?: string;
}) {
  return (
    <Chip
      colors={STATUS_CHIP[Math.max(0, Math.min(8, index))]!}
      className={className}
    >
      {label}
    </Chip>
  );
}

export function Card({
  children,
  className,
  style,
  onClick,
}: {
  children: ReactNode;
  className?: string;
  style?: CSSProperties;
  onClick?: () => void;
}) {
  return (
    <div
      className={cn("app-card", className)}
      style={style}
      onClick={onClick}
      role={onClick ? "button" : undefined}
      tabIndex={onClick ? 0 : undefined}
      onKeyDown={(e) => {
        if (
          onClick &&
          e.target === e.currentTarget &&
          (e.key === "Enter" || e.key === " ")
        ) {
          e.preventDefault();
          onClick();
        }
      }}
    >
      {children}
    </div>
  );
}

/** A shipment's bill with the invoice discount called out beneath it. */
export function BillFigure({
  bill,
  discount,
  className,
}: {
  bill: number;
  discount: number;
  className?: string;
}) {
  return (
    <div className={cn("font-bold leading-tight", className)}>
      <div>{fmtBdt(bill)}</div>
      {discount > 0 ? (
        <div className="text-xs font-medium text-danger">
          −{fmtBdt(discount)} disc
        </div>
      ) : null}
    </div>
  );
}

/** Label-on-top wrapper for controls that don't carry their own label prop. */
export function Field({
  label,
  children,
  className,
}: {
  label: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <div
      role="group"
      aria-label={label}
      className={cn("flex min-w-0 flex-col gap-1.5", className)}
    >
      <div className="text-sm font-medium text-muted-foreground">{label}</div>
      {children}
    </div>
  );
}

/** Itinerary codes ("CZ3444+CZ391") render one segment per line, no "+". */
export function FlightCode({
  code,
  className,
}: {
  code: string | null | undefined;
  className?: string;
}) {
  return (
    <span className={cn("leading-tight break-words", className)}>
      {displayFlightCode(code)}
    </span>
  );
}

export function SbMark({ size = 32 }: { size?: number }) {
  return (
    <div
      className="grid shrink-0 place-items-center rounded-lg bg-primary font-semibold text-white"
      style={{ width: size, height: size, fontSize: size * 0.4 }}
    >
      SB
    </div>
  );
}

export function ProgressBar({
  pct,
  danger,
  className,
  height = 6,
}: {
  pct: number;
  danger?: boolean;
  className?: string;
  height?: number;
}) {
  const clamped = Math.max(0, Math.min(100, pct));
  return (
    <div className={cn("bg-muted", className)} style={{ height }}>
      <div
        className="bg-primary"
        style={{
          width: `${clamped}%`,
          height,
          background: danger ? "var(--color-danger)" : "var(--color-primary)",
        }}
      />
    </div>
  );
}

/** Scannable payment or tracking QR code. */
export function QrBlock({
  value,
  size = 104,
}: {
  value: string;
  size?: number;
}) {
  return (
    <div
      className="grid shrink-0 place-items-center rounded-md border border-border bg-card p-2"
      style={{ width: size, height: size }}
    >
      <QRCodeSVG
        value={value}
        size={size - 20}
        fgColor="#1A1C1E"
        bgColor="#ffffff"
      />
    </div>
  );
}

/** Five milestones summarize the nine operational statuses without hiding the current step. */
export function Stepper({
  steps,
  current,
}: {
  steps: string[];
  current: number;
}) {
  const stages = [
    { label: "Booked", from: 0, icon: Package },
    { label: "China hub", from: 1, icon: Warehouse },
    { label: "In transit", from: 3, icon: Plane },
    { label: "Dhaka hub", from: 5, icon: Truck },
    { label: "Delivered", from: 8, icon: PackageCheck },
  ];
  const active = stages.reduce(
    (index, stage, i) => (current >= stage.from ? i : index),
    0,
  );
  const delivered = current >= 8;
  return (
    <ol
      className="workflow-progress"
      aria-label={`Shipment progress: ${steps[current] ?? steps[0]}`}
    >
      {stages.map((stage, i) => {
        const complete = i < active || delivered;
        const state = complete ? "done" : i === active ? "current" : "upcoming";
        const Icon = complete ? Check : stage.icon;
        return (
          <li
            key={stage.label}
            className={`workflow-step ${state}`}
            aria-current={i === active ? "step" : undefined}
          >
            <span className="workflow-marker" aria-hidden="true">
              <Icon size={20} strokeWidth={1.8} />
            </span>
            <div className="workflow-copy">
              <strong>{stage.label}</strong>
              <span>
                {complete
                  ? "Completed"
                  : i === active
                    ? "Current stage"
                    : "Upcoming"}
              </span>
            </div>
          </li>
        );
      })}
    </ol>
  );
}

export const CONDENSED_STEPS: { minIndex: number; label: string }[] = [
  { minIndex: 0, label: "Booked" },
  { minIndex: 1, label: "CN Hub" },
  { minIndex: 3, label: "In Transit" },
  { minIndex: 5, label: "BD Hub" },
  { minIndex: 8, label: "Delivered" },
];

export const PIPELINE_LABELS = [
  "Pending",
  "Received at CN Hub",
  "Ready for Shipment",
  "In Transit",
  "Customs Cleared",
  "Received at BD Hub",
  "Ready for Last Mile",
  "Out for Delivery",
  "Delivered",
];

export function LoadingBlock({ label = "Loading…" }: { label?: string }) {
  return (
    <div role="status" className="loading-block">
      {label}
    </div>
  );
}

export function ErrorBlock({ message }: { message: string }) {
  return <div className="section-notice notice-danger">{message}</div>;
}
