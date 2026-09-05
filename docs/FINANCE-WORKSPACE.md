# Finance workspace

Finance is organized into four sections:

- **Summary:** current funds, customer receivables, unpaid operating costs, period profit, cash movement, follow-up balances and recent transactions. Current balances are labeled separately from period activity.
- **Ledger:** a unified cash ledger of customer/flyer receipts, business income, owner capital, customer advances, expenses, refunds and transfers. Filter by period, account, transaction type or reference/description. Expand an entry for its reference and linked shipment, flight or supplier. Entries are paginated; Export page downloads only the visible page as CSV.
- **Accounts & funds:** current balances in native currency, account creation and direct access to each account's ledger. Historical reconciliation is kept here.
- **Statements:** monthly supplier billing, receipts and outstanding balances, with statement viewing.

Record entry and Move funds open focused dialogs. Supplier and flyer payments remain on their own pages so receipts settle the correct obligations. An expense recorded in the dialog appears in the ledger after saving.

The cash ledger uses actual recorded account amounts, preserving BDT and CNY separately. Transfers create two rows, one per account; filtered totals include those rows. The summary's external cash movement excludes internal transfers. Legacy entries without account snapshots are labeled Unassigned instead of being attributed to an inferred account. This is a cash movement ledger, not a reconstructed double-entry general ledger or certified bank statement.

Validation: 54 backend tests passed, including ledger permissions, period/account/type/search filters, pagination, native currency transfer legs and refunds. Browser checks covered desktop and 390px layouts, search/filter interactions, expense posting, account-to-ledger navigation, fund transfers and monthly statement viewing. All mutations during browser checks used the isolated audit database. No schema migration was needed for this redesign.
