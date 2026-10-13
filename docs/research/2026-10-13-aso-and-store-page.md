# ASO and the App Store page

Date: 2026-10-13. A desk study for the App Store release (D051), and the reasons for the files in `metadata/`. It follows `2026-10-12-store-name-and-languages.md` and `2026-10-13-name-and-trademark.md`.

Nothing in this note is live. The app record exists with the name "Maru: Pill & Vitamin Reminder", and this study changed nothing in App Store Connect. The maintainer decides the store text (`docs/process.md`, decision 3). Section 10 has the decisions of 2026-10-13 and the reason for each choice of the second round.

## 1. Summary

- Five patterns repeat in the best screenshot sets (section 2.2). The plan in section 7 copies them.
- A new app cannot win "pill reminder". Ten of the ten top US results have both words in the name, and the leaders have 8,000 to 100,000 ratings. "Supplement tracker" and "vitamin tracker" are open: apps with 0 to 125 ratings are in the top ten.
- The name is the strongest search field. The listing puts search words in the name and keeps the hook for the screenshots.
- es-MX and en-GB are in the listing. es-MX is the default of Mexico and of most of Latin America. en-GB is the default of the UK, Ireland, India, Singapore, and Malaysia, and an extra language in most other storefronts.
- Apple's own page does not say that screenshot text is a search field. Vendor blogs say it is since June 2025. Treat it as not proven, and write captions for people.
- The required iPhone screenshot size is now the medium Dynamic Island display: 1206 × 2622 or 1179 × 2556 pixels. The captures that exist are already 1206 × 2622.

## 2. Screenshot design

### 2.1 Method

- The first page of https://www.appshot.gallery/ (821 curated sets), in a browser.
- The US App Store screenshots of 18 apps, from the iTunes Search API, as contact sheets of the first six frames of each app.
- The same apps in the Japan, Germany, and China mainland storefronts, to see if the screenshots differ per language.
- Not found in the US store by name: Round Health, Dosecast, and Pillo. The search for "Pillo" returned "Pill Reminder - A Meds Tracker".
- Not done: screenshots.pro, appscreens, and theapplaunchpad galleries, and a search of X. See section 11.

### 2.2 The five patterns that the best share

1. **One short caption on top, in very large type.** Two to five words, at most two lines, about 9% to 11% of the frame width in type height terms (Opal, Oura, Finch, Structured, Tiimo). A second line in a smaller gray size is optional. Things is the one exception with a full sentence.
2. **The real UI, in a plain device frame that runs off the bottom edge.** The device takes 60% to 75% of the frame. No hands, no stock photos, no tilted 3D phones in the calm sets. Streaks and "Pill Reminder - All in One" use the raw UI with no caption. That works for Streaks because its UI is the brand.
3. **One calm background for the whole set.** One flat color or one soft wash (Structured pink, Finch sky blue, Oura black, Tiimo lilac). The UI brings the color. No frame fights the UI with a strong gradient.
4. **The first frame is the promise, not a feature.** "Get back 1h23m every day." (Opal), "your simple day planner" (Structured), "Self-care is better together" (Finch), "Your to-do list planner" (Tiimo). Frames two and three show the core loop. Widgets, sync, and privacy come later. Awards and ratings sit on frame one only when the app has them.
5. **Captions and UI are in the language of the store.** Of 14 reference apps that are in the Japan, Germany, or China storefronts, 11 change their screenshots per storefront. The three that do not are Flighty, Finch, and "Pill Reminder - A Meds Tracker".

No set in the sample joins frames into a panorama. Structured and Tiimo let one device cross a frame edge once. That is the most that the calm sets do.

### 2.3 The reference sets

| App | Shots | First three captions | Device | Background | Shows first |
|---|---|---|---|---|---|
| Opal | 9 | "Get back 1h23m every day." / "Blocks the apps you keep opening." / "Runs automatically when you need it." | Frame, runs off the bottom | One blue-gray wash | The outcome, with a number |
| Structured | 8 | "your simple day planner" / (UI only) / "establish routines & habits" | Frame, one device crosses two frames | One pale pink | The category, with awards |
| Tiimo | 7 | "Your to-do list planner" / a user quote / "Organize daily tasks" | Frame | One lilac | The category, with awards |
| Finch | 8 | "Self-care is better together" / "Build habits with friends by your side" / "Send each other support and silliness" | Rounded UI card, no bezel | One sky blue | The feeling |
| Oura | 9 | "Your Personal Health Companion" / "Get in Tune with Your Body" / "Invest in Your Health Future" | Cropped UI, no bezel | Black | The role |
| Gentler Streak | 10 | "Track your health & fitness" / "Monitor your wellness" / "Analyze your sleep" | Frame and Watch | A new color per frame | The function |
| Things 3 | 8 | "Meet Things. The award-winning to-do app that helps you achieve your goals." and so on | Frame | One blue | The name and a sentence |
| Bear | 8 | "Write beautiful notes" / "Organize with #tags" / "Your notes on all your devices" | Cropped device, drawings | A new color per frame | The function |
| Flighty | 10 | "First-class flight tracker" / a press quote / "Live Activities, Dynamic Island" | Tilted and cropped devices | Dark | The category, with awards |
| (Not Boring) Habits | 9 | An award quote / "1 Set a habit or goal" / "2 Get daily reminders & encouragement" | Frame | White | Proof, then steps |
| Streaks | 10 | No captions | Raw UI | The UI | The UI |
| Medisafe | 7 | "Never Forget A Med Again" / "Stay On Track & In Control" / "Check for Interactions" | An old iPhone with a home button | Teal gradient | A promise of delivery |
| MyTherapy | 9 | "Never Miss a Dose Again" / "Track Health Data for Your Whole Family" / "Pill Tracker & Refill Reminders" | Frame, a hand photo | Pale pink | A promise and a rating |
| EveryDose | 9 | "Take Every Dose" / "Get Medication Reminders" / "View your daily schedule" | UI card | One blue | A promise and a rating |
| Pill Reminder - A Meds Tracker | 5 | "Never miss your medicine again" / "Easy to use" / "Fully customizable interface" | An old iPhone | Purple gradient | A promise of delivery |
| Pill Reminder - All in One | 9 | No captions | Raw UI | The UI | The UI |
| Hero | 5 | A photo of people / "Medication, managed" / "Progress you can see" | Frame | White | The hardware |
| SuppCo | 8 | "The all-in-one supplement companion app" / "Get your stack rated and analyzed" / "Check supplement quality with TrustScore" | Frame, a hand | Off-white | The category |

