import { useId, useMemo, useRef, useState } from "react";
import { Input } from "@/components/beui/input";
export interface SearchOption {
  value: string;
  label: string;
  sub?: string;
  keywords: string;
}
export function SearchSelect({
  label,
  placeholder,
  options,
  value,
  onChange,
  className, clearable=false, disabled=false,
}: {
  label?: string;
  placeholder: string;
  options: SearchOption[];
  value: string;
  onChange: (value: string) => void;
  className?: string; clearable?:boolean; disabled?:boolean;
}) {
  const [query, setQuery] = useState(""),
    [open, setOpen] = useState(false),
    [active, setActive] = useState(0);
  const listId = useId(),
    input = useRef<HTMLInputElement>(null);
  const selected = options.find((o) => o.value === value);
  const filtered = useMemo(
    () =>
      options
        .filter(
          (o) =>
            !query.trim() ||
            o.keywords.toLowerCase().includes(query.trim().toLowerCase()),
        )
        .slice(0, 8),
    [options, query],
  );
  const pick = (option: SearchOption) => {
    onChange(option.value);
    setQuery("");
    setOpen(false);
    input.current?.blur();
  };
  return (
    <div className={className}>
      <div className="relative">
        {clearable && value && !disabled && <button type="button" className="float-right mb-1 text-xs text-primary" aria-label={`Clear ${label??"selection"}`} onClick={()=>{onChange("");setQuery("");setOpen(false)}}>Clear assignment</button>}
        <Input
          disabled={disabled}
          ref={input}
          label={label}
          placeholder={selected?.label ?? placeholder}
          value={open ? query : (selected?.label ?? "")}
          role="combobox"
          aria-expanded={open}
          aria-controls={open ? listId : undefined}
          aria-autocomplete="list"
          aria-activedescendant={
            open && filtered[active] ? `${listId}-${active}` : undefined
          }
          onChange={(v) => {
            setQuery(v);
            setActive(0);
            setOpen(true);
          }}
          onFocus={() => {
            setQuery("");
            setActive(0);
            setOpen(true);
          }}
          onBlur={() => setOpen(false)}
          onKeyDown={(e) => {
            if (e.key === "ArrowDown") {
              e.preventDefault();
              setOpen(true);
              setActive((i) => Math.min(i + 1, filtered.length - 1));
            } else if (e.key === "ArrowUp") {
              e.preventDefault();
              setActive((i) => Math.max(0, i - 1));
            } else if (e.key === "Enter" && open && filtered[active]) {
              e.preventDefault();
              pick(filtered[active]);
            } else if (e.key === "Escape" && open) {
              e.preventDefault();
              e.stopPropagation();
              setOpen(false);
            }
          }}
        />
        {open && (
          <div
            id={listId}
            role="listbox"
            aria-label={label ?? "Options"}
            className="absolute left-0 right-0 top-[calc(100%+4px)] z-20 max-h-[240px] overflow-auto rounded-md border border-border bg-card p-1 "
          >
            {filtered.map((option, i) => (
              <div
                id={`${listId}-${i}`}
                key={option.value}
                role="option"
                aria-selected={option.value === value}
                className={`flex cursor-pointer items-center justify-between gap-3 rounded px-3 py-3 text-sm ${i === active ? "bg-primary-soft text-primary" : ""}`}
                onMouseEnter={() => setActive(i)}
                onMouseDown={(e) => e.preventDefault()}
                onClick={() => pick(option)}
              >
                <span className="min-w-0 truncate">{option.label}</span>
                {option.sub && (
                  <span className="shrink-0 text-sm text-muted-foreground">
                    {option.sub}
                  </span>
                )}
              </div>
            ))}
            {!filtered.length && (
              <p className="p-3 text-sm text-muted-foreground">
                No matching options.
              </p>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
