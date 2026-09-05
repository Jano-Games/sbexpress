// beui.dev/components/motion/input — sized down for the design's dense forms.
import { AnimatePresence, animate, motion, useReducedMotion } from 'motion/react'
import { forwardRef, useEffect, useId, useRef, useState, type InputHTMLAttributes, type ReactNode } from 'react'
import { cn } from '@/lib/utils'

export interface InputProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'value' | 'defaultValue' | 'onChange'> {
  label?: string
  value?: string
  defaultValue?: string
  onChange?: (value: string) => void
  error?: string | boolean
  leftIcon?: ReactNode
  fieldClassName?: string
  inputClassName?: string
}

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  {
    label,
    value: valueProp,
    defaultValue,
    onChange,
    onFocus,
    onBlur,
    error,
    leftIcon,
    className,
    fieldClassName,
    inputClassName,
    disabled,
    id: idProp,
    type,
    ...rest
  },
  ref,
) {
  const reactId = useId()
  const id = idProp ?? reactId
  const reduce = useReducedMotion()
  const controlled = valueProp !== undefined
  const [internal, setInternal] = useState(defaultValue ?? '')
  const [focused, setFocused] = useState(false)
  const fieldRef = useRef<HTMLDivElement>(null)
  const value = controlled ? (valueProp ?? '') : internal
  const hasError = Boolean(error)
  const errorMessage = typeof error === 'string' ? error : null

  useEffect(() => {
    if (!fieldRef.current || reduce || !hasError) return
    const controls = animate(fieldRef.current, { x: [0, -5, 5, -3, 3, 0] }, { duration: 0.36 })
    return () => controls.stop()
  }, [hasError, reduce])

  return (
    <div className={cn('flex flex-col gap-1.5', className)}>
      {label ? (
        <label htmlFor={id} className="text-[12px] text-muted-foreground">
          {label}
        </label>
      ) : null}

      <div
        ref={fieldRef}
        className={cn(
          'relative h-10 overflow-hidden rounded-[9px] border bg-card transition-[border-color,box-shadow] duration-200',
          hasError
            ? 'border-danger ring-2 ring-danger/20'
            : focused
              ? 'border-primary ring-[3px] ring-primary/15'
              : 'border-border',
          disabled && 'opacity-60',
          fieldClassName,
        )}
      >
        {leftIcon ? (
          <span className="pointer-events-none absolute left-3 top-1/2 flex -translate-y-1/2 items-center text-muted-foreground [&_svg]:size-4">
            {leftIcon}
          </span>
        ) : null}

        <input
          ref={ref}
          id={id}
          type={type}
          value={value}
          disabled={disabled}
          aria-invalid={hasError || undefined}
          aria-describedby={errorMessage ? `${id}-error` : undefined}
          {...rest}
          onChange={(event) => {
            const next = event.target.value
            if (!controlled) setInternal(next)
            onChange?.(next)
          }}
          onFocus={(event) => {
            setFocused(true)
            onFocus?.(event)
          }}
          onBlur={(event) => {
            setFocused(false)
            onBlur?.(event)
          }}
          className={cn(
            'h-full w-full border-0 bg-transparent text-[12.5px] text-foreground caret-primary outline-none placeholder:text-faint',
            leftIcon ? 'pl-10' : 'pl-3',
            'pr-3',
            disabled && 'cursor-not-allowed',
            inputClassName,
          )}
        />
      </div>

      <AnimatePresence initial={false}>
        {errorMessage ? (
          <motion.p
            id={`${id}-error`}
            role="alert"
            initial={reduce ? { opacity: 0 } : { opacity: 0, y: -4 }}
            animate={{ opacity: 1, y: 0 }}
            exit={reduce ? { opacity: 0 } : { opacity: 0, y: -4 }}
            transition={{ duration: 0.18 }}
            className="m-0 text-xs text-danger"
          >
            {errorMessage}
          </motion.p>
        ) : null}
      </AnimatePresence>
    </div>
  )
})
