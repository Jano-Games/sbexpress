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

The session token is stored with pinned secure-storage options (AES-GCM, storage namespace `sbexpress_secure`, keychain `first_unlock_this_device`, not iCloud-synced). Android backup and device-transfer rules exclude that preferences file, its key file, and its configuration file so the token is not copied off the device.

## Android release signing

Release builds do not use the debug key. Debug and profile builds keep debug signing. `assembleRelease` fails until a keystore is configured. The keystore and passwords stay out of git (`*.jks`, `*.keystore`, and `key.properties` are ignored).

Gradle reads, in order:

1. `MOBILE_KEYSTORE_PASSWORD`, when set, is used for both the store password and the key password.
2. Otherwise `ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEY_PASSWORD`, then `storePassword` and `keyPassword` in `android/key.properties`.
3. The keystore path from `ANDROID_KEYSTORE_PATH`, then `storeFile`. A relative `storeFile` is resolved from `apps/mobile/android/`.
4. The alias from `ANDROID_KEY_ALIAS`, then `keyAlias`. If a path is set and no alias is given, the alias is `sbexpress`.

Create a keystore once and keep the file with the owner. Do not commit it:

```bash
keytool -genkeypair -v \
  -keystore "$HOME/sbexpress-release.keystore" \
  -alias sbexpress \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass:env MOBILE_KEYSTORE_PASSWORD \
  -keypass:env MOBILE_KEYSTORE_PASSWORD \
  -dname "CN=Sichuan Bangla Express, OU=Mobile, O=SBExpress, C=BD"
```

Then build a signed release APK. The API origin must be https:

```bash
export ANDROID_KEYSTORE_PATH="$HOME/sbexpress-release.keystore"
export ANDROID_KEY_ALIAS=sbexpress
export MOBILE_KEYSTORE_PASSWORD='the owner password'
cd apps/mobile
flutter build apk --release --dart-define=API_BASE_URL=https://api.example
```

`android/key.properties.example` shows the file form. Copy it to `android/key.properties` only on the machine that signs the release.

## Screens

Bottom navigation stays four tabs: হোম, Shipment, কাজ, আরও. Admin and hub see different homes and a different আরও directory. Money, customer names, invoices and settings are absent from the hub role, matching the hub API.

| Screen | Who | API |
|---|---|---|
| Login | All | `POST /api/auth/login`. Email and password. Role comes from the account. |
| Hub home | Hub | `GET /api/dashboard/hub`. Teal “আজকের বাকি কাজ” hero. |
| Admin home | Admin | `GET /api/dashboard/overview`. Review count, cash, unpaid, next flight, active shipments. |
| Shipments | Both | `GET /api/shipments`. Hub rows drop money and names. Admin can start intake. |
| Shipment process | Hub | Receive, weigh, pack, courier, dispatch, handover. IMEI photos when the shipment has devices. |
| Shipment detail | Admin | Summary, bill, photos. Issue or edit the invoice, view and share the PDF, record a payment into an existing ledger account. |
| Tasks | Both | `GET/POST /api/todos`. Admin can assign a note to hub. |
| Intake | Admin | Customers, categories, optional flight and flyer, `POST /api/shipments`. |
| Flights | Admin | List, detail, create, assign a flyer. Ticket cash is not posted from the phone. |
| Flyers | Admin | Profile, flights, document list, JPEG upload, verify. PDF documents open in the app and can still be shared. |
| Customers | Admin | List, detail, create, statement links, credit, and account activity with reversal. Balances come from issued invoices. |
| Finance | Admin | Cash, transfers, income and expenses, ledger, reconciliation, and a new fund. A non-zero opening balance is capital in the ledger, not income. |
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
