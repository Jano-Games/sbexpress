import { SbMark } from "@/components/ui";
import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { Lock, Mail } from "lucide-react";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import type { Role } from "@/api/types";
import { useAuth } from "@/state/auth";

const HOME: Record<Role, string> = { admin: "/overview", hub: "/hub" };

export function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (busy) return;
    setError(null);
    setBusy(true);
    try {
      const user = await login(email.trim(), password);
      navigate(HOME[user.role]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign-in failed");
      setBusy(false);
    }
  };

  return (
    <div className="login-page">
      <section className="login-intro">
        <div className="login-brand">
          <SbMark size={36} /> Sichuan Bangla Express
        </div>
        <div>
          <h2>Your operations. One workspace.</h2>
          <p>
            Manage cargo from booking to delivery, keep your records organized,
            and follow every payment.
          </p>
        </div>
        <footer>Chengdu · Dhaka</footer>
      </section>
      <main className="login-form-area">
        <div className="login-card">
          <h1>Sign in</h1>
          <p>
            Welcome back. Enter your account details to open your workspace.
          </p>
          <form
            className="flex flex-col gap-4"
            onSubmit={(e) => void submit(e)}
          >
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
            {error && (
              <p
                role="alert"
                className="rounded-lg bg-danger-soft p-3 text-sm text-danger"
              >
                {error}
              </p>
            )}
            <Button
              type="submit"
              size="md"
              className="mt-2 w-full"
              disabled={busy || !email.trim() || !password}
            >
              {busy ? "Signing in…" : "Sign in"}
            </Button>
          </form>
          <p className="login-caption">
            Staff access only. Customers can follow deliveries using their
            shipment tracking link.
          </p>
        </div>
      </main>
    </div>
  );
}
