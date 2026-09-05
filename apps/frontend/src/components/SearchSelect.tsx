import { useMemo, useState } from 'react'
import { Input } from '@/components/beui/input'

export interface SearchOption {
  value: string
  label: string
  /** Secondary text shown right-aligned in the list. */
  sub?: string
  /** Lower-cased haystack the query is matched against. */
  keywords: string
}

/**
 * Single-select combobox: shows the selected label at rest, becomes a search
 * box on focus. The query matches anywhere in `keywords` (e.g. a supplier's
 * name and short code).
 */
export function SearchSelect({
  label,
  placeholder,
  options,
  value,
  onChange,
  className,
}: {
  label?: string
  placeholder: string
  options: SearchOption[]
  value: string
  onChange: (value: string) => void
  className?: string
}) {
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(false)

  const selected = options.find((o) => o.value === value)

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return options.filter((o) => !q || o.keywords.includes(q)).slice(0, 8)
  }, [options, query])

  return (
    <div className={className}>
      <div className="relative">
        <Input
          label={label}
          placeholder={selected ? selected.label : placeholder}
          value={open ? query : (selected?.label ?? '')}
          onChange={(v) => {
            setQuery(v)
            setOpen(true)
          }}
          onFocus={() => {
            setQuery('')
            setOpen(true)
          }}
          onBlur={() => window.setTimeout(() => setOpen(false), 150)}
        />
        {open && filtered.length ? (
          <div className="absolute left-0 right-0 top-[calc(100%+4px)] z-20 max-h-[220px] overflow-auto rounded-[10px] border border-border bg-card p-1 shadow-[0_10px_28px_rgba(0,0,0,.14)]">
            {filtered.map((o) => (
              <div
                key={o.value}
                className="flex cursor-pointer items-center justify-between gap-2.5 rounded-[7px] px-3 py-2.25 text-[12.5px] font-semibold hover:bg-primary-soft hover:text-primary"
                onMouseDown={(e) => {
                  e.preventDefault()
                  onChange(o.value)
                  setQuery('')
                  setOpen(false)
                  ;(document.activeElement as HTMLElement | null)?.blur()
                }}
              >
                <span className="min-w-0 truncate">{o.label}</span>
                {o.sub ? <span className="shrink-0 text-[11px] font-normal text-faint">{o.sub}</span> : null}
              </div>
            ))}
          </div>
        ) : null}
      </div>
    </div>
  )
}
