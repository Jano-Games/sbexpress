import { AlertCircle, Bell, Check, Info, LoaderCircle, X } from "lucide-react";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";

export type ToastStatus = "neutral" | "info" | "loading" | "success" | "error";
export type ToastInput = {
  title: string;
  description?: string;
  status?: ToastStatus;
  duration?: number;
};
type ToastItem = ToastInput & { id: string };
type ToastContextValue = {
  showToast: (toast: ToastInput) => string;
  dismissToast: (id: string) => void;
};

const ToastContext = createContext<ToastContextValue | null>(null);
const icons = {
  neutral: Bell,
  info: Info,
  loading: LoaderCircle,
  success: Check,
  error: AlertCircle,
};
let toastId = 0;

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const timers = useRef(new Map<string, number>());

  const dismissToast = useCallback((id: string) => {
    const timer = timers.current.get(id);
    if (timer) window.clearTimeout(timer);
    timers.current.delete(id);
    setToasts((current) => current.filter((toast) => toast.id !== id));
  }, []);

  const showToast = useCallback(
    (input: ToastInput) => {
      const id = `toast-${Date.now()}-${toastId++}`;
      setToasts((current) => [
        ...current.slice(-3),
        { status: "neutral", duration: 3200, ...input, id },
      ]);
      if (input.status !== "loading" && input.duration !== 0) {
        const timer = window.setTimeout(
          () => dismissToast(id),
          input.duration ?? 3200,
        );
        timers.current.set(id, timer);
      }
      return id;
    },
    [dismissToast],
  );

  useEffect(() => {
    const activeTimers = timers.current;
    return () => {
      activeTimers.forEach((timer) => window.clearTimeout(timer));
      activeTimers.clear();
    };
  }, []);

  const value = useMemo(
    () => ({ showToast, dismissToast }),
    [dismissToast, showToast],
  );
  return (
    <ToastContext.Provider value={value}>
      {children}
      <ToastStack toasts={toasts} onDismiss={dismissToast} />
    </ToastContext.Provider>
  );
}

export function useToast() {
  const context = useContext(ToastContext);
  if (!context) throw new Error("useToast must be used within <ToastProvider>");
  return context;
}

function ToastStack({
  toasts,
  onDismiss,
}: {
  toasts: ToastItem[];
  onDismiss: (id: string) => void;
}) {
  return (
    <div className="toast-stack" aria-live="polite" aria-relevant="additions">
      {toasts.map((toast) => {
        const status = toast.status ?? "neutral",
          Icon = icons[status];
        return (
          <div
            key={toast.id}
            className={"toast-item toast-" + status}
            role={status === "error" ? "alert" : "status"}
          >
            <Icon size={20} />
            <div>
              <strong>{toast.title}</strong>
              {toast.description && <p>{toast.description}</p>}
            </div>
            <button
              type="button"
              onClick={() => onDismiss(toast.id)}
              aria-label="Dismiss notification"
            >
              <X size={18} />
            </button>
          </div>
        );
      })}
    </div>
  );
}
