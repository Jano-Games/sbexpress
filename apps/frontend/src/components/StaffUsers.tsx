import { ConfirmDialog } from "./ConfirmDialog";
import { useRef, useState } from "react";
import {
  Eye,
  EyeOff,
  KeyRound,
  Plus,
  Search,
  ShieldCheck,
  UserRound,
} from "lucide-react";
import { api } from "@/api/client";
import type { Role, StaffUser } from "@/api/types";
import { useFetch } from "@/state/useFetch";
import { useAuth } from "@/state/auth";
import { Button } from "./beui/button";
import { Input } from "./beui/input";
import { useToast } from "./beui/toast";
import { Panel, FormGrid, FormActions, SectionNotice } from "./DesignSystem";
import { EmptyState } from "./Workspace";
import { ErrorBlock, LoadingBlock } from "./ui";
import { Modal } from "./Modal";
import { fmtDate } from "@/lib/format";

const roleNames: Record<Role, string> = {
  admin: "Administrator",
  hub: "Hub manager",
};
const roleHelp: Record<Role, string> = {
  admin:
    "Full workspace access, including finance, settings and user management.",
  hub: "Hub dashboard, shipment handling and tasks. No access to settings or finance reports.",
};
const blankForm = {
  name: "",
  email: "",
  role: "hub" as Role,
  password: "",
  confirm: "",
  currentPassword: "",
};

