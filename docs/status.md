# Status

Updated: 2026-10-11.

Maru was developed in a private repository before it became public. Issue numbers, pull request numbers, and commit IDs in `docs/decisions.md` and `docs/research/` refer to that private history. This repository starts from one clean commit.

## Current state

- The app and the package build. CI builds and tests the package and builds the app for the iOS Simulator.
- Milestone A (the core loop on one iPhone) is complete in code: add and edit an item, Today, records, undo, history, item detail, settings, local reminders, an optional follow-up reminder, and as-needed items.
- The first release is in English (D017).
- The design rules are in `docs/design.md`. Native SwiftUI components only (D026).
- Maru does not integrate with Apple Health in V1 (D022).
- Three flow gaps against Apple Health Medications are closed in code (D033): a change of a record time in three taps, an archive in three taps with one confirmation, and a delete of an item with its records. Nobody saw them on a display yet.

## Next

1. Close the gaps against Apple Health Medications (`docs/research/2026-10-11-apple-health-gap.md`): delete an item, a shorter change of a record time, a shorter archive, and a question after a time zone change. The "Taken" action on a reminder is in code and needs a check on a real iPhone (D034). Time-sensitive reminders wait for the Apple Developer Program (D007, D034).
2. A feedback entry in Settings.
3. A Home Screen widget that records a dose.
4. Acceptance on a real iPhone: one week of daily use by the maintainer.
5. Milestone B: TestFlight. The bundle ID freeze and the Apple Developer Program come first (D005, D007).

## Working rules

- Do not build the app on the maintainer's Mac. The CI `app` job is the build check. One local device build is acceptable for an install on the maintainer's iPhone.

## Known gaps

- Dark Mode, the largest text sizes, and VoiceOver speech need a full check on a device.
- The String Catalog needs a sync before a second language.

## Run the app with sample data

Run the Debug build in an iPhone simulator with the launch arguments `-MaruSampleData YES -MaruSampleRecords YES`.
