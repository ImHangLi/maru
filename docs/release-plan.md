# Release plan

The plan for TestFlight and the App Store release (D051). Update the status column when a step finishes.

## 1. Maintainer actions

| Step | State |
|---|---|
| Join the Apple Developer Program as an individual | Open |
| Accept the Paid Apps agreement, and add the bank and tax data (W-8BEN) in App Store Connect | Open |
| Give the agent the Team ID, and set the paid team in Xcode for both targets | Open |
| Create an App Store Connect API key (App Manager). Enter it in a private prompt, never in chat | Open |
| Buy the landing page domain | Open |
| Create the PostHog project (EU cloud) | Open |
| Create the X, Reddit, and Product Hunt accounts for Maru | Open |
| Search the "Maru" trademark in the main markets | Open |

## 2. Identity

- Freeze the bundle IDs `com.imhangli.maru` and `com.imhangli.maru.widgets` before the first upload (D005).
- Register the App Group on the paid team. If the free team holds `group.com.imhangli.maru`, use a new group ID.
- Set the version to 1.0.0.
- Add the time-sensitive notification entitlement (D034).

## 3. Features

| Feature | Spec | Acceptance |
|---|---|---|
| Analytics: PostHog with a field allowlist, on by default outside the EU, the EEA, the UK, and Switzerland | §11, D051 | T41–T45 |
| Supporter purchase with StoreKit 2, and a restore | §14 C | T48 |
| Optional photo with background removal | §5.2 | T30–T32 |
| Six languages: en, zh-Hans, ja, es, de, ko | §13.2, D051 | T49 |
| Privacy manifests and the export compliance key | §10 | Done in this change |

## 4. Quality

- One week of daily use on the maintainer's iPhone, from 2026-10-12 to 2026-10-19.
- The open device checks in `docs/status.md`.
- Dark Mode, the largest text sizes, VoiceOver, and Reduce Motion (T33).
- Launch and record timing on a release build (T36).
- A TestFlight beta with external testers. It needs Beta App Review.

## 5. Store page

- Name, subtitle, and keywords: see the research note. Six languages with fastlane `deliver`.
- Screenshots for the 6.9-inch iPhone in each language.
- A privacy policy page and a support page on the landing page domain.
- Privacy labels that match the build: usage data and diagnostics, not linked to the user, no tracking.
- Age rating, the category Health & Fitness, and review notes: no account, the reminder behavior, and no medical advice (T50).

## 6. Launch

- A landing page with the store link, the privacy policy, and the support page.
- An X post and a thread.
- Reddit posts in subreddits that allow them. Read the rules of each subreddit first.
- Product Hunt and a "Show HN" post, because the code is open.
- Chinese, Japanese, Spanish, German, and Korean channels after the store page is live in that language.
