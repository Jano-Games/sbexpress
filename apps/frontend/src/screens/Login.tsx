import { useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { Lock, Mail } from 'lucide-react'
import { Button } from '@/components/beui/button'
import { Input } from '@/components/beui/input'
import type { Role } from '@/api/types'
import { useAuth } from '@/state/auth'

const HOME: Record<Role, string> = { admin: '/overview', hub: '/hub' }

export function Login() {
  const { login } = useAuth()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (busy) return
    setError(null)
    setBusy(true)
    try {
      const user = await login(email.trim(), password)
      navigate(HOME[user.role])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sign-in failed')
      setBusy(false)
    }
  }

  return (
    <div className="grid min-h-screen lg:grid-cols-2">
      <div className="flex min-w-0 flex-col bg-ink p-6 sm:p-10 lg:p-13 text-white">
        <div className="flex items-center gap-2.5">
          <div className="grid size-9.5 place-items-center rounded-[10px] bg-primary text-base font-extrabold">SB</div>
          <div className="text-[17px] font-extrabold leading-tight">Sichuan Bangla Express</div>
        </div>
        <div className="mt-8 lg:mt-auto">
          <div className="text-[28px] sm:text-[36px] lg:text-[40px] font-extrabold leading-[1.1] text-pretty">
            Chengdu to Dhaka,
            <br />
            every shipment accounted for.
          </div>
          <div className="mt-6.5 flex flex-wrap items-center gap-2.5 text-[13px] text-[#B9BCC1]">
            <span className="rounded-full bg-ink-soft px-3 py-1.5">CTU Chengdu</span>
            <span className="font-bold text-primary">→</span>
            <span className="rounded-full bg-ink-soft px-3 py-1.5">DAC Dhaka · Bashundhara Hub</span>
          </div>
        </div>
        <div className="mt-10 text-xs text-[#7A7D82]">Shipping, payments, and hub operations in one workspace.</div>
      </div>

      <div className="flex min-w-0 items-center justify-center px-6 py-10 sm:p-10">
        <form className="flex w-full max-w-[400px] flex-col gap-3" onSubmit={(e) => void submit(e)}>
          <h1 className="m-0 text-[28px] font-extrabold">Welcome back</h1>
          <div className="mb-1.5 text-[13px] text-muted-foreground">Staff accounts only — admin and hub manager</div>
          <Input
            label="Email"
            type="email"
            autoComplete="email"
            placeholder="you@sbx.express"
            leftIcon={<Mail />}
            value={email}
            onChange={setEmail}
            required
          />
          <Input
            label="Password"
            type="password"
            autoComplete="current-password"
            placeholder="••••••••"
            leftIcon={<Lock />}
            value={password}
            onChange={setPassword}
            required
          />
          {error && <p role="alert" className="rounded-lg bg-danger-soft p-3 text-sm text-danger">{error}</p>}
          <Button type="submit" size="lg" className="mt-1.5" disabled={busy || !email.trim() || !password}>
            {busy ? 'Signing in…' : 'Sign in →'}
          </Button>
          <div className="mt-1 text-xs text-muted-foreground">
            Customers don't log in — they get a tracking link per shipment with status and payment info.
          </div>
        </form>
      </div>
    </div>
  )
}
