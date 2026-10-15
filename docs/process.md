# How we work

This document describes how a change to Maru is planned, recorded, and reviewed. It applies to maintainers, contributors, and coding agents. Agent-specific rules are in `AGENTS.md`.

## Records

The repository is the project memory. A new contributor or a new agent session must be able to continue from these files alone.

| File | Content | Update rule |
|---|---|---|
| `docs/status.md` | Current milestone, work in progress, next steps, open questions | Rewrite at the end of every work session |
| `docs/decisions.md` | Numbered decisions with reasons | Append. Do not rewrite old entries. Mark a replaced decision as superseded |
| `docs/roadmap.md` | Direction, milestones, and future candidates | Change only after a maintainer decision |
| `docs/spec.md` | Product and technical spec | Change only after a maintainer decision. Record the change in `docs/decisions.md` |
| `docs/design.md` | Visual rules | Change with the decision that changes the rule |
| `docs/research/` | Dated research notes with source links | Add a new file per study |

Older records call the maintainer "the owner".

## Maintainer decisions

A pull request alone cannot make these decisions. A maintainer makes them and records them in `docs/decisions.md`.

1. A change to the product direction or the frozen scope in `docs/spec.md` §1.
2. Anything that costs money, such as the Apple Developer Program or paid services.
3. Anything published outside the repository: App Store or TestFlight builds, store text, the privacy policy, and replies to users.
4. The acceptance of a milestone, after a short demo (screenshots or a video) and a list of open risks.
5. Accounts, legal, and trademark actions.

## Work units

- One GitHub issue is one unit of work. It cites spec sections and acceptance IDs (`T01`–`T52`). It fits in one pull request.
- Group issues in GitHub milestones that match `docs/roadmap.md`.
- Use one branch for each issue.

## Flow for one issue

1. Read the issue, `docs/status.md`, and only the spec sections that the issue cites.
2. Implement. Build the package and the app. For a UI change, run the app in a simulator and capture screenshots.
3. Open a pull request. The description lists the covered acceptance IDs, the evidence, and the checks that did not run.
4. Get a review when "Token budget for agents" asks for one: a person, or a different model than the one that wrote the change. Fix real findings. A fix needs a new test only if the defect can lose, double, or wipe a record (D016).
5. Merge when CI passes and the review has no open blocking finding.
6. Update `docs/status.md`.

## Release checks

A fix of a reminder or of stored data is not done until a device check passes (D088).

1. Install the build on the iPhone and open the app.
2. Read the live log: `uvx pymobiledevice3 syslog live --udid <UDID>`. Filter for `Maru` and the category `reminders`.
3. Save an item, record a dose, and take an as-needed dose. Each action must end with a log line "Reminder run" and no line "Reminder run failed".
4. A line "A stored row did not load" names a rule. Fix the cause of that rule before the release.
5. A change of the schema adds a fixture to `Packages/MaruKit/Tests/MaruNotificationSimulationTests/Fixtures`: a database that the shipped version left after real use. `UpgradeTests` opens it with the new code and runs the whole reminder queue.

## Token budget for agents

The maintainer asked for a lean, token-efficient way of work (D045).

- The lead agent makes a small change itself. A small change touches about three files or fewer, or only text, assets, or docs.
- Use a subagent only for a large change with its own worktree. Run at most two implementation subagents at the same time.
- Keep a subagent brief short. Point to the spec sections, decisions, and files. Do not paste them.
- Review by risk:
  - A change to records, the database, reminders, or the tap resolver gets one review by a different model. A second round runs only for an open blocking finding, and it checks only that finding.
  - A change to UI, text, assets, or docs gets no model review. CI and the check on the maintainer's iPhone are the review.
- Batch the device install. Install one build after a group of merges, not after each merge.
- Keep one decision record for the group of small decisions that one maintainer message gives.
