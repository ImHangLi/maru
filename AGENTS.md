# Maru

Maru is a local-first iPhone and iPad app for daily supplements and simple medication schedules that the user confirms. It reminds on time, shows what to take now, and keeps a trustworthy record.

`docs/spec.md` is the source of truth for scope, data model, and acceptance. Read only the sections that your task needs. Section numbers and acceptance IDs (`T01`–`T55`) are stable references.

## Working mode

Before you plan, start, or end a work session, read `docs/process.md`. It defines the records that you must keep, the maintainer decisions, and the flow for one issue. Read `docs/status.md` at the start of every session, and rewrite it at the end.

When you work for the maintainer (called "the owner" in older records):

- The maintainer works only in chat and does not read code or files. Report in short, plain Chinese, in this order: what needs the maintainer, what changed, the demo, and the risks. Do not paste code. Do not ask the maintainer to open files.
- Ask before a maintainer decision in `docs/process.md`. Make every other decision yourself, then record it. When you ask, give a recommendation, the reason, and the cost of each option.
- A test on the maintainer's iPhone needs the maintainer. Notification behavior needs a real device (spec §8, §14 A).
- Run each issue in a subagent with its own Git worktree (D008).

When you work for another contributor, follow `CONTRIBUTING.md`, and do not make a maintainer decision.

## Project layout

- `project.yml`: the XcodeGen definition of the app. `Maru.xcodeproj` is generated and ignored by Git. Change `project.yml`, then run `xcodegen generate`. Do not edit the `.xcodeproj` by hand.
- `App/`: the SwiftUI app target. Keep views and app wiring here.
- `Watch/`: the watchOS app target (D071). It links only `MaruCore`. It has no database, and the iPhone app makes each record.
- `Packages/MaruKit/`: platform-neutral logic. `MaruCore` holds domain, scheduling, and record rules. It must not import SwiftUI, UIKit, StoreKit, or analytics SDKs, so `swift build` and `swift test` run on the Mac without a simulator. `MaruDatabase` holds the SQLite store and is the only target that imports GRDB. Record every third-party dependency in `docs/third-party-licenses.md`.
- `docs/`: the spec and research notes.

## Commands

```sh
xcodegen generate
swift build --package-path Packages/MaruKit
xcodebuild -project Maru.xcodeproj -scheme Maru -destination 'generic/platform=iOS Simulator' build
```

On the maintainer's Mac, run only the `swift` commands. Do not build the app or run a simulator there. The CI `app` job is the build check. One local device build is acceptable for an install on the maintainer's iPhone.

On another Mac, use XcodeBuildMCP to run the app in a simulator, take screenshots, and read logs.

## Rules that the spec makes non-negotiable

- Scope freeze (spec §1): no inventory, accounts, AI chat, streak penalties, or ads. Do not add a feature from the "明确不做" list without a spec change.
- Do not choose for the user: no default dose, no default medication time, and no silent conversion of unsupported schedules (spec §2).
- Show "recorded" or a success haptic only after the local transaction commits (spec §7.2).
- UI calls domain operations. UI must not write to the database, StoreKit, or analytics directly (spec §6).
- Never clear and rebuild the database to recover from an error (spec §7.3).
- Health data stays on the device. Do not send medication names, doses, intake times, or item IDs to analytics, logs, or crash reports. Do not initialize any analytics SDK before consent (spec §10, §11).
- The startup path must not wait for the network, analytics, StoreKit, or image processing (spec §9).

## Conventions

- Write code, comments, commit messages, and docs in English. Product copy lives in String Catalogs. English (`en`) is the source language. The first release also ships zh-Hans, ja, es, de, and ko (D051, D059).
- Use SwiftUI system controls and Swift 6 strict concurrency.
- "Maru" is the working brand. Keep the bundle ID, display name, and marketing strings separate (spec §13.3).

## Keep the repository lean

- Write no code for a future need. Add a type, a field, or a store function in the change that first calls it.
- When a decision removes a feature, remove its code, strings, assets, tests, and settings keys in the same change.
- When a change makes a comment, `docs/status.md`, or `project.yml` false, correct it in the same change.
- When a decision replaces a part of an older decision, name the new ID in the heading of the older one.
- Before you add a helper, search `App/` and `Packages/` for one that does the same job.
- Keep debug tools in `App/Debug/` or `App/DebugLaunch.swift`, inside `#if DEBUG`. Add a launch argument only for a named use, and remove it when the use ends.
- Write no test for a default value, or for the same path with other literals (D016).

## Definition of done

A change is done when the package and the app build, and the change states which spec sections or acceptance IDs it covers. Keep tests few (D016): one test per behavior that protects a record or an acceptance ID, and no test per review finding. Report the checks you did not run and why.
