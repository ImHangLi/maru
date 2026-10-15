# Notification correctness (2026-10-15)

Purpose: learn how iOS keeps local notifications correct, and test the Maru engines against it (D086).

## Sources and their limits

- [UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) and [Human Interface Guidelines: Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications). Both pages render with JavaScript. A fetch on 2026-10-15 returned only the titles. The points below come from the API reference as the author knows it. They are not checked against the live pages. A person must read the pages before a claim goes into the App Store text.
- Context7 has no index of Apple system frameworks, so it was not used.

## What the API gives (unverified against the live page)

1. A request has one identifier. An add with a known identifier replaces the pending request.
2. The same holds for a delivered notification: a new delivery with the same identifier replaces it in Notification Center.
3. `removePendingNotificationRequests` and `removeDeliveredNotifications` take identifiers and return no result. They are asynchronous calls. The app can only read the sets to learn the result.
4. An app holds at most 64 pending local requests. The system keeps the ones that fire first and drops the rest with no error.
5. A repeating calendar trigger fires on every matching day with the content that it had when it was added. Nothing reads the database at delivery time.
6. `.timeSensitive` shows the notification in a Focus when the user allows it.
7. The app runs only when the user opens it or when the system wakes it. A suspended or stopped app cannot change a request.

## How good apps keep notifications correct

| App | Pattern |
|---|---|
| Apple Reminders, Calendar | The system owns the data and the notifications. A change in the data changes the notification in the same transaction. The app is not a separate process that can stop in the middle. |
| Apple Health Medications | The same: a log of a dose cancels the reminder of that dose in the system. |
| Third-party apps | One request per occurrence (dated one-shot requests) for the next days, rebuilt from the database at each launch and each change. A repeating request only for content that never depends on a record. |

Rules that follow for Maru:

- Rebuild from the truth: compute the wanted set from the database at each run, compare it with the system, and fix the difference.
- Never trust old content. A request, a delivered notification, or a ledger entry from an older run or an older build is checked again at each run.
- Keep no state that can block a repair. A note that says "a removal is open" must lead to a new removal call, not to a wait with no end.
- A delivered notification cannot change its text. Remove it when it is wrong.

## What the simulator models and what it cannot

Modeled: pending and delivered sets, repeating and dated calendar triggers, one-time triggers, delivery when the clock passes a fire time, replace by identifier, removal that completes after N reads, removal that never completes, adds that the system drops with no error, the 64 limit, permission states, a time zone change, a process that stops at any call of a run, an app that does not open for days, an update with requests of an older build, and a user action during a run.

Not modeled:

- Real iOS timing. Removals, adds, and deliveries are exact here. On a device they are late, reordered across processes, or lost.
- Whether `removePendingNotificationRequests` is applied in order with a later `add`. The fake lets a late removal delete a newer request with the same identifier, which is the worst case.
- Delivery under Focus, Do Not Disturb, the notification summary, or a locked iPhone. Delivery under low power mode.
- Daylight saving gaps and repeats at a fire time. The fake skips a time that does not exist and fires the first of a repeated time.
- Whether iOS ever lets a run start. The app cannot run while it is suspended or stopped. A reminder that is wrong at that time stays wrong until the next open. No design can change this for local notifications. The window is the time between a change and the end of its run.
- `UNNotification.date` for a repeating request, and the exact `interruptionLevel` that `getPendingNotificationRequests` returns.
- AlarmKit. The fake alarm center only keeps a set.

## Edge cases that the scenarios cover

Record, skip, undo before, at, and after the time. Record from the "Taken" action of a first reminder and of a follow-up. Two items at one time, one recorded. Rename, edit of the time, a new time, archive, restore, delete, pause, resume. Daily, weekday, every-other-day, and fixed-zone items at one time. "Remind Again" per item and for all items. An alarm on and off, a refused alarm permission, an alarm that the system refuses. Names hidden and shown. Notifications off and on. A time zone change with the app closed. Midnight and three days with no open. A restart. Slow removal and dropped adds. 18 items with follow-ups under the limit of 64. A user action during a run. An update with follow-ups of the old identifier form and an unconfirmed global setting. A stop of the process at every call of a run, for archive, record, undo, time edit, pause, delete, and "Remind Again" for all items.