export function StaffUsers() {
  const auth = useAuth();
  const { showToast } = useToast();
  const { data, error, loading, reload } = useFetch<{ users: StaffUser[] }>(
    "/settings/users",
  );
  const [query, setQuery] = useState("");
  const [accessUser, setAccessUser] = useState<StaffUser | null>(null);
  const [mode, setMode] = useState<"add" | "edit" | "password" | null>(null);
  const [selected, setSelected] = useState<StaffUser | null>(null);
  const [form, setForm] = useState(blankForm);
  const [showPassword, setShowPassword] = useState(false);
  const [problem, setProblem] = useState("");
  const [busy, setBusy] = useState(false);
  const locked = useRef(false);
  const ownAccount = selected?.id === auth.user?.id;
  const hasPassword = mode === "add" || mode === "password";
  const users = data?.users ?? [];
  const filtered = users.filter((user) =>
    `${user.name} ${user.email} ${roleNames[user.role]}{!user.active && <span className="ml-2 text-danger">Inactive</span>}`
      .toLowerCase()
      .includes(query.trim().toLowerCase()),
  );
  const title =
    mode === "add"
      ? "Add user"
      : mode === "password"
        ? ownAccount
          ? "Change your password"
          : "Reset password"
        : "Edit user";
  const set = (key: keyof typeof blankForm) => (value: string) =>
    setForm((current) => ({ ...current, [key]: value }));
  function open(next: NonNullable<typeof mode>, user?: StaffUser) {
    setSelected(user ?? null);
    setForm({
      ...blankForm,
      ...(user ? { name: user.name, email: user.email, role: user.role } : {}),
    });
    setShowPassword(false);
    setProblem("");
    setMode(next);
  }
  function close() {
    if (locked.current) return;
    setMode(null);
    setForm(blankForm);
    setShowPassword(false);
    setProblem("");
  }
  const passwordMismatch = !!form.confirm && form.password !== form.confirm;
  const valid =
    (mode === "password" ||
      (form.name.trim().length > 0 && form.email.trim().length > 0)) &&
    (!hasPassword ||
      (form.password.length >= 8 &&
        form.password.length <= 128 &&
        form.password === form.confirm)) &&
    (mode !== "password" || !ownAccount || !!form.currentPassword);
  async function save() {
    if (!valid || locked.current || !mode) return;
    locked.current = true;
    setBusy(true);
    setProblem("");
    try {
      const profile = {
        name: form.name.trim(),
        email: form.email.trim().toLowerCase(),
        role: form.role,
      };
      if (mode === "add")
        await api.post("/settings/users", {
          ...profile,
          password: form.password,
        });
      else if (mode === "edit" && selected) {
        await api.patch(`/settings/users/${selected.id}`, profile);
        if (ownAccount) await auth.refresh();
      } else if (mode === "password" && selected) {
        await api.post(`/settings/users/${selected.id}/password`, {
          password: form.password,
          ...(ownAccount ? { currentPassword: form.currentPassword } : {}),
        });
      }
      const signedOut = mode === "password" && ownAccount;
      showToast({
        title: signedOut
          ? "Password changed. Sign in with your new password."
          : mode === "add"
            ? "User added. They can now sign in."
            : mode === "password"
              ? "Password reset. Previous sessions are signed out."
              : "User details updated",
        status: "success",
      });
      setMode(null);
      setForm(blankForm);
      setShowPassword(false);
      if (signedOut) await auth.logout();
      else await reload();
    } catch (e) {
      setProblem(e instanceof Error ? e.message : "Could not save user");
    } finally {
      locked.current = false;
      setBusy(false);
    }
  }
  return (
    <>
      <ConfirmDialog
        open={!!accessUser}
        onClose={() => setAccessUser(null)}
        title={accessUser?.active ? "Deactivate user?" : "Reactivate user?"}
        confirmLabel={accessUser?.active ? "Deactivate" : "Reactivate"}
        body={
          accessUser?.active
            ? `${accessUser.name} will lose access immediately. Their past activity remains in history.`
            : `${accessUser?.name} can sign in again with their existing credentials.`
        }
        onConfirm={async () => {
          if (!accessUser) return;
          try {
            await api.patch(`/settings/users/${accessUser.id}`, {
              active: !accessUser.active,
            });
            await reload();
            showToast({ title: "User access updated", status: "success" });
          } catch (e) {
            showToast({
              title: e instanceof Error ? e.message : "Could not change access",
              status: "error",
            });
          }
        }}
      />
      <Panel
        title="Team users"
        description="Manage staff access to this workspace. Customers use their shipment links."
        actions={
          <Button onClick={() => open("add")}>
            <Plus size={16} aria-hidden="true" />
            Add user
          </Button>
        }
      >
        <div className="mb-5 flex flex-wrap items-center justify-between gap-4">
          <Input
            className="w-full sm:max-w-xs"
            aria-label="Search users"
            placeholder="Search name, email or role"
            leftIcon={<Search size={16} />}
            value={query}
            onChange={setQuery}
          />
          {data && (
            <p className="text-xs text-muted-foreground">
              {users.length} {users.length === 1 ? "user" : "users"} ·{" "}
              {users.filter((user) => user.role === "admin").length}{" "}
              administrators
            </p>
          )}
        </div>
        {error ? (
          <div className="space-y-3">
            <ErrorBlock message={error} />
            <Button variant="secondary" onClick={() => void reload()}>
              Try again
            </Button>
          </div>
        ) : loading ? (
          <LoadingBlock label="Loading users…" />
        ) : filtered.length ? (
          <div className="data-table rounded-md border border-border">
            <table aria-label="Team users">
              <thead>
                <tr>
                  <th scope="col">User</th>
                  <th scope="col">Role</th>
                  <th scope="col">Added</th>
                  <th scope="col" className="text-right">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((user) => (
                  <tr key={user.id}>
                    <td>
                      <p className="font-medium">
                        {user.name}
                        {user.id === auth.user?.id && (
                          <span className="ml-2 rounded bg-primary-soft px-2 py-0.5 text-xs text-primary">
                            You
                          </span>
                        )}
                      </p>
                      <p className="mt-1 text-xs text-muted-foreground">
                        {user.email}
                      </p>
                    </td>
                    <td>
                      <span className="inline-flex items-center gap-2 whitespace-nowrap text-sm">
                        {user.role === "admin" ? (
                          <ShieldCheck size={15} aria-hidden="true" />
                        ) : (
                          <UserRound size={15} aria-hidden="true" />
                        )}
                        {roleNames[user.role]}
                        {!user.active && (
                          <span className="ml-2 text-danger">Inactive</span>
                        )}
                      </span>
                    </td>
                    <td className="whitespace-nowrap text-xs text-muted-foreground">
                      {fmtDate(user.createdAt)}
                    </td>
                    <td>
                      <div className="flex flex-wrap justify-end gap-2">
                        {user.id !== auth.user?.id && (
                          <Button
                            size="sm"
                            variant="secondary"
                            onClick={() => setAccessUser(user)}
                          >
                            {user.active ? "Deactivate" : "Reactivate"}
                          </Button>
                        )}
                        <Button
                          size="sm"
                          variant="secondary"
                          aria-label={`Edit ${user.name}`}
                          onClick={() => open("edit", user)}
                        >
                          Edit
                        </Button>
                        <Button
                          size="sm"
                          variant="ghost"
                          aria-label={`${user.id === auth.user?.id ? "Change password for" : "Reset password for"} ${user.name}`}
                          onClick={() => open("password", user)}
                        >
                          <KeyRound size={14} aria-hidden="true" />
                          Password
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            title={query ? "No matching users" : "No users yet"}
            description={
              query
                ? "Try another name, email or role."
                : "Add a staff member to give them access to this workspace."
            }
          />
        )}
      </Panel>
      <div className="mt-5 grid gap-4 sm:grid-cols-2">
        {(["admin", "hub"] as const).map((role) => (
          <div
            key={role}
            className="rounded-md border border-border bg-card p-5"
          >
            <h3 className="text-sm font-semibold">{roleNames[role]}</h3>
            <p className="mt-2 text-xs leading-relaxed text-muted-foreground">
              {roleHelp[role]}
            </p>
          </div>
        ))}
      </div>
      <Modal open={mode !== null} onClose={close} className="max-w-xl">
        <h2 className="text-xl font-semibold">{title}</h2>
        <p className="mb-6 mt-2 text-sm text-muted-foreground">
          {mode === "add"
            ? "Create a staff account with an email, password and access role."
            : mode === "password"
              ? `${selected?.name} · ${selected?.email}`
              : "Update this user’s profile and workspace access."}
        </p>
        <form
          onSubmit={(event) => {
            event.preventDefault();
            void save();
          }}
          className="space-y-5"
        >
          {mode !== "password" && (
            <>
              <FormGrid columns={1}>
                <Input
                  label="Full name"
                  value={form.name}
                  onChange={set("name")}
                  maxLength={100}
                  required
                  disabled={busy}
                  autoComplete="off"
                />
                <Input
                  label="Email address"
                  type="email"
                  value={form.email}
                  onChange={set("email")}
                  maxLength={254}
                  required
                  disabled={busy}
                  autoComplete="off"
                />
              </FormGrid>
              <label className="block text-sm font-medium">
                Role
                <select
                  aria-label="User role"
                  className="form-control mt-2"
                  value={form.role}
                  onChange={(event) =>
                    setForm((current) => ({
                      ...current,
                      role: event.target.value as Role,
                    }))
                  }
                  disabled={busy || (mode === "edit" && ownAccount)}
                >
                  <option value="hub">Hub manager</option>
                  <option value="admin">Administrator</option>
                </select>
              </label>
              <p className="text-xs leading-relaxed text-muted-foreground">
                {roleHelp[form.role]}
                {mode === "edit" &&
                  ownAccount &&
                  " Another administrator must change your own role."}
              </p>
            </>
          )}
          {hasPassword && (
            <>
              {mode === "password" && ownAccount && (
                <Input
                  label="Current password"
                  type="password"
                  value={form.currentPassword}
                  onChange={set("currentPassword")}
                  maxLength={128}
                  autoComplete="current-password"
                  required
                  disabled={busy}
                />
              )}
              <div className="relative">
                <Input
                  label={mode === "add" ? "Password" : "New password"}
                  type={showPassword ? "text" : "password"}
                  value={form.password}
                  onChange={set("password")}
                  minLength={8}
                  maxLength={128}
                  required
                  disabled={busy}
                  autoComplete="new-password"
                  inputClassName="pr-12"
                  aria-describedby="staff-password-help"
                />
                <Button
                  type="button"
                  size="icon"
                  variant="ghost"
                  className="absolute bottom-0.5 right-1"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                  disabled={busy}
                  onClick={() => setShowPassword((value) => !value)}
                >
                  {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                </Button>
              </div>
              <p
                id="staff-password-help"
                className="text-xs text-muted-foreground"
              >
                Use 8–128 characters. Share the password directly with the user.
              </p>
              <Input
                label="Confirm password"
                type={showPassword ? "text" : "password"}
                value={form.confirm}
                onChange={set("confirm")}
                maxLength={128}
                required
                disabled={busy}
                autoComplete="new-password"
                error={passwordMismatch ? "Passwords do not match" : undefined}
              />
              {mode === "password" && (
                <SectionNotice>
                  {ownAccount
                    ? "You will be signed out after changing your password."
                    : "The user will need to sign in again with the new password."}
                </SectionNotice>
              )}
            </>
          )}
          {problem && <SectionNotice tone="danger">{problem}</SectionNotice>}
          <FormActions>
            <Button variant="secondary" disabled={busy} onClick={close}>
              Cancel
            </Button>
            <Button type="submit" disabled={busy || !valid}>
              {busy
                ? "Saving…"
                : mode === "add"
                  ? "Create user"
                  : mode === "password"
                    ? ownAccount
                      ? "Change password"
                      : "Reset password"
                    : "Save changes"}
            </Button>
          </FormActions>
        </form>
      </Modal>
    </>
  );
}
