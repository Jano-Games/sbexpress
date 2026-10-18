import { Link } from "react-router-dom";
import { useState } from "react";
import { api } from "@/api/client";
import type { Todo } from "@/api/types";
import { useAuth } from "@/state/auth";
import { useFetch } from "@/state/useFetch";
import {
  PageHeader,
  PageTabs,
  SummaryStrip,
  EmptyState,
} from "@/components/Workspace";
import { Panel } from "@/components/DesignSystem";
import { Button } from "@/components/beui/button";
import { Input } from "@/components/beui/input";
import { useToast } from "@/components/beui/toast";
import { ErrorBlock, LoadingBlock } from "@/components/ui";

export function Todos() {
  const { user } = useAuth();
  const isAdmin = user?.role === "admin";
  const { showToast } = useToast();
  const { data, error, loading, reload } = useFetch<{ todos: Todo[] }>(
    "/todos",
  );
  const hubTasks = useFetch<{ todos: Todo[] }>(
    isAdmin ? "/todos?scope=hub" : null,
  );
  const [filter, setFilter] = useState("open");
  const [busy, setBusy] = useState(false);
  const [text, setText] = useState("");
  const [assignTo, setAssignTo] = useState<"admin" | "hub">("admin");

  async function act(job: () => Promise<unknown>) {
    if (busy) return;
    setBusy(true);
    try {
      await job();
      await reload();
    } catch (error) {
      showToast({
        title: error instanceof Error ? error.message : "Could not save task",
        status: "error",
      });
    } finally {
      setBusy(false);
    }
  }

  function add() {
    if (!text.trim() || busy) return;
    void act(async () => {
      await api.post("/todos", {
        text: text.trim(),
        ...(isAdmin ? { assignTo } : {}),
      });
      setText("");
      if (isAdmin && assignTo === "hub") await hubTasks.reload();
      showToast({
        title: assignTo === "hub" && isAdmin ? "Task assigned to hub staff" : "Task added",
        status: "success",
      });
    });
  }

  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  const visible = data.todos.filter(
    (task) => filter === "all" || (filter === "done" ? task.done : !task.done),
  );
  const completed = data.todos.filter((task) => task.done).length;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Tasks"
        description="Manage operational follow-ups. Hub steps are added automatically and close when the shipment moves on."
      />
      <SummaryStrip
        items={[
          {
            label: "Open tasks",
            value: data.todos.length - completed,
            description: "Work still to complete",
          },
          {
            label: "Completed",
            value: completed,
            description: "Finished follow-ups",
          },
          {
            label: "Total tasks",
            value: data.todos.length,
            description: "Manual and system tasks",
          },
        ]}
      />
      <Panel
        title="Add a task"
        description={
          isAdmin
            ? "Add a task for yourself, or assign it to Dhaka hub staff."
            : "Write a clear action for the next person working on it."
        }
      >
        <form
          className="flex flex-wrap items-end gap-4"
          onSubmit={(event) => {
            event.preventDefault();
            add();
          }}
        >
          <Input
            className="min-w-0 flex-1 basis-64"
            label="Task description"
            placeholder="What needs to happen next?"
            value={text}
            onChange={setText}
            disabled={busy}
            required
          />
          {isAdmin && (
            <label className="text-xs font-medium text-muted-foreground">
              Assign to
              <select
                aria-label="Assign task to"
                className="mt-2 h-10 rounded-md border border-border bg-card px-3 text-sm text-foreground"
                value={assignTo}
                disabled={busy}
                onChange={(event) => setAssignTo(event.target.value as "admin" | "hub")}
              >
                <option value="admin">Admin</option>
                <option value="hub">Hub staff</option>
              </select>
            </label>
          )}
          <Button type="submit" disabled={busy || !text.trim()}>
            {busy ? "Saving…" : assignTo === "hub" && isAdmin ? "Assign task" : "Add task"}
          </Button>
        </form>
      </Panel>
      <PageTabs
        value={filter}
        onChange={setFilter}
        items={[
          { value: "open", label: "Open tasks" },
          { value: "done", label: "Completed" },
          { value: "all", label: "All tasks" },
        ]}
      />
      <Panel
        title={
          filter === "done"
            ? "Completed tasks"
            : filter === "all"
              ? "All tasks"
              : "Open tasks"
        }
        description={`${visible.length} ${visible.length === 1 ? "task" : "tasks"} in this view`}
      >
        {!visible.length ? (
          <EmptyState
            title={
              filter === "done" ? "No completed tasks" : "No tasks in this view"
            }
            description={
              filter === "open"
                ? "You are caught up. Add a task when something needs follow-up."
                : "Tasks matching this view will appear here."
            }
          />
        ) : (
          <ul
            className="divide-y divide-border"
            aria-label="Task list"
            aria-busy={busy}
          >
            {visible.map((task) => (
              <li key={task.id} className="flex items-start gap-3 py-4">
                <input
                  id={`task-${task.id}`}
                  type="checkbox"
                  checked={task.done}
                  disabled={busy || !!task.href}
                  onChange={() =>
                    void act(() => api.post(`/todos/${task.id}/toggle`))
                  }
                  className="mt-1 size-4 shrink-0 cursor-pointer accent-primary disabled:cursor-default"
                  aria-label={`${task.done ? "Reopen task" : "Complete task"}: ${task.text}`}
                />
                <div className="min-w-0 flex-1">
                  <label
                    htmlFor={`task-${task.id}`}
                    className={`block cursor-pointer break-words text-sm ${task.done ? "text-muted-foreground line-through" : "text-foreground"}`}
                  >
                    {task.text}
                  </label>
                  <p className="mt-2 text-xs text-muted-foreground">
                    {task.href === "/review"
                      ? "Completes automatically when the receipt is reviewed"
                      : task.href
                        ? "Completes automatically when this hub step is done"
                        : task.auto
                          ? "Created automatically"
                          : "Team task"}
                  </p>
                </div>
                {task.href && !task.done && (
                  <Link
                    className="text-sm text-primary underline"
                    to={task.href}
                  >
                    {task.href === "/review" ? "Review payment" : "Open shipment"}
                  </Link>
                )}
                <span className="shrink-0 text-xs text-muted-foreground">
                  {task.done ? "Completed" : "Open"}
                </span>
              </li>
            ))}
          </ul>
        )}
      </Panel>
      {isAdmin && (
        <Panel
          title="Hub tasks"
          description="Automatic Dhaka hub steps and tasks assigned to hub staff. They close when the shipment step is finished."
        >
          {hubTasks.error ? (
            <ErrorBlock message={hubTasks.error} />
          ) : hubTasks.loading || !hubTasks.data ? (
            <LoadingBlock />
          ) : (
            <HubTaskList tasks={hubTasks.data.todos} />
          )}
        </Panel>
      )}
    </div>
  );
}

function HubTaskList({ tasks }: { tasks: Todo[] }) {
  const open = tasks.filter((task) => !task.done);
  if (!open.length) {
    return (
      <EmptyState
        title="No open hub tasks"
        description="Hub steps appear here when a shipment reaches Dhaka handling, and assigned tasks appear after you assign them."
      />
    );
  }
  return (
    <ul className="divide-y divide-border" aria-label="Hub task list">
      {open.map((task) => (
        <li key={task.id} className="flex items-start gap-3 py-4">
          <div className="min-w-0 flex-1">
            <p className="break-words text-sm text-foreground">{task.text}</p>
            <p className="mt-2 text-xs text-muted-foreground">
              {task.href
                ? "Completes automatically when this hub step is done"
                : "Assigned to hub staff"}
            </p>
          </div>
          {task.href && (
            <Link className="text-sm text-primary underline" to={task.href}>
              Open shipment
            </Link>
          )}
          <span className="shrink-0 text-xs text-muted-foreground">Open</span>
        </li>
      ))}
    </ul>
  );
}
