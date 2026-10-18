import { Link } from 'react-router-dom';
import { CheckCircle2, Circle } from 'lucide-react';
import { useFetch } from '@/state/useFetch';
import { Panel } from './DesignSystem';
import { ErrorBlock, LoadingBlock } from './ui';
type Setup = { rateConfirmed: boolean; accounts: number; paymentMethods: number; users: number; storageConfigured: boolean; cleanupEnabled: boolean; lastCleanupAt: string | null };
export function BusinessSetup() {
  const { data, error, loading } = useFetch<Setup>('/settings/setup-status');
  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  const steps = [
    { label: 'Confirm the CNY exchange rate', detail: data.rateConfirmed ? 'Your saved rate is used for new entries.' : 'Save your agreed rate below. The initial default has not been confirmed.', done: data.rateConfirmed, to: '#operating-defaults', action: 'Review rate' },
    { label: 'Add receiving accounts', detail: data.accounts ? data.accounts + ' account(s) available.' : 'Add your real cash, bank or wallet accounts and record opening funds in Finance.', done: data.accounts > 0, to: '/finance?tab=accounts', action: 'Open Finance' },
    { label: 'Set customer payment instructions', detail: data.paymentMethods ? data.paymentMethods + ' enabled payment method(s).' : 'Add the actual account details customers should use when paying.', done: data.paymentMethods > 0, to: '/settings?section=payments', action: 'Payment methods' },
  ];
  return <Panel title="Business setup" description="Complete these details before entering real payments.">
    <div className="divide-y divide-border">{steps.map(step => <div key={step.label} className="flex flex-wrap items-center gap-3 py-4 first:pt-0">
      {step.done ? <CheckCircle2 size={20} className="text-success" aria-label="Complete" /> : <Circle size={20} className="text-muted-foreground" aria-label="Needs setup" />}
      <div className="min-w-0 flex-1"><p className="font-medium text-sm">{step.label}</p><p className="mt-1 text-sm text-muted-foreground">{step.detail}</p></div>
      <Link className="text-sm font-medium text-primary" to={step.to}>{step.action}</Link>
    </div>)}</div>
    <div className="mt-3 border-t border-border pt-4 text-sm text-muted-foreground">
      <Link className="text-primary" to="/settings?section=users">Manage staff access</Link> · {data.users} active user(s).
      <p className="mt-2">File storage: {data.storageConfigured ? 'Configured' : 'Needs configuration'}. Upload cleanup: {data.cleanupEnabled ? data.lastCleanupAt ? 'Last completed '+new Date(data.lastCleanupAt).toLocaleString() : 'Enabled; first run pending' : 'Not enabled'}.</p>
    </div>
  </Panel>;
}
