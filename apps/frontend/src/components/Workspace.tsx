import { useEffect, useState, type ReactNode } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { Search, ChevronLeft, ChevronRight, Inbox } from "lucide-react";
import { Button } from "@/components/beui/button";
export function PageHeader({
  title,
  description,
  actions,
}: {
  title: string;
  description: string;
  actions?: ReactNode;
}) {
  return (
    <header className="page-header">
      <div>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>
      {actions && <div className="page-actions">{actions}</div>}
    </header>
  );
}
export function PageTabs({
  value,
  onChange,
  items,
}: {
  value: string;
  onChange: (value: string) => void;
  items: { value: string; label: string }[];
}) {
  return (
    <nav aria-label="Page sections" className="page-tabs">
      {items.map((t) => (
        <button
          key={t.value}
          type="button"
          onClick={() => onChange(t.value)}
          aria-current={value === t.value ? "page" : undefined}
          className={value === t.value ? "active" : ""}
        >
          {t.label}
        </button>
      ))}
    </nav>
  );
}
type SummaryItem = {
  label: string;
  value: ReactNode;
  description?: string;
  icon?: ReactNode;
  tone?: "neutral" | "primary" | "amber" | "success";
};
export function SummaryStrip({ items }: { items: SummaryItem[] }) {
  return (
    <dl className={`summary-strip summary-${items.length}`}>
      {items.map((item) => (
        <div key={item.label}>
          <dt>
            {item.label}
            {item.icon && <span aria-hidden="true">{item.icon}</span>}
          </dt>
          <dd>{item.value}</dd>
          {item.description && <p>{item.description}</p>}
        </div>
      ))}
    </dl>
  );
}
export function EmptyState({
  title,
  description,
  action,
}: {
  title: string;
  description: string;
  action?: ReactNode;
}) {
  return (
    <div className="empty-state">
      <Inbox size={27} strokeWidth={1.4} aria-hidden="true" />
      <h3>{title}</h3>
      <p>{description}</p>
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}
type Column<T> = {
  label: string;
  render: (row: T) => ReactNode;
  mobile?: boolean;
  align?: "left" | "right";
};
export function RecordList<T>({
  rows,
  columns,
  recordKey,
  href,
  searchText,
  placeholder = "Search records…",
  emptyTitle = "No records yet",
  emptyDescription = "New records will appear here.",
  filters,
  views,
}: {
  rows: T[];
  columns: Column<T>[];
  recordKey: (row: T) => string;
  href: (row: T) => string;
  searchText: (row: T) => string;
  placeholder?: string;
  emptyTitle?: string;
  emptyDescription?: string;
  filters?: ReactNode;
  views?: ReactNode;
}) {
  const [query, setQuery] = useState(""),
    [page, setPage] = useState(1);
  const filtered = rows.filter((r) =>
    searchText(r).toLowerCase().includes(query.toLowerCase().trim()),
  );
  useEffect(() => setPage(1), [query, rows]);
  const pages = Math.max(1, Math.ceil(filtered.length / 20)),
    current = Math.min(page, pages),
    visible = filtered.slice((current - 1) * 20, current * 20);
  return (
    <section className="record-list">
      {views && <div className="record-views">{views}</div>}
      <div className="record-toolbar">
        <label className="record-search">
          <span className="sr-only">Search records</span>
          <Search size={16} />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={placeholder}
          />
        </label>
        {filters}
        {query && (
          <Button variant="ghost" size="sm" onClick={() => setQuery("")}>
            Clear search
          </Button>
        )}
      </div>
      {!filtered.length ? (
        <EmptyState
          title={query ? "No matching records" : emptyTitle}
          description={
            query
              ? "Try a different name, reference or contact detail."
              : emptyDescription
          }
        />
      ) : (
        <>
          <div className="record-table">
            <table>
              <thead>
                <tr>
                  {columns.map((c) => (
                    <th
                      key={c.label}
                      className={c.align === "right" ? "text-right" : ""}
                    >
                      {c.label}
                    </th>
                  ))}
                  <th>
                    <span className="sr-only">Open record</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {visible.map((row) => (
                  <tr key={recordKey(row)}>
                    {columns.map((c, i) => (
                      <td
                        key={c.label}
                        className={c.align === "right" ? "text-right" : ""}
                      >
                        {i === 0 ? (
                          <Link className="record-link" to={href(row)}>
                            {c.render(row)}
                          </Link>
                        ) : (
                          c.render(row)
                        )}
                      </td>
                    ))}
                    <td>
                      <Link
                        aria-label={`Open ${recordKey(row)}`}
                        to={href(row)}
                        className="record-open"
                      >
                        <ChevronRight size={16} />
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="record-cards">
            {visible.map((row) => (
              <article key={recordKey(row)}>
                <Link to={href(row)} className="record-card-title">
                  {columns[0]?.render(row)}
                  <ChevronRight size={16} />
                </Link>
                <dl>
                  {columns
                    .slice(1)
                    .filter((c) => c.mobile !== false)
                    .map((c) => (
                      <div key={c.label}>
                        <dt>{c.label}</dt>
                        <dd>{c.render(row)}</dd>
                      </div>
                    ))}
                </dl>
              </article>
            ))}
          </div>
        </>
      )}
      <footer className="record-footer">
        <span>
          {filtered.length
            ? `${(current - 1) * 20 + 1}–${Math.min(current * 20, filtered.length)} of ${filtered.length} records`
            : "0 records"}
        </span>
        <div>
          <button
            aria-label="Previous records page"
            disabled={current <= 1}
            onClick={() => setPage((p) => p - 1)}
          >
            <ChevronLeft size={16} />
          </button>
          <span>
            Page {current} of {pages}
          </span>
          <button
            aria-label="Next records page"
            disabled={current >= pages}
            onClick={() => setPage((p) => p + 1)}
          >
            <ChevronRight size={16} />
          </button>
        </div>
      </footer>
    </section>
  );
}

export function usePageSection(
  defaultValue: string,
  allowed: string[],
  key = "section",
) {
  const [params, setParams] = useSearchParams();
  const raw = params.get(key) ?? defaultValue,
    value = allowed.includes(raw) ? raw : defaultValue;
  const setValue = (next: string) =>
    setParams((previous) => {
      const updated = new URLSearchParams(previous);
      if (next === defaultValue) updated.delete(key);
      else updated.set(key, next);
      return updated;
    });
  return [value, setValue] as const;
}
