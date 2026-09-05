import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { useEffect, useRef, type ReactNode } from 'react'
import { SPRING_PANEL } from '@/lib/ease'
import { cn } from '@/lib/utils'

export function Modal({
  open,
  onClose,
  children,
  className,
}: {
  open: boolean
  onClose: () => void
  children: ReactNode
  className?: string
}) {
  const reduce = useReducedMotion()

  const panel = useRef<HTMLDivElement>(null)
  const close = useRef(onClose)
  close.current = onClose
  useEffect(() => {
    if (!open) return
    const previous = document.activeElement as HTMLElement | null
    const overflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    const timer = window.setTimeout(() => {
      const heading = panel.current?.querySelector('h1,h2,h3,[data-dialog-title]')
      if (heading?.textContent) panel.current?.setAttribute('aria-label', heading.textContent)
      panel.current?.focus()
    }, 0)
    const onKey = (e: KeyboardEvent) => {
      if (!panel.current || document.querySelectorAll('[data-modal-panel]')[document.querySelectorAll('[data-modal-panel]').length - 1] !== panel.current) return
      if (e.key === 'Escape' && !panel.current.querySelector('[role="listbox"][aria-hidden="false"]')) { e.preventDefault(); close.current() }
      if (e.key === 'Tab') {
        const nodes = Array.from(panel.current.querySelectorAll<HTMLElement>('button:not(:disabled),a[href],input:not(:disabled),select:not(:disabled),textarea:not(:disabled),[tabindex="0"]')).filter(el => el.getClientRects().length && getComputedStyle(el).visibility !== 'hidden')
        const first = nodes[0], last = nodes[nodes.length - 1]
        if (!first) { e.preventDefault(); return }
        if (e.shiftKey && (document.activeElement === first || document.activeElement === panel.current)) {e.preventDefault();last?.focus()}
        else if (!e.shiftKey && document.activeElement === last) {e.preventDefault();first.focus()}
      }
    }
    document.addEventListener('keydown', onKey)
    return () => { window.clearTimeout(timer); document.removeEventListener('keydown', onKey); document.body.style.overflow = overflow; previous?.focus() }
  }, [open])

  return (
    <AnimatePresence>
      {open ? (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.18 }}
          className="fixed inset-0 z-50 flex items-center justify-center bg-ink/45 p-3 sm:p-5"
          onClick={onClose}
        >
          <motion.div
            ref={panel}
            role="dialog"
            aria-modal="true"
            aria-label="Form dialog"
            data-modal-panel
            tabIndex={-1}
            initial={reduce ? { opacity: 0 } : { opacity: 0, y: 16, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={reduce ? { opacity: 0 } : { opacity: 0, y: 10, scale: 0.98 }}
            transition={SPRING_PANEL}
            className={cn('max-h-[86vh] w-full max-w-[640px] overflow-auto rounded-2xl bg-card p-4 sm:p-6 shadow-[0_20px_60px_rgba(0,0,0,.25)]', className)}
            onClick={(e) => e.stopPropagation()}
          >
            <button type="button" aria-label="Close dialog" className="float-right ml-3 mb-2 grid size-8 place-items-center rounded-lg border border-border text-lg text-muted-foreground hover:bg-muted" onClick={onClose}>×</button>
            {children}
          </motion.div>
        </motion.div>
      ) : null}
    </AnimatePresence>
  )
}
