# Financial reporting consistency

Dashboard and Finance use shared/financialSummary.ts for available funds, cash movement, business net profit, supplier receivables (including monthly customers), ticket and shipment payables, and refunds. Dashboard money totals are read fresh instead of serving a cached independent calculation.

Business net profit = net shipment billing + flyer contributions + other business income - full ticket costs - recorded shipment transport/customs costs - all additional recorded expenses, including salary, rent (Others), packaging and courier. Capital deposits and internal transfers are not profit. Outstanding recorded shipment costs reduce profit before payment; their costField settlement entries do not count as another expense. Invoice discounts and credit adjustments reduce billing. Customer credit refunds reduce cash, not profit a second time.

Flight profit covers the shipments assigned to that flight and its ticket. General office expenses are deducted at business level. Shipment detail and flight detail share shipmentOperatingCosts. Shipment ticket allocation remains an estimate based on booked weight and capacity; unused capacity remains a cost at flight/business level. These scopes are intentionally distinct.

Period boundaries: shipment billing/base costs use shipment creation date, tickets/contributions use flight date, standalone expenses use their expense date, and cash receipts/refunds use posting dates. Compare the same reporting period. Weekly reporting excludes future dates.

Verified 2026-09-05: 68 backend tests, TypeScript checks, production build; dashboard UI checks at 1440px and 390px. Regression coverage includes salary/rent, additional shipment expenses, capital, internal transfers, monthly receivables, refunds, unpaid costs, and cost settlements without double counting. Aggregate live-data read also confirmed recorded BD courier cost reduces profit while remaining unpaid. No live balances or ledger rows were modified for this audit.

## Shipment expense billing (2026-09-05)

New additional expenses attached to a shipment now also add a customer charge at the same amount. Both the shipment expense endpoint and Finance expenses with a shipment code use the same transaction-safe billing helper. A saved invoice is revised with its discount preserved; if there is no invoice, the current draft is finalized with the new charge. Paid amounts are unchanged and outstanding balances refresh everywhere through the invoice total. Existing costField settlement payments do not add new charges. Historical costs are not retroactively billed by this change.

Tracking and invoice links show public-safe charge lines, subtotal, discount, total, verified paid amount and remaining due even after payment. A partial payment request remains capped at its issued amount; pending receipts do not reduce the verified balance. Internal expense reasons and account postings are not exposed publicly.

Verification: 70 backend tests passed, including duplicate expense replay, insufficient-funds rollback, discount preservation, invoice revisions, partial links and Finance/tracking agreement. Type checks and build passed; tracking browser checks passed at 1440px and 390px.
