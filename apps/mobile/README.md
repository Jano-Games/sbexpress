# SBExpress mobile

Android Flutter app for Admin and Hub Manager. It uses the same bearer session and JSON API as the web workspace. iOS is not a target.

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3002
```

Android emulator reaches the host API at `http://10.0.2.2:3002`. Physical phones use ADB reverse as described below. Debug HTTP is limited to loopback/emulator hosts; a plain HTTP LAN address is rejected by the app. `flutter run` without a device id targets the connected Android emulator or phone.

## Physical Android phone on Windows

Keep the main backend running on the PC at `127.0.0.1:3002`, with the project's Docker PostgreSQL and Redis services running. The Vite website port is not the mobile API.

On Android 11+, connect the phone and PC to the same network, enable Developer options and Wireless debugging, then open Pair device with pairing code. In PowerShell, set the ADB path for your Android SDK and replace the example placeholders with the phone's actual values:

```powershell
$adb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
& $adb pair 'PHONE_IP:PAIR_PORT'
# Enter the code while the phone's pairing dialog remains open.
# CONNECT_PORT comes from the main Wireless debugging screen, not the pairing dialog.
& $adb connect 'PHONE_IP:CONNECT_PORT'
& $adb devices -l
```

USB debugging with an authorized USB cable can be used instead of wireless pairing. Copy the phone's exact device ID from `adb devices -l` or `flutter devices`:

```powershell
cd N:\CCD\Mamun\apps\mobile
flutter pub get
$phoneId = 'DEVICE_ID'
& $adb -s $phoneId reverse tcp:3002 tcp:3002
flutter run -d $phoneId --dart-define=API_BASE_URL=http://127.0.0.1:3002
```

Reapply the reverse mapping after reconnecting. This local debug build needs the PC backend and the ADB connection; a standalone release uses the deployed HTTPS API.

### Windows Kotlin cross-drive cache failure

If the project is on `N:` and Pub cache is on `C:`, Kotlin incremental compilation can fail with `this and base files have different roots` / `Could not close incremental caches`. The project's `android/gradle.properties` disables Kotlin incremental compilation with `kotlin.incremental=false`. This affects Kotlin recompilation speed, not app behavior or Dart hot reload. Gradle's task up-to-date checks remain available.

After an already failed build, run `flutter clean` once, then rebuild. Do not delete the global Pub cache, move the project, or downgrade dependencies to fix this cache-path failure. The `flutter_image_compress_common` legacy KGP warning is a separate plugin migration warning and can remain on a successful build. See [Kotlin's incremental compilation documentation](https://kotlinlang.org/docs/gradle-compilation-and-caches.html#incremental-compilation).

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
| Flights | Admin | List, detail, create, assign a flyer. Ticket cash posts only when a fund is selected, and the confirmation states the BDT amount. |
| Flyers | Admin | Profile, flights, document list, JPEG upload, verify. PDF documents open in the app and can still be shared. |
| Customers | Admin | List, detail, create, statement links, credit, and account activity with reversal. Balances come from issued invoices. |
| Finance | Admin | Cash, transfers, income and expenses, ledger, reconciliation, and a new fund. A non-zero opening balance is capital in the ledger, not income. |
| Settings | Admin | Setup status, confirm the CNY rate, add bKash or bank methods, and manage staff. |
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

### Mobile interface and visual checks

The mobile UI uses one navy, white and blue theme, Hind Siliguri typography, outline icons and 48dp minimum touch targets. Home prioritizes balances and pending work; lists use tappable rows; shipment intake uses searchable customer and flight pickers; receipt review opens one receipt at a time. The bottom tabs load on their first visit and retain their state.

Generate current widget screenshots with real fonts, fixture data, and compact 320dp / 130% text-size checks:

```powershell
$env:CAPTURE_SCREENSHOTS = '1'
$env:MOBILE_SCREENSHOT_DIR = 'docs/screenshots'
flutter test test/capture_screenshots_test.dart
Remove-Item Env:CAPTURE_SCREENSHOTS
flutter test
```

The capture test checks rendering errors and writes PNG files directly; golden-file update mode is not required. The regular test suite also checks lazy tab loading, draft preservation and the receipt selection/approval flow.