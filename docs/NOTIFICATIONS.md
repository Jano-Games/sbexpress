# Notifications

One notification for every crucial step. Today they show under the bell in
the app. Push to phones (Firebase) comes later and reads the same rows, so
nothing about the events changes when it is added.

## Where they live

- Table `Notification`: `event`, `roles` (who sees it), English `title` and
  `body`, `params` (the facts in the text), `flightCode` / `shipmentCode` /
  `customerCode` (what a tap opens), `dedupeKey` (one event is sent once),
  `readBy` (staff user ids), `pushSentAt` (for push later), `createdAt`.
- Writing: `notify()` in `apps/backend/src/shared/notifications.ts`. It never
  fails the work that caused it. The text builders for every event sit next
  to it.
- Reading: `GET /api/notifications` (newest 100 for the user's role, with
  `read` and the `unread` count), `GET /api/notifications/unread`,
  `POST /api/notifications/:id/read`, `POST /api/notifications/read-all`.
  These writes skip the audit log: reading is not business activity.
- The app builds its own words (English or Bangla) from `event` and
  `params`; `title` and `body` are the English text push will use.

## Events

| Event | When | Who | Example |
| --- | --- | --- | --- |
| `flight_new` | Admin adds a flight | hub | New flight MU2039. Lands in Dhaka Sat 14 Nov at 15:25, in 5 days. Flyer Arif Rahman. |
| `flight_changed` | Date or landing time of a flight that has not left changes | hub | MU2039 now lands in Dhaka Sun 15 Nov at 15:25. |
| `flight_tomorrow` | 24 hours before landing | admin, hub | MU2039 lands tomorrow at 15:25. 6 orders. |
| `flight_departed` | The flight leaves (airline or by hand) | admin, hub | MU2039 left Chengdu at 10:52. Lands in Dhaka at 15:40. 6 orders are In transit. |
| `flight_soon` | 1 hour before landing | admin, hub | MU2039 lands in about 1 hour at 15:40. |
| `flight_landed` | The flight lands | admin, hub | MU2039 landed in Dhaka at 16:58. 7 orders to receive. |
| `flight_cancelled` | The airline says cancelled | admin, hub | The airline cancelled MU2039 on Sat 14 Nov. Nothing was changed here. |
| `flight_date_passed` | Still Upcoming the day after its date, no airline update | admin | MU2039 was due on Fri 13 Nov. The airline has no update. Confirm what happened. |
| `orders_received` | The hub receives a flight | admin | Mina Akter received 7 orders from BG298 at the Dhaka hub. |
| `sort_waiting` | The hub sends a sorted customer | admin | Mina Akter sorted Nila Store from BG298: 2 orders, 14.6 kg. Waiting for approval. |
| `sort_sent_back` | Admin sends a customer back | hub | C-14 from BG298 sent back by Rafiq Ahmed: SH-42 needs a photo with the carton open. |
| `sort_approved` | Admin approves a customer | hub | C-14 from BG298 approved. 2 orders In delivery with Steadfast. |
| `delivered` | The hub confirms delivery | admin | Mina Akter confirmed 2 orders of Nila Store from BG298 delivered. |
| `problem` | An order gets an exception (on hold, failed delivery, lost...) | the other team | SH-41 is on hold: Box is wet (Mina Akter) |

The hub sees customer codes only; customer names appear only in admin
notifications.

## Timed reminders

`startFlightReminders()` (`src/shared/flightNotices.ts`) runs every 5 minutes
on one server (Redis lock `flightnotify:lock`). It reads only our own data,
so it needs no flight-data key. Landing time is the airline's latest time once
known, otherwise the planned time. Each reminder has a `dedupeKey` with the
flight and its date, so a moved flight gets its reminders again.
Set `FLIGHT_REMINDERS=off` to stop them.

## Push later (Firebase)

1. Store each device's FCM token per staff user.
2. A small job sends rows with `pushSentAt = null` to the tokens of users in
   `roles`, using `title` and `body` (or Bangla built from `params`), then sets
   `pushSentAt`.
3. A tap opens the same screen as the bell: `flightCode`, `customerCode`,
   `shipmentCode`.
