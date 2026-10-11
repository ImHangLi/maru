# Apple Health Medications against Maru, gap analysis, 2026-10-11

The owner's goal: Maru covers almost every important feature of Apple Health Medications, and each flow is simpler than Apple's. This note compares the two, feature by feature and flow by flow.

Result in short:

- Maru is simpler in eight of the eleven flows that both apps have. The add flow is the largest gain: one screen and 3 taps against seven screens and about 12 taps.
- Maru is not simpler in three flows: record from a notification, change the time of a record, and archive. Section 3 gives a fix for each. Two fixes are small.
- Four gaps are worth work before the first public release: a "Taken" action on the reminder, Time Sensitive reminders, a delete for one item, and a choice after a time zone change for medications.
- The other gaps are planned for milestone B, wait for user feedback, or are out of scope by the spec.

## Method and sources

No code ran for this note. No build, no simulator, and no device. The Maru facts come from the code on `main` (commit `ab0624c`) and from the docs. The Apple facts have a source tag:

| Tag | Source | State |
|---|---|---|
| A1 | [Add and log medications with iPhone, iPad, and Apple Watch](https://support.apple.com/en-us/105064), published 2026-09-14 | Read on 2026-10-11 |
| A2 | iPhone User Guide, [Track your medications in Health on iPhone](https://support.apple.com/guide/iphone/track-your-medications-iph811670c81/ios). The page lists iOS 27 as its newest version | Read on 2026-10-11 |
| A3 | iPhone User Guide, [Learn more about your medications in Health on iPhone (U.S. only)](https://support.apple.com/guide/iphone/learn-more-about-your-medications-iph2fcefa8d6/ios) | Read on 2026-10-11 |
| A4 | Apple Watch User Guide, [Track your medications on Apple Watch](https://support.apple.com/guide/watch/medications-apd3dd24d78b/watchos) | Read on 2026-10-11 |
| A5 | Apple Watch Ultra User Guide, [Track your medications on Apple Watch Ultra](https://support.apple.com/en-ca/guide/watch-ultra/apd3dd24d78b/watchos) | Read on 2026-10-11, through a page summary |
| H | The hands-on run in `2026-10-11-apple-health-medications.md` (iOS 27.0 simulator, one run) | Project note |
| K | `2026-10-11-healthkit-medications-api.md` | Project note |
| M | Memory only. No Apple page that I read confirms it | Not verified |

Count rules for the flows:

- The count starts in the open app, on its first screen. For Maru that is Today. For Apple that is Health on the Summary tab.
- One tap, one swipe, or one long press is one gesture. Typed text and a scroll of a time wheel are not counted.
- A screen is a full page or a sheet. A menu, a dialog, or an alert is not a screen.

## 1. Feature table

Status words: **simpler** (Maru has it with fewer steps), **equal**, **partly**, **missing**, **planned** (missing now, in milestone B of `docs/roadmap.md`).

### Set up

| # | Feature | How Apple does it | Maru status | Evidence |
|---|---|---|---|---|
| 1 | Place of the feature | Health, Browse, Medications. Two levels below the first screen (A1, A2, H) | Simpler. Today is the first screen | `App/RootView.swift`, spec §1 |
| 2 | Add by a typed name | Type the name, tap Add, then Next (A1, A2) | Simpler. One text field on the one edit screen | `App/Editor/ItemEditorView.swift` |
| 3 | Name suggestions from a drug database | U.S. only. Suggestions show while the user types (A2) | Missing. Out of scope: Maru has no drug database | spec §13.1 |
| 4 | Add with the camera | U.S. only. Tap the camera symbol, then follow the steps (A1, A2) | Planned. Label scan with a check by the user, milestone B | spec §3 P03, roadmap B |
| 5 | Suggestions from Health Records | Shows on "Add a Medication" when the user has Health Records (A1) | Missing. Will not do | spec §1 (no account, local data) |
| 6 | Type or form | One screen, about sixteen forms (H) | Simpler. One menu, six forms, on the edit screen | D013, `ItemEditorView.swift` `formSection` |
| 7 | Strength | One screen. Units mg, mcg, g, mL, %. No IU. "Add Custom" for a value not in the list (A1, H) | Simpler. One free text field, "For example 1000 IU". Strength and amount are one field | D021, `ItemDraft.amount` |
| 8 | Schedule "Every Day" | Default of the schedule screen. The time starts at the current minute (H) | Simpler. No default time for a medication. A supplement gets a labeled example time | spec §2.1, `applyExampleTime` |
| 9 | Schedule "On Specific Days of the Week" | Tap Change, choose the type, pick days. Needs iOS 18 (A1) | Equal. "Repeat" opens a list of seven days | `WeekdayList` in `ItemEditorView.swift` |
| 10 | Schedule "Every Few Days" | Tap Change, choose the type (A2) | Missing | spec §1 "V1 不自动处理" |
| 11 | Schedule "On a Cyclical Schedule" | Tap Change, choose the type. Needs iOS 18 (A1, A2) | Missing. On the later list | roadmap "Cycles such as 21 days on" |
| 12 | Schedule "As Needed" | A schedule type (A1, A2) | Simpler. An item with no time is an as-needed item | D021, `App/Today/AsNeededSection.swift` |
| 13 | Several times each day | Add a time on the schedule screen (H) | Equal. "Add a Time" opens a time wheel | `NewTimeSheet` |
| 14 | An amount for each time | Each time has its own amount. It starts at "1 capsule" (H) | Partly. One amount for the whole plan. No default amount | `ScheduleVersion.dose`, spec §2.1 |
| 15 | Start date and end date | "Edit" under Duration on the schedule screen (A1) | Missing. A plan starts today and has no end. Archive ends it | spec §8.4, T10, `ItemDraft.build` |
| 16 | Shape | One screen, about thirty shapes. Can skip (A1, H) | Simpler. The six forms are also the icon | D013 |
| 17 | Colors | One screen. Left, right, and background, twelve colors each (H) | Simpler. One menu of eight colors. A new item gets a free color | D021 |
| 18 | Nickname and notes | "Optional Details" on the review screen. Later under Details, Edit (A1, A2) | Simpler. The name is the user's own text. A note has two presets and free text | D006, `noteSection` |
| 19 | Review screen | The seventh screen (H) | Simpler. The plan line under the reminder section shows the full plan before Save | `timesFooter`, spec §2.1 |

### Reminders

| # | Feature | How Apple does it | Maru status | Evidence |
|---|---|---|---|---|
| 20 | Reminder at the scheduled time | On by default. Master switch: Medications, Options, Dose Reminders (A1) | Equal. Each item has "Turn Off Reminders". The text shows a time and no item name | `ItemDetailView.swift`, D023 |
| 21 | Follow-up reminder | Medications, Options, Follow Up Reminders. Fixed at 30 minutes (A1, A2) | Equal, with one limit. Off, 15, 30, or 60 minutes. It stops after 7 days with no open of Maru | D021, `App/Settings/SettingsView.swift` |
| 22 | Critical Alerts | For each medication, after Follow Up Reminders is on. Sounds through a Focus and the mute switch (A2, A4) | Missing. Will not do. See section 2 for the replacement | D021 "Not added" |
| 23 | Record from the notification | Tap the notification, then "Skipped" or "Taken" (A1). Or press and hold, then choose an option (A2) | Partly. A tap opens Today at the right section. The notification has no action | `App/ReminderTapDelegate.swift`, spec §8.3 |
| 24 | "Remind Me in 10 Minutes" | An option of the notification on Apple Watch (A1). On iPhone: not confirmed (M) | Missing. The follow-up reminder covers a part of it | D021 |
| 25 | Time zone change | A notification asks the user to confirm the schedule (A1) | Partly. A supplement follows the device. A medication keeps its zone. Maru shows the zone but does not ask | spec §8.5, `ItemDraft.followsDevice` |
| 26 | Test of the reminder | None found (M) | Maru has more: "Send a Test Notification" and an honest permission state | D023 |

### Record and review

| # | Feature | How Apple does it | Maru status | Evidence |
|---|---|---|---|---|
| 27 | Record one dose as taken | Tap the plus next to the medication, "Taken", "Done" (A1) | Simpler. One tap on the circle, or one full swipe | `App/Today/TodayRow.swift` |
| 28 | Record one dose as skipped | Same sheet, "Skipped", "Done" (A1) | Simpler. Swipe left, then "Skip" | D028 |
| 29 | Record a whole time group | Plus, "Log All as Taken", "Done" (H, A4) | Simpler. "Record All" in the section header, one tap | D021, `SlotSection.swift` |
| 30 | Record an as-needed dose | "As Needed Medications", "Taken", "Done" (A2) | Simpler. One tap on the plus of the row | `AsNeededSection.swift` |
| 31 | Change the time while recording | The log sheet shows the time of each item (H) | Partly. Record first, then "Change Time…" | `ChangeTimeSheet` in `TodayRow.swift` |
| 32 | Change the amount of one record | The log sheet shows the amount of each item (H) | Missing. A record has no own amount | `IntakeEvent` |
| 33 | Change or remove a record | Tap the logged item, choose "Taken" or "Skipped", "Done" (A4 for Apple Watch. iPhone: M) | Simpler. Tap the circle, then "Undo" or "Mark as Skipped" | `RecordButton` |
| 34 | Record for a past day | Select a day in the week strip, then log (A2) | Simpler. History, tap the dose, Save | `App/History/HistoryRow.swift` |
| 35 | History of each medication | Tap a medication to see how often it was taken or skipped (A1, A2) | Partly. The detail shows the last 7 days. History lists every day. No count and no chart | `RecentSection`, roadmap B (heatmap) |
| 36 | "No record" is not "skipped" | Not confirmed (M) | Maru has more: three clear states | spec §4, `HistoryRow.swift` |

### Manage the list

| # | Feature | How Apple does it | Maru status | Evidence |
|---|---|---|---|---|
| 37 | Edit the schedule | Tap the medication, scroll to Schedule, "Edit", tap a field (A2) | Simpler. The same one edit screen | `AppModel+Editor.swift` |
| 38 | Edit icon, nickname, notes | Tap the medication, scroll to Details, "Edit" (A2) | Simpler. The same one edit screen | `ItemEditorView.swift` |
| 39 | Reorder the list | "Edit" above the list, then drag (A2) | Missing. My List keeps the order of the first save | `App/MyListView.swift` |
| 40 | Archive | Swipe left on the name, "Archive" (A1, A2) | Has it, not simpler. Four taps. See section 3 | `ItemDetailView.swift` |
| 41 | Restore from the archive | "Edit", then the plus. The old schedule is lost (A2) | Simpler and better. One "Restore" button. The plan stays | `App/Detail/ArchivedListView.swift`, T08 |
| 42 | Delete with all history | Tap the medication, "Delete Medication", confirm (A1) | Missing. An item can only be archived | No delete operation in `App/` or `MaruDatabase` |
| 43 | Replace a product | None. Edit, or delete and add (M) | Maru has more: "Replace with a New Product…" keeps the plan and the old records | T06, `ItemDraft.replacing` |

### Information, sharing, and other devices

| # | Feature | How Apple does it | Maru status | Evidence |
|---|---|---|---|---|
| 44 | Drug interactions | U.S. only. "Drug Interactions", with factors such as alcohol (A1, A3) | Missing. Will not do | spec §1 "明确不做" |
| 45 | About a medication, side effects | U.S. only. "About" on the medication page (A3) | Missing. Will not do | spec §1, §13.1 |
| 46 | Pregnancy and lactation information | Not on the pages that I read (M) | Missing. Will not do | spec §1 |
| 47 | Share with family or a doctor | Health Sharing. The user picks the medications (A1, A2) | Missing. Will not do | spec §1 (no account, no remote family view) |
| 48 | Export the list as a PDF | Medications, scroll down, "Export PDF" (A1, A2) | Missing. The planned export is an encrypted backup, not a list to read | spec §7.3, roadmap B |
| 49 | Sync between devices | iCloud, with the same Apple Account (A2) | Missing. Will not do in V1. Encrypted export and restore is planned | spec §1, §10, roadmap |
| 50 | Apple Watch app | Medications app. "Log All as Taken", or one item (A4) | Missing. On the later list | roadmap "Later" |
| 51 | Siri | "Log my 6AM medications as taken", on Apple Watch with watchOS 10.2 (A5). On iPhone: not confirmed (M) | Missing | No App Intents in the project |
| 52 | Home Screen or Lock Screen widget | Not on the pages that I read (M) | Planned. The owner confirmed a Home Screen widget | spec §6, roadmap B |
| 53 | Live Activity or Dynamic Island | Not on the pages that I read (M) | Missing. The owner decided against it | Owner decision |
| 54 | iPad | Health on iPad has Medications (A1) | Missing. iPhone only | spec header |
| 55 | Other apps can read the data | HealthKit, read-only, per medication (K) | Missing. Maru does not use HealthKit | D022 |
| 56 | Price, account, ads | Free, no account, no ads (H) | Equal | spec §1 |

## 2. Missing and partial features

"First release" means the public App Store release (milestone C). "Planned" items are already in milestone B and need no new decision.

| # | Feature | Important for a typical user? | Verdict | Size |
|---|---|---|---|---|
| 23 | "Taken" action on the reminder | Yes. It is the main flow of a reminder app, and Apple needs no app open for it | **Do before the first release.** Give the action only to a reminder that resolves to one item of today. The action must ask for an unlock. Spec §8.3 allows this case, so no spec change is necessary | Medium |
| 22 | Critical Alerts | The need behind it is important: a Focus or a summary can hide a reminder | Will not do Critical Alerts (D021). **Do before the first release:** send reminders at the Time Sensitive level. The user controls it in iPhone Settings. Add one line to spec §8.1. Do not promise delivery | Small |
| 42 | Delete one item with its records | Yes. A wrong or test item stays in the archive forever. Spec §3 P06 lists "privacy and delete" | **Do before the first release.** Put "Delete…" in the archived list, with a clear confirmation | Small |
| 25 | Time zone change | Yes for medications. A medication reminder keeps its home zone, so it can come at night after a flight. The user cannot move the plan to local time in one step | **Do before the first release.** After a zone change, show one row on Today for medication plans: keep the home times, or use local times. The user chooses, as spec §2 and §8.5 ask | Medium |
| 31 | Time while recording | Sometimes. "I took it an hour ago" is common | **Do before the first release**, with the flow fix in section 3 | Small |
| 52 | Widget | Yes | Planned, milestone B. Follow spec §10: no names by default | Medium |
| 35 | History of each item | Medium. "How often did I take it?" | Planned in part: the heatmap of milestone B. Add a count for each item only after feedback | Medium |
| 4 | Label scan | Medium. It speeds the add flow, which is already short | Planned, milestone B | Large |
| 49 | Sync and backup | Backup is important: a new iPhone must not lose the records. Sync is not | Planned: encrypted export and restore, milestone B. Sync stays on the later list | Large |
| 48 | A list to read or print | Medium. A doctor or a pharmacist asks "what do you take?" | Do later, with the export work. A plain text share of the active list is enough | Small |
| 10 | Every few days | Medium. Some people take iron or a vitamin every second day | Do later, after feedback. A repeating system trigger cannot do this, so it needs the one-time request budget of spec §8.4 | Medium |
| 11 | Cyclical schedule | Low for supplements. Important for some medications | Do later (roadmap). It is not a "simple schedule" | Large |
| 15 | Start date and end date | Low for supplements. Medium for a short course of a medication | Do later. Spec §8.4 already sets the condition: a device test of the stop | Medium |
| 14 | An amount for each time | Low. A second item covers it | Do later, after feedback | Small |
| 32 | Amount of one record | Low | Will not do now. It adds a field to every record for a rare case | Small |
| 12 | Amount of an as-needed item | Medium. "Ibuprofen 200 mg" has no place for the amount, only the name | Do later. Let an item with no time keep its amount | Small |
| 24 | Remind me in 10 minutes | Medium. The follow-up reminder covers most of it | Do later, on top of the notification action | Small |
| 39 | Reorder the list | Low. Today sorts by the part of the day | Do later, after feedback | Small |
| 50 | Apple Watch app | Medium. Roadmap trigger: users ask for faster logging | Do later (roadmap). The "Taken" action possibly shows on a mirrored Apple Watch notification with no Watch app. A device test must confirm it | Large |
| 51 | Siri and Shortcuts | Low to medium | Do later. An interactive widget needs the same App Intents, so do the two together | Medium |
| 54 | iPad | Low | Will not do in V1 | Medium |
| 3, 5 | Drug database, Health Records | Low for this user | Will not do. No server, no drug database, no clinical records | Large |
| 44, 45, 46 | Interactions, side effects, pregnancy | Important for some medication users, but it is medical content | Will not do. Spec §1 excludes an interaction check. Apple offers it only in the U.S. | Large |
| 47 | Share with family | Low for this user | Will not do. No account and no server | Large |
| 53 | Live Activity, Dynamic Island | Low | Will not do. Owner decision | Medium |
| 55 | HealthKit | Low | Will not do in V1 (D022) | Medium |

Spec changes that this section proposes:

1. Spec §8.1: reminders use the Time Sensitive level. The text must still not promise delivery.
2. Spec §3 P04 or P06: a delete of one archived item with its records.
3. Spec §8.5: after a zone change, Maru asks once for each medication plan. It never moves a plan without the answer.

None of these adds a feature from the "明确不做" list.

## 3. Flow comparison

Apple counts with the tag "about" come from the steps on Apple's pages and from the hands-on note. Nobody counted them tap by tap on a device.

| Flow | Apple Health | Maru on `main` | Simpler? |
|---|---|---|---|
| Add a daily item with one reminder | About 12 taps, 7 screens: Browse, Medications, Add Medication, Add, Next, type, Next, strength Next, schedule Next, shape Skip, colors Next, Done. This accepts the current minute as the time and "1" as the amount (A1, A2, H) | 3 taps, 1 screen for a supplement: plus, "Supplement", Save. The example time (08:00, or the user's earliest time) stays unless the user changes it. A medication: 5 taps, 1 screen and 1 small sheet: plus, "Medication", "Add a Time", Add, Save. The first save with a time adds the system permission prompt once | Yes |
| Record one dose in the app | 5 taps, 1 sheet: Browse, Medications, plus, Taken, Done (A1) | 1 tap, 0 screens: the circle | Yes |
| Record a whole time group | 5 taps, 1 sheet: Browse, Medications, plus, Log All as Taken, Done (H) | 1 tap: "Record All" | Yes |
| Record an as-needed dose | About 5 taps, 1 sheet: Browse, Medications, As Needed Medications, Taken, Done (A2) | 1 tap: the plus of the row | Yes |
| Record from a notification | 2 gestures. Tap the notification, then "Taken" (A1). Or press and hold, then choose an option, and Health does not open (A2) | 2 taps, and Maru opens: tap the notification, then the circle or "Record All". An unlock is necessary. A reminder that is not certain needs 3 taps: tap, "Show", circle | **No** |
| Skip | 5 taps, 1 sheet: Browse, Medications, plus, Skipped, Done (A1) | 2 gestures: swipe left, "Skip" | Yes |
| Undo a record | About 5 taps: Browse, Medications, the logged item, clear the status, Done (A4, M) | 2 taps: the filled circle, "Undo". Or swipe left, "Undo" | Yes |
| Change the time of a record | About 3 taps inside Medications: the logged item, the time, Done. 5 with Browse and Medications (H, M) | 4 or 5 taps, 1 sheet: the circle, "Change Time…", the time field, close the picker, Save | **No** |
| Edit a schedule | 6 taps, 2 screens: Browse, Medications, the medication, Edit, a field, Done (A2) | 4 or 5 gestures, 1 screen: long press, "Edit", the time, close the picker, Save | Yes, by a small margin |
| Archive | 4 gestures: Browse, Medications, swipe left, Archive (A1, A2) | 4 taps: the item name, "Change or End This Item…", "Archive…", "Archive" | **No** (equal) |
| Restore from the archive | About 5 taps, and the schedule is lost (A2) | 3 taps: My List, Archived, Restore. The plan stays | Yes |

Counts for Maru come from these files: `ItemEditorView.swift`, `TodayRow.swift`, `SlotSection.swift`, `AsNeededSection.swift`, `ReminderTapDelegate.swift`, `AppModel+ReminderTap.swift`, `ReminderChoiceSheet.swift`, `HistoryRow.swift`, `ItemDetailView.swift`, `ArchivedListView.swift`.

### The three flows where Maru is not simpler

**Record from a notification.** Apple records from the notification with no app open. Maru opens the app. Maru's reminder has no action (`ReminderTapDelegate.swift`: "There is no 'taken' action").

- Fix: register one notification category with a "Taken" action. Attach it only to a reminder request that covers exactly one item.
- The action runs the same record transaction as the circle. It needs the unlock option of the system, because the database is protected while the iPhone is locked (spec §10).
- When the reminder is not certain (another day, a zone change, an older plan), the action opens the choice sheet. It records nothing (spec §8.3).
- Result: 2 gestures and no app open, equal to Apple. A reminder for several items keeps the present 2 taps, because spec §8.3 forbids a blind record of a group.
- Size: medium. It needs a device test for the locked iPhone and for the background launch.

**Change the time of a record.** The sheet uses a compact date picker. The user must tap the field to open the picker and tap again to close it.

- Fix 1: show the time wheel in the sheet directly, as "Add a Time" already does. The flow becomes circle, "Change Time…", Save: 3 taps.
- Fix 2: add "Taken Earlier…" to the long press menu of an open row. It opens the same sheet and records with the chosen time. The flow becomes long press, "Taken Earlier…", Save: 3 gestures. Today this case needs 5 or 6 taps, because the user must record first.
- Size: small.

**Archive.** Maru has two confirmations in a row: the dialog "Change or End This Item…" and then the alert.

- Fix: add "Archive…" to the long press menu of a Today row and as a swipe action on a My List row. Keep the one alert, because its text says that archive is not advice to stop (spec §3 P04).
- The flow becomes long press, "Archive…", "Archive": 3 gestures. That is one less than Apple from the first screen.
- Size: small.

One more note: Apple's swipe to archive has no confirmation in the steps of its pages. I did not verify this on a device.

## 4. Recommendations, in priority order

1. **Add a "Taken" action to single-item reminders.** It closes the only main flow where Apple is ahead. Medium. Within spec §8.3.
2. **Send reminders at the Time Sensitive level.** It is the honest replacement for Critical Alerts, and it protects the core promise "reminds on time". Small. One line in spec §8.1.
3. **Fix the two slow flows in the app.** Show the time wheel in "Change Time", add "Taken Earlier…", and add "Archive…" to the row menus. Small. No spec change.
4. **Add a delete for one archived item with its records.** A user must be able to remove a mistake. Small. Spec §3 P06 already names delete.
5. **Ask after a time zone change, for medication plans only.** Keep the home times or use local times. Medium. It follows spec §2: the user chooses.
6. **Keep milestone B as planned, and add one plain text share of the list to the export work.** The widget, the heatmap, and the encrypted export close four more rows of the table.
7. **Wait for user feedback before these:** every few days, cycles, end dates, an amount for each time, Apple Watch, and Siri. Do not change the spec for them now. Do not build interactions, drug information, family sharing, or sync.

After items 1 to 5, Maru is simpler than Apple, or equal, in every flow of section 3. The features that stay missing are outside "supplements and simple medication schedules", or Apple offers them only in the U.S.

## 5. What I could not verify

- **Apple tap counts.** Nobody counted Apple's flows tap by tap on a device for this note. The counts come from Apple's written steps and from the hands-on note. The counts for undo and for the change of a logged time on iPhone are from memory.
- **Where Health opens.** The counts assume that Health opens on Summary. Health possibly opens on the last screen, which removes two taps from each Apple flow. A user can also pin Medications to Summary (M).
- **The notification on iPhone.** I did not see Apple's notification. The option names after a press and hold, a "Remind Me" option on iPhone, and the need for an unlock are not confirmed. Page A1 confirms "Remind Me in 10 Minutes" only for Apple Watch.
- **Widgets, Siri on iPhone, Live Activity.** The Apple pages that I read do not mention a Medications widget, Siri on iPhone, or a Live Activity. I recall a Medications widget from iOS 17 or later, but I found no Apple page for it.
- **Pregnancy and lactation information.** Not on the pages that I read. Memory only.
- **The schedule types.** The names "Every Day" and "As Needed" on the schedule screen come from the hands-on note and from memory. Pages A1 and A2 confirm "On Specific Days of the Week", "On a Cyclical Schedule", and "Every Few Days".
- **An archive confirmation in Apple Health.** Apple's steps show none. Not tested.
- **Page A5.** I read it through an automatic summary, not as full text. The Siri sentence is a quote from that summary.
- **Maru flows.** I counted them from the code. I did not run the app. The count for the compact time picker (one tap to open, one to close) depends on system behavior.
- **Time Sensitive reminders.** The interruption level and its entitlement are from memory of the UserNotifications API. Check the current Apple documentation and test on a device before the work starts.
- **The "Taken" action on a locked iPhone and on a mirrored Apple Watch notification.** Not tested. The database protection of spec §10 can block the write until the unlock.
- **Regions.** Apple's drug search, camera, interactions, and "About" are U.S. only by pages A1 to A3. I did not check other regions.
