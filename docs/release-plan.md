# Release plan

The plan for TestFlight and the App Store release (D051). Update the status column when a step finishes.

## 1. Maintainer actions

| Step | State |
|---|---|
| Join the Apple Developer Program as an individual | Done on 2026-10-13 |
| Accept the Paid Apps agreement, and add the bank and tax data (W-8BEN) in App Store Connect | Open: the agreement has the state "Pending User Info" on 2026-10-13, and a tax form is missing. The maintainer does not register for GST for now, so the tips may not be for sale in the Australian storefront (D064). Check the state of the agreement before the first release |
| Give the agent the Team ID, and set the paid team in Xcode for each target, also the Watch app (D071) | Team ID `JBG4XL9NQK`. Xcode needs the Apple ID again |
| Create an App Store Connect API key (App Manager). Enter it in a private prompt, never in chat | Done. The `asc` CLI uses it from the keychain |
| Buy the landing page domain | Done: `maru.day` |
| Create the PostHog project | Done. "Discard client IP data" is on. The cloud region must match `MARU_ANALYTICS_HOST` and the sentence in `PRIVACY.md` (D063) |
| Create the X, Reddit, and Product Hunt accounts for Maru | Open |
| Search the "Maru" trademark in the main markets | Open |

## 2. Identity

- Freeze the bundle IDs `com.imhangli.maru` and `com.imhangli.maru.widgets` before the first upload (D005).
- The Watch app has the bundle ID `com.imhangli.maru.watchkitapp` (D071). Version 1.0 ships without it (D074): the app target does not depend on `MaruWatch`, so an archive has no Watch app. A build with the Watch app needs Watch screenshots and a sentence in the privacy policy.
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
- An internal TestFlight build on the maintainer's iPhone. No external TestFlight step is planned. The submission for App Review follows, when the maintainer starts it.

## 5. Store page

- Name, subtitle, keywords, and description: the files in `metadata/`, in the layout of `asc metadata`. Six languages, es-MX, and en-GB. The reasons are in `docs/research/2026-10-13-aso-and-store-page.md`. The text is in App Store Connect (section 7).
- Screenshots at 1206 × 2622 pixels in each language. This is the required iPhone size. Section 7 of the same note has the six frames and their order. The frames are HTML copies of the UI, and captures must confirm them before the submission.
- Screenshots for the 13-inch iPad in each language (D072). App Store Connect requires them for an app that supports the iPad.
- A privacy policy page and a support page on the landing page domain. The pages are live.
- Privacy labels that match the build and `App/PrivacyInfo.xcprivacy`, all for analytics, linked to the user (D069), and with no tracking: Identifiers (Device ID), Usage Data (Product Interaction), Diagnostics (Other Diagnostic Data), and Other Data (Other Data Types, the region setting, D064). Do not select Location. Published (section 7).
- Age rating, the category Health & Fitness, and review notes: no account, the reminder behavior, and no medical advice (T50). Drafts are in section 8 of the note. The secondary category is Medical. Set (section 7).

## 6. Launch

- A landing page with the store link, the privacy policy, and the support page.
- An X post and a thread.
- Reddit posts in subreddits that allow them. Read the rules of each subreddit first.
- Product Hunt and a "Show HN" post, because the code is open.
- Chinese, Japanese, Spanish, German, and Korean channels after the store page is live in that language.

## 7. The App Store Connect record

Set on 2026-10-13 (D075), with the `asc` CLI and, for the parts with no public API, in the App Store Connect website. Each value was read again after the write. The app is not submitted for review.

### Settings

