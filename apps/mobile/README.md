# SBExpress mobile

Android Flutter app for Admin and Hub Manager. It uses the same bearer session and JSON API as the web workspace. iOS is not a target.

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3002
```

Android emulator reaches the host API at `http://10.0.2.2:3002`. A device on the same network needs the computer's LAN address. Debug Android allows cleartext so a local API works. `flutter run` without a device id targets the connected Android emulator or phone.

A debug APK (signed with the debug key):

```bash
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3002
```

## Release transport and session

`API_BASE_URL` defaults to `http://localhost:3002` for debug on this machine. Debug builds may use `http` only for `localhost`, `127.0.0.1`, `::1`, and the emulator host `10.0.2.2`. Release builds refuse every non-https origin, including localhost. A release build needs `--dart-define=API_BASE_URL=https://...`.

Any `401` clears the saved session and returns to login. Screens that were open are discarded. The client does not call logout for that path, because logout would `401` again.

The session token is stored with pinned secure-storage options (encrypted shared preferences, AES-GCM, keychain `first_unlock_this_device`, not iCloud-synced). Android backup and device-transfer rules exclude the `sbexpress_secure` preferences file so the token is not copied off the device.

## Android release signing

Release builds do not ship with the debug key. Debug and profile builds keep the debug signing config. A release assemble fails until a keystore is present. That keystore is a Nearo-provided CI secret and is not in this repo. Provide either:

- `apps/mobile/android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`), or
- `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`

`storeFile` is relative to `apps/mobile/android/` unless the path is absolute. See `android/key.properties.example`. Do not commit `key.properties` or the `.jks`.

## Screens

Bottom navigation stays four tabs: হোম, Shipment, কাজ, আরও. Admin and hub see different homes and a different আরও directory. Money, customer names, invoices and settings are absent from the hub role, matching the hub API.

| Screen | Who | API |
|---|---|---|
| Login | All | `POST /api/auth/login`. Email and password. Role comes from the account. |
| Hub home | Hub | `GET /api/dashboard/hub`. Teal “আজকের বাকি কাজ” hero. |
| Admin home | Admin | `GET /api/dashboard/overview`. Review count, cash, unpaid, next flight, active shipments. |
| Shipments | Both | `GET /api/shipments`. Hub rows drop money and names. Admin can start intake. |
| Shipment process | Hub | Receive, weigh, pack, courier, dispatch, handover. IMEI photos when the shipment has devices. |
| Shipment detail | Admin | Summary, bill, photos. Issue the calculated invoice, share tracking or invoice, record a payment into an existing ledger account. |
| Tasks | Both | `GET/POST /api/todos`. Admin can assign a note to hub. |
| Intake | Admin | Customers, categories, optional flight and flyer, `POST /api/shipments`. |
| Flights | Admin | List, detail, create, assign a flyer. Ticket cash is not posted from the phone. |
| Flyers | Admin | Profile, flights, document list, JPEG upload, verify. |
| Customers | Admin | List, detail, create. Balances come from issued invoices. |
| Finance | Admin | `GET /api/finance`. Read-only cash, results, receivables and accounts. |
| Settings | Admin | Setup status, confirm the CNY rate, show pay methods and staff. No new bank details are typed here. |
| IMEI guide | Both | Camera frame, then `POST /device-photo`. The photo stays private. |
| Media | Both | Pick a shipment and open its photos. |
| Payment review | Admin | Approve with an idempotency key, or reject. |

Empty rates and empty ticket costs save as zero. The app does not invent an account name, a payment amount, or a bank number.

## DTO rules

Hub models do not have money fields: `charge`, `billAmount`, `discountAmount`, `paidAmount`, `dueAmount`, `payStatus`, `payMethod`, rates, costs, invoice, or payments. They also drop `paymentTerms`, `freeOfCharge`, and `receiptStatus` when a snapshot still sends them. Hub UI shows status, weight, package count, device count, whether a photo exists, and courier ref. Customer names are not shown.

Admin models require the money fields. A hub-shaped payload missing `charge` is rejected instead of being shown as zero.

The hub chain label is fixed: `weigh → pack → courier → dispatch → handover`. Pickup still lists dispatch, marked not applicable, and does not reorder the other steps. Receiving a customs-cleared shipment is the gate into that chain, not a replacement for weigh.

## Photos

Before upload, photos are converted to JPEG, longest edge 2000px, quality 80. Files larger than 25 MB are rejected before decode. HEIC goes through the platform converter first, then the same JPEG rules. EXIF is dropped by re-encoding; the server strips it again. The picker temp file, which still has the original EXIF, is deleted after the upload finishes or fails. Presigned upload URLs must be `https` (debug may use `http` on loopback only). A failed upload retries the same bytes. A failed receipt screenshot does not block payment. Storage, network/CORS, expiry, and format errors stay distinct.

## Screenshots

`docs/screenshots/` shows the login screen, the hub “আজকের বাকি কাজ” hero, the shipment list, and admin payment review. Later captures of the admin home, flights, customers and finance snapshot are widget renders of the same UI against fixture JSON with the real DTO shapes. They are not from an Android emulator when the environment has no emulator. Hub fixtures may still contain money keys; the hub screens do not render them.
