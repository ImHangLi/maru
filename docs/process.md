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

- One GitHub issue is one unit of work. It cites spec sections and acceptance IDs (`T01`–`T50`). It fits in one pull request.
- Group issues in GitHub milestones that match `docs/roadmap.md`.
- Use one branch for each issue.

## Flow for one issue

1. Read the issue, `docs/status.md`, and only the spec sections that the issue cites.
2. Implement. Build the package and the app. For a UI change, run the app in a simulator and capture screenshots.
3. Open a pull request. The description lists the covered acceptance IDs, the evidence, and the checks that did not run.
4. Get a review from a second reviewer: a person, or a different model than the one that wrote the change. Fix real findings. A fix needs a new test only if the defect can lose, double, or wipe a record (D016).
5. Merge when CI passes and the review has no open blocking finding.
6. Update `docs/status.md`.
