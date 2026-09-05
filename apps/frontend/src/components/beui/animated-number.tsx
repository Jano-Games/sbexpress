// beui.dev/components/motion/number
import { animate, useInView, useReducedMotion } from 'motion/react'
import { useEffect, useRef, useState } from 'react'
import { EASE_OUT } from '@/lib/ease'
import { cn } from '@/lib/utils'

export interface AnimatedNumberProps {
  value: number
  duration?: number
  format?: (value: number) => string
  className?: string
  startOnView?: boolean
}

export function AnimatedNumber({
  value,
  duration = 1.2,
  format = (number) => Math.round(number).toLocaleString(),
  className,
  startOnView = true,
}: AnimatedNumberProps) {
  const ref = useRef<HTMLSpanElement>(null)
  const inView = useInView(ref, { once: true, amount: 0.6 })
  const reduce = useReducedMotion()
  const [display, setDisplay] = useState(0)
  const fromRef = useRef(0)

  useEffect(() => {
    if (startOnView && !inView) return
    if (reduce) {
      fromRef.current = value
      setDisplay(value)
      return
    }

    const controls = animate(fromRef.current, value, {
      duration,
      ease: EASE_OUT,
      onUpdate: (next) => {
        fromRef.current = next
        setDisplay(next)
      },
    })
    return () => controls.stop()
  }, [value, duration, inView, startOnView, reduce])

  return (
    <span ref={ref} className={cn('tabular-nums', className)}>
      {format(display)}
    </span>
  )
}
