# Status

Updated: 2026-10-11.

Maru was developed in a private repository before it became public. Issue numbers, pull request numbers, and commit IDs in `docs/decisions.md` and `docs/research/` refer to that private history. This repository starts from one clean commit.

## Current state

- The app and the package build. CI builds and tests the package and builds the app for the iOS Simulator.
- Milestone A (the core loop on one iPhone) is complete in code: add and edit an item, Today, records, undo, history, item detail, settings, local reminders, an optional follow-up reminder, and as-needed items.
- The first release is in English (D017).
- The design rules are in `docs/design.md`. Native SwiftUI components only (D026).
- Maru does not integrate with Apple Health in V1 (D022).
- An "every other day" schedule is in code (D036). Its reminders are dated requests for the next 7 due dates, and they need a check on a real iPhone.
- An export of the records as a CSV file, and a backup and a restore, are in code (D040). `docs/export-format.md` has the formats. The files are not encrypted. Nobody ran them on a real iPhone yet: the share sheet, the file picker, and a restore after a new install need that check.
- Three flow gaps against Apple Health Medications are closed in code (D033): a change of a record time in three taps, an archive in three taps with one confirmation, and a delete of an item with its records. Nobody saw them on a display yet.

## Next

1. Merge the "every other day" schedule (D036, pull request #49).
2. Check the "Taken" action of a reminder on a real iPhone (D034). Time-sensitive reminders wait for the Apple Developer Program (D007, D034).
3. A question after a time zone change (`docs/research/2026-10-11-apple-health-gap.md`).
4. A Home Screen widget that records a dose.
5. Acceptance on a real iPhone: one week of daily use by the maintainer.
6. Check the export, the backup, and the restore on a real iPhone (D040). The pull request has the steps.
7. A backup with a passphrase (D040, milestone B).
8. Milestone B: TestFlight. The bundle ID freeze and the Apple Developer Program come first (D005, D007).

## Open cleanup proposals

These need a maintainer decision or wait for pull request #49. The list with evidence is in the pull request "Remove dead code and stale content".

- Model parts with no caller in the app: `ProductVersion`, `ScheduleVersion.productVersionID`, and `Item.imageReference`. Their tables and columns stay in the schema.
- Debug launch arguments with no recorded use: `-MaruTab`, `-MaruHistory`, `-MaruSettings`, `-MaruTap`, `-MaruStorageError`, `-MaruSampleHistory`, and `-MaruSampleData one`.
- The time format of a row exists in four views. One shared helper can replace them.

## Known gaps

- Dark Mode, the largest text sizes, and VoiceOver speech need a full check on a device.
- The String Catalog needs a sync before a second language.

## Run the app with sample data

Run the Debug build in an iPhone simulator with the launch arguments `-MaruSampleData YES -MaruSampleRecords YES`.
