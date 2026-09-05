// beui.dev/components/motion/button
import {
  AnimatePresence,
  motion,
  useReducedMotion,
  type HTMLMotionProps,
} from 'motion/react'
import { forwardRef, useCallback, useRef, useState, type PointerEvent, type ReactNode } from 'react'
import { EASE_OUT, SPRING_PRESS } from '@/lib/ease'
import { cn } from '@/lib/utils'

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'outline' | 'dark' | 'success' | 'danger' | 'danger-outline'
export type ButtonSize = 'sm' | 'md' | 'lg' | 'icon'

export interface ButtonProps extends Omit<HTMLMotionProps<'button'>, 'children'> {
  variant?: ButtonVariant
  size?: ButtonSize
  pressScale?: number
  /** Spawn a Material-style ripple from the press point. Off by default. */
  ripple?: boolean
  children?: ReactNode
}

type Ripple = { id: number; x: number; y: number; size: number }

const VARIANT_CLASS: Record<ButtonVariant, string> = {
  primary: 'border-0 bg-primary text-primary-foreground font-bold hover:bg-primary/90',
  secondary: 'border border-border bg-card text-foreground font-semibold hover:bg-muted',
  ghost: 'border-0 bg-transparent text-muted-foreground hover:text-foreground hover:bg-primary/5',
  outline: 'border border-border bg-transparent text-foreground font-semibold hover:bg-primary/5',
  dark: 'border-0 bg-ink text-white font-semibold hover:bg-ink/90',
  success: 'border-0 bg-success text-white font-bold hover:bg-success/90',
  danger: 'border-0 bg-danger text-white font-bold hover:bg-danger/90',
  'danger-outline': 'border border-[#F1C4C4] bg-card text-danger font-bold hover:bg-danger-soft',
}

const SIZE_CLASS: Record<ButtonSize, string> = {
  sm: 'h-8 px-3.5 text-xs gap-1.5 rounded-lg',
  md: 'h-10 px-4.5 text-[13px] gap-2 rounded-[10px]',
  lg: 'h-12 px-6 text-sm gap-2 rounded-[10px]',
  icon: 'h-8 w-8 rounded-lg',
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'primary', size = 'md', pressScale = 0.97, ripple = false, className, children, onPointerDown, ...rest },
  ref,
) {
  const reduce = useReducedMotion()
  const [ripples, setRipples] = useState<Ripple[]>([])
  const nextId = useRef(0)

  const handlePointerDown = useCallback(
    (event: PointerEvent<HTMLButtonElement>) => {
      if (ripple && !reduce) {
        const rect = event.currentTarget.getBoundingClientRect()
        const s = Math.max(rect.width, rect.height) * 2
        const id = nextId.current++
        setRipples((prev) => [...prev, { id, x: event.clientX - rect.left, y: event.clientY - rect.top, size: s }])
      }
      onPointerDown?.(event)
    },
    [ripple, reduce, onPointerDown],
  )

  return (
    <motion.button
      ref={ref}
      type="button"
      whileTap={reduce || pressScale === 1 ? undefined : { scale: pressScale }}
      transition={SPRING_PRESS}
      onPointerDown={handlePointerDown}
      className={cn(
        'inline-flex appearance-none items-center justify-center select-none cursor-pointer',
        'transition-colors disabled:pointer-events-none disabled:opacity-50',
        ripple && 'relative overflow-hidden',
        VARIANT_CLASS[variant],
        SIZE_CLASS[size],
        className,
      )}
      {...rest}
    >
      {ripple && !reduce ? (
        <span className="pointer-events-none absolute inset-0 overflow-hidden rounded-[inherit]">
          <AnimatePresence>
            {ripples.map((r) => (
              <motion.span
                key={r.id}
                className="absolute rounded-full bg-current"
                style={{ left: r.x, top: r.y, width: r.size, height: r.size, x: '-50%', y: '-50%' }}
                initial={{ scale: 0.05, opacity: 0.3 }}
                animate={{ scale: 1, opacity: 0 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 1.6, ease: EASE_OUT }}
                onAnimationComplete={() => setRipples((prev) => prev.filter((x) => x.id !== r.id))}
              />
            ))}
          </AnimatePresence>
        </span>
      ) : null}
      {children}
    </motion.button>
  )
})
