# Evidence: what users want, and where Maru stands

Updated: 2026-10-11. Open this file first. It merges the research notes in this folder and links to them for the detail. It answers one question: when Maru ships, where is it better than the other apps, and what proves it?

Maru is not released. "Shipped" in this file means that the feature is in the code on `main`. It does not mean that users have it, and several features still need a check on a real iPhone (`docs/status.md`).

Sources of the two studies:

- China: 52 Xiaohongshu posts and about 890 comment lines (`2026-10-11-user-feedback-cn.md`).
- World: 46 Reddit threads with about 745 comments read, 1,183 App Store reviews from the US and the UK, 6 Apple Support Community threads, and small samples from Hacker News and X (`2026-10-11-user-feedback-world.md`).

All counts are approximate. A Reddit or Xiaohongshu count is a hand count of comments. A review count is the number of 1 to 3 star reviews with a keyword of the theme, so it overcounts. The counts give an order, not a share of users.

## 1. Summary: what users want

1. A core that is free, or paid one time. No subscription, no ads, no limit of two items.
2. An app that stays the same and keeps the records. No crashes, no lost history, no new screen in front of the list.
3. A clear reason to use it when Apple Health, the alarm, and the pill box exist.
4. A reminder that is hard to miss, and that comes again until the user confirms.
5. A sure answer to "did I take it?", with the time.
6. A record in one tap: in the app, on the reminder, on a widget, or on Apple Watch.
7. Schedules that are not daily: every other day, cycles, every few hours.
8. No account, and health data that stays private.
9. For users with many prescriptions: stock, family sharing, and a record for the doctor.
10. A way to take the data out.

## 2. Pain points, most frequent first

"CN" is the China study and "World" is the study outside China. Status words: **shipped** (in the code on `main`), **in progress**, **planned** (in `docs/status.md` or `docs/roadmap.md`), **not planned** (out of scope by the spec or a decision).

