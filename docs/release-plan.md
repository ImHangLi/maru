# Release plan

The plan for TestFlight and the App Store release (D051). Update the status column when a step finishes.

## 1. Maintainer actions

| Step | State |
|---|---|
| Join the Apple Developer Program as an individual | Done on 2026-10-13 |
| Accept the Paid Apps agreement, and add the bank and tax data (W-8BEN) in App Store Connect | Open: the agreement has the state "Pending User Info" on 2026-10-13, and a tax form is missing. The maintainer does not register for GST for now, so an in-app purchase may not be for sale in the Australian storefront (D064). Check the state of the agreement before the first release |
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
| Analytics: PostHog with a field allowlist, on by default outside the EU, the EEA, the UK, Switzerland, and South Korea. Each event has the region setting of the iPhone as a two-letter code | §11, D051, D064 | T41–T45 |
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
- Screenshots at 1206 × 2622 pixels in each language. This is the required iPhone size. Section 7 of the same note has the six frames and their order. The frames use simulator captures of `main`, and they are in `ui-shots/store-final/iphone/`, outside the repository.
- Screenshots for the 13-inch iPad in each language (D072), at 2064 × 2752 pixels. App Store Connect requires them for an app that supports the iPad. Both sets are uploaded (section 7).
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
- In-app purchases: Australia can refuse them while the maintainer has no GST registration (D064). The Paid Apps agreement decides it. Version 1.1.0 has no in-app purchase (D099).
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
| Usage Data: Product Interaction | Analytics | Yes | No | The events `setup_step`, `daily_usage_summary`, `notification_permission`, `setting_changed`, `data_action`, and `feedback_entry` (D077), and `paywall_shown` from 1.2 (D107) |
| Diagnostics: Other Diagnostic Data | Analytics | Yes | No | `core_error`, `app_version`, `ios_major`, and `device` |
| Other Data: Other Data Types | Analytics | Yes | No | `region` (D064) and `app_language` (D077) |

| Purchases: Purchase History | Analytics | Yes | No | `purchase_result` (D107). Not published yet |

The published label matches `PostHogClient`, `PRIVACY.md`, and `App/PrivacyInfo.xcprivacy` of 1.1. The code of 1.2 sends `purchase_result` (D107), and `App/PrivacyInfo.xcprivacy` lists "Purchase History". Add "Purchase History" to the label in App Store Connect before the release of 1.2.

### Tips

The tips were removed (D099). A paid "Pro" tier comes in version 1.2.

### Maru Pro (D107)

The code has the purchase, the paywall, and the entitlement. The maintainer does these steps in App Store Connect. The agent does not touch App Store Connect.

- [ ] Paid Apps agreement: the state is "Active", with the bank and the tax forms. No in-app purchase can be sold before that.
- [ ] Remove the three tip products of D053, or leave them "Removed from Sale" (D099).
- [ ] Create the subscription group "Maru Pro", with a localized display name in the eight store languages.
- [ ] In the group, create the auto-renewable subscription `com.imhangli.maru.pro.yearly`: duration 1 year, price about USD 9.99 with the price tiers of each storefront, a display name and a description in the eight store languages.
- [ ] Add the introductory offer to the yearly plan: "Free", 1 week, in all storefronts.
- [ ] Create the non-consumable `com.imhangli.maru.pro.lifetime`: price about USD 19.99, a display name and a description in the eight store languages.
- [ ] Turn on Family Sharing for both products. It cannot be turned off later.
- [ ] Add a review screenshot of the paywall and review notes for each product. The notes say where the paywall is (Settings, "Maru Pro") and that every free feature stays free.
- [ ] Add both products to the version 1.2 submission. The first in-app purchase of an app must go to review with a new version.
- [ ] Add "Purchase History" to the privacy label (see "Privacy label").
- [ ] Change the store text of 1.2: it must say what needs a purchase (guideline 2.3.2), and "no paywall" must go.
- [ ] Test in TestFlight with a Sandbox account: buy yearly, buy lifetime, restore, an offer code, and Ask to Buy.
- [ ] Do not submit before the Pro features are in the build. A purchase with no content is a rejection risk (guideline 3.1.1).

### Notes for App Review

The notes are in App Store Connect. They state: what Maru does, no account, the steps to see a reminder in two minutes, no medical advice and no dose calculation, where the data stays, the usage statistics, the label scan, and the widgets. The notes of 1.0.0 also say where the tips are. Remove that line before the submission of 1.1.0 (D099).

### TestFlight