| Setting | Value | Reason |
|---|---|---|
| Version | 1.0.0, manual release after approval | The record had "1.0", and the project has 1.0.0. A manual release keeps the release a maintainer decision |
| Store text | The files in `metadata/`, for en-US, en-GB, zh-Hans, ja, ko, de-DE, es-ES, and es-MX | `asc metadata push`. A second dry run shows no difference |
| Support, privacy, and marketing URLs | `https://maru.day/support/`, `https://maru.day/privacy/`, and `https://maru.day/`, with the folder `cn`, `jp`, `kr`, `de`, or `es` for the other languages | The paths of the live site. Each page returns 200 |
| Copyright | 2026 Hang Li | The name of the account holder |
| Primary category | Health & Fitness | See "Category" below |
| Secondary category | Medical | The maintainer decided it. Search reads both categories |
| Price | Free, base territory United States | |
| Availability | 174 territories, and new territories automatically. Not mainland China | The maintainer decided: no ICP filing for the first release |
| Content rights | Does not contain, show, or access third-party content | The name lists are the project's own. GRDB is code, not content |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `NO` in the Info.plist | Maru uses only the encryption of iOS. A build then needs no answer and no document |
| Regulated medical device | No | See "Medical device" below |
| Digital Services Act | Non-trader | It was declared before. The app page shows it as active for this app |
| Advertising identifier | Not used | The app has no AdSupport or AppTrackingTransparency code, and the label has no tracking |
| Review contact | The account holder, with the phone number and `hello@maru.day` | The maintainer gave them. The phone number is only in App Store Connect |
| Sign-in for review | Not required | Maru has no account |

### Category

Health & Fitness is the primary category. On 2026-10-13, in the US, 8 of the 10 top results for "pill reminder" and 7 of 10 for "medication reminder" have Medical as the primary category. 8 of 9 for "supplement tracker" and 7 of 9 for "vitamin tracker" have Health & Fitness. The name and the subtitle lead with supplements and vitamins, where a new app can rank, so the primary category follows that group. No reminder app is in the top 100 free apps of the Medical chart, and Medisafe with 101,000 ratings is not there, so the smaller chart gives a new app no place. Medical stays the secondary category, and search reads it.

### Territories

- Mainland China: not available. It needs an ICP filing number.
- The app information page names two more territory rules, and both are for games: the game license of Vietnam and the game rating number of Korea.
- EU: the trader status. Maru is declared as a non-trader, so the page shows no address or phone number.
- EU, EEA, UK, and US: the medical device declaration, see below.
- Age rating: no territory blocks the rating.
- The tips: Australia can refuse them while the maintainer has no GST registration (D064). The Paid Apps agreement decides it.
- Not checked beyond Apple's own pages: local consumer or health law of each territory.

### Age rating

| Question | Answer | Reason |
|---|---|---|
| Medical or Treatment Information | Infrequent or Mild | The app shows medicine and supplement names, and amounts from common labels as a typing aid. It gives no advice. "None" understates it, and "Frequent" is for an app whose content is medical information |
| Health or Wellness Topics | Yes | The app is about taking supplements and medicine |
| Alcohol, Tobacco, or Drug Use or References | None | A medicine name is not a reference to drug use |
| Unrestricted Web Access | No | The links open in the system browser |
| User-Generated Content, Messaging and Chat, Social Media, Advertising | No | The app has none of them |
| Parental Controls, Age Assurance | No | |
| Gambling, Simulated Gambling, Contests, Loot Boxes | No or None | |
| Violence, sexual content, profanity, horror, mature themes, weapons | None | |
| Kids age band, age rating override | Not set | |

Result: 13+ in 172 territories, and 12+ in Brazil, Korea, and Vietnam. The rating for systems earlier than version 26 is 12+.

### Medical device

The question is: "Is your app a regulated medical device in any country or region?" Apple asks it for the EU and EEA, the UK, and the US, because the categories are Health & Fitness and Medical. The answer is "No". Maru reminds and records what the user enters. It makes no diagnosis, calculates no dose, and makes no treatment decision. It has no CE mark, no UKCA mark, and no FDA registration.

