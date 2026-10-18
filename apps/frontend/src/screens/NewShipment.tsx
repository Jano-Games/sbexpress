import { Link, useNavigate } from "react-router-dom";
import { PageHeader } from "@/components/Workspace";
import { NewShipmentModal } from "@/modals/NewShipmentModal";
import { Button } from "@/components/beui/button";

export function NewShipment() {
  const navigate = useNavigate();
  return (
    <div className="space-y-5">
      <Link
        to="/shipments"
        className="inline-block text-sm text-muted-foreground hover:text-primary"
      >
        ← Shipments
      </Link>
      <PageHeader
        title="New shipment"
        description="Enter customer, cargo and billing information in one place."
        actions={
          <Button variant="secondary" onClick={() => navigate("/shipments")}>
            Cancel
          </Button>
        }
      />
      <NewShipmentModal
        embedded
        open
        onClose={() => {}}
        onDone={(code) => navigate(`/shipments/${encodeURIComponent(code)}`)}
      />
    </div>
  );
}
