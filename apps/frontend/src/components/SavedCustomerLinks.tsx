import { Copy, ExternalLink, Link2 } from "lucide-react";
import { Button } from "@/components/beui/button";
import { useToast } from "@/components/beui/toast";
import { fmtDate } from "@/lib/format";

export type SavedCustomerLink = {
  includesInvoice?: boolean;
  id: string;
  url: string | null;
  status: "active" | "expired" | "revoked";
  createdAt: string;
  expiresAt: string;
};
export function SavedCustomerLinks({ links }: { links: SavedCustomerLink[] }) {
  const { showToast } = useToast();
  return (
    <section className="saved-customer-links" aria-label="Saved customer links">
      <header>
        <div>
          <h3>Saved customer links</h3>
          <p>Links stay here after you close this screen.</p>
        </div>
        <span>{links.length}</span>
      </header>
      {!links.length ? (
        <div className="saved-links-empty">
          <Link2 size={22} />
          <p>Generated customer links will be saved here.</p>
        </div>
      ) : (
        <div className="saved-links-list">
          {links.map((link) => (
            <article key={link.id} className="saved-link-card">
              <div className="saved-link-meta">
                <span className={`saved-link-status ${link.status}`}>
                  {link.status === "active"
                    ? "Active"
                    : link.status === "expired"
                      ? "Expired"
                      : "Revoked"}
                </span>
                <span>
                  Created {fmtDate(link.createdAt)} · Expires{" "}
                  {fmtDate(link.expiresAt)}
                </span>
              </div>
              {link.includesInvoice !== undefined && (
                <p className="saved-link-content">
                  {link.includesInvoice
                    ? "Tracking + invoice"
                    : "Tracking only"}
                </p>
              )}
              {link.url ? (
                <>
                  <input
                    aria-label="Saved customer link"
                    readOnly
                    value={link.url}
                    onFocus={(event) => event.target.select()}
                  />
                  <div className="saved-link-actions">
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={() =>
                        void navigator.clipboard
                          .writeText(link.url!)
                          .then(() =>
                            showToast({
                              title: "Link copied",
                              status: "success",
                            }),
                          )
                          .catch(() =>
                            showToast({
                              title: "Select and copy the link above",
                              status: "error",
                            }),
                          )
                      }
                    >
                      <Copy size={14} />
                      Copy link
                    </Button>
                    {link.status === "active" && (
                      <a href={link.url} target="_blank" rel="noreferrer">
                        Open customer page
                        <ExternalLink size={14} />
                      </a>
                    )}
                  </div>
                </>
              ) : (
                <p className="saved-link-unavailable">
                  This older link cannot be copied. Generate a new saved link.
                </p>
              )}
            </article>
          ))}
        </div>
      )}
    </section>
  );
}
