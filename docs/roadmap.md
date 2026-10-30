# Roadmap

Status: confirmed by the owner on 2026-10-10 (D006). Positioning narrowed on 2026-10-11 (D021).

## Positioning

The simplest free reminder for daily supplements and simple medications. Reminds on time, shows what to take now, and answers "did I already take it?". No account, no ads, no paywall on the core, and data stays on the device.

After the test of Apple Health Medications (D021): Maru has no capability that Apple lacks. It wins only on experience. Every flow must be less tedious, more intuitive, and simpler than Apple's. Count screens and taps, and keep Maru lower.

Target users:

- People who take three or more supplements every day.
- People who forget, for example users with ADHD, who need a fast "taken" record.
- Users who leave Medisafe after its 2026 subscription change, or who find Apple Health Medications too limited.

Evidence: `docs/research/2026-10-market-scan.md`.

## V1 milestones

| Milestone | Result | Exit condition |
|---|---|---|
| A. Self-use | Manual add, open-ended reminders, Today, record, history, undo and correct, change time, turn off | The owner uses it daily on a real iPhone for one week. Spec §14 A checks pass |
| B. TestFlight | Optional photo, widget, six languages (D051), accessibility, analytics (D051), feedback | External testers use it. Spec §14 B checks pass |
| C. App Store | Review notes, privacy policy, privacy labels, support, store page, landing page (D051). The supporter purchase was removed (D099) | The app is approved and published |

Additions from research (D006):

- Milestone A: a user-entered note such as "with food" or "empty stomach". This is not advice from the app.
- Milestone B: a passive history heatmap. No streaks and no penalties.
- Milestone A (D021): item color, record a whole slot, an optional follow-up reminder (off by default), as-needed items, and IU as a unit.
- HealthKit Medications (D022): read-only, no dose writes. No integration in V1.
- Milestone A (D040): an export of the records as a CSV file, and a backup and a restore. The backup is not encrypted. A backup with a passphrase is dropped (D046).

## Later, only with evidence of real use

| Candidate | Trigger |
|---|---|
| Lock-screen quick logging. A first Apple Watch app is in work (D071) | Users ask for faster logging |
| Read-only import of medication names from Apple Health (D022) | Users ask to bring their list from Health |
| Optional end-to-end encrypted sync | Users with several devices ask for it |
| More languages: zh-Hant, ja, de, fr, es | Each language passes a full UI, notification, and error review |
| Paid convenience features: Maru Pro in version 1.2 (D099, D107), with the Lock Screen Live Activity, the Apple Watch app, extra app icons, extra reminder sounds, a Family of several people and pets on one iPhone (D121, D122), the PDF reports, and the 30-day counts (D130). Siri and Shortcuts are removed (D140). The purchase and the paywall are in code (D107) | The free core has steady use. Never put the core behind a paywall or limit items |

Not planned: inventory, accounts, remote view or sync of a family, AI chat, health scores, community, ads.