What this means for Maru:

- Four of the six medication sets open with "never miss" or "never forget". Maru must not say that (section 6). The open position is the other question: "Did I take it?"
- The medication sets look dated or clinical. A calm, current set is a way to stand out in the search results.
- The supplement sets sell scans, scores, and AI. Maru sells one look and one tap.

### 2.4 What Apple and ASO writers say

| Question | Finding | Source |
|---|---|---|
| Is text in a screenshot a search field? | Apple lists the name, the subtitle, the keywords, and the primary category as text relevance. It does not list screenshots. Vendor blogs say that Apple reads caption text since June 2025. One test of 64 phrases, cited by those blogs, found no strong evidence. Not proven. | [Apple: search](https://developer.apple.com/app-store/search/), [Stora](https://stora.sh/blog/2026-05-10-app-store-screenshot-captions-now-aso-keywords), [Appdrift](https://appdrift.co/blog/app-store-screenshot-text-indexing) |
| What shows in search results? | "Your app's rating and up to three screenshots or app previews may display in search results depending on the platform and image orientation." Portrait is the form that shows three. | [Apple: search](https://developer.apple.com/app-store/search/) |
| Portrait or landscape? | Writers recommend portrait for an iPhone app. No source with numbers was found. | [AppTweak](https://www.apptweak.com/en/aso-blog/how-to-optimize-your-app-screenshots) |
| Video previews? | Up to three per language and device size. They are optional. No current number for their effect was found. A preview may only show captures of the app (guideline 2.3.4). Skip it for 1.0. | [Apple: version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information) |
| How many screenshots? | One to ten for each device size, as `.jpeg`, `.jpg`, or `.png`, with no transparency. | [Apple: screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) |
| Which iPhone size is required? | "At least one screenshot for iPhone with Dynamic Island (medium display)": 1179 × 2556 or 1206 × 2622 pixels in portrait. The large display (1260 × 2736, 1290 × 2796, or 1320 × 2868) is optional. A missing size gets a scaled copy. | Same page |
| One size for all? | "If your app's user interface is consistent across multiple device sizes and localizations, you only need to provide screenshots for the highest required resolution." | Same page |
| A new device? | The page has a section for a folding iPhone ("iPhone Duo") with the note: "Starting in April 2027, screenshots will be required for any app using the iOS 27.1 SDK or later." It does not bind 1.0. | Same page |

Chinese practice, from one Xiaohongshu result page for "吃药提醒 app": the related searches are "吃药提醒app哪个好用", "吃药打卡app", "记录吃药时间的app", and "iphone用药提醒怎么设置". Post titles that got attention use the same doubt as Maru: "为了少想一次“今天吃药了吗”" and "比忘记喂药更可怕的是：想不起有没有喂". Two posts with the most likes praise the Medications function of Apple Health. That supports the caption "吃了没？看一眼就知道。" and the word "打卡" in the name.

## 3. Field rules

| Field | Limit | Read by search | Source |
|---|---|---|---|
| Name | 30 characters | Yes | Guideline 2.3.7, [Apple: search](https://developer.apple.com/app-store/search/) |
| Subtitle | 30 characters | Yes | Same |
| Keywords | 100, "terms separated by commas and no spaces" | Yes | Same. The version page says "100 bytes". `asc metadata validate` counts characters, and it accepts 98 Chinese characters. The limit for Chinese, Japanese, and Korean needs a check in App Store Connect |
| Primary category | One | Yes: "indexed by our search algorithm", with the secondary category | [Apple: search](https://developer.apple.com/app-store/search/) |
| Promotional text | 170 characters | No: it "doesn't affect your app's search ranking" | Same |
| Description | 4,000 characters, plain text | Apple does not list it | [Apple: version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information) |
| What's New | 4,000 characters | No | Same. It is "not available for the first version" |
| Support URL | Must lead to contact information | No | Same |

Apple's rules for the keyword field:

- "Don't repeat any words included in your app name, subtitle, or category."
- No plural of a word that is already there. "These are considered duplicates."
- No "app", no filler words such as "the", and no special characters.
- No "competing app names", no trademarks, and no "terms that are not relevant to the app".
- Each keyword must be longer than two characters (the version page). Two-character Chinese and Korean words are common in the stores. This rule for them is not verified.

### Extra languages in a storefront

Apple's page [App Store localizations](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations) lists the languages that a storefront supports.

| Storefront | Default | Also supported |
|---|---|---|
| United States | English (US) | Arabic, Chinese (Simplified), Chinese (Traditional), French, Korean, Portuguese (Brazil), Russian, Spanish (Mexico), Vietnamese |
| Japan | Japanese | English (US) |
| China mainland | Simplified Chinese | English (UK) |
| Germany | German | English (UK) |
| Spain | Spanish (Spain) | Catalan, English (UK) |
| Mexico | Spanish (Mexico) | English (UK) |
| South Korea | Korean | English (UK) |

Apple does not say that search reads every supported language of a storefront. ASO vendors say that it does, from tests with invented words ([AppTweak](https://www.apptweak.com/en/aso-blog/how-to-benefit-from-cross-localization-on-the-app-store), [MobileAction](https://www.mobileaction.co/blog/app-store-cross-localization/)).

Decision for the listing:

- **Add es-MX.** It is the language of the Mexico storefront, and the US storefront shows it to Spanish speakers. Its text is Mexican Spanish. It is not a second English keyword field.
- zh-Hans and ko are already in the set, and the US storefront supports both. Their users in the US see their own language.
- **Add en-GB** (second round). The same table lists English (UK) as the default of the United Kingdom, Ireland, India, Singapore, and Malaysia, and as an extra language of Australia, New Zealand, Germany, Austria, Switzerland, Spain, Mexico, Korea, Hong Kong, Taiwan, France, Brazil, and the Spanish-speaking storefronts of Latin America. The UK is the second market for Health & Fitness spend (the earlier note). The en-GB page says "Tablet" in the subtitle, the UK word, so the two English pages cover more words together.
- **Not added:** Arabic, Chinese (Traditional), French, Portuguese (Brazil), Russian, and Vietnamese pages that hold only English keywords. A US user with one of these languages would get a page in that language for an app that does not speak it. That is a wrong promise, and guideline 2.3.7 forbids metadata that exists "just to game the system".

## 4. Keywords

### 4.1 Method

- Search suggestions from the App Store hints endpoint (`MZSearchHints`), with the `X-Apple-Store-Front` header of each storefront. It still works. The order is Apple's.
- The top ten results of the iTunes Search API for the main terms, and the subtitle of each from its App Store page.
- "Crowded" is the count of top results with the term in the name or the subtitle.
- No paid tool, so no search volume. The order of the suggestions is the only sign of demand.
- The China mainland storefront may not get 1.0 (the ICP filing, see the earlier note). zh-Hans still serves Chinese speakers in other storefronts.

### 4.2 What people type

| Storefront | Suggestions for the main stems (Apple's order) |
|---|---|
| US | pill → "pill identifier", "pill reminder", "pill counter", "pill tracker". medication → "medication reminder", "medication tracker", "medication list". medicine → "medicine tracker", "medicine reminder". supplement → "supplement tracker", "supplement scanner", "supplement checker", "supplement reminder". vitamin → "vitamin tracker", "vitamin scanner", "vitamin reminder". did i take → "did i take my meds", "did i take that?", "did i take my pill?", "did i take it?" |
| China | 吃药 → 吃药提醒, 吃药打卡, 吃药记录, 吃药闹钟. 用药 → 用药助手, 用药提醒, 用药记录. 服药 → 服药打卡, 服药提醒, 服药记录. 保健品 → 保健品提醒 维生素服用记录 吃药打卡日历. 维生素 → 维生素追踪器, 维生素提醒 |
| Japan | お薬 → お薬手帳, お薬アラーム, お薬記録, お薬管理. 薬 → 薬 飲み忘れ, 薬 飲み忘れ防止, 薬管理. 服薬 → 服薬管理, 服薬記録, 服薬チェック, 服薬アラーム, 服薬リマインダー. サプリ → サプリ管理, サプリ飲み忘れ, サプリ記録. ピル → ピル 飲み忘れ防止, ピル管理 |
| Spain | pastillas → "recordatorio pastillas", "calendario pastillas", "control pastillas", "toma de pastillas". recordatorio → "recordatorio pastillas", "recordatorio de medicamentos". pastillero → "pastillero", "pastillero - alarma de meds" |
| Mexico | pastillas → "control de pastillas", "app para tomar pastillas", "horario de pastillas". recordatorio → "recordatorio de medicamentos" (first). medicinas → "control de medicinas", "alarma de medicinas". medicamentos → "alarma para medicamentos", "tomar medicamentos" |
| Germany | tabletten → "tabletten erinnerung", "tabletten tracker", "tabletten plan". medikamente → "medikamenten-erinnerung", "medikamentenplan". pillen → "pillenalarm", "pillen reminder", "pillenwecker". supplement → "supplement tracker", "supplement reminder", "supplements erinnerung". nahrungsergänzung → "nahrungsergänzung tracker" |
| Korea | 약 → 약 알림. 복약 → 복약관리, 복약알림. 영양제 → 영양제 체크, 영양제알림, 영양제 기록, 영양제 관리. 복용 → 약 복용 체크, 약 복용 알림 |

### 4.3 Fit and crowding

| Storefront, query | Term: top results with it | Ratings of the top results | Primary category Medical |
|---|---|---|---|
| US, "pill reminder" | pill 10/10, reminder 10/10, med 7/10, medication 6/10, tracker 5/10, medicine 4/10, alarm 3/10, supplement 1/10, vitamin 0/10 | 656 to 101,463, with one at 3 | 8/10 |
| US, "supplement tracker" | supplement 8/9, tracker 8/9, vitamin 3/9, pill 2/9, reminder 2/9 | Five of nine have 0 to 125 | 0/9 |
| US, "vitamin tracker" | tracker 9/9, supplement 6/9, vitamin 5/9, reminder 5/9, pill 4/9 | Five of nine have 0 to 88 | 2/9 |
| China, "吃药提醒" | 提醒 6/9, 吃药 5/9, 用药 5/9, 管理 5/9, 打卡 4/9, 记录 4/9, 服药 0/9 | Three habit apps with 100,000 or more. The reminder apps have 3 to 1,605 | 4/9 |
| Japan, "服薬管理" | 薬 10/10, 服薬 9/10, 管理 8/10, 飲み忘れ 8/10, アラーム 5/10, 記録 5/10, リマインダー 3/10, サプリ 1/10 | 1 to 213,039 | 5/10 |
| Japan, "サプリ 管理" | 記録 9/10, 管理 8/10, サプリ 7/10 | Six of ten have 1 to 14 | 0/10 |
| Spain, "recordatorio pastillas" | recordatorio 10/10, alarma 5/10, pastilla 4/10, medicamento 3/10, medicina 3/10 | 0 to 2,978 | 8/10 |
| Mexico, "recordatorio de medicamentos" | recordatorio 9/10, medicamento 6/10, alarma 6/10, medicina 3/10, pastilla 2/10 | 0 to 15,618 | 7/10 |
| Germany, "tabletten erinnerung" | erinnerung 7/9, tabletten 6/9, medikament 5/9, pillen 5/9, wecker 3/9 | 1 to 20,301 | 9/9 |
| Korea, "약 알림" | 약 8/10, 알림 8/10, 복약 5/10, 영양제 4/10, 기록 4/10 | 0 to 4,022, with two large apps of other kinds | 5/10 |

Ranking of the terms by fit and by room:

1. **Supplement and vitamin words** (supplement tracker, vitamin tracker, サプリ 管理, 영양제 알림, 保健品). Best fit for Maru's first users, and the weakest field. Lead with them where the language allows.
2. **The main reminder phrase of each market** (pill reminder, 吃药提醒, 服薬 リマインダー, recordatorio, Tabletten Erinnerung, 약 알림). The most demand and the most crowded. Maru needs the words to be found at all, but it cannot rank high on them at the start.
3. **The doubt phrase** ("did i take it", 吃了没, 飲んだっけ). Apple suggests it in the US. Six or more US apps use it as a name, so it stays out of the name and goes in the keywords and the captions.
4. **Record words** (log, history, 记录, 記録, registro, 기록). Good fit, medium crowding.
5. **Alarm words** (alarm, Wecker, アラーム, 알람). People type them for this kind of app. Maru is not an alarm, and the description says so. They are in the keyword field only. Remove them if a reviewer objects.

Left out on purpose: "お薬手帳" (a pharmacy record book in Japan, which Maru is not), "ピルマル" (the trademark note), "family" and "caregiver" words (Maru has no sharing), "refill" and "interaction" words (not in the app), "free", "best", and every app name.

## 5. The listing

The files are in `metadata/`, in the layout of `asc metadata` (`app-info/<locale>.json` and `version/1.0.0/<locale>.json`). `asc metadata validate --dir ./metadata` reports no issue. `asc metadata push` with `--dry-run` shows the plan before a change. The files replace the fastlane `deliver` idea in the release plan.

App Store Connect accepted the English name. The names of the other languages are not entered yet.

| Locale | Name | Subtitle |
|---|---|---|
| en-US | Maru: Pill & Vitamin Reminder (29) | One-Tap Supplement Tracker (26) |
| zh-Hans | Maru：吃药提醒与保健品打卡 (15) | 维生素、用药记录，吃了没一眼知道 (16) |
| ja | Maru：お薬とサプリの服薬リマインダー (20) | 飲んだかどうか、ひと目でわかる記録 (17) |
| en-GB | Maru: Pill & Vitamin Reminder (29) | Tablet & Supplement Tracker (27) |
| es-ES | Maru Recordatorio de pastillas (30) | Vitaminas y suplementos al día (30) |
| es-MX | Maru Recordatorio de pastillas (30) | Medicinas y vitaminas al día (28) |
| de-DE | Maru: Tabletten-Erinnerung (26) | Medikamente, Vitamine im Blick (30) |
| ko | Maru: 약 알림과 영양제 복약 기록 (21) | 먹었는지 한눈에, 탭 한 번이면 끝 (19) |

Keyword lines:

| Locale | Keywords |
|---|---|
| en-US | `medication,medicine,meds,dose,tablet,capsule,daily,schedule,history,log,alarm,widget,did,take,drug` |
| zh-Hans | `服药,药物,药品,闹钟,补充剂,补剂,营养品,每日,习惯,日历,小组件,鱼油,钙片,益生菌,定时,药盒,喝药,管家,助手,吃药时间,按时,慢病,胶囊,药片,叶酸,褪黑素,忘记,每天,追踪,健康管理` |
| ja | `飲み忘れ,防止,管理,アラーム,通知,ピル,ビタミン,くすり,カレンダー,ウィジェット,習慣,チェック,時間,漢方,目薬,サプリメント,服用,錠剤,毎日,のんだ,健康管理,トラッカー` |
| en-GB | `medication,medicine,meds,dose,capsule,daily,schedule,history,log,alarm,widget,did,take,one,tap,drug` |
| es-ES | `medicamentos,medicación,medicinas,píldora,alarma,pastillero,toma,dosis,control,calendario,registro` |
| es-MX | `medicamentos,suplementos,alarma,píldoras,pastillero,control,horario,tomar,dosis,calendario,registro` |
| de-DE | `supplements,pillen,medikamentenplan,einnahme,wecker,alarm,tracker,nahrungsergänzung,kapseln,dosis` |
| ko | `복용,알람,비타민,약먹는시간,체크,관리,리마인더,루틴,위젯,알약,캘린더,시간,챙겨먹기,일정,습관,건강기능식품,유산균,오메가3,투약,매일,깜빡,먹었나,섭취,트래커,건강관리` |

Alternatives for the name:

| Locale | Alternative 1 (the site title) | Alternative 2 |
|---|---|---|
| en-US | Maru: Know What You Took, with the subtitle "Supplement & Pill Reminder" | Maru: Daily Pill Check |
| zh-Hans | Maru：吃了没，看一眼就知道 | Maru：吃药提醒 |
| ja | Maru：飲んだかどうか、すぐわかる | Maru：お薬・サプリの記録 |
| es-ES, es-MX | Maru: ten claro lo que tomaste | Maru: Pastillas y vitaminas |
| de-DE | Maru: Wissen, was du nimmst | Maru: Tabletten & Vitamine |
| ko | Maru: 먹었는지 바로 확인 | Maru: 약 알림 |

Notes on the text:

- The description has one structure in every language. The first three lines carry the message: the doubt, then what Maru does, then where the data stays.
- The names of screens and buttons are the words of `App/Localizable.xcstrings`.
- The description says "widget", the schedule names, and "Export Records". `evidence.md` allows these only when they are in the released build. They are in the code on main. Check them against the build that ships.
- "Tap Taken on the reminder" has its condition in the text: a reminder for one item.
- "Remind Again" has its number in the text: up to 12.
- "Tap the circle beside an item": a tap on the name opens the detail, so the description names the circle.
- The schedule line names the schedules of D065: every day, every other day, every few days, and days on and days off, with 21 on and 7 off as the example. As-needed items have no reminder. The names are the words of `App/Localizable.xcstrings`. If the schedules of D065 ship in 1.1 and not in 1.0, remove them from this line for 1.0.
- The promotional text promises that the records stay on the iPhone, not all data. The optional usage statistics can leave the iPhone.
- en-US and en-GB: "med" was removed, because "meds" covers it. "drug" uses the free characters. It is not in the name or the subtitle.
- The last paragraph says that Maru gives no medical advice, that it is not an alarm, and that the user should ask a doctor or pharmacist (guideline 1.4.1).
- "Free" is in the description only. Guideline 2.3.7 keeps prices out of names, subtitles, and screenshots.
- The German name uses a hyphen, as correct German asks. Suggestions such as "doser: tabletten-erinnerung" show the form in the store. That search splits the word at the hyphen is not verified.
- "What's New" is not in the files, because Apple does not accept it for a first version. Text for the first update: "The first release of Maru. Thank you for trying it."
- No human native speaker reviewed any language. The text is by one model in one session. A native speaker must read each language before the release (D059).

URLs in the files:

| Field | Value | State |
|---|---|---|
| Support URL | `https://maru.day/support.html`, and `/cn/`, `/jp/`, `/es/`, `/de/`, `/kr/` before `support.html` | 404 today |
| Privacy policy URL | `https://maru.day/privacy.html`, with the same folders | 404 today |
| Marketing URL | `https://maru.day/`, with the same folders | The root shows "Coming soon" |

The paths are those of the branch `leon/site-redesign`. That branch must merge and deploy before a submission. es-MX uses the `/es/` pages.

### Back-translation

A second reading of each line, back into English, to find a meaning that moved.

| Locale | Field | Text | Back-translation |
|---|---|---|---|
| zh-Hans | Name | Maru：吃药提醒与保健品打卡 | Maru: medicine reminders and supplement check-in |
| zh-Hans | Subtitle | 维生素、用药记录，吃了没一眼知道 | Vitamin and medication records. Know at one look if you took it |
| zh-Hans | First line | 吃了没？打开 Maru，看一眼就知道。 | Did you take it? Open Maru, and one look tells you. |
| ja | Name | Maru：お薬とサプリの服薬リマインダー | Maru: a reminder to take medicine and supplements |
| ja | Subtitle | 飲んだかどうか、ひと目でわかる記録 | A record that shows at a glance if you took it |
| ja | First line | 飲んだっけ？ Maruを開けば、ひと目でわかります。 | Did I take it? Open Maru, and you see it at a glance. |
| es | Name | Maru Recordatorio de pastillas | Maru Pill reminder |
| es-ES | Subtitle | Vitaminas y suplementos al día | Vitamins and supplements, up to date |
| es-MX | Subtitle | Medicinas y vitaminas al día | Medicines and vitamins, up to date |
| es | First line | ¿Ya me lo tomé? Abre Maru y sal de dudas. | Did I take it already? Open Maru and end the doubt. |
| de-DE | Name | Maru: Tabletten-Erinnerung | Maru: tablet reminder |
| de-DE | Subtitle | Medikamente, Vitamine im Blick | Medications and vitamins in view |
| de-DE | First line | Schon genommen? Öffne Maru, und du weißt es. | Taken already? Open Maru, and you know. |
| ko | Name | Maru: 약 알림과 영양제 복약 기록 | Maru: medicine reminders, and a record of supplements and doses |
| ko | Subtitle | 먹었는지 한눈에, 탭 한 번이면 끝 | See at a glance if you took it. One tap, and done |
| ko | First line | 먹었나? Maru를 열면 바로 알 수 있어요. | Did I take it? Open Maru, and you know at once. |

Points for the native check:

- zh-Hans: "打卡" (check-in) is a habit-app word. It is the search word, but Maru has no streaks. The description says so.
- zh-Hans and ja: the notes "随餐" and "食後" are examples of a user's own note. A reader must not take them as advice.
- ja: "飲む" covers tablets and drinks. An eye drop or a cream does not fit the verb. The keyword "目薬" may be wrong for that reason.
- ko: "복약" is a formal word and "먹었는지" is a plain one. The mix is on purpose, for search and for tone.
- de-DE: "Supplements" against "Nahrungsergänzungsmittel". The app uses "Supplement".
- es-MX: differs from es-ES in four places only ("ya tomaste", "¿Te equivocaste?", "frasco", "Agrega"). The app has one Spanish.

## 6. Rules that bind the listing

From the [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), read on 2026-10-13.

| Rule | Text | Effect on Maru |
|---|---|---|
| 1.4.1 | "Medical apps that could provide inaccurate data or information, or that could be used for diagnosing or treating patients may be reviewed with greater scrutiny." "Apps should remind users to check with a doctor in addition to using the app and before making medical decisions." | The description ends with that reminder. The review notes say that Maru gives no advice |
| 1.4.2 | Drug dosage calculators must come from an approved entity | Maru calculates no dose. Say so in the review notes, because the add screen shows amounts from common labels |
| 2.3.1 | No hidden features. No "marketing your app in a misleading way" | Claim only what the build does |
| 2.3.3 | "Screenshots should show the app in use, and not merely the title art, login page, or splash screen." | Every frame shows a real screen. No frame is only text |
| 2.3.7 | No "trademarked terms, popular app names, pricing information" in metadata. Subtitles "should not include inappropriate content, reference other apps, or make unverifiable product claims." | No "free" in the name, the subtitle, or a caption. No "best". No app names. "One-Tap" is a fact of the UI |
| 2.3.10 | No "names, icons, or imagery of other mobile platforms" | No Android word anywhere |
| 3.1.1 | "Apps may use in-app purchase currencies to enable customers to 'tip' the developer" | The tips are in-app purchases, and they unlock nothing |
| 5.1.1 (i) | A privacy policy link in the metadata and in the app | Settings › About has it. The URL must work before the submission |
| 5.1.1 (v) | "If your app doesn't include significant account-based features, let people use it without a login." | Maru has no account |
| 5.1.3 | Health data must not go to advertising or data mining | No health data leaves the iPhone |
| 5.2.5 | No app that looks like an Apple product | The description does not name Apple Health. The widget frame shows system app icons on a Home Screen. Crop the frame to the widget if a reviewer objects |

`evidence.md` section 5 stays the list of claims. This study adds one fact to it: Apple's keyword page names "competing app names" as a reason for rejection.

## 7. The screenshots

The set is outside the repository, in the maintainer's screenshot folder `ui-shots/store-final/`: one HTML file (`index.html`), the simulator captures (`_cap/`), and for each of `en`, `zh-Hans`, `ja`, `es`, `de`, and `ko` six frames and one `overview.png` for each platform. es-MX uses the `es` frames, and en-GB uses the `en` frames. The first set, `ui-shots/store/`, drew the UI in HTML. This set replaces it.

Version 1.0 ships without the Watch app, so the set has no Watch screenshots, and no frame shows or names the Watch.

### 7.1 What Apple allows

Guideline 2.3.3: "Screenshots should show the app in use, and not merely the title art, login page, or splash screen. They may also include text and image overlays (e.g. to demonstrate input mechanisms, such as an animated touch point or Apple Pencil) and show extended functionality on device, such as Touch Bar." Guideline 2.3.7 forbids prices and text that is not about the app in a screenshot. Guideline 2.3.10 forbids imagery of other platforms. Source: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), read on 2026-10-13.

So a caption, a background, and an enlarged or cropped part of the real UI are allowed, when the UI is the app as it is. The app UI in this set comes from simulator captures of `main`. The reminder of frame 2 is drawn (section 7.4).

### 7.2 Sizes

Source: [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), read on 2026-10-13.

| Platform | Size in pixels | Rule on the page |
|---|---|---|
| iPhone | 1206 × 2622, portrait | "At least one screenshot for iPhone with Dynamic Island (medium display)". The large display (1260 × 2736, 1290 × 2796, or 1320 × 2868) is optional and gets a scaled copy |
| iPad | 2064 × 2752, portrait | The 13-inch display is "Required if app runs on iPad" |

The page also says "Required for Apple Watch apps" for the Watch sizes, and "You must use the same screenshot size for Apple Watch consistently across all localizations for the app." That matters when the Watch app ships.

### 7.3 The order, by acquisition value

A search result shows the name, the subtitle, and the first three portrait frames before any tap. So frames 1 to 3 must win the tap, and frames 4 to 6 serve the person who already opened the page.

| # | Caption (en) | Part of the UI | Reason for the place |
|---|---|---|---|
| 1 | Did I take it? One look. | The Today list, with photos and filled circles | The name beside it already says "reminder". So the first frame gives the reason to pick this one: the doubt that every person in this search knows. Four of six competitors open with "never miss", so this line is also the one that differs |
| 2 | Reminders at your times | One reminder as a notification card, and the Today widget under it | The searcher typed "reminder". The second frame proves that the app does the job that they searched for |
| 3 | One tap. Recorded. | One row before and after the tap | Effort is the main reason that people leave a tracker (`evidence.md`, pain points). This frame ends the group that shows in search: see, get reminded, record |
| 4 | See what you took | The History graph and the last 7 days | Proof that the record lasts. It is a benefit of week two, not of day one |
| 5 | Know it by its photo | My Items, with three photos | A feature that the other sets do not show. It comes after the reasons, because no person searches for it |
| 6 | No account. No ads. | The detail of one item | Trust closes the page. It removes the last doubt before the download |

Changes from the first set:

- The frame "Your day at a glance" (the Today widget) left the set. The maintainer then asked for the widget as a second card in frame 2. It is drawn, because no capture of a Home Screen widget was possible in the simulator session.
- The frame "Know it by its photo" is new. `main` now has item photos, and the sample data has three.
- The second line of frame 2 was "Tap Taken right on the reminder." It is now "They show what to take." The frame shows a standard reminder with no action button, so the old line named a control that the frame does not show.

The captions in the six languages are in `index.html` of the set. The new lines:

| Locale | Frame 2, second line | Frame 5 | Frame 5, second line |
|---|---|---|---|
| en | They show what to take. | Know it by its photo | Add a photo of your bottle. |
| zh-Hans | 提醒里写着该吃什么。 | 看照片，就认得 | 给每一项加一张瓶子的照片。 |
| ja | 何を飲むかも通知に表示。 | 写真で見分ける | ボトルの写真を追加できます。 |
| es | El aviso dice qué tomar. | Reconócelo por su foto | Añade una foto del envase. |
| de | Die Erinnerung nennt, was dran ist. | Am Foto erkennen | Füge ein Foto der Dose hinzu. |
| ko | 무엇을 먹을지 알림에 표시돼요. | 사진으로 바로 구분 | 약병 사진을 추가하세요. |

No native speaker read these lines. The iPad set says "iPad" where the iPhone set says "iPhone".

### 7.4 The design

The references are six sets from https://www.appshot.gallery/ outside the medication category: Atoms, Amie, Dime, Haptic, Superlist, and WaterDuo.

| Set | What this set takes from it |
|---|---|
| Atoms | An off-white page, a short caption in very large type, and one part of the UI that leaves the device |
| Amie | No device frame. Cropped parts of the real UI on a light page |
| Dime | One idea for each frame, and much empty space |
| Haptic | A real card that lifts off the screen with a soft shadow |
| Superlist | One accent color on one phrase of the caption |
| WaterDuo | One reminder as the proof of a reminder app |

- Each frame has one caption of two lines, 108 to 146 pixels high on the iPhone, and at most one gray second line. The second half of captions 1 and 3 is in the app pink.
- One background for the whole set: white that turns to a pale pink at the bottom.
- Frames 1, 4, 5, and 6 show the whole screen of one capture in the upper part of a device shape: an iPhone with a thin dark edge and the Dynamic Island, at 72% of the frame width, or an iPad with a thin even edge, at 90%. The device has the same size and place in each frame, and the bottom edge of the frame cuts it. The maintainer asked for this on 2026-10-13.
- Frame 2 shows one reminder as a card at 86% of the frame width, and the medium Today widget under it at the same width, with no Lock Screen, no wallpaper, and no clock. The maintainer asked for this. Both cards are drawn in HTML with the measures of the site component (`site/mock.py`), the app icon file, the title of the app's reminder, and the word of iOS for "now" in each language, as real Lock Screen captures showed it.
- Frame 3 shows the same row from two captures: one from a launch with no records, and one with the morning recorded. A touch point marks the circle. Guideline 2.3.3 allows an overlay that shows an input.

### 7.5 How the captures were made

- A Debug build of `main` in simulators that the task made: iPhone 18 Pro (1206 × 2622) and iPad Pro 13-inch (M5) (2064 × 2752), iOS 27.0.
- The system language of the simulator is the language of the set. The launch arguments are `-MaruSampleData YES -MaruSampleRecords YES`. The item names are the sample data of each language (D070).
- The status bar override sets the clock to 9:41, full battery, and full signal.
- `ui-shots/store-final/iap/tips-review.png` is the picture for the review of the three tips: Settings at the "Support Maru" section, in English, at 1320 × 2868 pixels, from `main` with `Config/Maru.storekit` active through a test host that was not committed.

### 7.6 Differences from the real app that remain

- The reminder and the widget of frame 2 are drawn. Nobody compared the widget with a capture in each language. The reminder is white on the light background. iOS draws a reminder as glass over the wallpaper.
- The iPad frame 3 shows the row at 200% without its empty middle, as the row looks in a narrow window. The pieces are from the captures.
- The dark device edge and the Dynamic Island are drawn.
- Frame 3 pairs two captures. It does not show one tap.
- On the iPad the content fills the window, so the text of the UI is small in a frame.

## 8. Category, age rating, and review notes

### Category

- Primary: Health & Fitness (the release plan).
- Secondary: **Medical**. The maintainer decided it. In the US, 8 of the 10 top results for "pill reminder" have Medical as the primary category, and Apple's search reads both categories. Guideline 1.4.1 applies to what the app does, not to its category.
- The other choice is Lifestyle. It fits the calm tone and adds no medical frame, but it adds no search fit. Productivity fits least.

### Age rating answers (draft)

The names are the fields of `asc age-rating edit`.

| Question | Answer | Reason |
|---|---|---|
| Medical or treatment information | Infrequent or mild | The app shows medicine and supplement names, and amounts from common labels as a typing aid |
| Health or wellness topics | Yes | The app is about taking supplements and medicine |
| Alcohol, tobacco, or drug use or references | None | A medicine name is not a reference to drug use. A reviewer may see it in another way |
| Unrestricted web access | No | The feedback form and the privacy policy open in the system browser |
| User-generated content, messaging and chat, social media | No | Nothing is shared |
| Advertising | No | No ads |
| Gambling, simulated gambling, contests, loot boxes | No or none | |
| Violence, sexual content, profanity, horror, mature themes, weapons | None | |
| Parental controls, age assurance | No | |
| Kids age band | Not set | The app is not for the Kids category |

The rating that results is not known until App Store Connect computes it.

### Notes for App Review (draft)

> Maru is a reminder and a record for supplements and medicine that the user enters.
>
> - No account and no login. Open the app and add an item.
> - To see a reminder: add an item with a time two minutes from now, allow notifications, and lock the iPhone. The reminder is a local notification. For a reminder with one item, press and hold it and tap "Taken". This records the dose with the app closed.
> - "Remind Again" in Settings sends more reminders for a dose with no record, up to 12 for each dose.
> - Maru gives no medical advice and calculates no dose. The name suggestions on the add screen are a typing aid from a list inside the app. For common supplements, the add screen shows amounts and times from common labels. They fill nothing until the user taps one.
> - "Scan Label" uses the camera to read text on the device. It saves no photo and sends nothing.
> - The three tips in Settings › Support Maru are optional consumable in-app purchases. A tip unlocks nothing.
> - Items and records stay on the device. Optional usage statistics have no health data. The privacy policy is in Settings › About › Privacy Policy.
> - Maru does not use HealthKit.

Add the sample launch arguments only if the reviewer needs data. A reviewer cannot pass launch arguments, so the notes above describe a start from an empty app.

## 9. Privacy label

The data types match `App/PrivacyInfo.xcprivacy` and `PRIVACY.md`. The manifest still sets `NSPrivacyCollectedDataTypeLinked` to false for each type. Change it to true before the submission, so that it agrees with the decision below.

"Do you or your third-party partners collect data from this app?" Yes.

| Data type | Collected | Purpose | Linked to the user | Used for tracking | What it is |
|---|---|---|---|---|---|
| Identifiers › Device ID | Yes | Analytics | Yes | No | The random install ID |
| Usage Data › Product Interaction | Yes | Analytics | Yes | No | The usage events |
| Diagnostics › Other Diagnostic Data | Yes | Analytics | Yes | No | The error codes, the app version, and the major iOS version |
| Other Data › Other Data Types | Yes | Analytics | Yes | No | The region setting as a two-letter code (D064) |

Not collected, and so not selected:

| Data type | Reason |
|---|---|
| Health & Fitness | Items, doses, and records stay on the iPhone |
| Location | Maru does not read the location. The region is a setting. PostHog does no lookup by IP address |
| Contact Info, Contacts | None. An email address in the feedback form goes to a web page in the system browser, outside the app |
| User Content (photos, other content) | Item photos stay on the iPhone |
| Purchases | Apple handles a tip. Maru does not send `purchase_result` yet. Select "Purchase History" in the same release that starts to send it |
| Identifiers › User ID | No account |
| Sensitive Info, Financial Info, Browsing History, Search History | None |

**Decision of the maintainer (2026-10-13):** "Linked to the user" is Yes for every analytics data type. The random install ID stays the same over time, so Apple's definition counts the data as linked. "Used for tracking" stays No.

**Before the submission:** the privacy policy URL and the support URL must be live in every language. Both return 404 today.

One judgment: the feedback form opens in the system browser. Apple's label covers data that the app collects. If the form moves into the app, add "Other User Content" and "Email Address".

## 10. Decisions and reasons

Decisions of the maintainer on 2026-10-13:

- The app record exists (Apple ID 6822159516) with the name "Maru: Pill & Vitamin Reminder". The English subtitle is "One-Tap Supplement Tracker".
- The secondary category is Medical.
- es-MX is in the listing.
- The alarm keywords stay.
- The separator "·" is not used anywhere. The Korean name and the list marks of the Chinese and Japanese descriptions changed.
- Mainland China is not in the first release. zh-Hans stays for the other storefronts.

Choices of the second round, each with its reason:

| Choice | Reason |
|---|---|
| Every name says the category in the words of the top search suggestion of that market | A reader gives a search result about one second. The category word answers "what is it" in that second, and the name is the field with the most search weight |
| Every subtitle gives the reason to tap, and adds search words that the name does not have | Apple reads both fields, so a repeated word is a lost word. "One look", "one tap", "im Blick", and "al día" promise less work, not more duty |
| No "never miss", no "don't forget", no streak word | A promise of delivery is not allowed (section 6). A guilt word pushes away the people who already feel bad about a missed dose |
| es names changed to "Maru Recordatorio de pastillas" (review round) | "recordatorio" is in 10 of 10 top names in Spain and 9 of 10 in Mexico, and "recordatorio pastillas" is a suggestion of Apple in both. The form with "de" is correct Spanish. With no colon, it has 30 characters. No brand rule asks for the colon |
| es-ES subtitle "Vitaminas y suplementos al día", es-MX "Medicinas y vitaminas al día" | The supplement words have the least competition. "Medicinas" is the common word in Mexico. "medicamentos" is in both keyword fields |
| de subtitle "Medikamente, Vitamine im Blick" | "Medikamente" is in 5 of 9 top results, and "im Blick" is the reason to tap. The form with "&" has 31 characters |
| ko name "Maru: 약 알림과 영양제 복약 기록" | The same four search words with no separator |
| en-GB added, with "Tablet" in the subtitle | Section 3. It is the only English page that the UK storefront reads |
| No keyword-only pages in other languages | Section 3 |

The search terms that each page aims at:

| Locale | Terms, first to last | Why |
|---|---|---|
| en-US, en-GB | "supplement tracker", "vitamin tracker", "vitamin reminder", "pill reminder", "medication reminder", "did i take it" | The first three are open: apps with 0 to 125 ratings are in the top ten. The next two have the demand, and Maru needs the words to show at all |
| zh-Hans | 吃药提醒, 吃药打卡, 用药记录, 保健品, 维生素 | 吃药提醒 is the first suggestion for 吃药. The top reminder apps have 3 to 1,605 ratings |
| ja | 服薬 リマインダー, お薬 記録, サプリ 管理, 飲み忘れ, 服薬管理 | "サプリ 管理" is open: six of the top ten have 1 to 14 ratings. 飲み忘れ is in the keyword field, because "防止" in a name reads as a promise |
| es-ES | recordatorio pastillas, recordatorio medicamentos, vitaminas, suplementos | The first suggestions for "pastillas" and "recordatorio" |
| es-MX | recordatorio pastillas, recordatorio de medicamentos, medicinas, vitaminas | "recordatorio de medicamentos" is the first suggestion for "recordatorio" in Mexico |
| de-DE | tabletten erinnerung, medikamente erinnerung, vitamine, supplements, medikamentenplan | "tabletten erinnerung" is the first suggestion for "tabletten" |
| ko | 약 알림, 영양제 알림, 복약 알림, 복약 기록 | 약 알림 is the second suggestion for 약, and the top apps have 0 to 4,022 ratings |

### Search volume

No free source gave a search volume without an account.

| Source | Result |
|---|---|
| App Store search suggestions, per storefront | Real, but an order and not a number. Section 4.2 |
| `asc apps public search` and `asc apps public rank` | Work with no account. They return result lists and one rank. They have no popularity value |
| Rating counts of the top results (iTunes Search API) | Real numbers. They show the strength of the competition, not the demand. Section 4.3 |
| Apple Ads search term popularity | The `asc` command `asc ads insights search-term-popularity find` reads it. It needs an Apple Ads account with an API key, and this Mac has none. No source says if an account with no campaign is enough. One vendor reports that the value is 5 for most terms since a change by Apple ([ASO.dev](https://static.aso.dev/blog/apple-ads-popularity-massive-drop/)) |
| Astro, AppFollow, AppTweak, Appfigures, AppKittie, ASO.dev | All need an account. ASO.dev has a trial of 3 days and no free plan. A vendor post gives 5 keywords a day for AppTweak and 10 for AppFollow on a free account, which was not checked |

## 11. Limits

- No search volume. No paid tool was used. The order of Apple's suggestions is the only sign of demand.
- The top-ten lists are from the iTunes Search API. Its order can differ from the order in the App Store app.
- The reading of the screenshot sets is by one model from contact sheets. Type sizes are estimates, not measurements.
- Not looked at: screenshots.pro, appscreens, theapplaunchpad, and X. Xiaohongshu: one result page only.
- No search volume number from any source (section 10).
- The frames use simulator captures. Section 7.6 has the differences from a real iPhone that remain.
- Round Health, Dosecast, and Pillo were not found by name.
- Not verified: that search reads screenshot text, that search reads every supported language of a storefront, the keyword limit for Chinese, Japanese, and Korean, the two-character rule for those languages, and how search treats a hyphen.
- The ASO sources are vendor blogs with tools to sell.
- No native speaker read the text. Nobody saw the mock on an iPhone.
- The support and privacy URLs return 404 today.
