# ASO and the App Store page

Date: 2026-10-13. A desk study for the App Store release (D051), and the reasons for the files in `metadata/`. It follows `2026-10-12-store-name-and-languages.md` and `2026-10-13-name-and-trademark.md`.

Nothing in this note is live. No app record exists, and this study changed nothing in App Store Connect. The maintainer decides the name and the store text (`docs/process.md`, decision 3).

## 1. Summary

- Five patterns repeat in the best screenshot sets (section 2.2). The plan in section 7 copies them.
- A new app cannot win "pill reminder". Ten of the ten top US results have both words in the name, and the leaders have 8,000 to 100,000 ratings. "Supplement tracker" and "vitamin tracker" are open: apps with 0 to 125 ratings are in the top ten.
- The name is the strongest search field. The listing puts search words in the name and keeps the hook for the screenshots. This differs from the site title "Maru: Know What You Took". The maintainer must choose (section 10).
- Add es-MX. Mexico uses it, and Apple shows it in the US storefront.
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
- An English (UK) page can add 100 keyword characters in five of the seven storefronts. Do this after the release, with data. It is a second English page to maintain.

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

**Every name is provisional.** Only the creation of the app record proves that a name is free.

| Locale | Name | Subtitle |
|---|---|---|
| en-US | Maru: Pill & Vitamin Reminder (29) | One-Tap Supplement Tracker (26) |
| zh-Hans | Maru：吃药提醒与保健品打卡 (15) | 维生素、用药记录，吃了没一眼知道 (16) |
| ja | Maru：お薬とサプリの服薬リマインダー (20) | 飲んだかどうか、ひと目でわかる記録 (17) |
| es-ES | Maru: Pastillas y vitaminas (27) | Recordatorio de medicamentos (28) |
| es-MX | Maru: Pastillas y vitaminas (27) | Recordatorio de medicamentos (28) |
| de-DE | Maru: Tabletten-Erinnerung (26) | Supplements & Medikamente (25) |
| ko | Maru: 약 알림·영양제 복약 기록 (20) | 먹었는지 한눈에, 탭 한 번이면 끝 (19) |

Keyword lines:

| Locale | Keywords |
|---|---|
| en-US | `medication,medicine,meds,med,dose,tablet,capsule,daily,schedule,history,log,alarm,widget,did,take` |
| zh-Hans | `服药,药物,药品,闹钟,补充剂,补剂,营养品,每日,习惯,日历,小组件,鱼油,钙片,益生菌,定时,药盒,喝药,管家,助手,吃药时间,按时,慢病,胶囊,药片,叶酸,褪黑素,忘记,每天,追踪,健康管理` |
| ja | `飲み忘れ,防止,管理,アラーム,通知,ピル,ビタミン,くすり,カレンダー,ウィジェット,習慣,チェック,時間,漢方,目薬,サプリメント,服用,錠剤,毎日,のんだ,健康管理,トラッカー` |
| es-ES | `suplementos,medicación,medicinas,píldora,alarma,pastillero,toma,dosis,control,calendario,registro` |
| es-MX | `medicinas,suplementos,alarma,píldoras,pastillero,control,horario,tomar,dosis,calendario,registro` |
| de-DE | `vitamine,pillen,medikamentenplan,einnahme,wecker,alarm,tracker,nahrungsergänzung,kapseln,dosis` |
| ko | `복용,알람,비타민,약먹는시간,체크,관리,리마인더,루틴,위젯,알약,캘린더,시간,챙겨먹기,일정,습관,건강기능식품,유산균,오메가3,투약,매일,깜빡,먹었나,섭취,트래커,건강관리` |

Alternatives for the name:

| Locale | Alternative 1 (the site title) | Alternative 2 |
|---|---|---|
| en-US | Maru: Know What You Took, with the subtitle "Supplement & Pill Reminder" | Maru: Daily Pill Check |
| zh-Hans | Maru：吃了没，看一眼就知道 | Maru：吃药提醒 |
| ja | Maru：飲んだかどうか、すぐわかる | Maru：お薬・サプリの記録 |
| es-ES, es-MX | Maru: ten claro lo que tomaste | Maru: Recordatorio pastillas |
| de-DE | Maru: Wissen, was du nimmst | Maru: Tabletten & Vitamine |
| ko | Maru: 먹었는지 바로 확인 | Maru: 약 알림 |

Notes on the text:

- The description has one structure in every language. The first three lines carry the message: the doubt, then what Maru does, then where the data stays.
- The names of screens and buttons are the words of `App/Localizable.xcstrings`.
- The description says "widget", "every other day", and "Export Records". `evidence.md` allows these only when they are in the released build. They are in the code on main. Check them against the build that ships.
- "Tap Taken on the reminder" has its condition in the text: a reminder for one item.
- "Remind Again" has its number in the text: up to 12.
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
| es | Name | Maru: Pastillas y vitaminas | Maru: Pills and vitamins |
| es | Subtitle | Recordatorio de medicamentos | Medication reminder |
| es | First line | ¿Ya me lo tomé? Abre Maru y sal de dudas. | Did I take it already? Open Maru and end the doubt. |
| de-DE | Name | Maru: Tabletten-Erinnerung | Maru: tablet reminder |
| de-DE | Subtitle | Supplements & Medikamente | Supplements and medications |
| de-DE | First line | Schon genommen? Öffne Maru, und du weißt es. | Taken already? Open Maru, and you know. |
| ko | Name | Maru: 약 알림·영양제 복약 기록 | Maru: medicine reminders, and a record of supplements and doses |
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

## 7. The screenshot plan

A design, not final images. The mock and its exports are outside the repository, in the maintainer's screenshot folder: `ui-shots/store/index.html` and `ui-shots/store/png/` (English and Simplified Chinese, 14 frames at 1206 × 2622).

### 7.1 Layout

- Seven portrait frames at 1206 × 2622 pixels, the required size. One upload serves every iPhone size.
- Background: white at the top that turns to a very light pink at the bottom (`#FFF3F5`). One background for all seven frames.
- Caption: on top, centered, the system font in bold, 128 pixels (108 for a long line), in `#1D1D1F`. The second half of the first two captions is in the app pink `#FF2D55`. An optional second line at 56 pixels in `#6E6E73`.
- The pink capsule of the icon sits over the first caption only. It is the one brand mark of the set.
- Device: a plain dark bezel with round corners, 968 pixels wide, that runs off the bottom edge. No hand, no tilt, no shine.
- Frame 2 has no device. It is the Today list as a cropped card at 108%, so the check marks are large. It breaks the row of phones once.
- No panorama, no badges, no ratings, and no price word.

### 7.2 The frames

| # | Screen and state | Why here |
|---|---|---|
| 1 | Today, with two items taken and three open | The promise. It answers "what is this" with the user's own question, and it shows the answer in the UI |
| 2 | Today as a cropped list, with the filled check marks | The second half of the promise: how little work it is |
| 3 | A Lock Screen reminder for one item, with the "Taken" action | The core loop is complete in three frames: see, record, get reminded |
| 4 | History, with the graph and "Last 7 Days" | The record is the proof that Maru remembers |
| 5 | The Home Screen with the "Today" widget | A second way to take the one look |
| 6 | The add screen with "Scan Label" | It removes the fear of setup |
| 7 | My Items, with photos | Trust at the end, for the reader who scrolls that far |

Captions. The first line is the headline. The second line is optional.

| # | en | zh-Hans | ja |
|---|---|---|---|
| 1 | Did I take it? / One look. | 吃了没？ / 看一眼就知道。 | 飲んだっけ？ / ひと目でわかる。 |
| 2 | One tap. / Recorded. | 点一下， / 就记好。 | ワンタップで / 記録完了。 |
| 3 | Reminders at your times. Second line: Tap Taken right on the reminder. | 按你的时间提醒。Second line: 在提醒上直接点“已服用”。 | 決めた時間にお知らせ。Second line: 通知から「服用済み」をタップ。 |
| 4 | See what you took. Second line: Months at a glance. | 吃过什么，一目了然。Second line: 几个月的记录一眼看完。 | 飲んだ記録がひと目で。Second line: 数か月分をまとめて。 |
| 5 | Your day at a glance. Second line: A widget on your Home Screen. | 今天，一眼看全。Second line: 主屏幕小组件。 | 今日の様子をひと目で。Second line: ホーム画面のウィジェット。 |
| 6 | Scan the label to add. Second line: Your iPhone reads the name. | 扫一下标签就能添加。Second line: 由 iPhone 读出名称。 | ラベルをスキャンして追加。Second line: 名前はiPhoneが読み取ります。 |
| 7 | No account. No ads. Second line: Your records stay on your iPhone. | 无需注册，没有广告。Second line: 记录只留在你的 iPhone 上。 | アカウント不要、広告なし。Second line: 記録はiPhoneの中だけに。 |

