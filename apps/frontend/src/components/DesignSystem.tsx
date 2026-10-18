import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function Panel({
  title,
  description,
  actions,
  children,
  className,
}: {
  title?: string;
  description?: string;
  actions?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={cn("ds-panel", className)}>
      {(title || actions) && (
        <header className="ds-panel-header">
          <div>
            {title && <h2>{title}</h2>}
            {description && <p>{description}</p>}
          </div>
          {actions && <div className="ds-panel-actions">{actions}</div>}
        </header>
      )}
      <div className="ds-panel-body">{children}</div>
    </section>
  );
}
export function FormSection({
  title,
  description,
  children,
}: {
  title: string;
  description?: string;
  children: ReactNode;
}) {
  return (
    <section className="form-section">
      <header>
        <h3>{title}</h3>
        {description && <p>{description}</p>}
      </header>
      {children}
    </section>
  );
}
export function FormGrid({
  children,
  columns = 2,
  className,
}: {
  children: ReactNode;
  columns?: 1 | 2;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "form-grid",
        columns === 1 && "form-grid-single",
        className,
      )}
    >
      {children}
    </div>
  );
}
export function FormActions({ children }: { children: ReactNode }) {
  return <footer className="form-actions">{children}</footer>;
}
export function DetailGrid({
  items,
  columns = 2,
}: {
  items: { label: string; value: ReactNode }[];
  columns?: 2 | 3;
}) {
  return (
    <dl className={cn("detail-grid", columns === 3 && "detail-grid-three")}>
      {items.map((item) => (
        <div key={item.label}>
          <dt>{item.label}</dt>
          <dd>{item.value ?? "—"}</dd>
        </div>
      ))}
    </dl>
  );
}
export function SectionNotice({
  children,
  tone = "neutral",
}: {
  children: ReactNode;
  tone?: "neutral" | "warning" | "success" | "danger";
}) {
  return (
    <div
      className={cn("section-notice", "notice-" + tone)}
      role={tone === "danger" ? "alert" : undefined}
    >
      {children}
    </div>
  );
}
