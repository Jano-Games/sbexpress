# Flight ticket payments

Flight creation no longer requires a fund. Leaving the optional account blank saves the booking and ticket cost as unpaid without creating an expense or changing a fund balance. Flyer contribution remains actual ticket cost minus agency share.

To pay later, open the flight, choose Pay ticket from a fund, select the account in Edit flight, and save. Selecting an account settles the outstanding ticket amount. Repeating the same settlement does not add another payment. Cost edits without an account do not move money; a reduction below the amount paid creates an outstanding refund until a receiving account is selected.

The flight detail shows ticket paid, remaining due, or refund due. Finance follow-up balances show flight ticket payables and outstanding ticket refunds separately. Payment and refund entries retain the exact account and currency posting snapshots.

The form checks account balance before paid submission, allows unpaid submission even without available funds, retains the draft on server errors, and prevents simultaneous duplicate submissions.

Validation (2026-09-05): production build passed; 65 backend tests passed using the isolated audit database; headless browser checks passed for no-fund save payload, insufficient balance, clearing fund selection, duplicate submit protection, preserved draft on error, and selected-account retry. No schema migration required.