- "No" needs nothing more.
- "Yes" needs, for each region, a registration number (EU SRN or FDA owner number, not for the UK), a URL with the instructions for use, a use statement, and safety information, and the product page shows them. Maru has none of these.
- Apple's page does not say what the product page shows for "No".
- If Maru adds dose advice or a check of interactions, ask this question again.

### Privacy label

"Data collection": yes. Tracking: no. Published on 2026-10-13.

| Data type | Purpose | Linked to the user | Tracking | What it is in the code |
|---|---|---|---|---|
| Identifiers: Device ID | Analytics | Yes | No | `distinct_id`, the random install ID |
| Usage Data: Product Interaction | Analytics | Yes | No | The events `setup_step`, `daily_usage_summary`, and `feedback_entry` |
| Diagnostics: Other Diagnostic Data | Analytics | Yes | No | `core_error`, `app_version`, and `ios_major` |
| Other Data: Other Data Types | Analytics | Yes | No | `region` (D064) |

The label matches `PostHogClient`, `PRIVACY.md`, and `App/PrivacyInfo.xcprivacy`. Add "Purchase History" in the release that first sends `purchase_result`.

### Tips

Three consumable in-app purchases, in `metadata/in-app-purchases/tips.json`.

| Product ID | English name | Price |
|---|---|---|
| `com.imhangli.maru.tip.small` | A Small Thanks | USD 0.99 |
| `com.imhangli.maru.tip.medium` | A Warm Thanks | USD 2.99 |
| `com.imhangli.maru.tip.large` | A Big Hug | USD 9.99 |

- The other territories have Apple's equalized prices. The tips are available in the same 174 territories as the app.
- Each has a name and a description in the eight store languages. The app shows the store name, so the app has no tip name of its own.
- Wording: guideline 3.1.1 allows a tip to the developer through in-app purchase. The names thank, and no text says "donation" or "donate", because Apple keeps donations for approved nonprofits (guideline 3.2.1). Each description and the review note say that a tip unlocks nothing.
- Each product has a review note with the path Settings, "Support Maru".
- Open: each product has the state "Missing Metadata" until it has a review screenshot. No capture shows the tips with their names and prices. Take one from the TestFlight build, add it to each product, and submit the three products with version 1.0.0.
- Open: a sale needs the Paid Apps agreement.

### Notes for App Review

The notes are in App Store Connect. They state: what Maru does, no account, the steps to see a reminder in two minutes, no medical advice and no dose calculation, where the tips are and that they unlock nothing, where the data stays, the usage statistics, the label scan, and the widgets.

### TestFlight

- Build 1 of version 1.0.0, uploaded on 2026-10-13 from `main` after D074. It has the app and the widgets, and no Watch app. Its state is "Valid", and it is in internal testing.
- The archive used the Release configuration, automatic signing, and the analytics key from the Keychain on the command line. The distribution profiles have the App Group, and the app profile has the time-sensitive entitlement. The upload validation rejected nothing.
- The group "Internal" is an internal group with access to all builds. The maintainer is its tester.
- The feedback email and the beta review contact email are `hello@maru.day`. Build 1 has its "What to Test" text.
- Build 1 is on version 1.0.0. A later build replaces it with `asc versions attach-build`.
- Not done on purpose: no Beta App Review and no public link. No external TestFlight step is planned.

### What is open before the submission

`asc validate --strict` on version 1.0.0 reports only the first two items.

- The screenshots for the iPhone and the 13-inch iPad.
- The review screenshot of the tips. The three products stay in "Missing Metadata" until each has one. Take one capture of Settings, "Support Maru", with the names and the prices, then run `asc iap review-screenshots create` for each product.
- The Paid Apps agreement has the state "Pending User Info": a tax form is missing. The Free Apps agreement is active. The app can ship without it, and the tips cannot be sold until it is active.
- A first in-app purchase goes to review with an app version. Add the three tips to the submission of 1.0.0.
- The submission itself. The maintainer starts it.
