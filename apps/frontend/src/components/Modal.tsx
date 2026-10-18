import { useEffect, useId, useRef, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { cn } from "@/lib/utils";

export function Modal({
  open,
  onClose,
  children,
  className,
}: {
  open: boolean;
  onClose: () => void;
  children: ReactNode;
  className?: string;
}) {
  const titleId = useId();
  const panel = useRef<HTMLDivElement>(null);
  const close = useRef(onClose);
  close.current = onClose;
  useEffect(() => {
    if (!open) return;
    const previous = document.activeElement as HTMLElement | null;
    const overflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const timer = window.setTimeout(() => {
      const heading = panel.current?.querySelector(
        "h1,h2,h3,[data-dialog-title]",
      );
      if (heading?.textContent) {
        if (!heading.id) heading.id = titleId;
        panel.current?.setAttribute("aria-labelledby", heading.id);
      }
      panel.current?.focus();
    }, 0);
    const onKey = (e: KeyboardEvent) => {
      if (
        !panel.current ||
        document.querySelectorAll("[data-modal-panel]")[
          document.querySelectorAll("[data-modal-panel]").length - 1
        ] !== panel.current
      )
        return;
      if (
        e.key === "Escape" &&
        !panel.current.querySelector('[role="listbox"][aria-hidden="false"]')
      ) {
        e.preventDefault();
        close.current();
      }
      if (e.key === "Tab") {
        const nodes = Array.from(
          panel.current.querySelectorAll<HTMLElement>(
            'button:not(:disabled),a[href],input:not(:disabled),select:not(:disabled),textarea:not(:disabled),[tabindex="0"]',
          ),
        ).filter(
          (el) =>
            el.getClientRects().length &&
            getComputedStyle(el).visibility !== "hidden",
        );
        const first = nodes[0],
          last = nodes[nodes.length - 1];
        if (!first) {
          e.preventDefault();
          return;
        }
        if (
          e.shiftKey &&
          (document.activeElement === first ||
            document.activeElement === panel.current)
        ) {
          e.preventDefault();
          last?.focus();
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault();
          first.focus();
        }
      }
    };
    document.addEventListener("keydown", onKey);
    return () => {
      window.clearTimeout(timer);
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = overflow;
      previous?.focus();
    };
  }, [open, titleId]);

  if (!open) return null;
  return createPortal(
    <div className="modal-backdrop" onClick={onClose}>
      <div
        ref={panel}
        role="dialog"
        aria-modal="true"
        aria-label="Form dialog"
        data-modal-panel
        tabIndex={-1}
        className={cn("modal-panel", className)}
        onClick={(event) => event.stopPropagation()}
      >
        <button
          type="button"
          aria-label="Close dialog"
          className="modal-close"
          onClick={onClose}
        >
          ×
        </button>
        {children}
      </div>
    </div>,
    document.body,
  );
}
