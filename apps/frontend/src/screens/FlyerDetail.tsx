import { FlyerDocuments } from "@/components/FlyerDocuments";
import { useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { api } from "@/api/client";
import { useFetch } from "@/state/useFetch";
import type { FlyerDetail as Detail, FlyerFlight } from "@/api/types";
import { Button } from "@/components/beui/button";
import { useToast } from "@/components/beui/toast";
import { ErrorBlock, LoadingBlock } from "@/components/ui";
import { DetailGrid, Panel, SectionNotice } from "@/components/DesignSystem";
import {
  PageHeader,
  PageTabs,
  RecordList,
  SummaryStrip,
  usePageSection,
} from "@/components/Workspace";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { AddFlightModal } from "@/modals/AddFlightModal";
import { AddFlyerModal } from "@/modals/AddFlyerModal";
import { fmtDate, fmtKg } from "@/lib/format";

function FlightSummary({
  title,
  flight,
}: {
  title: string;
  flight: FlyerFlight | null;
}) {
  return (
    <Panel
      title={title}
      actions={
        flight ? (
          <Link
            className="text-sm font-medium text-primary"
            to={`/flights/${encodeURIComponent(flight.code)}`}
          >
            Open flight →
          </Link>
        ) : undefined
      }
    >
      {flight ? (
        <DetailGrid
          items={[
            { label: "Flight", value: flight.code },
            { label: "Departure date", value: fmtDate(flight.date) },
            { label: "Departure time", value: flight.depTime || "—" },
            { label: "Arrival time", value: flight.arrTime || "—" },
            { label: "Booked cargo", value: fmtKg(flight.bookedKg) },
            { label: "Status", value: flight.statusLabel },
          ]}
        />
      ) : (
        <p className="text-sm text-muted-foreground">
          {title === "Next flight"
            ? "No upcoming flight scheduled."
            : "No previous flight recorded."}
        </p>
      )}
    </Panel>
  );
}

export function FlyerDetail() {
  const { name = "" } = useParams();
  const navigate = useNavigate();
  const { showToast } = useToast();
  const { data, error, loading, reload } = useFetch<{ flyer: Detail }>(
    `/flyers/${encodeURIComponent(name)}`,
  );
  const [section, setSection] = usePageSection("profile", [
    "profile",
    "documents",
    "flights",
  ]);
  const [addingFlight, setAddingFlight] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [archiveOpen, setArchiveOpen] = useState(false);
  if (error) return <ErrorBlock message={error} />;
  if (loading || !data) return <LoadingBlock />;
  const flyer = data.flyer;

  return (
    <div>
      <ConfirmDialog
        open={archiveOpen}
        onClose={() => setArchiveOpen(false)}
        title={flyer.archivedAt ? "Restore flyer?" : "Archive flyer?"}
        confirmLabel={flyer.archivedAt ? "Restore" : "Archive"}
        body="Existing flight assignments and settlements remain intact. Archived flyers are excluded from new assignments."
        onConfirm={async () => {
          try {
            await api.post(`/flyers/${encodeURIComponent(name)}/archive`, {
              archived: !flyer.archivedAt,
            });
            await reload();
          } catch (e) {
            showToast({
              title: e instanceof Error ? e.message : "Could not update flyer",
              status: "error",
            });
          }
        }}
      />
      <Link to="/flyers" className="mb-4 inline-block text-sm text-primary">
        ← Flyers
      </Link>
      <PageHeader
        title={flyer.name}
        description="Flyer profile and flight history"
        actions={
          <>
            <Button variant="secondary" onClick={() => setEditOpen(true)}>
              Edit flyer
            </Button>
            <Button variant="secondary" onClick={() => setArchiveOpen(true)}>
              {flyer.archivedAt ? "Restore flyer" : "Archive flyer"}
            </Button>
            {!flyer.archivedAt && (
              <Button onClick={() => setAddingFlight(true)}>Add flight</Button>
            )}
          </>
        }
      />
      {flyer.archivedAt && (
        <SectionNotice>
          This flyer is archived. Their history and settlements are retained.
        </SectionNotice>
      )}
      <SummaryStrip
        items={[
          { label: "Assigned flights", value: flyer.flights.length },
          { label: "Cargo carried", value: fmtKg(flyer.totalKg) },
          {
            label: "Documents",
            value: `${flyer.documentCount} uploaded · ${flyer.verifiedDocumentCount} verified`,
          },
          {
            label: "Next departure",
            value: flyer.nextFlight
              ? fmtDate(flyer.nextFlight.date)
              : "Not scheduled",
          },
        ]}
      />
      <PageTabs
        value={section}
        onChange={setSection}
        items={[
          { value: "profile", label: "Profile" },
          { value: "documents", label: "Documents" },
          { value: "flights", label: "Flights & settlements" },
        ]}
      />

      {section === "profile" && (
        <div className="space-y-5">
          <Panel title="Contact information">
            <DetailGrid
              items={[
                { label: "Full name", value: flyer.name },
                { label: "WeChat ID", value: flyer.wechat },
                {
                  label: "China phone",
                  value: (
                    <>
                      {flyer.cnPhone}
                      {flyer.cnWhatsapp && (
                        <p className="mt-1 text-xs text-muted-foreground">
                          WhatsApp available
                        </p>
                      )}
                    </>
                  ),
                },
                {
                  label: "Bangladesh phone",
                  value: (
                    <>
                      {flyer.bdPhone}
                      {flyer.bdWhatsapp && (
                        <p className="mt-1 text-xs text-muted-foreground">
                          WhatsApp available
                        </p>
                      )}
                    </>
                  ),
                },
                { label: "China address", value: flyer.cnAddress },
                { label: "Bangladesh address", value: flyer.homeAddress },
                { label: "Emergency contact", value: flyer.emergencyContact },
              ]}
            />
          </Panel>
          <Panel title="Education">
            <DetailGrid
              columns={3}
              items={[
                { label: "University", value: flyer.university },
                { label: "Program", value: flyer.program },
                { label: "Batch", value: flyer.batch },
              ]}
            />
          </Panel>
          <Panel
            title="Profile management"
            description="Profiles with assignments, financial history or documents must be archived."
            actions={
              <Button
                variant="danger-outline"
                onClick={() => setDeleteOpen(true)}
              >
                Delete flyer
              </Button>
            }
          >
            <p className="text-sm text-muted-foreground">
              Review linked flights and settlements before removing this
              profile.
            </p>
          </Panel>
        </div>
      )}

      {section === "documents" && (
        <FlyerDocuments key={flyer.name} name={flyer.name} />
      )}

      {section === "flights" && (
        <div className="space-y-5">
          <div className="grid gap-5 lg:grid-cols-2">
            <FlightSummary title="Next flight" flight={flyer.nextFlight} />
            <FlightSummary title="Last flight" flight={flyer.lastFlight} />
          </div>
          <SectionNotice>
            Open a flight to review this flyer’s contribution, payments and
            settlement.
          </SectionNotice>
          <RecordList
            rows={flyer.flights}
            recordKey={(flight) => flight.code}
            href={(flight) => `/flights/${encodeURIComponent(flight.code)}`}
            searchText={(flight) =>
              `${flight.code} ${flight.date} ${flight.statusLabel}`
            }
            placeholder="Search flight code or departure date"
            emptyTitle="No flights assigned"
            emptyDescription="Add a flight for this flyer to start their travel and settlement history."
            columns={[
              { label: "Flight", render: (flight) => flight.code },
              { label: "Departure", render: (flight) => fmtDate(flight.date) },
              { label: "Status", render: (flight) => flight.statusLabel },
              {
                label: "Booked weight",
                align: "right",
                render: (flight) => fmtKg(flight.bookedKg),
              },
              {
                label: "Weight allowance",
                align: "right",
                render: (flight) => fmtKg(flight.spaceKg),
              },
              {
                label: "Device allowance",
                render: (flight) =>
                  `${flight.mobiles} phones · ${flight.laptops} laptops`,
              },
            ]}
          />
        </div>
      )}

      <AddFlightModal
        open={addingFlight}
        onClose={() => setAddingFlight(false)}
        onDone={() => void reload()}
        lockedFlyer={flyer.name}
      />
      <AddFlyerModal
        open={editOpen}
        onClose={() => setEditOpen(false)}
        editing={flyer}
        onDone={(newName) => {
          if (newName !== flyer.name)
            navigate(`/flyers/${encodeURIComponent(newName)}`, {
              replace: true,
            });
          else void reload();
        }}
      />
      <ConfirmDialog
        open={deleteOpen}
        onClose={() => setDeleteOpen(false)}
        title={`Delete flyer ${flyer.name}?`}
        body="Only an unused profile can be deleted. Archive a flyer with documents, assignments or financial history."
        onConfirm={async () => {
          try {
            await api.delete(`/flyers/${encodeURIComponent(flyer.name)}`);
            showToast({ title: `${flyer.name} deleted`, status: "success" });
            navigate("/flyers");
          } catch (e) {
            showToast({
              title: e instanceof Error ? e.message : "Failed",
              status: "error",
            });
          }
        }}
      />
    </div>
  );
}
