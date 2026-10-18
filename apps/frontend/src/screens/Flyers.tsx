import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Plus } from "lucide-react";
import { useFetch } from "@/state/useFetch";
import type { Flyer } from "@/api/types";
import { Button } from "@/components/beui/button";
import { ErrorBlock, LoadingBlock } from "@/components/ui";
import {
  PageHeader,
  PageTabs,
  RecordList,
  SummaryStrip,
  usePageSection,
} from "@/components/Workspace";
import { AddFlyerModal } from "@/modals/AddFlyerModal";

function documentsReviewed(flyer: Flyer) {
  return (
    flyer.documentCount > 0 &&
    flyer.verifiedDocumentCount === flyer.documentCount
  );
}

export function Flyers() {
  const navigate = useNavigate();
  const { data, error, loading, reload } = useFetch<{ flyers: Flyer[] }>(
    "/flyers?includeArchived=1",
  );
  const [adding, setAdding] = useState(false);
  const [view, setView] = usePageSection(
    "all",
    ["all", "ready", "missing", "archived"],
    "view",
  );
  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  const complete = data.flyers.filter(
    (f) => !f.archivedAt && documentsReviewed(f),
  ).length;

  return (
    <div>
      <PageHeader
        title="Flyers"
        description="Manage traveler profiles, contact details and document readiness."
        actions={
          <Button onClick={() => setAdding(true)}>
            <Plus size={16} /> Add flyer
          </Button>
        }
      />
      <SummaryStrip
        items={[
          { label: "Registered flyers", value: data.flyers.length },
          { label: "Files reviewed", value: complete },
          {
            label: "Needs documents / review",
            value: data.flyers.filter((f) => !f.archivedAt).length - complete,
          },
        ]}
      />
      <RecordList
        views={
          <PageTabs
            value={view}
            onChange={setView}
            items={[
              { value: "all", label: "Active flyers" },
              { value: "archived", label: "Archived" },
              { value: "missing", label: "Needs documents / review" },
              { value: "ready", label: "Files reviewed" },
            ]}
          />
        }
        rows={data.flyers.filter((f) =>
          view === "archived"
            ? !!f.archivedAt
            : !f.archivedAt &&
              (view === "all" ||
                (view === "ready"
                  ? documentsReviewed(f)
                  : !documentsReviewed(f))),
        )}
        recordKey={(f) => f.name}
        href={(f) => `/flyers/${encodeURIComponent(f.name)}`}
        searchText={(f) =>
          `${f.name} ${f.university} ${f.program} ${f.cnPhone} ${f.bdPhone} ${f.wechat}`
        }
        placeholder="Search flyer, university or phone"
        emptyTitle={
          data.flyers.length ? "No flyers in this view" : "No flyers registered"
        }
        emptyDescription={
          data.flyers.length
            ? "Choose another document filter to see your flyers."
            : "Register a flyer to keep their contact information and assign flights."
        }
        columns={[
          {
            label: "Flyer",
            render: (f) => `${f.name}${f.archivedAt ? " · Archived" : ""}`,
          },
          {
            label: "University",
            render: (f) => (
              <div>
                {f.university}
                <p className="mt-1 text-xs text-muted-foreground">
                  {f.program} · {f.batch}
                </p>
              </div>
            ),
          },
          { label: "China phone", render: (f) => f.cnPhone },
          { label: "Bangladesh phone", render: (f) => f.bdPhone },
          {
            label: "Document status",
            render: (f) => (
              <span
                className={
                  documentsReviewed(f)
                    ? "text-success"
                    : "text-muted-foreground"
                }
              >
                {f.documentCount
                  ? `${f.documentCount} files · ${f.verifiedDocumentCount} verified`
                  : "No documents"}
              </span>
            ),
          },
        ]}
      />
      <AddFlyerModal
        open={adding}
        onClose={() => setAdding(false)}
        onDone={(name) =>
          navigate(`/flyers/${encodeURIComponent(name)}?section=documents`)
        }
      />
    </div>
  );
}
