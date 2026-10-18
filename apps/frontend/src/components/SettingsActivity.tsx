import { useState } from "react";
import { useFetch } from "@/state/useFetch";
import { Panel } from "./DesignSystem";
import { Button } from "./beui/button";
import { ErrorBlock, LoadingBlock } from "./ui";
import { fmtLogAt } from "@/lib/format";
type Event = {
  id: string;
  actorId: string;
  actorName: string;
  action: string;
  entity: string;
  details: unknown;
  before: unknown;
  createdAt: string;
};
export function SettingsActivity() {
  const [page, setPage] = useState(1);
  const { data, error, loading } = useFetch<{
    events: Event[];
    total: number;
    limit: number;
  }>(`/settings/activity?page=${page}`);
  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  return (
    <Panel
      title="Team activity"
      description="Named staff activity recorded from this update onward. Earlier shipment logs remain in each shipment."
    >
      <div className="data-table">
        <table>
          <thead>
            <tr>
              <th>When</th>
              <th>Person</th>
              <th>Action / record</th>
              <th>Changes</th>
            </tr>
          </thead>
          <tbody>
            {data.events.map((e) => (
              <tr key={e.id}>
                <td className="whitespace-nowrap">{fmtLogAt(e.createdAt)}</td>
                <td>
                  <strong>{e.actorName}</strong>
                  <p className="text-xs text-muted-foreground">
                    ID: {e.actorId.slice(-8)}
                  </p>
                </td>
                <td>
                  <strong>{e.action}</strong>
                  <p className="break-all text-xs text-muted-foreground">
                    {e.entity}
                  </p>
                </td>
                <td>
                  <details>
                    <summary className="cursor-pointer text-primary">
                      View recorded values
                    </summary>
                    <div className="max-w-lg space-y-3 py-3">
                      <h4 className="font-medium">Submitted changes</h4>
                      <pre className="whitespace-pre-wrap break-all text-xs">
                        {JSON.stringify(e.details, null, 2)}
                      </pre>
                      {e.before != null && (
                        <>
                          <h4 className="font-medium">Before change</h4>
                          <pre className="whitespace-pre-wrap break-all text-xs">
                            {JSON.stringify(e.before, null, 2)}
                          </pre>
                        </>
                      )}
                    </div>
                  </details>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {!data.events.length && (
        <p className="py-5 text-sm text-muted-foreground">
          New staff actions will appear here.
        </p>
      )}
      <div className="mt-4 flex items-center justify-between">
        <span className="text-sm">
          {data.total} events · Page {page}
        </span>
        <div className="flex gap-2">
          <Button
            variant="secondary"
            disabled={page === 1}
            onClick={() => setPage((n) => n - 1)}
          >
            Previous
          </Button>
          <Button
            variant="secondary"
            disabled={page * data.limit >= data.total}
            onClick={() => setPage((n) => n + 1)}
          >
            Next
          </Button>
        </div>
      </div>
    </Panel>
  );
}
