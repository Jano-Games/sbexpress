# SBExpress mobile

Flutter app for Admin and Hub Manager. It talks to the API on branch `cursor/hub-api-upload-fixes-6df5` (SBExpress PR #1). After that PR merges, point `API_BASE_URL` at the merged API. The parsers stay on these DTO rules.

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://localhost:3002
```

Android emulator: `http://10.0.2.2:3002`. Release builds should use HTTPS. Debug Android allows cleartext so a local API works.

## This slice

| Screen | Who | Status |
|---|---|---|
| 7 Login | All | Email + password. Role comes from `POST /api/auth/login`. No role picker. This API has no OTP. |
| 1 Hub dashboard | Hub | `GET /api/dashboard/hub`. Weigh, pack, and the delivery-chain counts. |
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

Before upload, photos are converted to JPEG, longest edge 2000px, quality 80. HEIC goes through the platform converter first, then the same JPEG rules. EXIF is dropped by re-encoding; the server strips it again. A failed upload retries the same bytes. A failed receipt screenshot does not block payment. Storage, network/CORS, expiry, and format errors stay distinct.
