# Store name and launch languages

Date: 2026-10-12. Two desk studies for the App Store release (D051).

## Store name

Method: the iTunes Search API (US store, 2026-10-12) for each candidate, for "maru", and for the generic terms. Sources of the pain points: `2026-10-11-user-feedback-world.md` (theme 5) and `2026-10-market-scan.md`.

- "Did I take it?" is the strongest pain point, but six or more apps already use it in the name. A "Maru: ..." name with it looks like a copy.
- "Pill Reminder", "Medication Reminder", and "Supplement Tracker" are crowded in names. They are good subtitle words for search.
- No app uses "Maru: ..." in the pill space. A search for "maru" returns Japanese study apps and restaurants.

| Rank | Name | Subtitle | Risk |
|---|---|---|---|
| 1 | Maru: Know What You Took (24) | Supplement & Pill Reminder (26) | A soft hook |
| 2 | Maru: Tap Once, Taken (21) | Quiet Vitamin & Med Log (23) | A promise about the UI that a Watch flow can change |
| 3 | Maru: Quiet Daily Check-In (26) | Private Pill & Vitamin Log (26) | Sounds like a mood app |

Keyword field for rank 1 (96 characters): `vitamin,medication,meds,medicine,tracker,dose,tablet,daily,schedule,history,alarm,offline,widget`.

Do not use medical claims ("never miss a dose", "treat") or price words ("free") in the name or the subtitle (App Review Guidelines 1.4.1, 2.3.7).

## Languages

- The US has more than half of the global Health & Fitness spend. The UK is second with 8% (Sensor Tower, https://sensortower.com/blog/state-of-mobile-health-and-fitness-in-2025).
- iOS has 60.5% of mobile in Japan, September 2026 (StatCounter, https://gs.statcounter.com/os-market-share/mobile/japan).
- Spanish covers Spain, Mexico, and most of Latin America. French covers France, Canada, Belgium, and Switzerland. German covers Germany, Austria, and Switzerland.
- The China mainland store requires an ICP filing number for new apps since September 2023 (https://computing.co.uk/news/4131589/apple-enforces-chinese-government-licence-requirement). A filing generally needs a Chinese entity, and health apps can need more approval (https://appinchina.co/blog/how-can-i-publish-on-the-apple-app-store-china/). No source says that an app with no network is exempt.
- No sourced country numbers were found for Korea, Brazil, or supplement markets per country. That part of the ranking is a judgment.

## Translation tools

The catalogs are small: 282 strings in `App/Localizable.xcstrings` and 21 in `Widget/Localizable.xcstrings`. Two strings have plural variations.

- An agent can translate the String Catalog JSON directly, and a reviewer checks the Git diff. No paid service is necessary.
- swift-translate (https://github.com/hidden-spectrum/swift-translate) and Lingo.dev CLI (https://github.com/lingodotdev/lingo.dev) translate `.xcstrings` with an LLM key. Their maintenance and cost were not confirmed.
- fastlane `deliver` keeps the store text in one folder per locale and uploads it (https://docs.fastlane.tools/actions/appstore).
- Risks: German, Spanish, and French need their own plural variations. German text runs long in the widgets. A native speaker must check the reminder and dose text (spec §13.2).
