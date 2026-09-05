import { useEffect, useState } from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { api } from '@/api/client'
import { useAuth } from '@/state/auth'
import { cn } from '@/lib/utils'
import { SbMark } from '@/components/ui'

interface NavItem {
  label: string
  to: string
  badge?: number
}

export function AppShell() {
  const { user, logout } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [badges, setBadges] = useState<{ review: number; todos: number }>({ review: 0, todos: 0 })

  // Sidebar badges (receipts to review, open tasks). The overview endpoints
  // are cached server-side, so refreshing on every navigation is cheap.
  useEffect(() => {
    if (!user) return
    const path = user.role === 'admin' ? '/dashboard/overview' : '/dashboard/hub'
    api
      .get<{ reviewCount?: number; openTodoCount: number }>(path)
      .then((r) => setBadges({ review: r.reviewCount ?? 0, todos: r.openTodoCount }))
      .catch(() => undefined)
  }, [user, location.pathname])

  if (!user) return null

  const nav: NavItem[] =
    user.role === 'admin'
      ? [
          { label: 'Overview', to: '/overview' },
          { label: 'Shipments', to: '/shipments' },
          { label: 'Flights', to: '/flights' },
          { label: 'Flyers', to: '/flyers' },
          { label: 'Suppliers', to: '/suppliers' },
          { label: 'Finance', to: '/finance' },
          { label: 'Review queue', to: '/review', badge: badges.review },
          { label: 'To-do', to: '/todos', badge: badges.todos },
          { label: 'Settings', to: '/settings' },
        ]
      : [
          { label: 'Hub overview', to: '/hub' },
          { label: 'Shipments', to: '/shipments' },
          { label: 'To-do', to: '/todos', badge: badges.todos },
        ]

  return (
    <div className="flex min-h-screen flex-col md:flex-row">
      <a href="#main-content" className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-[100] focus:rounded-lg focus:bg-card focus:p-3">Skip to content</a>
      <header className="flex items-center justify-between border-b border-border bg-card px-4 py-3 md:hidden">
        <div className="flex items-center gap-2"><SbMark size={26}/><span className="text-xs font-bold">Sichuan Bangla Express</span></div>
        <details className="relative"><summary className="cursor-pointer rounded-lg border border-border px-3 py-2 text-xs font-semibold">Menu</summary><nav aria-label="Mobile navigation" className="absolute right-0 top-full z-40 mt-2 w-52 rounded-xl border border-border bg-card p-2 shadow-lg">{nav.map(item=><NavLink key={item.to} to={item.to} onClick={e=>e.currentTarget.closest('details')?.removeAttribute('open')} className={({isActive})=>`block rounded-lg px-3 py-2.5 text-sm ${isActive?'bg-primary-soft font-semibold text-primary':'text-foreground'}`}>{item.label}</NavLink>)}<button className="w-full border-t border-border px-3 py-2.5 text-left text-sm" onClick={()=>void logout().then(()=>navigate('/login'))}>Log out</button></nav></details>
      </header>
      <aside className="hidden w-[212px] shrink-0 md:sticky md:top-0 md:h-screen md:overflow-y-auto md:flex flex-col gap-[3px] border-r border-border bg-card px-3.5 py-5.5">
        <div className="mb-5 flex items-center gap-2.5 px-1.5">
          <SbMark size={30} />
          <div className="text-[13px] font-extrabold leading-tight">
            Sichuan Bangla
            <br />
            Express
          </div>
        </div>
        {nav.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-2 rounded-lg px-3 py-2.25 text-[13px] no-underline',
                isActive || location.pathname.startsWith(`${item.to}/`)
                  ? 'bg-primary-soft font-bold text-primary'
                  : 'font-medium text-muted-foreground hover:bg-muted',
              )
            }
          >
            <span className="flex-1">{item.label}</span>
            {item.badge ? (
              <span className="rounded-full bg-primary px-1.75 py-0.5 text-[10.5px] font-bold text-white">{item.badge}</span>
            ) : null}
          </NavLink>
        ))}
        <div className="mt-auto rounded-[10px] bg-muted p-3 text-xs">
          <div className="font-bold">{user.name}</div>
          <div className="mt-px text-muted-foreground">{user.roleLabel}</div>
          <button
            type="button"
            className="mt-2 cursor-pointer border-0 bg-transparent p-0 text-xs font-semibold text-blue"
            onClick={() => {
              void logout().then(() => navigate('/login'))
            }}
          >
            Log out
          </button>
        </div>
      </aside>
      <main id="main-content" tabIndex={-1} className="min-w-0 flex-1 px-4 py-5 md:px-8 md:py-6.5">
        <div className="mx-auto w-full max-w-[1600px]"><Outlet /></div>
      </main>
    </div>
  )
}
