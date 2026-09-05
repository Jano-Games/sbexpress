import { lazy, Suspense } from 'react'
import { PublicStatement } from '@/components/StatementLinks'
import { Navigate, Route, Routes } from 'react-router-dom'
import { useAuth } from '@/state/auth'
import { AppShell } from '@/components/AppShell'
import { LoadingBlock } from '@/components/ui'
const Login = lazy(() => import('@/screens/Login').then(module => ({default:module.Login})))
const Overview = lazy(() => import('@/screens/Overview').then(module => ({default:module.Overview})))
const Shipments = lazy(() => import('@/screens/Shipments').then(module => ({default:module.Shipments})))
const ShipmentDetail = lazy(() => import('@/screens/ShipmentDetail').then(module => ({default:module.ShipmentDetail})))
const Flights = lazy(() => import('@/screens/Flights').then(module => ({default:module.Flights})))
const FlightDetail = lazy(() => import('@/screens/FlightDetail').then(module => ({default:module.FlightDetail})))
const Flyers = lazy(() => import('@/screens/Flyers').then(module => ({default:module.Flyers})))
const FlyerDetail = lazy(() => import('@/screens/FlyerDetail').then(module => ({default:module.FlyerDetail})))
const Suppliers = lazy(() => import('@/screens/Suppliers').then(module => ({default:module.Suppliers})))
const SupplierDetail = lazy(() => import('@/screens/SupplierDetail').then(module => ({default:module.SupplierDetail})))
const Finance = lazy(() => import('@/screens/Finance').then(module => ({default:module.Finance})))
const Review = lazy(() => import('@/screens/Review').then(module => ({default:module.Review})))
const Todos = lazy(() => import('@/screens/Todos').then(module => ({default:module.Todos})))
const Settings = lazy(() => import('@/screens/Settings').then(module => ({default:module.Settings})))
const HubOverview = lazy(() => import('@/screens/HubOverview').then(module => ({default:module.HubOverview})))
const Track = lazy(() => import('@/screens/Track').then(module => ({default:module.Track})))

const HOME: Record<string, string> = { admin: '/overview', hub: '/hub' }

export default function App() {
  const { user, booting } = useAuth()

  return (
    <Suspense fallback={<div className="p-8"><LoadingBlock label="Loading page…" /></div>}>
    <Routes>
      <Route path="/s/:token" element={<PublicStatement />} />
      <Route path="/t/:token" element={<Track />} />
      <Route path="/login" element={user ? <Navigate to={HOME[user.role]!} replace /> : <Login />} />
      {booting ? (
        <Route path="*" element={<div className="p-10"><LoadingBlock label="Signing in…" /></div>} />
      ) : user ? (
        <Route element={<AppShell />}>
          <Route index element={<Navigate to={HOME[user.role]!} replace />} />
          <Route path="/overview" element={user.role === 'admin' ? <Overview /> : <Navigate to="/hub" replace />} />
          <Route path="/shipments" element={<Shipments />} />
          <Route path="/shipments/:code" element={<ShipmentDetail />} />
          <Route path="/flights" element={user.role === 'admin' ? <Flights /> : <Navigate to="/hub" replace />} />
          <Route path="/flights/:code" element={user.role === 'admin' ? <FlightDetail /> : <Navigate to="/hub" replace />} />
          <Route path="/flyers" element={user.role === 'admin' ? <Flyers /> : <Navigate to="/hub" replace />} />
          <Route path="/flyers/:name" element={user.role === 'admin' ? <FlyerDetail /> : <Navigate to="/hub" replace />} />
          <Route path="/suppliers" element={user.role === 'admin' ? <Suppliers /> : <Navigate to="/hub" replace />} />
          <Route path="/suppliers/:code" element={user.role === 'admin' ? <SupplierDetail /> : <Navigate to="/hub" replace />} />
          <Route path="/finance" element={user.role === 'admin' ? <Finance /> : <Navigate to="/hub" replace />} />
          <Route path="/review" element={user.role === 'admin' ? <Review /> : <Navigate to="/hub" replace />} />
          <Route path="/todos" element={<Todos />} />
          <Route path="/settings" element={user.role === 'admin' ? <Settings /> : <Navigate to="/hub" replace />} />
          <Route path="/hub" element={user.role === 'hub' ? <HubOverview /> : <Navigate to="/overview" replace />} />
          <Route path="*" element={<Navigate to={HOME[user.role]!} replace />} />
        </Route>
      ) : (
        <Route path="*" element={<Navigate to="/login" replace />} />
      )}
    </Routes>
    </Suspense>
  )
}
