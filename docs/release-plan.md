# Release plan

The plan for TestFlight and the App Store release (D051). Update the status column when a step finishes.

## 1. Maintainer actions

| Step | State |
|---|---|
| Join the Apple Developer Program as an individual | Done on 2026-10-13 |
| Accept the Paid Apps agreement, and add the bank and tax data (W-8BEN) in App Store Connect | Open. The maintainer does not register for GST for now, so the tips may not be for sale in the Australian storefront (D064). Check the state of the agreement before the first release |
| Give the agent the Team ID, and set the paid team in Xcode for each target, also the Watch app (D071) | Team ID `JBG4XL9NQK`. Xcode needs the Apple ID again |
| Create an App Store Connect API key (App Manager). Enter it in a private prompt, never in chat | Open |
| Buy the landing page domain | Done: `maru.day` |
| Create the PostHog project | Done. "Discard client IP data" is on. The cloud region must match `MARU_ANALYTICS_HOST` and the sentence in `PRIVACY.md` (D063) |
| Create the X, Reddit, and Product Hunt accounts for Maru | Open |
| Search the "Maru" trademark in the main markets | Open |

## 2. Identity

- Freeze the bundle IDs `com.imhangli.maru` and `com.imhangli.maru.widgets` before the first upload (D005).
- The Watch app has the bundle ID `com.imhangli.maru.watchkitapp` (D071). The app embeds it, so an archive includes it. To ship 1.0 without the Watch app, archive 1.0 before that change merges, or remove the `MaruWatch` dependency for the archive. A build with the Watch app needs Watch screenshots and a sentence in the privacy policy.
- Register the App Group on the paid team. Done: the paid team is the free team, so the group ID stays (D062).
- Set the version to 1.0.0. Done (D062).
- Add the time-sensitive notification entitlement (D034). Done in code (D062). The device build waits for the Apple ID in Xcode.

## 3. Features

| Feature | Spec | Acceptance |
|---|---|---|
| Analytics: PostHog with a field allowlist, on by default outside the EU, the EEA, the UK, and Switzerland. Each event has the region setting of the iPhone as a two-letter code | §11, D051, D064 | T41–T45 |
| Supporter tips with StoreKit 2 (D053). They may not be for sale in the Australian storefront (D064) | §14 C | T48 |
| Optional photo with background removal | §5.2 | T30–T32 |
| Six languages: en, zh-Hans, ja, es, de, ko | §13.2, D051 | T49 |
| Privacy manifests and the export compliance key | §10 | Done in this change |

## 4. Quality

- One week of daily use on the maintainer's iPhone, from 2026-10-12 to 2026-10-19.
- The open device checks in `docs/status.md`.
- The check on a real iPad (D072). If it fails, set `TARGETED_DEVICE_FAMILY` to `"1"` in both targets before the first upload. An update cannot remove the iPad later.
- Dark Mode, the largest text sizes, VoiceOver, and Reduce Motion (T33).
- Launch and record timing on a release build (T36).
- Analytics, with a release build that has the key:
  - "Discard client IP data" in the PostHog project: on. Look at the setting again before the release.
  - Check the packets (T42). Each event has only the fields of `PRIVACY.md`. The region is two letters or absent, and no event has a language, a time zone, or a location.
  - Check in PostHog that the events have no GeoIP properties and no person profile.
- A TestFlight beta with external testers. It needs Beta App Review.

## 5. Store page

- Name, subtitle, keywords, and description: the files in `metadata/`, in the layout of `asc metadata`. Six languages, es-MX, and en-GB. The reasons are in `docs/research/2026-10-13-aso-and-store-page.md`. The app record has the name "Maru: Pill & Vitamin Reminder".
- Screenshots at 1206 × 2622 pixels in each language. This is the required iPhone size. Section 7 of the same note has the six frames and their order. The frames use simulator captures of `main`, and they are in `ui-shots/store-final/iphone/`, outside the repository.
- Screenshots for the 13-inch iPad in each language (D072), at 2064 × 2752 pixels. App Store Connect requires them for an app that supports the iPad. They are in `ui-shots/store-final/ipad/`.
- A privacy policy page and a support page on the landing page domain. The URLs in `metadata/` return 404 until the new site is live.
- Privacy labels that match the build and `App/PrivacyInfo.xcprivacy`, all for analytics, linked to the user (D069), and with no tracking: Identifiers (Device ID), Usage Data (Product Interaction), Diagnostics (Other Diagnostic Data), and Other Data (Other Data Types, the region setting, D064). Do not select Location.
- Age rating, the category Health & Fitness, and review notes: no account, the reminder behavior, and no medical advice (T50). Drafts are in section 8 of the note. The secondary category is Medical.

## 6. Launch

- A landing page with the store link, the privacy policy, and the support page.
- An X post and a thread.
- Reddit posts in subreddits that allow them. Read the rules of each subreddit first.
- Product Hunt and a "Show HN" post, because the code is open.
- Chinese, Japanese, Spanish, German, and Korean channels after the store page is live in that language.
