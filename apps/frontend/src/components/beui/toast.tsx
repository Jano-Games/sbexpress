// BeUI-style animated toast stack with a small app-level provider.
import { AlertCircle, Bell, Check, Info, LoaderCircle, X } from 'lucide-react'
import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { EASE_OUT, SPRING_PANEL } from '@/lib/ease'

export type ToastStatus = 'neutral' | 'info' | 'loading' | 'success' | 'error'
export type ToastInput = { title: string; description?: string; status?: ToastStatus; duration?: number }
type ToastItem = ToastInput & { id: string }
type ToastContextValue = { showToast: (toast: ToastInput) => string; dismissToast: (id: string) => void }

const ToastContext = createContext<ToastContextValue | null>(null)
const icons = { neutral: Bell, info: Info, loading: LoaderCircle, success: Check, error: AlertCircle }
let toastId = 0

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([])
  const timers = useRef(new Map<string, number>())

  const dismissToast = useCallback((id: string) => {
    const timer = timers.current.get(id)
    if (timer) window.clearTimeout(timer)
    timers.current.delete(id)
    setToasts((current) => current.filter((toast) => toast.id !== id))
  }, [])

  const showToast = useCallback(
    (input: ToastInput) => {
      const id = `toast-${Date.now()}-${toastId++}`
      setToasts((current) => [...current.slice(-3), { status: 'neutral', duration: 3200, ...input, id }])
      if (input.status !== 'loading' && input.duration !== 0) {
        const timer = window.setTimeout(() => dismissToast(id), input.duration ?? 3200)
        timers.current.set(id, timer)
      }
      return id
    },
    [dismissToast],
  )

  useEffect(() => {
    const activeTimers = timers.current
    return () => {
      activeTimers.forEach((timer) => window.clearTimeout(timer))
      activeTimers.clear()
    }
  }, [])

  const value = useMemo(() => ({ showToast, dismissToast }), [dismissToast, showToast])
  return (
    <ToastContext.Provider value={value}>
      {children}
      <ToastStack toasts={toasts} onDismiss={dismissToast} />
    </ToastContext.Provider>
  )
}

export function useToast() {
  const context = useContext(ToastContext)
  if (!context) throw new Error('useToast must be used within <ToastProvider>')
  return context
}

function ToastStack({ toasts, onDismiss }: { toasts: ToastItem[]; onDismiss: (id: string) => void }) {
  const reduce = useReducedMotion()
  return (
    <div
      aria-live="polite"
      aria-relevant="additions"
      className="pointer-events-none fixed bottom-5 right-5 z-[100] flex w-[min(360px,calc(100vw-32px))] flex-col items-end gap-2"
    >
      <AnimatePresence initial={false}>
        {toasts.map((toast) => {
          const status = toast.status ?? 'neutral'
          const Icon = icons[status]
          return (
            <motion.div
              layout
              key={toast.id}
              role={status === 'error' ? 'alert' : 'status'}
              drag={reduce ? false : 'x'}
              dragConstraints={{ left: 0, right: 0 }}
              dragElastic={0.18}
              onDragEnd={(_, info) => {
                if (Math.abs(info.offset.x) > 72) onDismiss(toast.id)
              }}
              initial={reduce ? { opacity: 0 } : { opacity: 0, y: 12, scale: 0.98 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={reduce ? { opacity: 0 } : { opacity: 0, x: 28, scale: 0.98 }}
              transition={reduce ? { duration: 0.01 } : SPRING_PANEL}
              className="pointer-events-auto relative flex w-full items-start gap-3 overflow-hidden rounded-xl border border-border bg-ink p-3.5 shadow-2xl"
            >
              <span
                className={`mt-0.5 grid size-8 shrink-0 place-items-center rounded-full ${
                  status === 'success'
                    ? 'bg-success/25 text-[#7CE79A]'
                    : status === 'error'
                      ? 'bg-danger/25 text-[#FF8F8F]'
                      : 'bg-primary/25 text-[#7BD8CF]'
                }`}
              >
                <motion.span
                  animate={status === 'loading' && !reduce ? { rotate: 360 } : undefined}
                  transition={status === 'loading' && !reduce ? { duration: 1, repeat: Infinity, ease: 'linear' } : undefined}
                >
                  <Icon className="size-4" />
                </motion.span>
              </span>
              <div className="min-w-0 flex-1">
                <div className="text-[13px] font-semibold text-white">{toast.title}</div>
                {toast.description ? <div className="mt-0.5 text-xs leading-5 text-white/60">{toast.description}</div> : null}
              </div>
              <button
                type="button"
                onClick={() => onDismiss(toast.id)}
                aria-label="Dismiss notification"
                className="grid size-7 shrink-0 place-items-center rounded-md border-0 bg-transparent text-white/50 transition-colors hover:bg-white/10 hover:text-white cursor-pointer"
              >
                <X className="size-3.5" />
              </button>
              {toast.duration !== 0 && status !== 'loading' ? (
                <motion.span
                  aria-hidden
                  className="absolute bottom-0 left-0 h-px bg-primary"
                  initial={{ width: '100%' }}
                  animate={{ width: 0 }}
                  transition={{ duration: (toast.duration ?? 3200) / 1000, ease: EASE_OUT }}
                />
              ) : null}
            </motion.div>
          )
        })}
      </AnimatePresence>
    </div>
  )
}
