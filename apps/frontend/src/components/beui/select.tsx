import { Check, ChevronDown } from "lucide-react";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useId,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type KeyboardEvent,
  type ButtonHTMLAttributes,
  type ReactNode,
} from "react";
import { cn } from "@/lib/utils";

type Placement = "top" | "bottom";
type SelectContextValue = {
  value?: string;
  open: boolean;
  setOpen: (open: boolean) => void;
  select: (value: string) => void;
  register: (value: string, label: string) => void;
  unregister: (value: string) => void;
  labelFor: (value?: string) => string | undefined;
  disabled: boolean;
  triggerId: string;
  listId: string;
  placement: Placement;
};

const SelectContext = createContext<SelectContextValue | null>(null);

function useSelectContext(component: string) {
  const context = useContext(SelectContext);
  if (!context) throw new Error(`${component} must be used within <Select>`);
  return context;
}

export function Select({
  value,
  defaultValue,
  onValueChange,
  disabled = false,
  className,
  children,
}: {
  value?: string;
  defaultValue?: string;
  onValueChange?: (value: string) => void;
  disabled?: boolean;
  className?: string;
  children: ReactNode;
}) {
  const baseId = useId();
  const rootRef = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false);
  const [internal, setInternal] = useState(defaultValue);
  const [labels, setLabels] = useState<Map<string, string>>(new Map());
  const [placement, setPlacement] = useState<Placement>("bottom");
  const controlled = value !== undefined;
  const current = controlled ? value : internal;

  const select = useCallback(
    (next: string) => {
      if (!controlled) setInternal(next);
      onValueChange?.(next);
      setOpen(false);
    },
    [controlled, onValueChange],
  );

  const register = useCallback((nextValue: string, label: string) => {
    setLabels((currentLabels) => {
      if (currentLabels.get(nextValue) === label) return currentLabels;
      const next = new Map(currentLabels);
      next.set(nextValue, label);
      return next;
    });
  }, []);

  const unregister = useCallback((nextValue: string) => {
    setLabels((currentLabels) => {
      if (!currentLabels.has(nextValue)) return currentLabels;
      const next = new Map(currentLabels);
      next.delete(nextValue);
      return next;
    });
  }, []);

  useEffect(() => {
    if (!open) return;
    const onPointerDown = (event: PointerEvent) => {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    };
    const onKeyDown = (event: globalThis.KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("pointerdown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  useLayoutEffect(() => {
    if (!open || !rootRef.current) return;
    const rect = rootRef.current.getBoundingClientRect();
    setPlacement(
      window.innerHeight - rect.bottom < 260 && rect.top > 260
        ? "top"
        : "bottom",
    );
  }, [open]);

  const context = useMemo<SelectContextValue>(
    () => ({
      value: current,
      open,
      setOpen,
      select,
      register,
      unregister,
      labelFor: (nextValue) =>
        nextValue === undefined ? undefined : labels.get(nextValue),
      disabled,
      triggerId: `${baseId}-trigger`,
      listId: `${baseId}-list`,
      placement,
    }),
    [
      baseId,
      current,
      disabled,
      labels,
      open,
      placement,
      register,
      select,
      unregister,
    ],
  );

  return (
    <SelectContext.Provider value={context}>
      <div
        ref={rootRef}
        className={cn("relative", className)}
        onBlur={(event) => {
          if (!event.currentTarget.contains(event.relatedTarget as Node | null))
            setOpen(false);
        }}
      >
        {children}
      </div>
    </SelectContext.Provider>
  );
}

export function SelectTrigger({
  children,
  className,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement>) {
  const context = useSelectContext("SelectTrigger");
  const handleKeyDown = (event: KeyboardEvent<HTMLButtonElement>) => {
    if (
      event.key === "ArrowDown" ||
      event.key === "ArrowUp" ||
      event.key === "Enter" ||
      event.key === " "
    ) {
      event.preventDefault();
      context.setOpen(true);
    }
  };

  return (
    <button
      {...props}
      type="button"
      id={context.triggerId}
      disabled={context.disabled}
      aria-haspopup="listbox"
      aria-expanded={context.open}
      aria-controls={context.listId}
      onClick={() => context.setOpen(!context.open)}
      onKeyDown={handleKeyDown}
      className={cn("select-trigger form-control", className)}
    >
      {children}
      <span aria-hidden className="text-muted-foreground">
        <ChevronDown className="size-4" />
      </span>
    </button>
  );
}

export function SelectValue({
  placeholder = "Select",
  className,
}: {
  placeholder?: string;
  className?: string;
}) {
  const context = useSelectContext("SelectValue");
  const label = context.labelFor(context.value);
  return (
    <span
      className={cn(
        "min-w-0 truncate",
        label ? "text-foreground" : "text-muted-foreground",
        className,
      )}
    >
      {label ?? placeholder}
    </span>
  );
}

export function SelectContent({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  const context = useSelectContext("SelectContent");
  const top = context.placement === "top";
  const listRef = useRef<HTMLUListElement>(null);

  useEffect(() => {
    if (!context.open) return;
    const frame = window.requestAnimationFrame(() => {
      const selected = listRef.current?.querySelector<HTMLButtonElement>(
        '[data-selected="true"]',
      );
      const first = listRef.current?.querySelector<HTMLButtonElement>(
        "button:not([disabled])",
      );
      (selected ?? first)?.focus();
    });
    return () => window.cancelAnimationFrame(frame);
  }, [context.open]);

  const handleKeyDown = (event: KeyboardEvent<HTMLUListElement>) => {
    const items = Array.from(
      listRef.current?.querySelectorAll<HTMLButtonElement>(
        "button:not([disabled])",
      ) ?? [],
    );
    if (!items.length) return;
    const index = items.indexOf(document.activeElement as HTMLButtonElement);
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      const direction = event.key === "ArrowDown" ? 1 : -1;
      items[(index + direction + items.length) % items.length]?.focus();
    } else if (event.key === "Home" || event.key === "End") {
      event.preventDefault();
      items[event.key === "Home" ? 0 : items.length - 1]?.focus();
    } else if (event.key === "Tab") {
      context.setOpen(false);
      document.getElementById(context.triggerId)?.focus();
    } else if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      context.setOpen(false);
      document.getElementById(context.triggerId)?.focus();
    }
  };

  return (
    <ul
      ref={listRef}
      id={context.listId}
      role="listbox"
      aria-labelledby={context.triggerId}
      aria-hidden={!context.open}
      onKeyDown={handleKeyDown}
      style={{
        pointerEvents: context.open ? "auto" : "none",
        visibility: context.open ? "visible" : "hidden",
      }}
      className={cn(
        "select-options",
        top ? "bottom-[calc(100%+6px)]" : "top-[calc(100%+6px)]",
        className,
      )}
    >
      {children}
    </ul>
  );
}

export function SelectItem({
  value,
  textValue,
  disabled = false,
  children,
  className,
}: {
  value: string;
  textValue?: string;
  disabled?: boolean;
  children: ReactNode;
  className?: string;
}) {
  const context = useSelectContext("SelectItem");
  const { register, unregister } = context;
  const selected = context.value === value;
  const label = textValue ?? (typeof children === "string" ? children : value);

  useLayoutEffect(() => {
    register(value, label);
    return () => unregister(value);
  }, [label, register, unregister, value]);

  return (
    <li>
      <button
        type="button"
        role="option"
        tabIndex={-1}
        aria-selected={selected}
        data-selected={selected}
        disabled={disabled}
        onClick={() => {
          context.select(value);
          document.getElementById(context.triggerId)?.focus();
        }}
        className={cn(
          "select-option",
          selected
            ? "bg-muted text-foreground"
            : "bg-transparent text-muted-foreground hover:bg-muted hover:text-foreground focus-visible:bg-muted",
          "disabled:pointer-events-none disabled:opacity-50",
          className,
        )}
      >
        <span className="min-w-0 truncate">{children}</span>
        {selected ? <Check className="size-3.5 shrink-0 text-primary" /> : null}
      </button>
    </li>
  );
}