| # | es | de | ko |
|---|---|---|---|
| 1 | ¿Ya me lo tomé? / Sal de dudas. | Schon genommen? / Ein Blick genügt. | 먹었나? / 한눈에 확인. |
| 2 | Un toque. / Registrado. | Ein Tippen. / Erfasst. | 한 번 탭하면 / 기록 끝. |
| 3 | Te avisa a tus horas. Second line: Toca «Tomado» en el recordatorio. | Erinnert zu deinen Zeiten. Second line: Tippe in der Erinnerung auf „Eingenommen“. | 정한 시간에 알림. Second line: 알림에서 바로 ‘복용함’. |
| 4 | Mira lo que tomaste. Second line: Meses enteros de un vistazo. | Sieh, was du genommen hast. Second line: Ganze Monate auf einen Blick. | 먹은 기록을 한눈에. Second line: 몇 달 치도 한 화면에. |
| 5 | Tu día de un vistazo. Second line: Un widget en la pantalla de inicio. | Dein Tag auf einen Blick. Second line: Ein Widget auf dem Home-Bildschirm. | 오늘 하루를 한눈에. Second line: 홈 화면 위젯. |
| 6 | Escanea la etiqueta. Second line: Tu iPhone lee el nombre. | Etikett scannen, fertig. Second line: Dein iPhone liest den Namen. | 라벨을 스캔해 추가. Second line: iPhone이 이름을 읽어요. |
| 7 | Sin cuenta. Sin anuncios. Second line: Tus registros se quedan en tu iPhone. | Ohne Konto. Ohne Werbung. Second line: Deine Aufzeichnungen bleiben auf deinem iPhone. | 계정도 광고도 없어요. Second line: 기록은 내 iPhone에만 남아요. |

The caption of frame 3 is true only for a reminder with one item. The frame shows one item.

### 7.3 Captures that are still needed

The mock uses the captures that exist: Today, History, and the item detail in six languages, and the reminder and the widget in English. One simulator session, with the sample data and one build, must take these, each in six languages at 1206 × 2622:

1. The reminder on the Lock Screen with the "Taken" action, with no keyboard in the picture. The English capture shows a keyboard.
2. The Home Screen with the "Today" widget, with the widget text in each language.
3. The add screen with the "Scan Label" row and a name in the field. A second choice is the scan card over a real bottle.
4. My Items with a photo on three or more items.
5. Today in the state of frame 1, with the status bar at 9:41. The six captures that exist are good.
6. Settings with "Remind Again" open, as a reserve frame for the follow-ups.
7. Today in Dark Mode, as a reserve frame.

The sample items have English names in every language. A set for Japan, Korea, or China reads better with local names, such as "维生素 D" and "鱼油". That needs a small change to the sample data, or a hand-made set of items for each language.

## 8. Category, age rating, and review notes

### Category

- Primary: Health & Fitness (the release plan).
- Secondary: **Medical**, as a recommendation. In the US, 8 of the 10 top results for "pill reminder" have Medical as the primary category, and Apple's search reads both categories. Guideline 1.4.1 applies to what the app does, not to its category.
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

The answers match `App/PrivacyInfo.xcprivacy` and `PRIVACY.md`.

"Do you or your third-party partners collect data from this app?" Yes.

| Data type | Collected | Purpose | Linked to the user | Used for tracking | What it is |
|---|---|---|---|---|---|
| Identifiers › Device ID | Yes | Analytics | No | No | The random install ID |
| Usage Data › Product Interaction | Yes | Analytics | No | No | The usage events |
| Diagnostics › Other Diagnostic Data | Yes | Analytics | No | No | The error codes, the app version, and the major iOS version |
| Other Data › Other Data Types | Yes | Analytics | No | No | The region setting as a two-letter code (D064) |

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

One judgment: the feedback form opens in the system browser. Apple's label covers data that the app collects. If the form moves into the app, add "Other User Content" and "Email Address".

## 10. Decisions for the maintainer

1. **The name.** Search words in the name ("Maru: Pill & Vitamin Reminder", in the files) or the phrase of the site ("Maru: Know What You Took", alternative 1). The first is better for search and plainer. The second is the brand line, and the site and the first screenshot already carry it. If the maintainer picks the second, the subtitle becomes "Supplement & Pill Reminder".
2. **The secondary category.** Medical (recommended) or Lifestyle.
3. **es-MX.** Add it (recommended) or keep six languages.
4. **The alarm words** in the keyword fields. Keep them (recommended) or remove them, because Maru says that it is not an alarm.
5. **Local item names** in the screenshots of zh-Hans, ja, and ko.
6. **The China mainland storefront**, as in the earlier note. The zh-Hans text is ready in both cases.

## 11. Limits

- No search volume. No paid tool was used. The order of Apple's suggestions is the only sign of demand.
- The top-ten lists are from the iTunes Search API. Its order can differ from the order in the App Store app.
- The reading of the screenshot sets is by one model from contact sheets. Type sizes are estimates, not measurements.
- Not looked at: screenshots.pro, appscreens, theapplaunchpad, and X. Xiaohongshu: one result page only.
- Round Health, Dosecast, and Pillo were not found by name.
- Not verified: that search reads screenshot text, that search reads every supported language of a storefront, the keyword limit for Chinese, Japanese, and Korean, the two-character rule for those languages, and how search treats a hyphen.
- The ASO sources are vendor blogs with tools to sell.
- No native speaker read the text. Nobody saw the mock on an iPhone.
- The support and privacy URLs return 404 today.
