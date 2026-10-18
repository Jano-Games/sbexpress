import { Suspense, useEffect, useRef, useState } from "react";
import {
  NavLink,
  Outlet,
  useLocation,
  useNavigate,
  Link,
} from "react-router-dom";
import {
  LayoutDashboard,
  Package,
  Plane,
  Users,
  ContactRound,
  Wallet,
  ClipboardCheck,
  ListTodo,
  Settings,
  LogOut,
  Menu,
  X,
} from "lucide-react";
import { useFetch } from "@/state/useFetch";
import { useAuth } from "@/state/auth";
import { LoadingBlock, SbMark } from "@/components/ui";

const modules = [
  { label: "Dashboard", to: "/overview", icon: LayoutDashboard },
  { label: "Shipments", to: "/shipments", icon: Package },
  { label: "Flights", to: "/flights", icon: Plane },
  { label: "Customers", to: "/suppliers", icon: ContactRound },
  { label: "Flyers", to: "/flyers", icon: Users },
  { label: "Finance", to: "/finance", icon: Wallet },
  { label: "Payment review", to: "/review", icon: ClipboardCheck },
  { label: "Tasks", to: "/todos", icon: ListTodo },
  { label: "Settings", to: "/settings", icon: Settings },
];
export function AppShell() {
  const { user, logout } = useAuth(),
    location = useLocation(),
    navigate = useNavigate();
  const [mobile, setMobile] = useState(false);
  const { data: badges, reload: reloadBadges } = useFetch<{
    reviewCount: number;
    openTodoCount: number;
  }>(user ? "/dashboard/counts" : null);
  useEffect(() => {
    if (user) void reloadBadges();
  }, [location.pathname, reloadBadges, user]);
  const navigationRef = useRef<HTMLElement>(null),
    menuRef = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    setMobile(false);
  }, [location.pathname, location.search]);
  useEffect(() => {
    const desktop = window.matchMedia("(min-width: 801px)");
    const closeOnDesktop = () => {
      if (desktop.matches) setMobile(false);
    };
    desktop.addEventListener("change", closeOnDesktop);
    return () => desktop.removeEventListener("change", closeOnDesktop);
  }, []);
  useEffect(() => {
    if (!mobile) return;
    const oldOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    navigationRef.current?.querySelector<HTMLElement>("button,a")?.focus();
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setMobile(false);
        menuRef.current?.focus();
      }
      if (event.key === "Tab") {
        const nodes = Array.from(
          navigationRef.current?.querySelectorAll<HTMLElement>("a,button") ??
            [],
        );
        const first = nodes[0],
          last = nodes.at(-1);
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last?.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first?.focus();
        }
      }
    };
    document.addEventListener("keydown", onKey);
    return () => {
      document.body.style.overflow = oldOverflow;
      document.removeEventListener("keydown", onKey);
    };
  }, [mobile]);
  if (!user) return null;
  const navigation =
    user.role === "admin"
      ? modules
      : [
          { label: "Hub dashboard", to: "/hub", icon: LayoutDashboard },
          modules[1]!,
          modules[7]!,
        ];
  return (
    <div className="application">
      <a className="skip-link" href="#main-content">
        Skip to content
      </a>
      <header className="application-header">
        <div className="application-header-inner">
          <button
            ref={menuRef}
            type="button"
            className="mobile-menu"
            aria-label="Open navigation"
            aria-expanded={mobile}
            onClick={() => setMobile(true)}
          >
            <Menu size={22} />
          </button>
          <Link
            to={user.role === "admin" ? "/overview" : "/hub"}
            className="application-brand"
          >
            <SbMark size={32} />
            <span>
              Sichuan Bangla <strong>Express</strong>
            </span>
          </Link>
          <span className="application-context">Operations workspace</span>
          <div className="application-account">
            <div>
              <strong>{user.name}</strong>
              <span>
                {user.role === "admin" ? "Administrator" : "Hub manager"}
              </span>
            </div>
            <button
              type="button"
              aria-label="Sign out"
              title="Sign out"
              onClick={() => void logout().then(() => navigate("/login"))}
            >
              <LogOut size={18} />
            </button>
          </div>
        </div>
      </header>
      {mobile && (
        <button
          className="navigation-scrim"
          aria-label="Close navigation"
          onClick={() => setMobile(false)}
        />
      )}
      <nav
        ref={navigationRef}
        aria-label="Main navigation"
        className={"application-navigation" + (mobile ? " is-open" : "")}
      >
        <div className="navigation-inner">
          <div className="mobile-navigation-heading">
            <strong>Workspace</strong>
            <button
              type="button"
              aria-label="Close navigation"
              onClick={() => {
                setMobile(false);
                menuRef.current?.focus();
              }}
            >
              <X size={22} />
            </button>
          </div>
          {navigation.map((item) => {
            const count =
              item.to === "/review"
                ? (badges?.reviewCount ?? 0)
                : item.to === "/todos"
                  ? (badges?.openTodoCount ?? 0)
                  : 0;
            return (
              <NavLink
                key={item.to}
                to={item.to}
                onClick={() => setMobile(false)}
                className={({ isActive }) =>
                  "module-link" + (isActive ? " active" : "")
                }
              >
                <item.icon size={17} />
                <span>{item.label}</span>
                {count > 0 && <b>{count}</b>}
              </NavLink>
            );
          })}
        </div>
      </nav>
      <main id="main-content" tabIndex={-1} className="workspace-main">
        <Suspense fallback={<LoadingBlock label="Loading page…" />}>
          <Outlet />
        </Suspense>
      </main>
      <footer className="application-footer">
        <span>Sichuan Bangla Express</span>
        <span>BDT & CNY · Reports in BDT</span>
      </footer>
    </div>
  );
}
