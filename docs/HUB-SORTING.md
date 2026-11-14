# Hub sorting and admin approval

The Dhaka side of an order after round 12:

1. **Receive.** The hub receives the flight's orders once customs clears them.
2. **Sort, per customer.** For each order: measured kg, what arrived, goods
   photos. For the customer: number of packages, packing photos, delivery
   partner, courier ID (optional, can be added until delivered) and a note.
   Then **Send to admin**.
3. **Approve or send back.** The admin checks booked against measured weight,
   the new bill and the photos. Approve: courier orders go In delivery; Hub
   pickup orders become ready for pickup. Send back: the orders return to the
   hub with a note, keeping what the hub filled in.
4. **Delivered.** The hub confirms who received it.

Sort replaces the hub's old Weigh / Pack / Courier / Dispatch steps. The admin
keeps the correction tools on the order page.

## Statuses

No new statuses, so the customer's tracking page keeps its 9 steps.

| What people see | Status | Fields |
| --- | --- | --- |
| To sort | `received_bd_hub` | `sentBackAt` empty |
| Sent back | `received_bd_hub` | `sentBackAt`, `sentBackNote`, `sentBackBy` |
| Waiting for admin | `ready_for_last_mile` | `sortedAt`, no `approvedAt` |
| Ready for pickup | `ready_for_last_mile` | `approvedAt`, `deliveryMode = pickup` |
| In delivery | `out_for_delivery` | `approvedAt`, `dispatchedAt` |
| Delivered | `delivered` | `handedOverAt` |

Orders booked the older way (packed with a courier, no `sortedAt`) show as
Waiting for admin and are approved the same way.

New Shipment fields: `arrivedNote`, `hubNote`, `sortedAt`, `sortedBy`,
`approvedAt`, `approvedBy`, `sentBackNote`, `sentBackAt`, `sentBackBy`.
Goods and packing photos are `ShipmentMedia` with purpose `goods` and
`packing`. Delivery partners are the `deliveryPartners` setting (admin edits
them in Settings); Hub pickup is always offered.

## API (`/api/sorting`)

| Route | Who | What |
| --- | --- | --- |
| `GET /flights/:code` | admin, hub | Customers on the flight with their orders, state, photos and the partner list |
| `POST /flights/:code/customers/:customer/sort` | admin, hub | `{ orders: [{ code, kg, arrived }], packages, partner, courierRef?, note? }` |
| `POST /flights/:code/customers/:customer/approve` | admin | Approve one customer |
| `POST /flights/:code/approve-all` | admin | Approve every customer that needs no look; returns `skipped` |
| `POST /flights/:code/customers/:customer/send-back` | admin | `{ note }` |
| `POST /flights/:code/customers/:customer/courier-ref` | admin, hub | `{ ref }` |
| `POST /flights/:code/customers/:customer/delivered` | admin, hub | `{ confirmation }` |
| `GET /approvals` | admin | Everything waiting, by flight |
| `GET /hub-summary` | admin, hub | Customers to sort or fix, waiting, in delivery |

A customer "needs a look" when an order's measured weight differs from the
booking by the warning threshold (Settings) or more. Approve all leaves those.

The hub sees customer codes, never names, phones, addresses or money.

## Track

`GET /api/flights/hub/:code/position` (admin, hub) gives the position of a
flight in the air: the leg, every airport on the route, latitude and
longitude, height, speed, heading, landing time and progress. One answer is
kept for 15 minutes; `?refresh=1` asks again when that has passed, at most 6
times a day per flight and `TRACK_DAILY_CALLS` (default 24) times a day for all
flights. Without a flight-data key it answers with marked sample data.
