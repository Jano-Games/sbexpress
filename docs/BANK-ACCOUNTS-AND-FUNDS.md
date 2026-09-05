# Bank accounts and funds

Bank payment methods and Finance bank funds now have a persistent one-to-one link (`PayMethod.accountId`). The Account row remains the single source of truth for the balance.

- Settings → Payment methods → Bank account creates a BDT bank fund with zero opening balance. Its generated fund name includes the bank name and account number.
- Finance → Add account → Bank account requires bank name, account number and account holder. It creates the account and payment method in one transaction and preserves the supplied opening balance/currency.
- Ordinary cash, wallet and reserve funds do not become customer bank payment methods.
- Bank name/account number duplicates are rejected across both creation paths. A second failed creation does not leave an extra fund.
- Editing bank details keeps the existing fund link and balance. The fund name stays stable for existing ledger and receipt references.
- Hiding a payment method does not hide or change its financial balance. Deleting a payment method retains the financial account and history.
- Tracking and monthly-statement receipt submission resolve the exact linked receiving fund; two accounts at the same bank are not confused. Public responses do not expose the internal account link.

Migration: `20260905100000_link_bank_funds` (additive). Applied to the local application and isolated audit databases. No existing bank records required backfilling in the local database at deployment.

Validation: 58 tests passed, frontend/backend typechecks passed, production build passed. Browser checks created banks through both actual forms in the isolated audit database and verified the corresponding entry and balance in the other screen. Main business data was not used for test mutations. Pre-migration backup: `N:\Codex\mamun-before-bank-link-20260905.dump`.

## Mobile banking and existing funds — follow-up fix

The initial implementation covered only bank_account payment methods. Mobile banking (including bKash/Nagad) now uses the same one-to-one account link. Finance mobile/wallet creation collects provider and number and creates the corresponding payment method. Settings-created mobile methods create a fund; unambiguous existing legacy provider funds are reused without changing their balances. Public mobile receipts resolve the exact linked fund.

Existing generic funds can be converted with Finance → Accounts & funds → Edit / link payment method. Select Bank account or Mobile money and enter the actual account details. The existing fund identity, currency and balance remain unchanged. Unknown bank account numbers are never invented.

Finance account cards now include Delete. Only unused, zero-balance accounts can be deleted, after UI confirmation. A linked payment method is removed in the same transaction. Nonzero balances, payments, expenses, transfers, refunds and receipt history prevent deletion. The endpoint requires admin authorization.

Existing local bKash method was repaired with scripts/link-payment-funds.ts after backup. One method was linked; UCB Current was not guessed or automatically converted. Backup: N:\Codex\mamun-before-mobile-link-20260905.dump.

Validation: 61 tests passed; typechecks and production build passed. Isolated browser tests verified fund-to-bank conversion, its appearance in Settings, confirmed deletion of both linked records, and Finance mobile creation appearing as a payment method.
