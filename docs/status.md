# Status

Updated: 2026-10-12.

Maru was developed in a private repository before it became public. Issue numbers, pull request numbers, and commit IDs in `docs/decisions.md` and `docs/research/` refer to that private history. This repository starts from one clean commit.

## Current state

- The app and the package build. CI builds and tests the package and builds the app for the iOS Simulator.
- Milestone A (the core loop on one iPhone) is complete in code: add and edit an item, Today, records, undo, history, item detail, settings, local reminders, optional follow-up reminders, and as-needed items.
- The first release is in English (D017).
- The design rules are in `docs/design.md`. Native SwiftUI components only (D026).
- Maru does not integrate with Apple Health in V1 (D022).
- An "every other day" schedule is in code (D036). Its reminders are dated requests for the next 7 due dates, and they need a check on a real iPhone.
- Quick add is in code (D038): "Scan Label" on the add screen reads a name from a label with the camera, on the iPhone, and the name field proposes names from two built-in lists (941 supplement names, 789 medicine names). After the first test on the iPhone, the scan card shows the words of a tapped text as buttons, and the user chooses the words and edits the name on the card (D042). Nobody saw the new card yet, and it needs a check on a real iPhone with real bottles.
- An export of the records as a CSV file, and a backup and a restore, are in code (D040). `docs/export-format.md` has the formats. The files are not encrypted. Nobody ran them on a real iPhone yet: the share sheet, the file picker, and a restore after a new install need that check.
- Smart completion for supplements is in code (D043): a supplement name from the built-in list sets the usual form until the user chooses one, and the amount, the reminder, and the note show candidates that fill nothing until a tap. The list has 103 supplements. Nobody saw the screen yet.
- History has a graph of squares above the timeline (D041): one square per day, three levels of the tint by the share taken, and 13, 26, or 52 weeks. A touch or a drag selects a day, and the timeline scrolls to it. Nobody saw it on a display yet. The drag, the haptic, the dark-mode levels, and VoiceOver need a check on a real iPhone.
- Today rows show the time on the second line (D044): the set time of an open row, the intake time of a taken row, and "Skipped". Nobody saw the rows on a display yet.
- The user sets the follow-ups (D039): 1, 2, 3, or 5 times, or "Until Recorded" with at most 12 for each dose, also across a change of the setting, and 5 minutes to 1 hour between them. Follow-ups continue after midnight until 01:00, and their "Taken" action records the dose of the day before. Nobody saw them on a device yet. They need a check on a real iPhone: the times, the stop after a record, the group in Notification Center, a Focus, and the action after midnight.
- Reminders skip a recorded dose and give one notification for each fire time (D047): a dose recorded before its time does not remind, two items at one time give one notification that names the open items, and a daily item and an every-other-day item share one request on a due day. Nobody saw it on a device yet. It needs a check on a real iPhone: record before the time and no notification, undo before the time and the notification comes, one of two items recorded and the text names the other one with the "Taken" action.
- The optional item photo is in code (D056): "Photo (Optional)" at the end of the add and edit screen, a photo from the library or the camera, a background removal on the device that never blocks Save, and the photo in place of the form icon on Today, My Items, the item detail, and the archived list. The backup does not hold the photo files. Nobody saw it on a display. It needs a check on a real iPhone: the camera, the background removal with one bottle, a bottle in a hand, and two bottles (T29), a Cancel during the removal (T30), a missing file, and a locked iPhone.
- Three flow gaps against Apple Health Medications are closed in code (D033): a change of a record time in three taps, an archive in three taps with one confirmation, and a delete of an item with its records. Nobody saw them on a display yet.

## Next

1. Check on the maintainer's iPhone, in one session: the item photo (D056), the History graph, the Today row times, the scan card with two real bottles, smart completion, the follow-ups and "Until Recorded" with the "Taken" action after midnight (D034, D039), and the export, backup, and restore (D040). Each pull request has its steps.
2. Home Screen widgets are in code (D048), "Today" and "Take Now". Nobody saw them. Check on the iPhone: the signing of the App Group with the free team, the one-time move of the database, the tap on a capsule with the app closed, and the reminders after it. The database now lives in the App Group container, and the old copy stays in Application Support.
3. Acceptance on a real iPhone: one week of daily use by the maintainer. It started on 2026-10-12.
4. Milestone B: TestFlight. The maintainer starts it. The bundle ID freeze and the Apple Developer Program come first (D005, D007). Time-sensitive reminders also wait for the program (D034).

## Known gaps

- Dark Mode, the largest text sizes, and VoiceOver speech need a full check on a device.
- The String Catalog needs a sync before a second language.

## Run the app with sample data

Run the Debug build in an iPhone simulator with the launch arguments `-MaruSampleData YES -MaruSampleRecords YES`.