- Build 4 of version 1.0.0 is the submission build. It was uploaded on 2026-10-14 from `main` (`54f71cf`), it has the app and the widgets and no Watch app, and its state is "Valid". It has the analytics events of D077 and D078 and opens the feedback form in Safari.
- Builds 1 and 2 came before it, on the same day. Build 2 has two shorter German titles and the hidden tip section. Build 3 has the text color in rows, no "Send a Test Notification" row, and a progress bar in the medium Today widget. Build 3 went to review on 2026-10-13, and the maintainer withdrew it on 2026-10-14 for build 4.
- Each archive used the Release configuration, automatic signing, the analytics key from the Keychain on the command line, and the build number as `CURRENT_PROJECT_VERSION` on the command line. `project.yml` keeps build number 1. The distribution profiles have the App Group, and the app profile has the time-sensitive entitlement. The upload validation rejected nothing.
- The Release build has no test control. The strings "Test Notification" and "Test Scenarios" are not in the app binary, the widget binary, or the compiled string tables of build 3. Build 4 has the same analytics key as build 3, and the same entitlements.
- The group "Internal" is an internal group with access to all builds. The maintainer is its tester.
- The feedback email and the beta review contact email are `hello@maru.day`. Each build has its "What to Test" text.
- A later build replaces build 4 on the version with `asc versions attach-build`.
- Not done on purpose: no Beta App Review and no public link. No external TestFlight step is planned.

### Store text of version 1.1

The files are in `metadata/version/1.1.0/` for the eight store languages. They are drafts. Nobody pushed them to App Store Connect. The plan is `2026-10-15-store-page-personas-and-trust.md` in the maintainer's research folder, and the first feedback is in `pitch-feedback-2026-10-15.md` in the maintainer's notes.

Maintainer decisions of 2026-10-15:

- **Privacy: keep the usage statistics.** The text never says "connects to nothing" or "no data leaves". It says that items and records stay on the iPhone or iPad, that Maru needs no account, and that what the user takes is never sent anywhere. The optional usage counts stay in the text, and they never include what the user takes. The text uses plain words. It does not lead with "server", "local-first", or "open source".
- **Subtitle.** English: "Supplement & Medicine Tracker". The other languages keep the same meaning in 30 characters or fewer. The name stays as in 1.0.0.
- **"Free" must be clear.** The promotional text and the first lines of the description start with "100% free" in the local words, and they say "no subscription, no ads, no paywall". The name, the subtitle, and the keywords have no price word (guideline 2.3.7).
- **No setup.** The first lines say that there is no sign-up and nothing to set up first.
- **Features in the text.** Dark mode, and alarms for each item (iOS 26 or later).
- **Persons in proportion.** Vitamins, supplements, and medicine lead. One short paragraph, "Not just for you", says that a user can track a pet or a parent on the user's own phone. The paragraph says that Maru has no profiles and no sharing.
- **Removed from 1.0.0.** The line "It is not an alarm", the lines "Open source", and the tip answer. The zh-Hans text uses 药品 and 保健品 like the app. All languages use the button names of `App/Localizable.xcstrings`.
- **No medical claim.** The text has no "never miss a dose" and no competitor name.

Checks before the text goes to App Store Connect:

- Keep the alarm lines only after the iPhone check in `docs/status.md` passes (silent mode, Focus, locked screen). If the check fails, remove "rings like the Clock app" and the alarm words in the promotional text, the description, and "What's New".
- The text says "no paywall", and it does not say "no in-app purchases", because a paid "Pro" tier comes in version 1.2 (D099). Version 1.1 has no in-app purchase.
- The keyword field holds at most 100 bytes in en, es, and de. The zh-Hans, ja, and ko fields hold at most 100 characters, as in 1.0.0, and they are more than 100 bytes. Apple states the limit as 100 bytes. App Store Connect accepted the 1.0.0 values. Check the CJK fields when you push them.
- A native speaker has not read the text for zh-Hans, ja, ko, es, and de.
- The site privacy pages and the FAQ still show the text of 1.0. A maintainer changes them with the release.

### What is open before the submission

`asc validate --strict` on version 1.0.0 reports no error. Its three warnings are the tips that are not in the submission.

- The screenshots are uploaded for the eight store languages: six for the 6.9-inch iPhone and six for the 13-inch iPad in each.
- The Paid Apps agreement has the state "Pending User Info": a tax form is missing. The Free Apps agreement is active. The app ships without the tips.
- Done: the maintainer submitted version 1.0.0 with build 4 on 2026-10-14. Its state is "Waiting for Review", and the release is manual.
