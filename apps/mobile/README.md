# SBExpress mobile

Flutter app for Admin and Hub Manager. It talks to the API on branch `cursor/hub-api-upload-fixes-6df5` (SBExpress PR #1). After that PR merges, point `API_BASE_URL` at the merged API. The parsers stay on these DTO rules.

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://localhost:3002
```

Android emulator: `http://10.0.2.2:3002`. Debug Android allows cleartext so a local API works.

## Release transport and session

`API_BASE_URL` defaults to `http://localhost:3002` for debug on this machine. Debug builds may use `http` only for `localhost`, `127.0.0.1`, `::1`, and the emulator host `10.0.2.2`. Release builds refuse every non-https origin, including localhost. A release build needs `--dart-define=API_BASE_URL=https://...`.

Any `401` clears the saved session and returns to login. Screens that were open are discarded. The client does not call logout for that path, because logout would `401` again.

The session token is stored with pinned secure-storage options (encrypted shared preferences, AES-GCM, keychain `first_unlock_this_device`, not iCloud-synced). Android backup and device-transfer rules exclude the `sbexpress_secure` preferences file so the token is not copied off the device.

## Android release signing

Release builds do not ship with the debug key. Debug and profile builds keep the debug signing config. A release assemble fails until a keystore is present. That keystore is a Nearo-provided CI secret and is not in this repo. Provide either:

- `apps/mobile/android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`), or
- `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`

`storeFile` is relative to `apps/mobile/android/` unless the path is absolute. See `android/key.properties.example`. Do not commit `key.properties` or the `.jks`.

## This slice

| Screen | Who | Status |
|---|---|---|
| 7 Login | All | Email + password. Role comes from `POST /api/auth/login`. No role picker. This API has no OTP. |
| 1 Hub dashboard | Hub | `GET /api/dashboard/hub`. Teal “আজকের বাকি কাজ” hero with weigh, pack, and courier → dispatch → handover counts. |
| 2 Shipments | Hub | `GET /api/shipments`, parsed with the hub DTO. |
| 3 Shipment process | Hub | weigh → pack → courier → dispatch → handover, in that order. |
| 4 Hub tasks | Hub | `GET /api/todos`. Auto steps open the shipment. Manual notes can be completed. |
| 6 Payment review | Admin | `GET /api/review`, approve (idempotency key) and reject. Screenshot is optional. |
| 9 Shipment detail | Admin | Summary, bill, photos. Tracking-only share. Invoice-included share is not in this slice. |
| 18 More | Both | Role badge and logout. Other entries are labeled stubs. |

Stubbed, with no invented data: 5 IMEI guide frame, 8 intake, 10 issue-and-share, 11 flights, 12 flyer documents, 13 customers, 14 finance snapshot, 15 task assignment, 16 settings, 17 media browser (shipment photos themselves are live).

## DTO rules

Hub models do not have money fields: `charge`, `billAmount`, `discountAmount`, `paidAmount`, `dueAmount`, `payStatus`, `payMethod`, rates, costs, invoice, or payments. They also drop `paymentTerms`, `freeOfCharge`, and `receiptStatus` when a snapshot still sends them. Hub UI shows status, weight, package count, device count, whether a photo exists, and courier ref. Customer names are not shown.

Admin models require the money fields. A hub-shaped payload missing `charge` is rejected instead of being shown as zero.

The hub chain label is fixed: `weigh → pack → courier → dispatch → handover`. Pickup still lists dispatch, marked not applicable, and does not reorder the other steps. Receiving a customs-cleared shipment is the gate into that chain, not a replacement for weigh.

## Photos

Before upload, photos are converted to JPEG, longest edge 2000px, quality 80. Files larger than 25 MB are rejected before decode. HEIC goes through the platform converter first, then the same JPEG rules. EXIF is dropped by re-encoding; the server strips it again. The picker temp file, which still has the original EXIF, is deleted after the upload finishes or fails. Presigned upload URLs must be `https` (debug may use `http` on loopback only). A failed upload retries the same bytes. A failed receipt screenshot does not block payment. Storage, network/CORS, expiry, and format errors stay distinct.

## Screenshots

`docs/screenshots/` shows Login, the hub dashboard with the teal “আজকের বাকি কাজ” hero, Shipments, and Admin payment review. They were captured from Chrome running this UI. This environment has no Android emulator, so the shots are not from an emulator. The API behind them was a local fixture with the same DTO shapes, including money keys the hub screens ignore.