| # | Pain point | CN mentions | World mentions | Quotes | Competitors with the problem | Maru's answer | Proof |
|---|---|---|---|---|---|---|---|
| 1 | Paywall, subscription, ads, or a limit on free items | About 15 | About 45 Reddit comments, 118 reviews | "I will never pay a subscription for a reminder app. A one-time payment, yes." ([Reddit](https://www.reddit.com/r/androidapps/comments/1pfx7su/)) "I downloaded three apps and each one needs a paid upgrade." ([XHS](https://www.xiaohongshu.com/explore/6a4eeccd0000000008030347)) | Medisafe: subscription required in some countries from 2026-01-01 ([terms](https://www.medisafe.com/terms-and-conditions/)). MyTherapy: ads and an "Ad-free Subscription" ([store page](https://apps.apple.com/us/app/pill-reminder-mytherapy/id662170995)). Pill Reminder - All in One: 2 reminders in the free version ([store page](https://apps.apple.com/us/app/pill-reminder-all-in-one/id816347839)) | **Shipped.** Free core, no ads, no account, no limit on items | Spec §1, `docs/faq.md`, `PRIVACY.md` |
| 2 | The app became worse: crashes, lost records, an update that hides the list | Not a theme | 67 reviews about an update, 46 about crashes, 34 about lost data | "All my history of medicines is gone. Back to pen and paper." ([EveryDose reviews](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1188929364/sortby=mostrecent/json)) "The update forces you to a 'For You' page." ([Medisafe reviews](https://itunes.apple.com/us/rss/customerreviews/page=1/id=573916946/sortby=mostrecent/json)) | Medisafe, EveryDose, MyTherapy, Max, and Pill Reminder - All in One, by user reviews. Apple Health: a blank Medications screen until a restart, 114 "Me too" votes ([Apple thread](https://discussions.apple.com/thread/255955677)) | **Shipped in the design, not proved in use.** Today is the first screen. A plan change keeps past records. "Recorded" shows only after the commit. No database reset | Spec §3 P01, §7.2, §7.3, T06, T19, T37, D019 |
| 3 | "Why not Apple Health, an alarm, or a pill box?" | About 37 | About 75 Reddit comments | "What is the point of a feature that the system already has?" ([XHS](https://www.xiaohongshu.com/explore/695abd92000000001e0145d5)) "Four steps for something that needs two." ([Reddit](https://www.reddit.com/r/ios/comments/y5147j/)) | Apple Health: the record is deep in the app, and users report no Home Screen widget ([Reddit](https://www.reddit.com/r/ios/comments/y5147j/)) | **Shipped** as a rule: each shared flow has fewer steps than Apple Health. The answer for the store page is written | D021, D033, `2026-10-11-apple-health-gap.md`, `docs/faq.md` |
| 4 | A reminder that is easy to miss, or that does not arrive | About 18 | About 40 Reddit comments, 32 reviews | "I click on the reminder and then forget to take it." ([Reddit](https://www.reddit.com/r/birthcontrol/comments/1l5cn00/)) "Does it ring like an alarm?" ([XHS](https://www.xiaohongshu.com/explore/695abd92000000001e0145d5)) | MyTherapy and EveryDose: reminders that did not come, by user reviews ([MyTherapy UK](https://itunes.apple.com/gb/rss/customerreviews/page=1/id=662170995/sortby=mostrecent/json), [EveryDose](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1188929364/sortby=mostrecent/json)) | **Partly shipped.** Local reminders with no server. Follow-ups that the user sets are **in progress** (D039): 1 to 5 times or "Until Recorded", 5 minutes to 1 hour apart. "Until Recorded" has a stated limit of 12 for each dose. Time Sensitive reminders are **planned**. An alarm that passes silent mode is **not planned** | Spec §8.1, §4, D021, D034, D039 |
| 5 | "Did I take it or not?" | About 16 | About 25 Reddit comments | "I can have the pills in my hand and then wonder for 5 minutes if I took my medicine." ([Reddit](https://www.reddit.com/r/cfs/comments/1u8hnda/)) "If I take it, I fear a double dose. If I do not, I fear a missed dose." ([XHS](https://www.xiaohongshu.com/explore/6a72f2fc000000003301e248)) | Alarms and calendars: they keep no record. Apple Health: "I do not know if it is recorded or not" ([XHS](https://www.xiaohongshu.com/explore/6a72a199000000002701d760)) | **Shipped.** Today keeps the recorded row with its time. History separates taken, skipped, and no record | Spec §3 P01, §4, D032 |
| 6 | The record costs too many steps | About 14 | About 25 Reddit comments, 15 reviews | "The record of a habit is now more work than the habit." ([XHS](https://www.xiaohongshu.com/explore/6ab799370000000002029feb)) "I would love a notification with an action: taken, skip, or remind me later." ([Reddit](https://www.reddit.com/r/iosapps/comments/1vq3ji3/)) | Apple Health: about 5 taps in the app (`2026-10-11-apple-health-gap.md`), and no Shortcuts action, 31 "Me too" votes ([Apple thread](https://discussions.apple.com/thread/256058038)) | **Shipped:** one tap, "Record All", and a "Taken" action on a single-item reminder. **In progress:** a Home Screen widget. **Planned later:** Apple Watch and Siri | D021, D034, `docs/status.md`, `docs/roadmap.md` |
| 7 | Schedules that are not "every day" | About 18 | About 15 Reddit comments, 32 reviews | "Every day I do not forget. Every other day I lose the rhythm." ([XHS](https://www.xiaohongshu.com/explore/6a13310400000000350225dc)) "Took it now, remind me again in 6 hours." ([Reddit](https://www.reddit.com/r/ADHDmeds/comments/1nwcwol/)) | Apple Health: an "every other day" plan reminds on two days in a row, 29 "Me too" votes ([Apple thread](https://discussions.apple.com/thread/256237756)). EveryDose and Max: reviews about hourly and cycle plans | Daily and weekdays are **shipped**. Every other day is **in progress**. Cycles are **planned later**. Every X hours is **not planned** | D035, spec §1, `docs/roadmap.md` |
| 8 | Stock, refill, and expiry | About 13 | About 14 Reddit comments, 14 reviews | "The alarm, the calendar, and the built-in reminders do not show how many pills you have left." ([Reddit](https://www.reddit.com/r/mildlyinfuriating/comments/1pholda/)) "I run out with no warning." ([XHS](https://www.xiaohongshu.com/explore/6a1c2a1200000000380342a7)) | Apple Health: no pill count, by user reports. Pill Reminder - All in One: "sometimes it deducts the dose, sometimes not" ([reviews](https://itunes.apple.com/gb/rss/customerreviews/page=1/id=816347839/sortby=mostrecent/json)) | **Not planned** | Spec §1, D035 |
| 9 | Family, caregivers, more than one person | About 12 | About 20 Reddit comments, 17 reviews | "Both apps assume one user with one set of meds." ([Reddit](https://www.reddit.com/r/CaregiverSupport/comments/1t7boem/)) "I wanted to separate the medication of my grandfather and my grandmother." ([XHS](https://www.xiaohongshu.com/explore/6aaa74a7000000002803a8b1)) | Max: no sync between two phones, by a user review ([reviews](https://itunes.apple.com/us/rss/customerreviews/page=1/id=1502063556/sortby=mostrecent/json)) | **Not planned.** It needs a server and accounts | Spec §1 |
| 10 | Accounts, privacy, and the sale of data | Part of about 15 | About 12 Reddit comments, 30 reviews | "Must work offline, preferably no signups." ([Reddit](https://www.reddit.com/r/androidapps/comments/1pfx7su/)) "A panel makes it very difficult to opt out from the sale of your personal information." ([MyTherapy UK reviews](https://itunes.apple.com/gb/rss/customerreviews/page=1/id=662170995/sortby=mostrecent/json)) | MyTherapy: "Data Used to Track You: Identifiers" ([store page](https://apps.apple.com/us/app/pill-reminder-mytherapy/id662170995)). Medisafe: keeps user information up to 7 years ([terms](https://www.medisafe.com/terms-and-conditions/)) | **Shipped.** No account, no server, no network requests, public source code | `PRIVACY.md`, D031, spec §10 |
| 11 | A long history, a record for the doctor, and an export | About 10 | About 10 Reddit comments, 42 reviews | "The doctor usually asks how many doses I missed." ([Reddit](https://www.reddit.com/r/Hypothyroidism/comments/1gf18uw/)) "It only lets me look at a month before the current date." ([Medisafe reviews](https://itunes.apple.com/us/rss/customerreviews/page=1/id=573916946/sortby=mostrecent/json)) | Medisafe: a history of one month, by a user review. Pill Reminder - All in One: a schedule change changes old records, by user reviews | History with no time limit is **shipped**. A CSV export, and a backup and a restore, are **in code** (D040). A count for each item is **planned** with the heatmap | D032, D040, spec §7.3, `docs/roadmap.md` |
| 12 | Android and HarmonyOS | About 15 | Not counted | "Independent developers never think of Android." ([XHS](https://www.xiaohongshu.com/explore/6aaa74a7000000002803a8b1)) | Pillo: Android only, with a waitlist for iOS ([vendor page](https://pillo.care/blog/medisafe-no-longer-free-best-free-alternatives)) | **Not planned.** Maru is an iPhone app | Spec header |
| 13 | Notes and supplements: "with food", custom names, IU, what it is for | About 14 | About 20 Reddit comments, 15 reviews | "Fish oil is not there. Basic vitamins and supplements are missing." ([MyTherapy reviews](https://itunes.apple.com/us/rss/customerreviews/page=1/id=662170995/sortby=mostrecent/json)) "The forms are too few. Let the user type a custom one." ([XHS](https://www.xiaohongshu.com/explore/696a60f6000000001a02828c)) | Apple Health: no IU unit (`2026-10-11-apple-health-medications.md`). MyTherapy: supplements missing from its list, by a user review | **Shipped.** Free text names, IU, a note with presets, as-needed items | D006, D021, spec §2.1 |
| 14 | Trust in a small new app | About 12 | About 5 Reddit comments | "One look and it is AI." ([XHS](https://www.xiaohongshu.com/explore/6ab799370000000002029feb)) "Funny how many of these apps keep popping up." ([Reddit](https://www.reddit.com/r/Supplements/comments/1ryt7qg/)) | Many new apps with the same promise. See section 4 | **Partly shipped.** Native system controls, public source code. The rules for a release in China are not checked | D026, D031 |
| 15 | Time zones, travel, and clock changes | Not a theme | About 10 Reddit comments, 6 reviews | "Time zone hell. Give us the option to never change the time." ([Medisafe reviews](https://itunes.apple.com/us/rss/customerreviews/page=1/id=573916946/sortby=mostrecent/json)) | Medisafe, EveryDose, and Pill Reminder - All in One, by user reviews | The zone rule is **shipped**. The question after a zone change is **planned** | Spec §8.5, D019, T25, `docs/status.md` |
| 16 | Interactions and medication information | About 3 | About 6 requests | "Will you add drug and supplement interactions?" ([Reddit](https://www.reddit.com/r/iosapps/comments/1rwjxtf/)) | Apple Health: interactions only in the U.S. (`2026-10-11-apple-health-gap.md`) | **Not planned.** Maru gives no medical information | Spec §0, §1 |

## 3. Competitors

Each cell has one mark:

- **C**: confirmed on the linked page on 2026-10-11. A store page and a privacy label come from the developer.
- **U**: users report it in the studies. Nobody verified it.
- **NV**: not verified. No source that I read states it.

Nobody tested these apps for this file, except one simulator run of Apple Health.

| App | Price and paywall | Account | Where the data lives | Steps to record a dose | Schedule types | Widget and Apple Watch | Strong points | Weak points that users report |
|---|---|---|---|---|---|---|---|---|
| Apple Health Medications | Free, no ads. C (`2026-10-11-apple-health-medications.md`) | No separate account. Sync uses the Apple Account. C ([Apple guide](https://support.apple.com/guide/iphone/track-your-medications-iph811670c81/ios)) | On the device, with iCloud sync. C (same guide) | About 5 taps in the app, 2 from the notification. From Apple's written steps, not counted on a device (`2026-10-11-apple-health-gap.md`) | Every day, days of the week, every few days, cyclical, as needed. C ([Apple support](https://support.apple.com/en-us/105064)) | Lock Screen widget: U. Home Screen widget: users report none, NV. Apple Watch app: C ([Apple guide](https://support.apple.com/guide/watch/medications-apd3dd24d78b/watchos)) | On every iPhone. Follow-up reminder and Critical Alerts. Apple Watch. Interactions in the U.S. | Deep in the Health app. Blank screen until a restart (iOS 18). "Every other day" errors (iOS 26). No pill count. No Shortcuts action |
| [Medisafe](https://apps.apple.com/us/app/medisafe-medication-management/id573916946) | Free download. Premium from $2.99 to $9.99 for each month and from $27.99 to $39.99 for each year. C (store page). A paid subscription is necessary in certain countries outside the U.S. from 2026-01-01. C ([terms](https://www.medisafe.com/terms-and-conditions/)). Free limit of 2 medications: U | An account exists: "Manage your entire family from one account". C (store page). Required or not: NV | On Medisafe servers. The terms keep user information up to 7 years. C (terms) | NV | NV | Lock Screen widget and Apple Watch app. C (store page) | Reminders that repeat until the user confirms. Family alerts. Long record of use | Paywall. "For You" screen in front of the list. Crashes. Broken Apple Watch app in September 2026. History of one month. Confusing time zone question |
| [MyTherapy](https://apps.apple.com/us/app/pill-reminder-mytherapy/id662170995) | Free download with ads. "Ad-free Subscription" at $0.99 and $9.99. "Plus, Lifetime" at $49.99. C (store page) | An account exists: "multiple profiles in one account". C (store page). Required or not: NV | NV. The privacy label lists "Data Used to Track You: Identifiers". C (store page) | "One-tap dose confirmation", by the release notes of the vendor. NV | NV | NV | Reminder that repeats. Stock count. Records the intake time | Ads from 2026. Reminders that did not arrive. A panel about the sale of data in the UK. Supplements missing from its list |
| Round Health | NV. Users call it free with no ads: U | NV | NV | One touch on Apple Watch: U | NV | Apple Watch: U | Clean and simple. Refill reminders: U | The US store lookup returned no result on 2026-10-11, and the listing page returned "not found". The cause is not verified |
| [Pill Reminder - All in One](https://apps.apple.com/us/app/pill-reminder-all-in-one/id816347839) | Free with 2 reminders. "Full Version" for $2.99, one time. C (store page) | No account in the description. NV | "The developer does not collect any data from this app." Backup and restore to a device. C (store page) | NV | Every X hours, every X days, weeks, or months, days of the week, as needed, 21 days on and 7 off. C (store page) | NV | Widest schedule list in this table. One-time price. Refill count | A schedule change changes old records. Time zone errors. No sync. No sound after iOS 27 for one user. As-needed moved behind a menu |
| [EveryDose](https://apps.apple.com/us/app/everydose-medication-reminder/id1188929364) | Free download. Plus at $9.99 for each month. The yearly price is $59.99 in the purchase list and $69.99 in the description. C (store page) | Login with Apple, Google, or Facebook, by the release notes. Required or not: NV | NV | NV | Daily, as needed, specific days, every X hours, weeks, or months, cycles. C (store page) | iPhone only. C (store page). Widget: NV | Interaction alerts. Sharing with a caregiver | No notifications for days. Crashes. Lost history. Login errors. Forced time zone shift |
| Pillo | Free with a paid plan for dependents, by the vendor. Ads: U | NV | NV | NV | NV | Android only, with a waitlist for iOS. C ([vendor page](https://pillo.care/blog/medisafe-no-longer-free-best-free-alternatives)) | An alarm that continues until the user confirms. The most frequent Medisafe replacement on Reddit | Too many notifications for some users. Ads. Not on iPhone |
| [Guava](https://apps.apple.com/us/app/guava-health-tracker/id1622255863) | Free, with no purchase in the store list. C (store page). Reviews mention a paid plan: NV | Login with Apple or Google, by the release notes. Required or not: NV | The privacy label lists health data as "linked to you". C (store page) | NV | NV | NV | Wide health tracker. Reads medications and doses from Apple Health | Not a simple reminder. Few complaints in the sample |

The same columns for Maru on `main`: free with no purchase yet. No account. A local database on the iPhone, with no server. One tap to record in the app, and one action on a single-item reminder. Daily, days of the week, and as needed. No widget and no Apple Watch app yet.

## 4. Where Maru is better, equal, and behind

All statements about Maru describe the code on `main`. Nobody verified them with outside users.

### Better today

| Point | Against | Evidence | Limit of the claim |
|---|---|---|---|
| The core is free, with no subscription, no ads, and no limit on items | Medisafe, MyTherapy, EveryDose, Pill Reminder - All in One | Section 3, spec §1 | Maru plans a supporter purchase. It must stay outside the core |
| No account and no network requests | Medisafe, MyTherapy, EveryDose, Guava | `PRIVACY.md`, store pages in section 3 | A feedback form is in progress. It will send data when the user sends feedback. The claim must change then |
| One tap to record, and one tap for a whole part of the day | Apple Health, about 5 taps | `2026-10-11-apple-health-gap.md` | Apple's count comes from written steps, not from a device |
| One screen to add an item, with no default dose and no default medication time | Apple Health, seven screens | `2026-10-11-apple-health-medications.md`, spec §2.1 | One simulator run of Apple Health |
| History with three clear states and no time limit | Medisafe, by one user report of a one-month limit | D032, spec §4 | The Medisafe limit is a user report |
| A plan change keeps the old records | Pill Reminder - All in One, and Apple Health for dose edits, by user reports | Spec §7.1, T06 | The competitor behavior is not verified |
| IU as a unit and free text names for supplements | Apple Health, MyTherapy | D021, the hands-on note | IU was missing in Apple Health on iOS 27.0 in one run |
| Public source code | Every app in section 3 | D031 | None |

### Equal

- Free, no account, and no ads: equal to Apple Health.
- A follow-up reminder: Apple's is fixed at 30 minutes. Maru offers 1 to 5 follow-ups or "Until Recorded" (at most 12 for each dose), 5 minutes to 1 hour apart. They stop after 7 days with no open of the app (D021, D039).
- A record from the reminder: equal to Apple for a reminder with one item. Apple also records a group. Maru opens the app for a group (D034).
- Daily and weekday schedules, as-needed items, archive, and delete.
- "No account, data stays on the phone" as a promise: equal to at least 5 new apps in the Reddit sample. This promise does not separate Maru from them.

### Behind

| Gap | Who has it | How often users ask | Maru's state |
|---|---|---|---|
| A reminder that repeats until the user confirms, or an alarm that passes silent mode | Medisafe, MyTherapy, Pillo, and Apple Health with Critical Alerts | The most frequent wish about function in the world study | In progress (D039): "Until Recorded" sends up to 12 follow-ups for each dose, until 01:00 of the next day at the latest. It is not an alarm, and it does not pass silent mode or a Focus |
| Time Sensitive reminders | Apple Health and others | Part of the same wish | Planned, after the Apple Developer Program membership (D034) |
| Apple Watch app | Apple Health, Medisafe | Frequent outside China | Planned later (roadmap) |
| Home Screen or Lock Screen widget | Medisafe has a Lock Screen widget | Frequent in both studies | In progress |
| Backup, export, and sync | Apple Health has iCloud sync. Medisafe has a server | Medium | A CSV export of the records, and a backup and a restore, are in code (D040). Nobody checked them on a real iPhone yet. The backup is not encrypted: a backup with a passphrase is planned for milestone B. Sync is on the later list |
| Every other day, cycles, every X hours, an end date | Apple Health, Pill Reminder - All in One, EveryDose | Frequent | Every other day is in progress. The others are later or out of scope |
| Stock and refill | Medisafe, MyTherapy, Pill Reminder - All in One, EveryDose Plus | About 27 mentions in the two studies, plus 14 reviews | Not planned (D035) |
| Family sharing and profiles | Medisafe, MyTherapy, EveryDose | Medium | Not planned (spec §1) |
| Interactions and medication information | Apple Health in the U.S., EveryDose | Low | Not planned (spec §1) |
| A question after a time zone change | Apple Health | Low | Planned (`docs/status.md`) |
| Siri and Shortcuts | Few apps | Low | Planned later |
| iPad, Android | Most competitors | About 15 mentions in China | Not planned |
| A record of real use | Every competitor | Not a request, but it decides trust | Maru has no release, no ratings, and no crash data |

## 5. Claims for the App Store text

### Claims that Maru can make

Check each claim again against the build that ships.

| Claim | Evidence | Condition |
|---|---|---|
| "Free. No subscription and no ads." | Spec §1 | The supporter purchase must not lock a core function |
| "No account. No sign-up." | Spec §1, T01 | None |
| "No limit on the number of items." | `docs/faq.md` | None |
| "Your records stay on your iPhone." | `PRIVACY.md`, spec §10 | The iPhone backup can include them. `PRIVACY.md` says so |
| "Maru makes no network requests." | `PRIVACY.md` | True today. Change it to "only when you send feedback" when the feedback form ships |
| "Open the app and record with one tap." | D021, `TodayRow.swift` | None |
| "Record from the reminder." | D034 | Only for a reminder with one item. The check on a real iPhone is still open |
| "See what you took, what you skipped, and what has no record." | D032, spec §4 | None |
| "Change the time of a record, or undo it." | D033 | None |
| "Reminders say what to take. One switch hides the names." | D029 | None |
| "Works for supplements: your own names, IU, and a note such as 'with food'." | D006, D021 | The note is the user's text. Do not present it as advice |
| "No streaks and no penalties." | Spec §1 | None |
| "Open source." | D031 | None |
| "One place for one job." | `docs/faq.md`, D035 | It is a description, not a measured fact |

### Claims that Maru must not make

| Claim | Reason |
|---|---|
| "Never miss a dose", "reminders always arrive", or any promise of delivery | Spec §8.1, T24, and T50 forbid it. A Focus, a summary, or the system can hold a notification |
| "Better adherence", "better health", or any clinical result | Spec §0 and T50. No study supports it |
| "More reliable than" a named app | Maru has no release and no crash data. The competitor problems are user reports |
| "Better than Apple Health" with no limit | Apple has more functions. The honest form is "fewer taps to record", after a count on a device |
| "The only private reminder", or "the only free one" | Apple Health is free and has no account. Many new apps make the same promise |
| "Reminds you until you take it", with no limit | "Until Recorded" sends at most 12 follow-ups for each dose, until 01:00 of the next day at the latest (D039). State the number |
| "Breaks through Focus or silent mode" | Time Sensitive reminders are not done (D034). Critical Alerts are out (D021) |
| "Every other day", "widget", or "feedback in the app" | In progress. Claim them only when they are in the released build |
| "Sync", "Apple Watch", "refill reminders", "family sharing" | Not in the app |
| "Export your records" or "back up and restore" | In code (D040). Claim them only when they are in the released build. Do not say "encrypted backup" |
| "Works with Apple Health" | Maru does not use HealthKit (D022) |
| "Checks interactions" or "tells you when to take it" | Maru gives no medical advice (spec §1) |
| A competitor's name in the store text | Guideline 2.3.7 forbids "popular app names" in metadata, and Apple's keyword page names "competing app names" as a reason for rejection (`2026-10-13-aso-and-store-page.md`) |

## 6. Index of the research notes

| Date | File | What it holds |
|---|---|---|
| 2026-10-10 | `2026-10-market-scan.md` | First short scan of competitors and pain points. Its MyTherapy line ("free, no ads") is out of date. See pain point 1 |
| 2026-10-10 | `2026-10-10-visual-direction.md` | Visual references and the Apple design rules that apply to the Today screen |
| 2026-10-11 | `2026-10-11-apple-health-medications.md` | One hands-on run of Apple Health Medications on an iOS 27.0 simulator, and the answer to "why Maru?" |
| 2026-10-11 | `2026-10-11-healthkit-medications-api.md` | What an app can do with the HealthKit Medications API. An app can read, and it cannot write doses |
| 2026-10-11 | `2026-10-11-apple-health-gap.md` | Feature table and flow counts for Apple Health against Maru, with the gaps to close |
| 2026-10-11 | `2026-10-11-user-feedback-cn.md` | User feedback from 52 Xiaohongshu posts, in 13 themes with verdicts |
| 2026-10-11 | `2026-10-11-user-feedback-world.md` | User feedback from Reddit, App Store reviews, the Apple Support Community, Hacker News, and X, in 15 themes with verdicts |
| 2026-10-11 | `evidence.md` | This file |

## 7. Findings that can change the plan

1. **Reminder strength is the largest gap in function.** Users in both studies want a reminder that comes again until they confirm. Maru sent one follow-up. The owner decided D039: the user sets the number and the time between follow-ups, and "Until Recorded" sends up to 12 for each dose. The check on a real iPhone is still open. An alarm that passes silent mode stays a gap.
2. **Apple's "every other day" has a public bug.** Maru builds the same schedule now. A correct result is a claim that Maru can prove, and a wrong day is the same harm. Test it more than the other schedules.
3. **Reliability is the second complaint in reviews.** A small scope protects Maru, but only real use proves it. Keep the one-week device test before any public claim.
4. **MyTherapy now has ads.** The market scan called it free with no ads. "No ads" is a stronger point than the plan assumed.
5. **Users who leave Medisafe ask for an export first.** A readable export before the public release lowers the fear of a second lock-in. Status: in code (D040).
6. **Apple Watch is asked for much more outside China.** It stays on the later list. It is the first thing that users of Apple Health and Medisafe will miss.
7. **Stock is asked for in both studies.** D035 keeps it out. The requests come from users with prescriptions, not from supplement users. Say on the store page that Maru does not count stock.
8. **Maru's promise is not unique.** At least 5 new apps in the Reddit sample promise "free, local, no account". The proof points that few of them have are the public source code, the tap counts, and the honest record states.

## 8. Limits

- The two studies are one day of collection each. The counts are approximate.
- Most feedback is about prescription medication. Maru's main use is supplements, and only about 20 of the 98 posts and threads are about supplements.
- Competitor facts come from store pages, terms, and user reports. Nobody installed the apps.
- The facts about Maru come from the code and the docs. Several flows still need a check on a real iPhone.
- The detail of each limit is in the two study notes.
