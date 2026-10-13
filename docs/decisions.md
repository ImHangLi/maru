# Decisions

Append new decisions at the end. Do not rewrite old entries.

## D001 · 2026-10-10 · Working brand is "Maru"

Owner decision. "Maru" is short and easy to say in en, zh, ja, de, fr, and es. In Chinese and Japanese, 丸 means pill, and ○ (maru) means "correct" or "done" in Japan. Descriptive names are crowded (Stack, StackDay, SupStack, Pillo, Dosely, Intake). The icon and the App Store subtitle carry the meaning, for example "Maru: Supplement Reminder". A trademark search is not done yet.

## D002 · 2026-10-10 · XcodeGen and a local Swift package

The `.xcodeproj` is generated from `project.yml` and is not in Git, so parallel worktrees do not conflict on it. Platform-neutral logic lives in `Packages/MaruKit` so that builds and tests run without a simulator.

## D003 · 2026-10-10 · The owner works only in chat

Owner decision. Agents own files, records, and routine decisions. The owner gates are in `docs/process.md`.

## D004 · 2026-10-10 · CI builds only the package (superseded by D031)

Superseded by D031.

macOS runner minutes cost 10x on private repositories. App builds and simulator runs happen locally until the cost is justified.

## D005 · 2026-10-10 · Placeholder bundle ID

`com.imhangli.maru` is a placeholder. Freeze it before the first TestFlight upload.

## D006 · 2026-10-10 · V1 direction confirmed

Owner decision. The positioning, the target users, and milestones A, B, and C in `docs/roadmap.md` are confirmed. V1 adds two items from research:

- A user-entered intake note, for example "with food" or "empty stomach". It is a user note, not app advice. Milestone A.
- A passive history heatmap with no streaks and no penalties. Milestone B.

The optional single follow-up reminder needs a real-device prototype first (spec §8.2). Build it only if the prototype shows that it works.

## D007 · 2026-10-10 · Apple Developer Program after milestone A

Owner decision. Use free on-device provisioning during milestone A. Buy the membership before TestFlight.

## D008 · 2026-10-10 · Issue work runs in subagents owned by the main chat

The owner chats in one thread. Each issue runs in a subagent that works in its own Git worktree. Do not open separate top-level chat threads unless the owner asks.

## D009 · 2026-10-10 · Tests follow spec §16 (narrowed by D016)

Spec §16 requires domain and database tests, real-device notification records, and performance results. Add tests for domain, database, and scheduling logic in `Packages/MaruKit`.

## D010 · 2026-10-10 · Today screen follows the time cards, with an orange accent (style replaced by D011, orange accent replaced by D018)

Owner decision. The Today screen uses variant B (one card per time slot). The accent color is orange, not green. The owner asked for less text and a style near Superpower, Everlab, and Anthropic: a warm neutral surface, one accent, and a serif for the large text. The study is in `docs/research/2026-10-10-visual-direction.md`. The exact orange and the refined layout (prototype variant B2) wait for the owner's answer. Write `docs/design.md` after that answer.

## D011 · 2026-10-10 · Apple system style for the Today screen (row time added by D044)

Owner decision. The owner rejected prototype variant B2. This decision supersedes the style part of D010 (warm surface and serif). The orange accent and the grouping by time slot stay.

- Use the Apple system style: San Francisco only, system colors, and the system orange as the accent. No serif, no custom background color, and no colored outline on a card.
- Do not show clock times such as 08:00 on the Today screen. Show the name of the time slot (for example "Morning"). This differs from spec §3 P01, which asks for the clock time of the current slot. Amend the spec when the owner confirms the final variant.
- Use fewer words. A row shows the name and the dose. The circle shows the state. The intake note and the recorded time move to the detail sheet and the correction dialog.
- Design references are good Apple-style apps of any category, not only health apps.

## D012 · 2026-10-11 · Accent choice, system font, recorded rows, and finished slots (fold after a record by D028, accent picker replaced by D021 and D025, dim and strikethrough removed by D032, a part that the user opens stays open by D055, folding removed by D057)

Owner decision, after the study in `docs/research/2026-10-10-visual-direction.md`.

- Accent: the default is a bright orange in light mode and a deeper orange in dark mode. The user can pick the accent in settings from a short row of clearly different colors. Each color has a light value and a dark value. Prototype set: orange, pink, green, teal, blue, purple, graphite.
- Font: the Apple system font only. A custom Latin font leaves Chinese text in the system font, and the owner does not accept that mismatch.
- Today layout: the cards variant. The list variant is dropped.
- Recorded rows: the default is dim. A setting adds a strikethrough.
- Finished slots: when every item of a slot has a record, the slot shows as one line the next time the user returns to the app. A tap on the title opens it, and a second tap folds it. Only a finished slot folds.
- These settings (accent, recorded-row style) join the scope of issue #11. The Today behavior joins issue #7.

## D013 · 2026-10-11 · White surface, row content, and text size (white surface replaced by D021, form choice changed by D043)

Owner decision, after three rounds of surface options (see `docs/research/2026-10-10-visual-direction.md`).

- Surface: the system background (white in light mode, black in dark mode) with gray wells. No tinted background, gradient, glow, or custom paper color. Color appears only in the icons, the record mark, and the current slot title. This keeps D011 and replaces every surface experiment after it.
- Row: a bare dosage-form icon in the accent first, the name, and the record circle last. The six own icons (capsule, tablet, softgel, powder scoop, drop, jar for an unknown form) are accepted. The user picks the form. The app does not guess it.
- Amount: optional, entered by the user, shown on a second line under the name. The product strength is not on the Today screen.
- Text size: follow the system setting at every size, including the accessibility sizes. No maximum and no in-app text size control. Recommendation by the agent, pending the owner's objection. Reasons: the people who choose the largest sizes need them most, iOS already has a per-app text size setting, and spec §5.3 forbids smaller text for the sake of layout. The layout adapts: names wrap and never truncate, the icon and the circle have a size limit, and the icon is hidden at the three largest sizes.

## D014 · 2026-10-11 · Database layer (file protection level replaced by D066)

Agent decisions from issue #2 (PR #15), after four review rounds by a different model.

- GRDB 7.11.1 (MIT) lives in a separate package target, `MaruDatabase`. `MaruCore` has no third-party code. Each third-party dependency is recorded in `docs/third-party-licenses.md`.
- The store reuses the domain rules. Reads and records go through `OccurrenceRecord`, `Schedule`, and the domain initializers. SQL has only keys, foreign keys, unique constraints, and checks.
- A record returns success only after the transaction commits and `F_FULLFSYNC` succeeds. A weaker flush does not count. The writer runs with `synchronous=FULL` and `fullfsync=ON`. One record costs about 5 ms on a Mac. Ordinary saves do not wait for the full flush.
- After `unavailable` from a record, the event can already be stored. The caller must keep the same event and schedule version, read the stored state, and retry the same event. It must not show success before a successful retry. This binds issues #5, #6, and #7.
- File protection is `complete`. A locked device cannot read or write the database, so a notification action must require an unlock (spec §8, §10).
- The first creation uses a temporary name and an atomic rename. An existing zero-byte database file, or WAL and SHM files with no database file, report `corrupt`. The store never clears and rebuilds (T37).
- The store has no delete operations. Slots, versions, product versions, and occurrences are immutable in the store.
- `Preferences` is not in the health database. Issue #11 decides its storage.
- Not verified, for the real-device issue #13: the flush result and its cost on an iPhone, protection at file creation, and the locked-device failure and recovery. The backup behavior of the database directory is not decided.

## D015 · 2026-10-11 · Today layout is cards

Owner decision. After the layout study (timeline, timeline with a Now mark, stack, ladder, blocks, tiles), the Today screen stays with one card per time slot. Card titles are in the text color, with no accent on the current slot. The other layouts are removed from the prototype. They stay in the prototype history and in `docs/research/2026-10-10-visual-direction.md`.

Addendum, same day: the owner compared "Cards" with "Cards, refined" (a raised record button and a smaller card title, from the X study) and chose the original Cards. The refined variant is removed.

## D016 · 2026-10-11 · Keep tests few

Owner decision. The owner said that the app has too many tests (137 after three backend issues) and asked to cut the ones with no use. This narrows D009.

- Write a test only for a behavior that protects a health record (no lost, doubled, or wiped record) or that an acceptance ID in `docs/spec.md` needs. One test per behavior.
- Do not write a test for each review finding, for a guarantee of the compiler, for a trivial initializer or default value, or for the same path with other literals.
- An implementation brief and a review brief state this limit. A reviewer does not ask for more tests unless a required behavior has none.
- A cleanup pass removes existing tests that do not meet this rule.

## D017 · 2026-10-11 · English first (replaced by D051 and D059 for the first public release)

Owner decision. The first release is in English. This includes the App Store screenshots and all store text. Simplified Chinese is optional and can follow later. This replaces "ship `en` and `zh-Hans` first" in `AGENTS.md`. Chat with the owner stays in Chinese.

## D018 · 2026-10-11 · Pink default accent, day ring, and final small points (ring removed by D026, My List and current slot points replaced by D020)

Owner decision.

- Default accent: the pink of Apple Health, which is the system pink (#FF2D55 in light mode). The agent named one risk: this pink is close to the system red for errors and destructive actions. The owner accepts it. The user can still pick another accent in settings (D012). The logo and the store material take the pink.
- Day ring: one small circle beside the "Today" title shows the progress of the day, with no number. It replaces the row of small circles. The exact look (thin line, segments, or fill) waits for the owner's choice in the prototype.
- Text size: confirmed as in D013. Follow the system at every size, with no maximum and no in-app control.
- No mark for the current time slot on Today. The owner asked whether it repeats other signals, and the agent agreed that the order of the cards and the open circles are enough.
- No other change from the last style pass: no bold type and no larger icons.
- My List uses the same cards as Today, with the group title inside its card. The system list put the group label on a different left edge from the page title, and the owner reported that as a misalignment.

## D019 · 2026-10-11 · Occurrence window and time zone policy

Agent decisions from issue #3 (PR #16), after two review rounds by a different model.

- A generation run covers yesterday, today, and tomorrow in the time zone of each plan. A long time away does not fill the days between (T26).
- A stored occurrence follows the schedule while it has no intake event and its date is not in the past in its stored zone or in the new zone. It keeps its ID and its key. After the first intake event (an undo also counts), or after its date, it never changes. This is the one exception to "occurrences are immutable in the store" in D014.
- `Schedule.isEnabled` stops reminders, not occurrences. An archived item gets no new occurrence.
- The named zone decides the instant. A local time that a clock change removes or repeats gives one occurrence with the plan time that the user confirmed, and it is flagged for review. The app does not move, drop, or double the dose (T25).
- A `.fixed` plan keeps its zone when the device moves. A `.followsDevice` plan moves the occurrences with no intake event and a date not in the past to the new device zone, and keeps the clock time.
- The store has no schema change. The resolved instant is computed, not stored.
- Open point for the history screen (#10): rows that are no longer planned and have no record stay in the database, so history must read by records.

## D020 · 2026-10-11 · Ring, opening highlight, My List, palette, and settings entry (ring and icon-only tab setting removed by D026, palette replaced by D021, My List form replaced by D032, opening highlight removed by D050)

Owner decisions, with two agent recommendations that the owner asked for.

- Day ring: one plain thin ring with no segments and no number. One line with a round end grows around the circle as the records come in. The owner tried a ring with one arc per time slot and went back to the plain ring. This replaces the three ring options in D018.
- Opening highlight: when the app opens or returns to the front, the title of the current time slot has the accent for about six seconds and then returns to the text color. This replaces "no mark for the current time slot" in D018. Keep the code small.
- My List goes back to the system grouped list with the group label outside the group. The owner prefers it to cards. Apple's own apps have the same small inset between the page title and the group label (checked on the iOS 27 simulator: "Summary" and "Pinned" in Health), so the inset is kept. This replaces the My List point in D018.
- Accent palette: pink (default), orange, green, teal, blue, purple, and black. Black replaces gray. In dark mode the black accent is near white, and the check mark on it is black.
- Settings entry (agent recommendation, the owner asked): a gear button at the top left of both tabs that opens a sheet. Not a third tab. Reasons: settings are rare, a tab is for a place the user goes every day, Apple's own apps (Health, Fitness, App Store) put the same kind of entry in a top corner, and two tabs keep the bar calm. A reminder problem such as notifications turned off shows on Today itself (spec §2.2), so the user does not need to find settings to learn about it. The add button sits at the top right of both tabs. This keeps the two tabs of spec §1.
- New optional setting: the tab bar shows icons with no words. Off by default. The names stay for VoiceOver.

## D021 · 2026-10-11 · Direction after Apple Health Medications, no app accent, item colors, header wash (wash removed by D024, no accent setting replaced by D025, one follow-up replaced by D039, "Record All" removed by D060)

Owner decision, after the hands-on test in `docs/research/2026-10-11-apple-health-medications.md`. The owner accepted the recommendation: continue milestone A with a narrower positioning. The owner set three requirements for every flow: not tedious, intuitive, and simple. The owner asked for the Apple Health features that Maru should have, each in a simpler flow. The owner left the wash color and the details to the agent and went offline, so the agent made the choices below.

Direction:

- Maru is a faster and simpler way to remember and record daily supplements and simple medications. It is simpler than Apple Health Medications in every flow that both apps have. Count screens and taps, and keep Maru lower.
- A study of the HealthKit Medications API runs before milestone B (option 2 of the test note). It does not block milestone A.

Visual decisions (agent choices, easy to change later):

- No accent setting. The app has one fixed tint, the system pink (D018), for controls, the day ring, and the opening highlight. This replaces the accent picker in D012, D018, and D020. Color now comes from each item, as in Apple Health.
- Header wash: on. One hue, the app pink, with the measured curve of Apple Health and the relative luminance of Apple's colors (0.54 in light mode, 0.09 in dark mode). The page is the gray grouped background with white cards, as in Apple Health. This replaces the white surface of D013. Reason: the owner asked for the wash, and the wash needs the gray page with opaque cards to look as it does in Health.

Apple Health features that milestone A adds, in a simpler form:

1. Item color. Each item has one color from a row of eight clearly different colors: pink, orange, yellow, green, mint, blue, purple, and brown. The form icon on Today and My List takes the item color. A new item gets the first color in the row that no active item uses, and the user can change it in the same edit screen. Apple asks for a shape and three colors on two separate screens. Maru has one row of forms (D013) and one row of colors on the one edit screen (spec §3 P03).
2. Record a whole slot. A slot card on Today has one control that records every open item in the slot as taken, in one transaction. Apple needs open, plus, "Log All as Taken", and "Done".
3. Optional follow-up reminder. Off by default (spec §4). When on, one extra reminder comes a set time after the slot (15, 30, or 60 minutes) only if the slot still has an open item. It is one-time requests for the next seven days, refreshed when the app runs. A record removes the follow-up of its occurrence. If the app does not run for seven days, the follow-ups stop and the main reminders continue. The settings text states this limit.
4. As-needed items. An item with no schedule can be recorded at any time from an "As needed" card at the end of Today. Each record makes its own occurrence at the record time.
5. IU as an amount unit. Apple Health has no IU, and many vitamin labels use it.

Not added: Critical Alerts (Apple grants this entitlement only on request, and spec §8.1 forbids claims of guaranteed delivery), the Apple Watch app and iCloud sync (later list in `docs/roadmap.md`), and shapes beyond the six forms of D013.

## D022 · 2026-10-11 · No HealthKit Medications integration in V1

Agent decision, after the study in `docs/research/2026-10-11-healthkit-medications-api.md`. An app can only read the medications that the user allows and their dose events. It cannot write a dose, and it cannot read schedule times. So Maru cannot be a faster front end for Health. Option 2 of D021 is closed. An optional read-only name import stays a later candidate. It needs a device test of the entitlement first.

## D023 · 2026-10-11 · Settings sheet and preference storage (display settings removed by D026 and D032, foreground rule replaced by D027, no-names rule replaced by D029, feedback row added by D037) (test notification removed by D076)

Agent decisions from issue #11.

- Preferences live in `UserDefaults.standard`, not in the health database (D014). Display settings use two keys, read with `@AppStorage`. The follow-up setting keeps the key of PR #25. No value means off. Reason: the settings must be readable while the iPhone is locked, and they hold no health data.
- The sheet has three groups: reminders (permission state, "Open Settings" when off or quiet, and the test), follow-up (Off, 15, 30, or 60 minutes), and display (strikethrough, tab bar icons only). All options are off by default.
- The permission shows as On, Quiet (provisional), Off, or Not Asked Yet. Maru reads it at each return to the front and never shows the system prompt from settings or Today (spec 2.2, T13, T14).
- Today shows one small line, "Notifications are off", only while the permission is denied. A tap opens the sheet.
- The test notification is one one-time request with one fixed identifier, `test|settings`, in about 5 seconds. It runs in the notification queue of `AppStore`. Neither engine removes it, and both count it while it waits. At the system limit, it first removes the latest follow-up, then the follow-ups are set again after it fires. It never removes a series request. It shows as a banner while Maru is in front. A tap on it records nothing.
- No "show item names on the lock screen" option. Spec 8.2 makes neutral text the baseline and does not require the option. Names would need new content for each series and each follow-up. The sheet states in one line that reminders show only a time.
- No language row: the first release has only English (D017). No help or feedback row: feedback sending is milestone B.

## D024 · 2026-10-11 · No header wash, app-specific empty text (empty text and tab bar point replaced by D026)

Owner decisions after the first install on a device.

- Remove the pink header wash of D021. Today uses the plain grouped background, the same as My List. The fixed pink tint and the item colors stay.
- The empty Today page does not read like a to-do list. With no items, it says "Add a supplement or medication with the + button." With items but nothing due today, it says "No doses to take today."
- The "tab bar icons only" setting must work. A label style has no effect in the tab bar, so the icon-only item uses an image with an accessibility label.

## D025 · 2026-10-11 · App color setting

Owner decision. The owner asked for a setting that changes the accent color of the whole app. This replaces "no accent setting" in D021. The item colors of D021 stay.

- Settings has an "App Color" group between the follow-up group and the display group. It shows the eight item colors as a row of circles, the same as the color row on the edit screen.
- Pink is the default, so the app does not change for current users.
- The choice lives in `UserDefaults.standard` under `display.appColor`, read with `@AppStorage` (D023).
- The choice is the tint of the whole app: buttons, the filled record circle, the day ring, the opening highlight, and the sheets. Item colors are independent of it. Errors and destructive actions stay the system red.
- In light mode, orange, yellow, green, and mint have less than 3:1 contrast on white. As the tint, they get a darker value with the same hue that reaches 3:1. Dark mode uses the system colors.
- A label on a filled tint, such as a check mark, a weekday letter, or the Save text, is white or black. White stays when it has at least 3:1 contrast on the fill. Otherwise the label is black. The rule checks the light and the dark value of the fill separately, so yellow, orange, green, and mint get black labels in dark mode. The color circles on the edit screen use the same rule.

## D026 · 2026-10-11 · Native components only (notices removed by D028, header check mark removed by D032)

Owner decisions after use on the device. The owner asked to remove every control that is not a native component.

- Use native SwiftUI system components. Use a custom control only when no native one does the same job. Record each kept custom control and the reason.
- No day ring. Today has no ring beside the title. This replaces the ring of D018 and D020.
- History opens from a button in the navigation bar of Today, with a calendar symbol and the label "History". The button sits between the gear and the add button.
- Today is a system grouped list. Each part of the day is a list section with a large header. The current part, "Record All", and the fold of a finished part stay in the header.
- The empty Today text is a system empty view in the middle of the page. With no item: "No Items Yet" and "Tap + to add a supplement or medication." With items and nothing due today: "Nothing to Take Today".
- The add and edit screen has "Cancel" at the top left and "Save" at the top right. Save is off until the draft is valid. The bottom Save button and the "Enter a name to save" hint are gone. The plan line is the footer of the reminder section.
- Form, color, and app color are system menus. The repeat days are a list with check marks, as in Clock. A new time comes from a sheet with a time wheel.
- The record circle is an SF Symbol in a button: an empty circle, a filled check, a gray dash, or a red mark. History shows no record as a dashed circle.
- No "tab bar icons only" setting. The tab bar always shows icons with names. This replaces the setting of D020 and the tab point of D024.
- Kept custom controls: the save and change notices at the bottom of the page. SwiftUI has no native notice that closes by itself and does not block the page. An alert would block the page and need a tap.

## D027 · 2026-10-11 · Reminders show while Maru is in front

Agent decision, after an owner bug report from the device: "the test notification works, a reminder does not".

- Cause: the notification delegate returned no presentation options for every notification except the test of settings. While Maru was in front at the reminder time, the system dropped the reminder with no banner, no sound, and no entry in Notification Center. The simulator log showed `Received response 0 for willPresentNotification` and `Saving notification: NO`.
- Every notification of Maru now shows as a banner, in the list, and with sound, also while Maru is in front. This replaces "only the test shows while Maru is in front" in D023.
- Spec 8.2 allows a foreground check against the records, and T23 asks to avoid a misleading repeated display. Maru does not do that check yet. The reminder text is neutral, so a reminder after a record does not say that a dose is not taken.

## D028 · 2026-10-11 · No toasts, animated fold, and row gestures (a part that the user opens stays open by D055, folding removed by D057)

Owner decisions after use on the device. The owner asked to follow Apple apps such as Health, and for every interaction to feel smooth and native.

- No toast. Apple Health shows no message after a save. The sheet closes, and the list updates in place. Maru does the same. The save notice and the change notice at the bottom of the page are gone. This replaces the kept custom controls of D026.
- Errors use a system alert. A reminder that failed after a save or a change gets an alert, because spec §8.1 asks to say "plan saved, reminder not set". The plan is saved, so the alert names only the reminder problem. Notifications that are off get no alert, because Today and My List show "Notifications are off" in place, and T13 forbids repeated questions.
- The item detail shows the reminder state as a plan row: "On", "Not Set", or "Not Confirmed", with the reason in the footer (T03). The state comes from the last run of the reminder engine. Before the first run of a process, the row does not show.
- Lost with the notices: "Add Another" (use the add button) and "Restore" after an archive (use the archived list in My List). The archive keeps its confirmation alert.
- The record that finishes a part of the day folds it after about 0.7 seconds, with the same animation as a tap on the header. Reduce Motion changes it at once. Only a finished part folds. D012 folded a part only on a return to the app. A part that was folded earlier opens first, so it never snaps closed.
- Today rows have native swipe actions and a context menu. An open row: swipe right "Taken", swipe left "Skip". A taken row: swipe left "Undo". A skipped row: swipe right "Taken", swipe left "Undo". A row that is not saved: swipe right "Try Again". The menu has the same actions, "Change Time…" for a taken row, and "Details" and "Edit". An as-needed item has "Take Now", and a dose has "Undo" and "Change Time…". Every action uses the same domain operation as the circle, so success shows only after the commit (spec §7.2). The record circle stays a separate hit target. VoiceOver lists the swipe actions as actions of the row.
- The page stays the gray grouped background with white cards, as in Apple Health and Settings. Every page uses it, also while it loads.

## D029 · 2026-10-11 · Reminders say what to take

Owner decision, after use on the device: "The notification does not tell me what to do. I just got 'Check your 12:30 plan'." This replaces the neutral-text baseline of spec 8.2 and the "no show item names option" point of D023.

- Reminders show the item names by default. Settings has a switch, "Show Names in Reminders", in its own group below the reminder group. It is on by default.
- Wording, as short as possible, with no "·" separator:

  | | Title | Body with names | Body without names |
  |---|---|---|---|
  | Reminder | "Time to take" | The items of that time | "Open Maru to see your plan." |
  | Follow-up | "Still to take" | The items of that time with no record | "Open Maru to see your plan." |

- The names use the list style of the language: "Zinc", "Zinc and Creatine", "Zinc, Creatine, and Iron". More than three items give the first two names and the count of the others: "Zinc, Creatine, and 2 more".
- No clock time is in the text. iOS shows the delivery time on every notification. A written time can be wrong for a plan in a fixed time zone, and it keeps an old 12-hour or 24-hour format.
- No amount is in the text. Today shows the amount.
- The text never says "you have not taken it". The user can record before the time, and a repeating request cannot change its text (spec 8.2). "Still to take" is only on a follow-up. A follow-up is set only while an item of that time is open.
- A request keeps the text that it got when it was added. So the engines compare the text too:
  - A pending request is current when its identifier, its `userInfo`, and its title and body match the wanted request. The notification target makes the text in the language of now, so a new name, item, setting, or language gives other text.
  - Other text gives an add with the same identifier, which replaces the pending request. It takes no new room, and it needs no removal. The request budget, the removal ledger, and the removal checks stay as they were.
  - The `userInfo` (series ID and schedule revision) and the tap resolver do not change.
- A delivered notification also keeps its text. Each refresh of the follow-ups removes a delivered follow-up whose text is not the text of its group now, for example after a record of one of its items, a rename, or an archive. A delivered first reminder stays. It was true for its time, and a rule on its text removed valid reminders in review. One exception: when the user hides the names, a delivered first reminder that shows names is removed.
- A request names only the items of its own day. When the items of one time have different weekdays, the series gets one request for each weekday instead of one daily request. With names off, the text is the same on each day, so such a series keeps one daily request.
- The per-weekday requests use more of the budget of 48. So a switch of the setting can leave a plan with no reminder. The switch reports the result as a save does: the Reminder state in the item detail and an alert. The engine runs again at launch and on return to the front.
- Health data rule: the names stay on the device in local notifications. The text is read back from the system only in memory for the comparison, and it is never logged (spec 10).
- The setting lives in `UserDefaults.standard` under `reminders.hideNames`. No value means names on (D014, D023).

## D030 · 2026-10-11 · One motion language (the cases press and fill, and the motion of a tap and of numbers, changed by D058)

Owner decision, with agent detail. The owner likes the open and fold animation and asked for the same care on every page: motion where a change needs it, none where it does not, and the same motion for the same kind of change. The earlier report, a finished part that snapped closed while a tap on its header animated, was a consistency problem.

Owner:

- Motion stays restrained. Nothing decorative.
- The same kind of change uses the same motion on every page. A change that moves the layout must not snap on one page and animate on another.

Agent detail:

- Three cases in `App/Motion.swift`: layout (the `snappy` spring of the fold), state (a fade of 0.2 seconds, with the system replace effect on a symbol), and attention (the fade of 1.2 seconds of the opening highlight). `docs/design.md` "Motion" lists where each one applies. `AppModel.foldAnimation` and the literal durations in the views are gone.
- Reduce Motion: a layout change shows at once. State and attention are fades with no move, so they stay. A symbol cross-fades with no scale.
- New motion after an audit of every page: rows and sections that come or go on Today, My List, the archived list, the item detail, History, and Settings. Rows and footers of the add and edit form. The change between an empty page and a list. A finished part that folds on a return to the app. The icon of a Today row now dims with its name. The check mark and "Record All" in a part header fade.
- The record circle is one image for every state. Before, each state was its own image, and no motion reached the circle, so the system replace effect had nothing to run on.
- The first content of a page has no entrance: Today at a launch, the item detail, and the first days of History (spec §9). Text values, the app color, the repeat day check marks, and the storage problem page change at once.
- The system keeps the motion of sheets, pushes, menus, alerts, swipe actions, and pickers.
- The record rule stays: a row changes only after the commit (spec §7.2). No motion starts at the tap.
- The row animation of a system list is the one of the system. The layout case starts it, and the system chooses its curve.

## D031 · 2026-10-11 · Open source under the MIT license, and CI builds the app

Owner decision. Maru becomes a public repository under the MIT license. This replaces D004.

- macOS runner minutes are free for public repositories. CI builds the app for the iOS Simulator, in addition to the package build and tests. The app needs Xcode 27, so the app job runs on the `xcode-27` runner image.
- The repository holds no personal health data, no local paths, and no credentials. Records refer to private work only as history, without links to private branches or local files.
- `docs/process.md` applies to every contributor. The rules for agents that work for the maintainer are in `AGENTS.md`.

## D032 · 2026-10-11 · Owner feedback: plain folded header, timeline history, grid for My List, add-item defaults ("Remind Again" row replaced by D039, row time added by D044, chevron removed by D050, folding removed by D057)

## D032 · 2026-10-11 · Owner feedback: plain folded header, timeline history, grid for My List, add-item defaults ("Remind Again" row replaced by D039, row time added by D044, timeline on the main History page replaced by D054, folding removed by D057)

Owner decisions after use on the device. The owner wants a simple, native app with no repeated information.

- A folded part of the day has the same title look as an open part. No gray text for a state.
- The header of a finished part has no check mark. The chevron says that the part folds, and only a finished part folds. This replaces the header check mark of D012 and D026.
- History is one timeline: newest first, grouped by day ("Today", "Yesterday", then the date). Each row is one action: taken, skipped, time changed, or undone. Undone and replaced actions stay in the list. A planned dose of a past day with no record stays in its day as "No record". Older days load when the list ends. The corrections of D014 and D028 stay, with a swipe or a long press on the newest row of a dose.
- Add item: the kind starts on "Supplement", and the form starts on "Capsule". These two defaults are owner decisions. Spec §2 still forbids a default amount and a default reminder time. The "choose a type" hint is gone.
- "Remind Again" shows the delay after the first reminder as its value, for example "After 30 min". Its footer is one short sentence.
- The setting "Strike Through Recorded Items" is gone, with its stored preference. This replaces the strikethrough setting of D012.
- My List is a grid of tiles, not a list. This replaces the list form of My List in D020. The tile is a kept custom control (D026), because the system has no grid card.
- Each footer and helper text is one short sentence.

Later owner points in the same round:

- A. No "·" separator in any text of the app. Natural words or a second line replace it. The reminder notification text is not part of this change.
- B. A recorded row on Today does not dim. It differs from an open row only by the circle. This replaces the dim of D012. A skipped row and a row that is not saved also show their state only in the circle.
- C. The tab and the page "My List" have the name "My Items". File and type names stay.
- D. A tile of My Items shows only the form icon, large, in the item color, and the name in a strong weight. It has no plan line and no amount. The plan stays in the item detail. The order is the first time of day of the plan, then the name. As-needed items come last. No section titles.

Agent detail:

- The timeline groups by the day of the dose, so a day still answers "did I take it". The time at the end of a row is the time of the action. The words name the intake time when it differs.
- The history rule of D019 changes in one point: a dose with an intake event shows also after an undo. No new store read and no schema change.
- The example time of a new supplement (spec §2.1) is no longer a time in the draft. It is the start value of the time wheel, and it counts only after "Add".
- My Items reads the plans when the page shows, not at launch, so the startup path does not load the schedules (spec §9).
- The record mark of a History row is gone: the words say the action. So no symbol changes state in History.

## D033 · 2026-10-11 · Shorter record correction and archive, and delete of an item

Agent decision under the owner's direction: match Apple Health Medications, with simpler flows. The gap study `docs/research/2026-10-11-apple-health-gap.md` found three flows that were not simpler.

- Change the time of a record: three taps, not four or five. The time sheet shows the time wheel at once. The context menu of a recorded row on Today and of the newest row of a dose in History opens the sheet directly with "Change Time…".
- "Taken Earlier…" is in the context menu of an open row on Today. It opens the same sheet, and "Save" records the dose as taken at the chosen time. It uses the record transaction of the circle, so it needs no new domain code. The wheel does not go past the current time, and the save limits the time to the current time.
- Archive: three taps and one confirmation. "Archive…" is in the context menu of a Today row and of a My Items tile. The alert keeps its text, which says that archive is not advice to stop (spec §3 P04).
- "Change or End This Item…" on the item detail opens a system menu, not a dialog. The dialog was a second confirmation before the alert. Its message "Changes start today. Past records stay the same." is gone, because it is not true for a delete.
- Delete of an item with its records. "Delete Item…" is in the menu of the item detail, on the detail of an archived item, and in the archived list as a swipe action and in the context menu. One alert names the item and says that its plan and its records are deleted and that the user cannot undo this.
- One store operation and one transaction delete the item, its product versions, its schedules, its occurrences, its intake events, and the projection rows of those occurrences. The event history and the projection of every other occurrence stay as they were. A failure rolls back every row.
- After the commit, one run of the notification queue removes the reminders and the follow-ups of the item. A removal that the run did not confirm gets the alert of an archive. `ReminderOutcome` now has `removalPending`, because a deleted schedule has no entry in `schedules`.
- The kept drafts of the item are deleted: the draft of its edit and the draft of its replacement. Every event of the item that the store did not confirm is forgotten, also one that no page shows. History drops the doses of the item at once and reads again, and a History read that started before the delete does not show.
- Spec §7.3 gets one sentence: a delete that the user asks for and confirms is not the forbidden "clear and rebuild". The "明确不做" list does not forbid a delete, and spec §3 P06 names "privacy and delete".
- One archive and delete confirmation for the whole app is in `RootView`. Each page asks the model for it.
- The swipe button "Delete Item…" has no destructive role. With that role the system removes the row before the confirmation.
- Tests (D016): one new test, for the delete transaction.

## D034 · 2026-10-11 · A "Taken" action on a single-item reminder, and time-sensitive reminders (time-sensitive level done by D062, unlock rule changed by D066)

Agent decision, under the owner's direction to match Apple Health Medications (`docs/research/2026-10-11-apple-health-gap.md`, rows 22 and 23).

The "Taken" action:

- A reminder or a follow-up that stands for exactly one item has one action, "Taken". A reminder for two or more items has no action, and a tap opens Today as before. Spec 8.3 forbids a blind record of a group.
- A first reminder has the action when its day has exactly one item at that time. With the names hidden, a daily request has the action only when each of its days has exactly one item, so the series keeps its one request. A follow-up has the action when its group has exactly one item, open or not.
- The action has the option `authenticationRequired` and no `foreground` option. The system asks for an unlock, then starts Maru in the background. The database has complete file protection (spec 10).
- The action uses the tap resolver. A first reminder must resolve with no doubt: on time, today, the plan of now, and no clock change. Its revision is a hash of the slots and the schedule versions of its members, so a reminder from before a plan change does not resolve. A follow-up carries its plan date, so only the date and the device zone are checked. The result must be exactly one item, the stored dose must be of today in its own zone, and it must be open.
- A follow-up has no revision. With the names hidden, a delivered follow-up keeps its identifier and its text after another item takes its time. So a follow-up with the action carries the ID of its one item and of its schedule version in `userInfo`, and no name. The action records only a dose of that item with that version. A follow-up with no such ID, or with another one, records nothing. The IDs stay in the local notification system and are never logged (spec 10).
- The record is the transaction of the record circle, with the source `notificationAction`. The event revises the last event that the store read. So a second action, or an action after a record in the app, writes nothing (T18). A dose that is already taken needs no record, and the action ends with no message.
- After the commit, the follow-ups update as after a record on Today.
- The handler returns to the system when the record commits or fails, or after 5 seconds, the first of the two. It returns one time on every path. It waits for no notification call of the system: the follow-up update and the "Not recorded" notification run after it. The record is not cancelled at the limit.
- The action never replaces a skip, and it never sends a second event next to an event that the store did not confirm (D014).
- When the action can not record, it records nothing. Apple gives a background action no way to open the app. So Maru sends one notification, "Not recorded" and "Open Maru to record it.", which names no item. Maru also prepares what a tap on the reminder shows: the confirmation sheet, or "Unlock to Continue" for a locked database (T40). An open of Maru removes the notification.
- The request content has a category now. The engines treat a pending request with another action state as not current, and they replace it with an add of the same identifier, as for text (D029). It takes no new room. The budget of 48 and the removal rules do not change. The `userInfo` of a first reminder does not change.
- The action title and the two notice texts are in the String Catalog of `MaruNotifications`.

Time-sensitive reminders:

- Not done. The interruption level of reminders, follow-ups, and the test notification stays the default level.
- The level needs the capability "Time Sensitive Notifications". Apple's capability table gives it to the Apple Developer Program and the Enterprise Program, and not to a free Apple Developer account. Maru uses free provisioning until milestone B (D007), so the maintainer's personal team can not sign a build with the entitlement.
- Do this after the membership: add the capability in `project.yml`, and set the level on the three request types. The WWDC21 session says: enable the capability in Xcode, then set the level on the content. The entitlement key `com.apple.developer.usernotifications.time-sensitive` comes from Apple Developer Forums threads. No Apple reference page that I found states it.
- The API has no permission request for this level. Apple says that the user can turn off Time Sensitive alerts for an app. How the system first asks the user is not on the pages that I read, and it needs a device check. Spec 8.1 still forbids a promise of delivery.
- Critical Alerts stay out (D021).

Sources, read on 2026-10-11:

- [Declaring your actionable notification types](https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types): the system launches the app in the background for an action, and files with complete protection can be unavailable when the device is locked.
- [Handling notifications and notification-related actions](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions): an action goes to the app "without bringing the app to the foreground". The page gives no run time.
- [`authenticationRequired`](https://developer.apple.com/documentation/usernotifications/unnotificationactionoptions/authenticationrequired) and [`foreground`](https://developer.apple.com/documentation/usernotifications/unnotificationactionoptions/foreground).
- [`UNNotificationInterruptionLevel.timeSensitive`](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/timesensitive).
- [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios).
- [Send communication and Time Sensitive notifications, WWDC21](https://developer.apple.com/videos/play/wwdc2021/10091/).

## D035 · 2026-10-11 · After the user feedback study: every other day, no stock, and a launch FAQ

Owner decisions after the study in `docs/research/2026-10-11-user-feedback-cn.md`.

- Add an "every other day" schedule. Supplement users asked for it most. It needs a spec change in the schedule rules.
- Stock, refill, and expiry stay out of scope (spec section 1), although about 13 mentions asked for them.
- The first release answers the common questions directly, as a FAQ: `docs/faq.md`. The owner's words for the product: one single, separate, easy place for this job. A record is simple. A missed record is fine. The app exists to lower the mental load.
- Do not build the app on the maintainer's Mac. CI is the build check. One local device build is acceptable for an install on the maintainer's iPhone.

## D036 · 2026-10-11 · Every other day: rule and reminders (two notifications at one time replaced by D047, "no cycles" and "no date picker" replaced by D065)

Agent decision, under the owner decision D035. It changes spec 2.1, 8.1, 8.2, 8.3, 8.5, and 15 (new acceptance ID T51, and a note on T22).

The rule:

- A schedule version can have a start date for "every other day". A dose is due on the start date and on each date an even number of calendar days after it.
- The rule counts calendar dates in the calendar and the time zone of the plan. It does not count hours. So a clock change and a time zone change do not move the rhythm. A missed or skipped dose does not move it.
- The start date is in the schedule version. An edit of a time or of the amount makes a new version with the same start date, so the rhythm stays. A change of the rhythm or of the first day makes a new version from today with a new start date. Past records do not change.
- A day with no dose has no occurrence. So the item is not on Today, and History shows no "No record" row for it. The three-day window and the history rules of D019 did not change.
- Only this rule. No cycles, no changing amounts, and no interval in hours (spec 1).

The database:

- Migration `v4` adds one column, `scheduleVersion.everyOtherDayFrom`. A version from before has `NULL` and loads unchanged. A check keeps every weekday on a version with a start date, as the domain does.

The reminders:

- iOS has no repeating trigger for "every second day". A calendar trigger repeats by its components, and no component means "each second date".
- A plan of every other day gets dated requests: one request that fires one time, for each of its next 7 due dates at each of its times. Each run of the reminder engine sets them again: after a save, at a launch, and on a return to the front. Follow-ups work the same way.
- The dated requests are series requests. They use the identifier prefix, the budget of 48, the comparison of text and action, the removal ledger, and the room rules of the engine with no change. Their identifier ends with the date. The trigger is a calendar trigger with a date and `repeats: false`.
- The repeating requests get the budget first, then the dated requests. So a change of one plan to every other day never removes the daily reminder of another plan. The 7 requests of one time fit in the budget together, or none of them is set. Then the schedule shows "Not Set" with "too many times". A plan never has a reminder on some of its dates only.
- The limit: the last request is for the seventh due date from the last run. When the user does not open Maru before that date, the reminders of this plan stop after it. The repeating reminders of the other plans continue. Follow-ups stop after 7 days in the same way (D021). The difference is that a follow-up is optional, and this is the first reminder of the plan.
- The item detail states the limit. When the reminder is "On" for such a plan, the footer says: "Maru sets the reminders of the next 7 dose days each time you open it." Spec 8.2 rejects a short queue that fails with no notice. This queue is the one exception, because the page states its length.
- A daily item and an every-other-day item at the same time give two notifications on a due day, not one. The repeating request names only the daily item. The dated request names only the items that are due on its date. One grouped notification needs the daily item in a dated request too. Then the daily reminder also stops when the user does not open Maru, or the repeating request names an item on a day with no dose. Two notifications keep the daily reminder with no limit, and no notification names an item on a day when it is not due. Each of the two is for one item, so each has the "Taken" action (D034).
- Two every-other-day items at the same time on the same dates share one request, as two daily items do.
- A dated request carries the series ID, the schedule revision, and its plan date. The tap resolver reads the date from the request and not from the delivery time. The other rules of spec 8.3 stay: another day, a late delivery, an uncertain device zone, an older plan, or a clock change opens the confirmation. The revision of a dated request names only the slots that are due on its date. The revision of a repeating request names only the slots with a weekly rule. So the "Taken" action keeps its identity check (D034).
- A follow-up is dated already, so it did not change. One follow-up names every open item of its time, also an every-other-day item on its due day.
- A dated request can fire in the time of a run. The engine does not report a request as not registered when its fire time passed before the run read the pending requests. The run reads the clock at that read, after every wait. A request whose time is still to come must be pending, also when the time is near.
- The reminder text did not change (D029), and the String Catalog of `MaruNotifications` has no new text.

The screens:

- The repeat page has "Every Day" and "Every Other Day" in the first section. Under it are the seven days, or the two choices "Starting Today" and "Starting Tomorrow". No date picker.
- The app picks no first day (spec 2.1). Save stays off, and the plan line says "Choose the first day.", until the user chooses.
- The draft keeps a start date, and not the words "today" or "tomorrow". It is the stored start date of the plan, or the calendar date that a first-day choice had at the tap. Only a tap on a first-day choice changes it, and the tap reads the date at that moment. So a save after midnight, or a draft that comes back on a later day, keeps the rhythm.
- On an edit of a stored plan, the check mark is on "Starting Today" when today has a dose by the start date, else on "Starting Tomorrow". A tap on the row with the check mark changes nothing.
- The plan line of a plan that starts today or tomorrow reads "Every other day at 8:00 AM, starting tomorrow, with no end date". A plan that started before today reads "Every other day at 8:00 AM, with no end date". The item detail shows "Every other day" and a row "Next Dose" with "Today", "Tomorrow", or a weekday. "Next Dose" reads the plan and not the records. After the last time of a due day it shows the day after tomorrow.
- A tile of My Items has no plan line (D032), so My Items did not change.

Rejected:

- One grouped notification for a daily item and an every-other-day item. See above.
- Two weekly requests, or any set of repeating requests. No set of weekday triggers gives every second day, because a week has seven days.
- A repeating time-interval trigger of 48 hours. It counts hours, so a clock change moves it by one hour, and a time zone change moves it more. It also has no start date in the future.
- A top-up in the background (`BGAppRefreshTask`). Spec 8.1 forbids a reminder that depends on a background refresh, and iOS gives no guarantee for one.
- More than 7 due dates. Each time of such a plan uses 7 of the 48 requests. 14 dates halve the number of times that fit, for a longer limit that still exists.
- A default first day. Spec 2.1 lets a draft show "every day", but the first day decides on which days the user takes the item.
- A date picker for the first day. Two choices cover the need, and D035 asks for this schedule only.

Tests (D016): three new tests. The rhythm across a clock change, the dated requests with their dates and the budget, and the migration.
- Accepted limit, from the third review round: when the system clock moves back during the last read of the pending requests, a request that fired in that moment can count as missing, and the item shows "Not Set" until the next run of the engine. The next run corrects it. No record and no reminder is lost, so this stays as it is.

## D037 · 2026-10-11 · Feedback through a web form

Owner decision. Settings has a "Send Feedback" button at the end. It opens the owner's Tally form (https://tally.so/r/jadWkR) in the system browser.

- No server of Maru, no email address of the owner in the app, and no data of the app in the request. The page loads only after a tap.
- The form asks for a message, and for an email address only if the user wants a reply. It asks the user to leave out health details.
- `PRIVACY.md` names Tally. "No network requests" is now "no network requests by itself".
- The button uses the system `openURL` action and asks for the in-app browser sheet. On a system before iOS 26, Safari opens. No custom browser view.


## D038 · 2026-10-11 · Quick add: scan a label and name suggestions (form proposal changed by D043) (scan card partly replaced by D042)

Owner decision, with agent detail. The owner said that typing is tiring and that a user who types for a while gives up. The study is `docs/research/2026-10-11-quick-add.md`. It changes spec 3 P03 and 5.2.

The rule: a scanned or suggested value is a proposal. The user sees it on the edit screen and saves it with the normal "Save". A proposal never sets the type, the amount, or a reminder time (spec 2.1).

Scan Label:

- The edit screen of a new item starts with one row, "Scan Label", above the name. The row shows a camera symbol, a small sparkle symbol beside the title, and the line "Point the camera at the bottle." The symbols take the app tint.
- A tap opens the live scanner of the system, VisionKit `DataScannerViewController`, with text recognition, highlights, and guidance. It runs on the iPhone.
- The card at the bottom says "Tap the name on the label". A tap on a text puts it on the card as the name. A second tap adds a second line of the name. Each part has a remove button when the name has two or more parts, and "Clear" removes the name. "Use This Name" gives the name to the edit screen. The name limit is four parts.
- Maru cleans the text: it removes trademark signs and footnote marks, it makes a space from a dot between two parts ("D3·K2" becomes "D3 K2"), and it makes one space from each run of spaces and line breaks. A removed sign never joins two words. A text in capitals only becomes readable, for example "VITAMIN D3" becomes "Vitamin D3". Short codes such as "B12", "CoQ10", "5-HTP", and "NAC" keep their form. A text with a lowercase letter keeps its letters.
- When the text that the camera saw has exactly one form word, the form row offers it, for example "Use Softgel". The form changes only after a tap. "Softgel capsules" counts as a softgel. Maru has no gummy form, so "gummies" gives no proposal.
- No photo is stored. Only the name that the user chose and the form words go to the edit screen. Nothing goes to the network or to a log.
- The camera permission comes with the first tap on "Scan Label" (spec 2.2). A user who refuses gets no second message. When the camera is off for Maru at a later tap, an alert has one sentence and a button to the Settings app. A device with no scanner support does not show the row.
- The row shows only for a new item and for a replacement product. The edit screen of a stored item does not have it.
- The amount is not part of the scan in this version. A second tap target on the card makes each tap ambiguous: it can mean "more of the name" or "the amount". A strength on a label is also not the amount that the user takes (spec 2.1). The user types the amount.
- The scanner is a kept wrapper (D026): VisionKit has no SwiftUI view for the live scanner. The wrapper holds the system view controller and adds no custom drawing.

Name suggestions:

- Two text files in the app hold the names: 941 supplement names and 789 medicine names. Some have aliases for the search. They come from general knowledge of common labels. They are not a copy of a database. Each list is in the order of how common a name is.
- The medicine list holds generic names of common prescription and over-the-counter medicines, and well-known brand names. This is an owner decision: everything that a user can need must be there, and a suggestion is only a suggestion. The lists are a typing aid. They are not medical information, and they hold no strength, no dose, and no use of a medicine.
- The lists favor the names of the United States. They also have the common names of the United Kingdom, Canada, and Australia, for example "Paracetamol" and "Salbutamol".
- An alias is only another spelling or a clear abbreviation of the same name, for example "Vit D" for "Vitamin D" or "HCTZ" for "Hydrochlorothiazide". Each other name is its own entry: a brand, a second name of the same substance, a regional spelling, a salt, and a formulation. So a tap never changes one product, one formulation, or one substance into another. "Effexor" and "Effexor XR" are two entries.
- The lists hold names of products and substances. They hold no entry that is a strength, a use, or a category, such as "Low-Dose Aspirin", "Laxative", or "Joint Support".
- The search ignores case, accents, spaces, hyphens, and dots. It starts at two characters. The order is: a name of the user's own items, a match at the start of a name, a match at the start of a word, a match in a word. An alias counts one rank lower than a name, and only from the start of a word. In one rank, the names of the type on the screen come first: medicine names when the type is "Medication", supplement names when it is "Supplement". The type only orders the rows. A tap never changes the type.
- Up to four rows show under the name field while the field has the focus. A tap fills the name and closes the keyboard. The rows come and go with the layout motion (D030). This is the form of Mail and Reminders: proposals in the list, under the field. A keyboard toolbar with chips cuts long names and does not follow the largest text sizes. `.searchable` changes the look of the form.
- The lists load when the edit screen opens, off the main thread, and never at launch (spec 9). A search of the names takes about 1.5 ms in a debug build on the Mac.

Rejected:

- A barcode lookup on the network. Each lookup tells a server which product the user has. That breaks "no network requests by itself" and spec 10.
- A cloud vision model. The photo of a label leaves the iPhone, and Maru then needs a server, a consent screen, and a new privacy label.
- The on-device language model, for now. Only a part of the iPhones has it, and it can return a value that is not on the label. The tap flow works on every iPhone that Maru supports. The study keeps it as the second step.
- Only supplement names in the list. This was the first plan, because a wrong medicine suggestion looked like a safety risk. The owner decided to include medicine names.
- A check for an item with the same name after a scan (T05). Not in this version. A name of the user's own items shows first in the suggestions.

Tests (D016): two new tests in `MaruCore`. One for the cleaning of label text and the form proposal, one for the search order and its edge cases.

Not verified: no build ran on a Mac of the maintainer, and nobody saw the screens. The scan needs a check on a real iPhone with real bottles.

## D039 · 2026-10-11 · More follow-ups, and "Until Recorded" with a stated limit

Owner decision, with agent detail. Two studies of user feedback found one top wish: a reminder that comes again until the user confirms (`docs/research/evidence.md`, sections 1 and 7). The owner: users ask for this, so Maru must have it. The user chooses how many times, and can choose "until I confirm". The owner left the time between reminders to the agent. This replaces the one follow-up of D021 and the "Remind Again" row of D032. It changes spec 4.

The setting:

- "Remind Again" has two menu rows in one section. The first row is the number: "Off", "1 Time", "2 Times", "3 Times", "5 Times", or "Until Recorded". The second row, "Every", is the time between reminders: 5, 10, 15, or 30 minutes, or 1 hour. It shows only when the number is not "Off".
- The setting is off by default (spec 4). When the user turns it on, the time starts at 30 minutes. That is the middle delay of D021 and the delay of the follow-up of Apple Health.
- An install from before keeps its behavior. Its stored delay is the time between reminders, and a stored value with no number means "1 Time". So "After 30 min" becomes "1 Time" and "30 min". The new key is `reminders.followUpCount` in `UserDefaults.standard` (D014). "Off" removes both keys.
- Each change of the setting, "Off" too, keeps one time: the time at which the engine confirmed the removal of the old follow-ups. The setting and this time are one value under one key, `reminders.followUp.v2`, so one write changes both, and a stop of the app cannot leave a new setting with an old time. It holds no health data.
- The footer of "Until Recorded" states the limit and the last time: "Maru reminds you up to 12 times for each dose, until 1:00 AM at the latest." The time uses the time format of the device. The other choices keep "Only for items that you did not record."

The schedule rule:

- The first follow-up comes one interval after the dose time. Each next one comes one interval after the one before.
- A follow-up names only the items of that time with no record, as before (D029). A record, a skip, an archive, a delete, or an edit changes or removes the pending follow-ups at the next run of the engine, and the run removes a delivered follow-up with old text.
- A follow-up reminds for an item only before 01:00 of the day after the dose, and before the next dose time of the same item. This rule applies to every number, not only to "Until Recorded". So a dose at 23:30 with 30 minutes gets follow-ups at 00:00 and 00:30.
- 01:00 and not 03:00: a dose late in the evening gets follow-ups, and a dose at bedtime does not get them all night. The owner agreed to follow-ups after midnight if the change is small and does not hurt other users. For any dose, the change adds at most one hour of follow-ups after midnight, inside the same limit.
- Until 01:00, the "Taken" action of a follow-up of the day before records that dose (D034). The follow-up carries its plan date, its item, and its schedule version, so the date is not a guess. After 01:00 the action records nothing. A tap on such a follow-up opens the confirmation, with the dose of the day before as a candidate (spec 8.3). Today still shows only the doses of today (D019). The record shows in the history.
- When the items of one time stop at different moments, a later follow-up names only the items that it still reminds for.
- Each follow-up of a time with exactly one item has the "Taken" action with the identity check of D034.
- A plan of every other day gets follow-ups only on its due days, because a day with no dose has no occurrence (D036). An as-needed item has no time, so it gets none.
- The first follow-up keeps the identifier of D021. A later one adds its number. All follow-ups of one dose time have one thread identifier, so Notification Center shows them as one group.

"Until Recorded" and its limit:

- iOS has no local notification that starts at a later time and repeats until the app stops it. A repeating time interval trigger counts from the time of the add. The app does not run in the background (spec 8.1). So "Until Recorded" is dated requests: at most 12 for each dose time.
- 12 comes from the system limit. iOS keeps at most 64 pending requests for one app. Four dose times of one day with 12 follow-ups each use 48 requests. With 4 series requests and a reserve of 2, the total is 54 of 64. So a plan with up to four times gets the full number for every dose of the next 24 hours, and 10 requests stay free for later doses or a plan of every other day. With 12, the reminders last 1 hour at 5 minutes, 2 hours at 10 minutes, and 6 hours at 30 minutes.
- Each open of Maru and each record sets the follow-ups again, as before. The "Taken" action also does this.
- The limit is for each dose, also across a change of the setting. A dose before the last change gets the worst case: one follow-up came for each 5 minutes from the dose time to the change, at most 12. The setting of now gets only the rest, after the change. A dose after the change gets the setting of now.
- After a change, the engine removes every old follow-up first. An old one can come until the system confirms the removal, so the time of the change is the time after that confirmation. Until then, the plan sets no follow-up. A run that stops before the confirmation leaves the change open for the next run.
- Example: a dose at 08:00 gets 12 at 5 minutes until 09:00. A change to 30 minutes, confirmed at 08:31, adds 6, from 09:00 to 11:30. A change confirmed after 09:00 adds none.
- Accepted: a dose before a change can get fewer follow-ups than the setting says, because the plan does not know which old follow-ups came. It never gets more than 12. A change of the setting during a dose is rare.
- The rolling split of the room can add a future request, remove it, and add it again at later runs. This follows the split rule below, and it is accepted.
- Maru does not claim reminders with no end. The settings text states the number.

The budget:

- The series requests keep their budget of 48 (spec 8.4, D036). The follow-ups no longer have a fixed 16. They get the system limit minus a reserve of 2 and minus the series requests of the plan: 64 - 2 - 3 = 59 for a plan with three daily times, and 14 for a plan that uses all 48.
- The reserve is for the test notification of Settings, and for one new series request that the engine adds before it removes the old one.
- The follow-ups never take the room of a first reminder. The plan computes the room from the series requests that it wants. The engine checks the pending requests again before each add. When a save needs more room, the series engine removes the latest follow-ups first, as before.
- The split is fair. The dose times whose next follow-up comes in the same 24 hours share the room. Each gets one follow-up in turn, the nearest first, then each gets one more. Then the dose times of the next 24 hours get the room that is left. So one dose time never takes the room of the others, and the nearest doses come first.
- A dose time can get fewer follow-ups than the setting says when the plan has many times. The footer says "up to". The Reminder state in the item detail is the state of the first reminder only, and it stays true, because a follow-up never takes the room of a first reminder.

Rejected:

- An interval of 1 minute. It reads as an alarm that the user can not stop, and 12 requests then cover only 12 minutes.
- An alarm through AlarmKit, for now. It is a different product: a full-screen alarm with its own permission. Maru stays a quiet reminder (spec 4).
- A claim of reminders with no end. A fixed number that the page states is true. "Until Recorded" with no stated limit is not.
- A repeating time interval trigger. It can not start at a dose time in the future, and it continues after a record until the app runs.
- One limit for all follow-ups of the fixed 16. Three dose times with 12 follow-ups each need 36.
- Critical Alerts stay out (D021). Time-sensitive reminders wait for the Apple Developer Program (D034).

What the Apple documentation says, read on 2026-10-11:

- The limit of 64 is on the page of the old API: "the system keeps the soonest-firing 64 notifications (with automatically rescheduled notifications counting as a single notification) and discards the rest" ([`UILocalNotification`](https://developer.apple.com/documentation/uikit/uilocalnotification)). The pages of `UNUserNotificationCenter` state no number. Maru keeps 64 as the limit and stays 2 below it.
- A repeating time interval trigger needs 60 seconds or more, and the app must remove it to stop it ([`init(timeInterval:repeats:)`](https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger/init(timeinterval:repeats:))).
- Notifications with the same thread identifier show as one group ([`threadIdentifier`](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent/threadidentifier)).
- The default level, `active`, does not pass a Focus or the scheduled summary. Only `timeSensitive` does, and the user can turn that off ([`active`](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/active), [`timeSensitive`](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/timesensitive)). So with a Focus or the summary on, the follow-ups can come late and together. Spec 8.1 still forbids a promise of delivery.
- The system picks the notification that the summary features by its [`relevanceScore`](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent/relevancescore). Maru does not set it.

Tests (D016): two new tests. The limit of a dose across a change of the interval near the limit, and the "Taken" action of a follow-up after midnight.

Not verified: no check on a real iPhone yet. Open points are the group in Notification Center, the behavior of many requests at 5 minutes, the summary and a Focus, and the "Taken" action of a follow-up after midnight.

## D040 · 2026-10-11 · Export of records, and backup and restore (passphrase part changed by D046)

Owner decision, with agent detail. The feedback studies found that Maru had no export, no backup, and no sync, and that a user who leaves another app asks first if the history can come too (`docs/research/evidence.md`, theme 11). The owner: do these, simple, minimal, and in the style of Maru. It changes spec 7.3, T38, and T39. `docs/export-format.md` has both file formats.

Owner:

- "Export Records": a file that a person can read in Numbers or Excel.
- "Back Up" and "Restore": a full copy that Maru can read again, for a new iPhone or a new install.
- A restore replaces the data. It never merges two data sets in this version.
- No iCloud sync in this change. It needs the Apple Developer Program (D007) and a design of its own.

Agent detail, the record export:

- A CSV file with one line for each dose and the state that is valid now: date, planned time, item, type, amount, state, time taken, and time zone. An action that the user took back is not a line of its own.
- The lines are the doses of History (D019), and every recorded dose of today or a later date. A dose in a fixed time zone, or a dose of a stay in another zone, can have a date after the date of the iPhone. So the file has every record, and it never disagrees with the History page.
- UTF-8 with a byte order mark, because Excel reads a CSV file without the mark in a local encoding. Numbers reads both.
- The words of the file are fixed English text, so a file reads the same on every iPhone.
- No choice of a range. The file has all records. A range is one more control for a file that stays small.
- A field that starts with `=`, `+`, `-`, `@`, a tab, or a carriage return gets an apostrophe in front (OWASP, CSV injection). A spreadsheet app can run such a text as a formula. The apostrophe makes it plain text. The stored name and amount do not change. `docs/export-format.md` says so.

Agent detail, the backup:

- One SQLite database file with the extension `.marubackup`. `VACUUM INTO` makes a consistent copy while the app writes. A plain copy of the database file of a live WAL database can miss commits.
- The file header marks the file: an application ID, and the format version 1. One more table holds three settings: the app color, the names in reminders, and "Remind Again".
- SQLite, and not JSON: the restore then uses the migrations and the load checks that the store already has. A JSON document needs a second reader and a second writer for every table, and each can differ from the store.

Agent detail, the restore:

1. The user picks a file. Maru copies it to the protected directory of the database, under a temporary name.
2. Maru checks the application ID and the format version. A file with a migration that this version does not know is refused as "newer".
3. Maru does not trust the schema of the file. It builds a new database with its own schema, at the migration level of the backup, and copies each row into it under every constraint.
4. Maru applies the later migrations to this new database, then reads every item, schedule, occurrence, and record through the checks of a normal load, and runs the integrity check and the foreign key check of SQLite.
5. Until here, the database of the app did not change. A failure removes the temporary files and shows a plain message.
6. One alert asks: "Replace All Data?". It says that the backup replaces every item and record on this iPhone.
7. The copy: the SQLite online backup copies the new database into the open database of the app, in one write transaction. No file changes its name, and the store stays open. A stop of the app or an error before the commit rolls the transaction back, so the old data stays complete. The next open removes the temporary files.
8. The first version renamed the files. A review found two paths that lost data or broke the open store: a failed rename back after a failed flush, and a stop between the two file names. The online backup has no such path.
9. After the copy, the model forgets what it kept about the old data, and Today shows no rows. Then the settings of the backup apply, the settings sheet closes, and every page reads again. A read or a record that started before the copy changes nothing in the model when it ends, because its IDs can belong to the old data. One run of the notification queue sets the reminders of the restored plans and removes the old ones. This run can ask for the notification permission, because the user confirmed plans with reminders (spec 2.2). Without this, a new iPhone gets no reminder until the first save.
10. No record of the old data goes into the restored data. A backup can have the same IDs as the data on the iPhone, so a check in the model after the commit is too late. Two guards:
    - While the restore runs, the settings sheet stays open (no "Done", no swipe), and Today, the history, and the "Taken" action of a reminder record nothing.
    - The store has a generation of its data, 0 at the open. Only the restore changes it: it raises it by one in its write transaction. Every write of the store passes the generation that the model read with, and one helper compares it in the same write transaction, before any change. The restore and the writes run on the same writer, so a write with the old generation is refused, writes nothing, and the pages read again. This covers every record, an item save or replacement, an archive and a restore from the archive, a delete, reminders on or off, and the generation run of the occurrences.
11. The flush to the storage medium runs after the commit. When it fails, the data is replaced all the same. The restore is then a success for the model: it forgets the old data, takes the new generation, reads again, and sets the reminders. Settings stays open and says "Restored", and that Maru could not confirm the save. Only an error before the commit says that the data did not change.

- Spec 7.3 forbids a clear and a rebuild of the database to recover from an error. That rule stays. A restore that the user asks for and confirms is a different thing, as the delete of an item is (D033). Spec 7.3 now says so.
- Spec 7.3 said that an import must not turn on its reminders before a check, so that no reminder comes two times. A restore replaces all data, so one iPhone never has two copies. Two iPhones with the same data both remind. That is the choice of the user.

Encryption:

- The backup and the export are not encrypted in this version. The footer of the section says so, and `PRIVACY.md` says so.
- A backup with a passphrase needs a key derivation from the passphrase, a file format with a salt and an authentication tag, a passphrase screen, and a wrong-passphrase path. CryptoKit has no key derivation for a passphrase. That work is a change of its own, and a mistake in it loses a backup. It is the next step, in milestone B.
- The iPhone backup of iOS, in iCloud or on a computer, can already include the data of Maru (`PRIVACY.md`). For most users it is the way to a new iPhone. The file backup is for a user who starts a new iPhone with no transfer, or who wants a copy in a place of their choice.

The screens:

- "Your Data" is a section of Settings, before "Send Feedback". Export: 2 taps to the share sheet, from Today. Backup: 2 taps. Restore: 2 taps to the file picker, 1 tap on the file, and 1 tap on "Replace".
- The share sheet is `UIActivityViewController` in a system sheet. `ShareLink` needs the file before the tap, and it gives no sign when the sheet closes. Maru makes the file after the tap and removes it when the sheet closes. This is the one use of the UIKit share sheet (D026).
- The file picker lets the user pick every file, so a backup with a changed name still restores. The check refuses each other file.
- The files wait in a temporary folder with complete file protection. The folder has one file at most. The sheet closes when the user shares the file or closes it, and then the file goes. A file that stays after a stop of the app goes at the next launch.

Not done, and why:

- A restore from the storage problem page. That page shows when the database does not open, and a restore there needs a design that keeps the damaged file (spec 7.3).
- A merge of a backup with the data on the iPhone, and an import from another app.
- An automatic backup on a schedule.
- A stop of the app right after the copy and before the settings apply keeps the old settings with the restored data. The window is a few milliseconds, and a setting is easy to set again. A safe order needs the settings in the database (D014).

Tests (D016): four new tests. A backup then a restore on another directory gives the same data and replaces what was there. A newer, damaged, or inconsistent backup is refused and the data stays. A record and an archive with the generation from before a restore are refused and change nothing. A name with a comma, a quotation mark, and a line break stays one CSV field, and a text that starts like a formula gets an apostrophe.

## D041 · 2026-10-11 · History graph (scroll of the timeline to a day replaced by D054)

Owner decision, with agent detail. It brings the passive history heatmap of D006 forward from milestone B. It changes spec 3 P05.

Owner:

- The History page gets a graph of squares at the top, in the style of the GitHub contribution graph. The timeline of D032 stays under it.
- Three levels of color, by the share of the planned doses of a day that are taken.
- The graph grows with use. It starts at 13 weeks. A one-week step and a step of a few weeks are too small, so they are gone.
- No title and no count on the card. A title such as "Last 3 Weeks" says that Maru did not keep the older days, but Maru keeps every day from the first one.
- No black border on the selected day. The selection uses the most minimal form in the style of the app.
- Motion stays restrained and the same as on the other pages (D030). Where no motion is needed, there is none.

Agent detail:

- One square for each day, with a corner of 22% of the side. One column is one week, and the rows are the weekdays in the first weekday order of the user's calendar. Time runs from left to right, so today is at the right end of the filled part.
- The steps: 13 weeks from the week of the first day, 26 weeks when 13 are full, and 52 weeks, as two bands of 26 with the older band above, when 26 are full. The graph takes the next step on the first day of a week that does not fit. After 52 weeks it shows the last 52 weeks and moves one column each week. The older days stay in the timeline. The first day is the first schedule version or the first record, as for the timeline.
- The graph fills the width of the card. The gap is a fixed share of the side, 0.19 at 13 columns and 0.3 at 26, so the squares keep their shape on each screen width.
- The levels: "all" when every planned dose is taken, "most" when more than half are taken, and "some" for half or less. These are the tint at 100%, 60%, and 30% over the card. A skipped dose is not taken. An as-needed dose does not count. Half counts as "some", so one of two doses is not "most".
- A planned day with nothing taken is a quiet neutral (the tertiary system fill). A day with nothing planned, for example an off day of an every-other-day item, is a fainter neutral (the quaternary system fill), so it does not look like a miss. A day that is not here yet is a faint outline. A day before the first day has no square. So a new user sees calm, even outlines with the first squares filled.
- Today has no mark. It is the last filled square, so its place is clear, and a second ring would compete with the selection ring.
- The labels: short month names above the column where a month starts, in the secondary color. A label that would touch another one does not show. "M W F" at the left only at 13 weeks, and not at the accessibility text sizes. No legend, no count, and no sentence.
- Selection: a thin ring in the tint, with a gap of 1 point, and a small date label in the place of the month labels over the selected column, for example "Tue, Aug 18". No dark border, no shadow, no magnifier, and no motion. A light selection haptic comes when the selected day changes.
- A touch or a drag selects the nearest day, so the finger does not need to hit a square. A day that is not here yet gives today. A tap on the selected day clears the selection.
- At the end of the touch the timeline scrolls so that the section of the selected day is first under the graph. It loads older pages until it has that day. A day with no rows gives the nearest older day with rows. A clear scrolls back to today. On iOS 18 and later, a scroll of the timeline by hand clears the selection. iOS 17 has no scroll phase, so there the selection stays until a tap.
- The graph stays above the timeline and does not scroll with it. A drag inside a scrolling list competes with the scroll of the list, and the results differ by iOS version. Out of the list, the drag and the scroll never compete for one touch. The timeline also scrolls under a graph that stays on the display, as the list of days under the month in Calendar. The cost is the height of the card: 238 points at 13 weeks and 272 points at 52 weeks on a screen of 402 points.
- The data: one read for the range of 52 weeks. One query reads every stored planned dose of the range with its state. `History.counts` decides which doses belong to a day with the same function as the timeline (D019, D032, D036), so the graph and the timeline cannot disagree. The read runs when History opens, off the main thread, never at launch (spec 9). It takes about 27 ms for 3,640 doses in a debug build on the Mac. A commit, a return to the app, and a delete of an item read it again. No schema change.
- The page shows its first content when the timeline and the graph are read, so the graph does not push the timeline down.
- VoiceOver reads the graph as one element. The value is a summary, for example "Since August 10. Days with all taken: 40. Most: 3. Some: 2. None: 1.", or the selected day with "2 of 3 taken". Swipe up or down moves the selected day, and the timeline follows.
- Kept custom control (D026): SwiftUI has no heat map. One `Canvas` draws the squares and the labels, and one drag gesture selects. Swift Charts can draw squares with rectangle marks, but it gives no ring with a gap for the selection, and its labels follow the axes, not the start of a month.

Rejected:

- Round dots and large circles. They read as a list of points, and the owner chose squares.
- A calendar of large cells, and steps of one week or of a few weeks with weeks as rows. The owner found them too small, and they need a turn from rows to columns.
- One strip for each item. It shows which item is missed and makes the page a report card.
- A title with a duration, or with month names. A duration says that older days are gone.
- A count of days. A count can drop after a correction, and the owner asked for none.
- A streak, or any count of days in a row (D006, D021).
- A dark border on the selected day, a shadow, a magnifier bubble, and a band behind the selected week.
- A tint ring on today. It competes with the selection ring.

Tests (D016): one new test, for the day counts with an every-other-day item and a skipped dose.

Not verified: no build of the app on this Mac and no look on a display. CI builds the app. The levels in dark mode, the drag, the haptic, and VoiceOver need a check on a real iPhone.

## D045 · 2026-10-11 · Lean agent work and the follow-up end after midnight

Maintainer decisions.

- Agents work in a token-efficient way. The rules are in `docs/process.md`, "Token budget for agents". Fewer subagents, short briefs, and a model review only for changes that can affect records or reminders.
- Follow-ups past midnight end at 01:00 at the latest (D039). The maintainer left the choice to the agent. The reason: a bedtime dose with no record must not ring for most of the night.

## D044 · 2026-10-11 · Today rows show the time

Owner decision: "Each Today row shows the name and the amount. If the item has a reminder, also show its set time, on the second line, as small gray text." The section headers stay words such as "Morning", not clock times (D011).

This replaces two points in part: the recorded time of D011 moves back to the row, and a recorded row of D032 B differs from an open row by the circle and the time.

- The second line of a row has the amount, then the time, in the list form of the user's language: "2 capsules, 8:00 AM". With no amount, it has only the time: "8:00 AM". The time follows the 12 or 24 hour setting of the user.
- An open row shows the time that the user set. A taken row shows the time of the intake: "2 capsules, Taken at 8:07 AM", the words of the correction dialog and the as-needed doses. A skipped row shows "2 capsules, Skipped".
- A medication that keeps another time zone (D019, spec 8.5) shows its set time with the city, as the edit screen does: "9:00 AM Shanghai time".
- An item with its reminders off still shows its set time, because the time puts the row in its part of the day. "Reminders off" stays under it (T07).
- As-needed rows do not change. They have no set time, and each dose of today already shows its time under the item.
- VoiceOver reads the name and the second line as one label: "Vitamin D, 2 capsules, 8:00 AM".
- One shared time format, `Date.FormatStyle.rowTime(in:)`, replaces the four copies in Today, the as-needed doses, the reminder choice, and History.

Not verified: no build ran on a Mac of the maintainer, and nobody saw the rows on a display.

## D042 · 2026-10-11 · Scan Label word choice and edit (form proposal changed by D043)

Owner feedback after a test of "Scan Label" on the iPhone. The scanner returns a whole line or block for one tap, so the name came with other words: the strength, "Dietary Supplement", and the count. The owner also wanted to change the name on the scan screen, so that the scan is not a one-way step. This replaces the card of D038 after the first tap: the large name and the remove buttons for each part. The rest of D038 stays.

- The scan reads only the name in this version. The card before the first tap says "Tap the name on the label" and "Maru reads only the name."
- After a tap, the card shows each word of the text as a button, in reading order. A second tapped text adds its words after the first words, in the order of the taps. The limit of four texts stays.
- The words that look like the name are chosen at the start. The rule is in `LabelText.words(in:)` in `MaruCore`, with the stock phrases in one list:
  - A number with a unit or a count is not chosen: "1000 IU", "5 mg", "90ct", "50 Billion CFU".
  - A stock phrase is not chosen: "Dietary Supplement", "Supplement", "Capsules", "Softgels", "Tablets", "Gummies", "Serving", "Supports", "Count", "Ct", "Net", "Value", "Pack", "Bottle", "Formula", "Advanced", "High Potency", "Extra Strength", and a few more.
  - A number with no unit is chosen only after a chosen word and when no unit, count, or stock phrase follows it. So "Omega 3" keeps its "3". "Magnesium 400" also keeps "400", and the user removes it with one tap.
  - A sign such as "+" is chosen only between two chosen words, as in "D3 + K2".
  - Each other word is chosen.
- A tap on a word adds it to the name or removes it. A word is a system toggle in the button style (`.toggleStyle(.button)`, `.bordered`). A chosen word shows the on state of the system, in the tint, and has the selected trait for VoiceOver.
- Under the words, a text field holds the name. The edit rule: the field shows the chosen words. Typing changes only the field. A tap on a word, or on a new text on the label, sets the field to the chosen words again. "Clear" empties the words and the field. "Use This Name" gives the field text to the edit screen, and it is off while the field is empty.
- The cleaning of D038 applies to the chosen words as one text: signs, capitals, and short codes. The buttons show the words as the label prints them. Typed text stays as the user typed it.
- The words wrap in rows. SwiftUI has no wrapping layout for iOS 17, so a small `Layout` in `LabelScanView.swift` places the system buttons. It draws nothing (D026).
- Motion: the card grows with the layout motion when a text is added. A word changes with the state motion (D030).
- The form proposal of D038 does not change. It uses all the text that the camera saw.

Tests (D016): one new test in `MaruCore` for the choice of words. The old part of the cleaning test for the name from two texts is gone with its function.

Not verified: no app build on a Mac of the maintainer. CI builds the app. Nobody saw the card. The default choice needs a check on a real iPhone with real bottles.

## D043 · 2026-10-12 · Smart completion for supplements

Owner decision, with agent detail. It changes spec 2.1 and 3 P03 in part.

Owner: "Only for supplements we give candidates. That is the safest. This is not medical advice, it is smart completion, a different concept. We never lock anything. The user keeps the choice." After the user enters or picks a supplement name, the form changes to the usual form of that supplement, and the user can change it. The amount, the reminder, and the note each show candidates.

Rules:

- Supplements only. When the type is "Medication", or the name is in the medicine list, the screen shows no form, amount, time, or note candidates. A change of the type to "Medication" removes the candidates at once. The values in the draft stay.
- The name must be a supplement name of the built-in list or one of its aliases, in full. The match ignores case, accents, spaces, hyphens, and dots, as the name suggestions do (D038). A longer name, for example a brand with a supplement name in it, gets no candidates. So "Kids Zinc Drops" never gets the candidates of "Zinc".
- The candidates follow the name when the name field loses the focus: after a tap on a name suggestion, after "Use This Name" in the scan, or when the user leaves the field. So the form does not change at each key press.
- Form: the app sets the usual form only while the user did not choose a form on this screen. A choice in the form menu, or a tap on a form proposal, counts as a choice. A stored item, a replacement product, and a kept draft start with a chosen form. After a choice, a different usual form shows as a one-tap proposal under the form menu, for example "Use Softgel". The app never changes a form that the user picked.
- The form on a scanned label follows the same rule, and it comes before the usual form, because it is the form of this product. This changes D038: a scanned form now sets the form of a supplement while the user did not choose one. For a medication the scanned form stays a one-tap proposal, as in D038.
- Amount, reminder time, and note: candidates only. Each is a small system button with the bordered style, under its field. Nothing fills until the user taps. The buttons stand in one row, or in a column when the row does not fit, for example at the large text sizes.
- An amount candidate fills the amount field. The amounts show while the field is blank or holds one of them. An amount that the user typed hides them.
- A time candidate has the slot word of Today: "Morning", "Noon", or "Evening". A tap adds a reminder time, as "Add a Time" does. The time is the earliest time in that part of the day that the user already confirmed for a supplement, else 8:00, 12:00, or 20:00. The time row shows the time, and the user can change it or remove it. A candidate hides when the draft has a time in its part of the day. The example time of spec 2.1 for the time wheel stays.
- A note candidate sets the note: "With food" and "On an empty stomach" are the presets of the note menu. Another text becomes "My own note" with that text. The note candidates show only while the note is "None".
- The footer under the note says "Suggestions come from common labels. Check your own label." It shows while a candidate shows.
- The edit screen of a stored item shows no candidates until the user changes the name.

Content:

- `App/Resources/SupplementCompletions.txt` holds 103 entries. One line per supplement: name, form, amounts, times, note, and source, separated by "|". Each name is in `SupplementNames.txt`, so its aliases match too.
- The values are common US label directions, two NIH Office of Dietary Supplements fact sheet points (vitamin D absorbs better with a meal that has fat, and calcium carbonate absorbs best with food), and one FDA label rule (psyllium with a full glass of water, 21 CFR 201.319). They come from general knowledge of common labels. They are not a copy of a database.
- A field stays empty when no convention is clear. Examples: no usual form for magnesium, biotin, B complex, or vitamin K2, because their forms differ by brand. No note for iron, because sources differ: it absorbs best on an empty stomach, but many people take it with food against stomach upset. Times only for melatonin, valerian, and magnesium, in the evening.
- The list loads with the name lists, when the edit screen opens, never at launch (spec 9). Nothing goes to the network.

Agent detail:

- `SmartCompletion` in `MaruCore` holds the candidates, the filter of the candidates that the draft already has, and the form rule. `NameIndex.completion(for:category:)` finds them. `DayPart` moves from the app to `MaruCore`, so the time rule is in the package.
- One test in `MaruCore` (D016): the match, the medication rule, the filter, the time rule, and the form rule.

Not verified: no app build ran on the Mac of the maintainer, and nobody saw the screen. The candidates need a check on a real iPhone.

## D046 · 2026-10-12 · Scope trim: no time zone question, no passphrase backup

Owner: "We do not handle the time zone. The widget is to be done. Show me the design first. The backup with a password is not needed. The one week on the real phone: OK, I already use it. TestFlight I will do later."

- The question after a time zone change (`docs/research/2026-10-11-apple-health-gap.md`, row 25) is dropped. Reminders keep the current behavior of spec §8.5.
- The backup with a passphrase is dropped from milestone B. This changes D040: the backup stays not encrypted. The user keeps the file in a safe place.
- The Home Screen widget stays. The owner sees a design before the build starts.
- The one week of daily use on the owner's iPhone started on 2026-10-12.
- TestFlight waits for the owner. The Apple Developer Program costs money, so it is a maintainer decision.

## D047 · 2026-10-12 · One reminder for each fire time, and no reminder for a dose that is recorded

Agent decision, after two owner requests. First bug: the reminder was set to 9:00, the owner recorded the dose at 8:45, and the 9:00 notification still came. Second request: two or more items at one clock time give one notification that names the open items. This changes the limit of spec 8.2 and the two notifications of D036. It adds amendment notes to spec 8.1 and 8.2.

The rule:

- A record before the fire time (taken or skipped) closes its dose. A closed dose is not named, and it does not remind. When every dose of a time is closed, that time has no notification today.
- A repeating request cannot skip one date. So a weekday that needs another text leaves the repeating requests. The other weekdays keep their weekly requests (weekday, hour, and minute). The weekday that left gets one dated request for each of its next two dates that still have a time to come, with the text of that date. A time of every day with a record gives six weekly requests, one dated request for today with the open items, and one for the same weekday next week.
- Every run compiles again: launch, return to the front, save, a record, and an undo. After the fire time passes, the plan has the one repeating request again. An undo before the time brings today back.
- A dated request with a closed member names only the open members. It carries their slot IDs (`openSlots`), so a tap and the "Taken" action find only the open doses. It has the "Taken" action when exactly one item is open (D034). The revision stays the revision of all members that are due on its date, so the tap resolver checks the identity as before (spec 8.3).
- A daily or weekly item and an every-other-day item at the same time give one notification on a day when both are due. Each weekday of the time that has such a date in the next 14 days gets dated requests, so no notification names an item on a day when it is not due (D036).
- Two items at one time in different time zone rules give one series when a named zone equals the device zone now and a version that follows the device has the same time. The merged series follows the device zone. This is the trade-off: when the device moves to another zone, the medication reminder moves with it. The owner dropped the time zone question (D046).
- Room: the plan keeps the plain requests of every time first, counted as if no dose were closed, so a record or an undo never changes which groups fit. The new requests use only the room that is left in the budget of 48. With no room, the time keeps its plain request, and the notification still comes. A record never removes the reminder of another plan.

Limits, to state in the settings text later:

- A weekday that left the repeating requests reminds on two dates. Then it stops until the app runs again. So with no run for seven days, the daily item loses that weekday. The review raised this limit, and the lead agent accepted it, because the app runs whenever the user records early.
- A daily item and an every-other-day item at the same time have dated requests for 14 days and no repeating request. With no run for 14 days, both stop. The record of the "Taken" action from a notification does not run the engine. The next launch or return does.
- A follow-up still has its own group for each zone rule. The follow-ups of the zones that D047 joins are not joined yet.

Agent detail:

- `ReminderPlan` gets `closed`. `LocalStore` reads it from the occurrence state in the same read as the plan.
- `ReminderSeries` gets `done` and the key `openSlots`. The plan function `rework` builds the weekly and dated requests of one time.
- The tap resolver gets the rule `dated` (every version that is due on the date), and a series of the device accepts the named zone that equals the device zone.
- The app runs the reminder engine, and then the follow-ups, after each record and each undo.
- One test in `MaruCore` (D016) covers the plan rule. The test of D036 changed: a daily and an every-other-day item at one time now give one request for each date.

Not verified: no app build ran on the Mac of the maintainer, and nobody saw a notification. It needs a check on a real iPhone.

## D048 · 2026-10-12 · Home Screen widgets: Today and Take Now (file protection level replaced by D066, widget name, header separator, and VoiceOver labels replaced by D068)

Owner decision on the design (D046), with agent detail. It adds two widgets, small and medium each. It follows spec 6 (Widgets), 7.2, 9, and 10. Spec 10 says a widget shows only non-sensitive content by default.

The owner design:

- Each dose is one capsule, tilted by 45 degrees like the app icon. Taken: filled with the app tint of D025, as a gradient. Not taken: light gray with a thin gray edge. A skipped dose looks like a dose that is not taken. The background is white in light mode and the system background in dark mode. No list rows.
- "Today" has no names and no buttons. Small: the slot word in the tint and its time, the number of open doses ("2 left"), and the capsules of the slot at the bottom right. When every dose is done: "All done" and the next time, "7 of 7", and filled capsules. Medium: "Today" and "4 of 7", then a column for each slot with its time and capsules. The slot of the clock has its title in the tint. A tap opens Today at the slot.
- "Take Now" shows only the current slot. Small: up to 2 doses as rows (capsule, name, amount). Medium: up to 4 as columns. A tap on a gray capsule records the dose. A taken dose shows a filled capsule and a gray name. The widget has no undo. Open doses come first when the slot has more doses than fit, and the header shows "+N" for the rest.

Where the database lives:

- The database moves from `Application Support/Database` to `Database` in the App Group container `group.com.imhangli.maru`. The widget extension cannot reach the container of the app. The group ID follows the bundle ID `com.imhangli.maru`. The extension has the ID `com.imhangli.maru.widgets`.
- The move runs once, in `LocalStore.adopt(from:into:)`, before the first open. It does nothing when the container has a database already, or when the earlier directory has none. It makes one consistent copy with `VACUUM INTO` under a temporary name, reads the copy with the integrity check and the foreign key check, sets the complete file protection, flushes it, and gives it the final name with an atomic rename that never replaces a file (the way `create` does). A stop before the rename leaves only temporary files, which the next open removes.
- The earlier files stay. The change deletes nothing and rebuilds nothing (spec 7.3). A failure of the move shows the storage problem page and never opens an empty database in the container, which would hide the data. A later change can remove the old copy when the maintainer has used the new build for a while. Until then the iPhone holds two copies of the data, both inside the app container with the same file protection. An earlier build that runs after this one reads the old copy and does not see new records.
- The widget never creates the database. It opens the container only when a database is there, so an empty database can not come before the move. Before the first launch of the app after the update, the widgets ask the user to open Maru.
- A build with no App Group entitlement, such as the CI build with no signing, keeps the database in Application Support and has no widget data.
- The store waits up to 3 seconds for a lock (busy timeout), because two processes open the same database now. SQLite in WAL mode lets them read and write in turn. Risk: a process that the system suspends while it holds a database lock can be ended by the system (code 0xdead10cc). The store holds a lock only inside one transaction, so the risk is small. It needs a check on a device.
- The container has complete file protection (spec 10). A locked iPhone gives no data to the widget.

Where the record runs:

- `TakeDoseIntent` is compiled in the app and in the extension. It carries two IDs and no health data. The app adds the conformance to `ForegroundContinuableIntent` in `App/TakeDoseIntent+App.swift`. Apple's WidgetKit article says that the system then performs the intent in the app process. By default it runs in the extension process. The protocol is deprecated for `supportedModes`, but `supportedModes` does not say where the intent runs. The extension can not use the protocol, so only the app target has the conformance.
- The reason for the app process: the reminder engine and the follow-up engine must run after a record (D047), and spec 8.4 forbids two overlapping notification updates. Their settings and ledgers are in `UserDefaults.standard` of the app. The extension can not read them. A second engine in another process would need shared defaults and a lock across processes. In the app process there is one model and one queue.
- `AppModel.takeFromWidget` reads the dose again with `LocalStore.widgetTarget`: the same occurrence, the same schedule version, a date of today in its own zone, and no state. Then it records with `commitAndWait`, the transaction of the record circle, with the data generation check of D040 (`checkedWrite`), and the event revises the last event it read (T18). The source of the event is `app`. After the commit it waits for the reminder run of D047 before it returns, because the system can suspend the process after the intent returns. A dose that is taken already is a success with no new event.
- When the database is locked, the dose changed, the plan changed, the dose has a skip, or the commit fails, nothing is recorded and the widget shows no success. The intent throws the error of `needsToContinueInForegroundError`, and the system asks to open Maru. The capsule fills only when the timeline reads the committed record (spec 7.2).
- Not verified: where the system runs the intent when a widget button calls it. If the device runs it in the extension, the hook of the app is empty and the intent throws, so no record is written. Then the capsule does nothing. Fix: move the record into the extension with shared defaults and a lock across processes.

The data of the timelines:

- No snapshot file. The widgets read the database through `TodaySnapshot.load`, the same function as the app. A snapshot file would be a second copy of the names with its own protection, and it could disagree with the database. The load runs the generation of the occurrences of today, as the app does at a launch, so the widget has data also when the user did not open the app today. It is the same domain operation and it creates only rows that the app would create.
- One timeline has an entry for now and one at each change of the part of the day (11:00 and 17:00 by the rule of `DayPart`), and the next read is at the end of the day. So the current slot moves with no reload, and a locked iPhone at 11:00 does not blank the widget. The app asks WidgetKit to reload after each read of its own, and after a change of the tint. A record by a tap makes WidgetKit reload the timeline. When the read fails, the widget says "Open Maru to update." and tries again in 15 minutes.
- The current slot of "Take Now" is the slot of the clock, or the next one with doses, or the last one. It does not jump when its last dose is taken, so the user sees the capsule fill. "Today" small shows the first slot from the clock on that has an open dose, else the first earlier slot with an open dose.
- The tint comes from the App Group preferences. The app writes the color there at a launch and at a change (a copy of `display.appColor`). It is no health data.
- A tap on "Today" opens `maru://today/<slot>`. The app scrolls to the slot and opens it. A link before Today loads waits for the load.

Signing:

- App Groups work with a free personal team in Xcode for the maintainer's own devices. I could not confirm it from an Apple page: the capability table of Apple (supported capabilities, iOS) lists "App Groups" and my tool could not read the columns. A forum answer by Apple DTS says that personal teams are separate and that a group belongs to one team. So the maintainer's team `JBG4XL9NQK` should sign both targets. The first build on the iPhone proves it. The free team has a limit of new App IDs per week, and the extension needs one more. If Xcode refuses the group, the widgets wait for the Apple Developer Program (D007).
- The extension has the deployment target iOS 17, as the app.

Agent detail:

- Shared code is in `Shared/` and goes into both targets: the Today snapshot, its load function, the item tint, the slot title, the time format, the group values, and the intent. `Widget/` has the views.
- Copy is in `Widget/Localizable.xcstrings`, English only (D017).
- Privacy (spec 10): the widgets write no log. "Today" shows no name. "Take Now" shows names and amounts, so it is the user's choice to add it to the Home Screen. It shows nothing on a locked iPhone that the system has not drawn already.
- Review fixes. The widget never opens `LocalStore`: its `init` removes staged backup files and creates files. `LocalStore.readForWidget` opens the database read-only in one read transaction, and plans the occurrences in memory (it stores none). A tap on an occurrence that is not stored opens the app. A restore now rejects a missing or empty staged file and opens it read-only, so it can not copy an empty database over the data.
- The restore epoch is a counter in the file `restore-epoch` next to the database. A restore adds one at its start and one at its end, so an odd number means a restore runs. The widget reads it before and after its read, and it puts the number in each button. The intent compares it with the file before it records, and the in-process data generation check of D040 still runs in the record transaction. A restore that starts after the check changes the generation, so the record is refused. A restore that ended before the check changed the epoch, so the button is refused.
- The record transaction of the widget also requires the plan of now: an active item, a slot in the plan, and the planned schedule version (`requireCurrentPlan`). The occurrence row of an archived item or of a removed slot stays, so the version check alone was not enough.
- A tap on a dose that is taken already flushes again and waits for the reminder run before it reports success, because the first tap can have committed and failed to flush.
- Tests (D016): one new test, a restore with a missing staged file, and one for the move.

Not verified: no app build ran on the Mac of the maintainer, and nobody saw a widget. CI builds the app. Needs a check on a real iPhone: the signing, the move of an existing database, the tap on a capsule with the app closed and with the app open, the reminder and the follow-up that go after the tap, a locked iPhone, a change of the tint, and dark mode.

## D049 · 2026-10-12 · Simplify: remove unused code (`Item.imageReference` restored by D056)

The maintainer asked for this on 2026-10-12. Users see no change.

- Debug launch arguments: `-MaruTab`, `-MaruHistory`, `-MaruSettings`, `-MaruStorageError`, `-MaruSampleHistory`, and `-MaruSampleData one`, with their code. `-MaruTap`, `-MaruScenario`, `-MaruSampleData YES`, and `-MaruSampleRecords YES` stay.
- Model: `ProductVersion`, `ProductSource`, `ProductVersionID`, `ScheduleVersion.productVersionID`, and `Item.imageReference`. The tables and columns stay in the schema with no migration. Reads ignore them and writes leave them NULL.
- `TimeZoneRecord` protocol: it had one conformer. `DefaultsTimeZoneRecord` now lives in `MaruCore`.
- `AppStore`: one helper opens the store for both record transactions. The `history` and `historyCounts` forwarders are gone.
- Tests and helpers: `noTypeCarriesInventoryFields`, `DoseTests`, `writerSetting`, and `WidgetDay.hasOpenDose`.
- `LocalStore+Move.swift` is now `LocalStore+Adopt.swift`.

## D051 · 2026-10-12 · Release plan: full V1 scope, store name, six languages, analytics on by default (the notice outside the opt-in regions replaced by D078)

Maintainer decisions for the App Store release. The plan is in `docs/release-plan.md`. The research is in `docs/research/2026-10-12-store-name-and-languages.md`.

- Scope: the full milestones B and C. The first release has analytics, a supporter purchase, the optional photo, and six languages. This replaces the trimmed scope that the agent recommended.
- Store name: "Maru: Know What You Took". Subtitle: "Supplement & Pill Reminder". "Did I Take It?" is in the names of six or more apps.
- Languages: en, zh-Hans, ja, es, de, and ko. This replaces "English first" of D017 for the first public release. The China mainland storefront waits, because it needs an ICP filing.
- Analytics: on by default, with a one-time notice and a switch in Settings. In the EU, the EEA, the UK, and Switzerland, the user opts in first (GDPR and the ePrivacy rules). This changes spec §11.3. All other rules of spec §11 stay: no names, doses, intake times, or item IDs leave the device.
- Marketing: a landing page on an own domain. The maintainer buys the domain.

## D053 · 2026-10-12 · Optional supporter tips with StoreKit 2

The maintainer asked for an optional supporter purchase. Spec 14 C, spec 9, T35, and T48 apply. The agent made these decisions.

- Three consumable tips: `com.imhangli.maru.tip.small`, `.medium`, and `.large`. Settings has a "Support Maru" section with one button for each tip. The button shows `displayName` and `displayPrice` from StoreKit. Prices are set in App Store Connect and not in code.
- Nothing is locked. A tip is a consumable with no entitlement, so the app stores no purchase state and has no "Restore Purchases" button. A tip never reads or writes health data.
- `App/Support/SupportStore.swift` is the only code that imports StoreKit. `MaruCore` and `MaruDatabase` do not. The Settings view calls the store.
- The app starts `Transaction.updates` at launch in an unstructured task. The task waits for the system, so the launch does not wait (T35). The store loads the products only when the section shows.
- Every transaction is finished. A verified, not refunded transaction shows one line of thanks. A cancel shows nothing. A pending tip shows "waits for approval". A failure or an unverified transaction shows "did not go through". A refund shows nothing. In all cases the app stays as it is (T48).
- `purchase_result` (spec 11.5) is not sent. The app has no analytics client yet (spec 11.3). Add the event with the analytics client.
- `Config/Maru.storekit` has the three tips for local tests. `project.yml` defines the `Maru` scheme with this file in the Run action. The other scheme actions keep the default configurations.
- Copy is English only (D017). The new strings are not in the String Catalog yet. The sync is a known gap in `docs/status.md`.

Not verified: no app build ran on the Mac of the maintainer, and nobody bought a tip. CI builds the app. Needs a check in a simulator or on an iPhone with the StoreKit configuration: a buy, a cancel, a pending tip, a failure, a refund from the StoreKit transaction manager, and a tip that ends after a relaunch. App Store Connect needs the three products before a TestFlight build.

## D052 · 2026-10-12 · Product analytics: allowlist, region default, own sender (event fields extended by D077, notice outside the opt-in regions replaced by D078)

Agent decisions for the analytics part of D051. They follow spec §10 and §11. Spec §11.3 says "off by default". D051 replaces that with the region rule below.

- Transport: a minimal `URLSession` sender to the PostHog capture API (`POST {host}/batch`), in the new `MaruAnalytics` target. It is not the PostHog iOS SDK. The SDK has many automatic captures and integrations, and spec §11.4 asks to disable all of them and to audit the network traffic. A sender with no automatic capture needs no such audit, and it adds no dependency, so `docs/third-party-licenses.md` has no change. Each event has `$process_person_profile: false` and `$geoip_disable: true`.
- Allowlist: `AnalyticsEvent` in `MaruCore` holds the schema of spec §11.5. Its init rejects an unknown event, an unknown field, and a value outside the allowed values (T45). The app builds events with factories that take enums. A test sends each factory result through the checked init.
- Fields that the spec lists but the app does not send yet: `setup_step` has only `step = item_saved`, with no scan or timing field. `daily_usage_summary` has four flags: record, history, notification, widget. It has no "edit" flag. `feedback_entry` has no "sent" field, because the app cannot know if the user sent the form. `purchase_result` is in the schema, and no code sends it, because Maru has no purchase yet. Add a field in the change that first sends it.
- Region: `Locale.current.region`. The opt-in set is the EU member states, Iceland, Liechtenstein, Norway, the UK, Switzerland, six outermost regions of France, Åland, Gibraltar, Jersey, Guernsey, and the Isle of Man. A missing region gets the opt-in rule. The limit: the region setting is not the place of the user.
- Default "on" starts only after the one-time notice shows (after the first item save, when no sheet or alert is open). In an opt-in region the same notice asks, and the answer "Not Now" leaves it off. An explicit choice in Settings always wins.
- A build with an empty key (the default) has no switch, no notice, no client, and no network request. The key and the host come from the build settings `MARU_ANALYTICS_KEY` and `MARU_ANALYTICS_HOST`, through two Info.plist keys. The default host is the PostHog US cloud. Change it for an EU project.
- Daily summary: local flags in `UserDefaults`, one bit for each part and day. The summary of a day goes out on the next day that the app runs. A day with no flag has no summary. `day_index` counts from the first flag after analytics became active, not from the install.
- Off (T43): the client stops, the memory queue clears, the install ID goes, and the local flags go. A new ID is made at the next opt-in. The client cannot delete data on the server, because the spec forbids an admin key in the app. A deletion request needs the install ID, and the app does not show it yet. This is an open gap.
- Queue (T44): in memory only, at most 100 events, at most 3 days old, 20 events for each request, sent 5 seconds after the first event. After a failed request nothing is sent for 5 minutes. No timer wakes the device. A refused batch (4xx other than 408 and 429) is dropped.
- Open items for the maintainer: turn on "Discard client IP data" in the PostHog project. Choose the host region. Check the privacy label and the Privacy Manifest of the build. Review the opt-in list and the notice text. This change did not translate the new strings.

Not verified: the app build and the screens. CI builds the app. The send to a real PostHog project and a packet capture (T42) need a key and a device.

## D056 · 2026-10-12 · Optional item photo (place on the edit screen replaced by D073)

The maintainer asked for this on 2026-10-12. It covers spec §5.1, §5.2, and §10, and T29 to T32. It restores `Item.imageReference`, which D049 removed.

What the user sees:

- The add and edit screen has a section "Photo (Optional)" after the note. It has "Choose Photo" (the system `PhotosPicker`, which needs no permission), "Take Photo" (the system camera), a switch "Remove Background", and "Remove Photo". "Take Photo" shows only on an iPhone with a camera.
- The photo replaces the form icon on a Today row, on a My Items tile, on the item detail, and on the archived list. The form icon stays as the fallback. History rows keep the form icon.
- An item with no photo looks and works as before (T32).

How it works:

- Maru reads the chosen photo, scales it to at most 512 pixels on the longest side, and applies its rotation. The scale happens while Maru reads the file, so the full image is never decoded. Then Maru crops the middle square. The crop is JPEG. It is always the first result, so Save never waits for the background removal.
- The background removal uses `VNGenerateForegroundInstanceMaskRequest` (iOS 17, on device) and runs off the main actor at utility priority. It keeps the result only when Vision finds exactly one subject. With no subject or with many subjects it fails, and the crop stays (T29). Maru never picks one of many subjects. A cutout is PNG with alpha. The switch "Remove Background" lets the user keep the crop when the cutout looks wrong.
- The image has no metadata. The decoded image holds only pixels, and the encoder gets no properties, so EXIF data and the location do not reach the file. Maru never keeps the original image (T31).
- Stale results (T30): the photo state lives in the edit screen, and the background work is a SwiftUI task of that screen with the identity of the latest request. A new request, a Cancel, a Save, and a Discard cancel the task, and each step checks the cancel before it writes the state. The result never reaches a closed screen or another item. Nothing writes a file before Save.
- Save writes the new file first, and then the transaction stores the file name in `item.imageReference`. A failed transaction removes the new file. After the commit, Maru removes the old file. "Remove Photo" and a delete of the item remove the file after the commit. A restore removes every photo file that no restored item uses.
- A file name is a new UUID for each photo, and Maru never changes a file. So the name is the cache key, and an old image can not show for a new photo. A name with a path part is ignored.
- Lists draw the form icon first and read the photo off the main actor, as a 192 pixel image in an in-memory cache. The photo replaces the icon when the read ends. A missing file, or a read that fails on a locked iPhone, keeps the form icon. The startup path does not read a photo (spec §9).

Where it lives:

- The files are in `Photos/` in the App Group container, next to `Database/`. A build with no container uses Application Support. The folder and each file have complete file protection (spec §10).
- `Item.imageReference` is the file name. The column `imageReference` exists since the first migration, so there is no migration. An old row has NULL.
- The widgets show no photo. The widget snapshot carries the file name only for the app code that shares the type.

Backup (D040):

- The in-app backup holds the column with the file name and not the files. A restore on the same iPhone shows a photo only when its file is still there. A restore on another iPhone shows the form icon. This keeps the backup file as small as the database, and the user can choose the photo again.
- The iPhone backup, in iCloud or on a computer, includes the files as it includes the database. `PRIVACY.md` and `docs/export-format.md` say so. The record export (CSV) has no photo.
- The draft file of the edit screen does not hold a photo. After the app stops, the user chooses the photo again.

Not verified: no app build ran on the Mac of the maintainer, and nobody saw the screen. CI builds the app. The background removal, the camera, and the real size of a row need a check on a real iPhone. The Simulator may fail the background removal and then shows the crop. Check with a bottle on a table, with a bottle in a hand, and with two bottles, for T29. Check a missing file and a locked iPhone.

## D050 · 2026-10-12 · Plain slot header: no chevron, no opening highlight (folding removed by D057)

Maintainer decision after use on the device.

- The header of a finished part of the day has no chevron. A tap on the header still folds and opens the section. This replaces the chevron of D032.
- The title of the current part of the day stays in the text color when the app opens or returns. This removes the opening highlight of D020 and the attention motion of D030.

## D055 · 2026-10-12 · A part that the user opens stays open (folding removed by D057)

Maintainer decision after use on the device.

- A tap that opens a finished part of the day keeps it open. It stays open after a return to the app, after a later record, and on the next days, until a tap folds it again.
- A tap that folds a part removes the choice, so the part folds by itself again (D012, D028).
- The choice is a display setting in `UserDefaults`, not a record. A backup does not carry it.

## D054 · 2026-10-12 · History rows by item and logs by item and by day (empty slot replaced by D061)

Maintainer decision on 2026-10-12, from the pattern of the Finch app (concept "S2"). It replaces the long timeline on the main page of History (D032) and the scroll of the timeline to a day of the graph (D041).

- Under the graph, one section "Last 7 Days" in the grouped list. One row for each item that had a planned dose or a taken as-needed dose in the last 7 days. An archived item shows only when it had one.
- Row: the form icon in the item color, the name, the part of the day or "As Needed" on a second line, and at the trailing edge a strip of 7 small capsules. The oldest day is at the left and today is at the right.
- Capsule of a day: filled in the item color when every planned dose of that day is taken. The item color at 40% when some are taken. A hollow outline when planned doses exist and none is taken. An empty slot of the same width when nothing is planned. An as-needed item shows a filled capsule on a day with a taken dose, and an empty slot on other days.
- A planned dose of today that is not due yet, with no record, counts as nothing planned until its time. Reason: a miss that shows before the user can take the dose is wrong. A dose with a record counts at once, also before its time.
- A tap on a row pushes the log of the item: the rows of the timeline, with all corrections, only for that item. Newest first, grouped by day. Older days load as before, 30 days per load.
- A tap on a day of the graph pushes the log of that day: the rows of the timeline for that day, with all corrections. A push, not a sheet, so the time sheet of a correction does not open over another sheet. The selection ring stays until the log closes.
- Undone and replaced actions stay in both logs (D032). The main page no longer lists actions.
- A capsule that changes after a record uses the state motion (D030), which keeps its fade with Reduce Motion.
- VoiceOver reads the name, the second line, and a summary: "Taken on 5 of the last 7 days", or "All doses taken on 2 of 3 planned days" when the item has no plan on some days. The strip is hidden from VoiceOver. The graph keeps its adjustable element. Its default action opens the log of the selected day.

Agent detail:

- No new store read and no schema change. `History.week` (`MaruCore`) builds the strips from the days that the first page of the timeline reads. That page always holds the last 7 days.
- The alerts and the success haptic of a correction moved to one modifier. The page and each log use it, and only the one on top is active.
- A tap on a day no longer clears the selection. The selection clears when the log closes. The scroll phase rule for iOS 18 (D041) is gone.
- Test (D016): one, for the strip marks with a half-taken day, an as-needed dose, and a dose of today that is not due yet.

Not verified: no build of the app on this Mac and no look on a display. CI builds the app. The strip in dark mode and at the largest text sizes, the push from the graph, the alerts from a log, and VoiceOver need a check on a real iPhone.

## D057 · 2026-10-12 · Today never folds, and the item detail shows the week strip ("Record All" removed by D060, line under the strip replaced by D061)

Maintainer decision on 2026-10-12, after use on the device.

- Every part of the day on Today always shows its rows. A part folds never: not after a launch, not after a return to the app, not after the last record, and not by a tap on its header. This replaces the fold rules of D012, D028, D032, D050, and D055.
- The header of every part is the plain title. "Record All" stays on a part with two or more open rows (D021).
- The choice of D055 and its `UserDefaults` key are gone. The app does not read the old key, and a stale value does no harm.
- A tapped reminder still scrolls to its part (D028). The scroll was the only use of the focus that remains.
- In the item detail, the section "Last 7 Days" shows the strip of 7 capsules of D054 in place of the list of records. One view draws the strip in History and in the detail. `History.week` computes it, so the two cannot disagree. A line under the strip counts the days, for example "Taken on 5 of the last 7 days".
- The detail has no tap on the strip. The log of an item needs the History page state, and the detail does not hold it. The History tab has the item log.
- The store reads `recordedOccurrences` and `recordedAsNeededOccurrences` are gone, because only the old list used them.

Not verified: no build of the app on this Mac and no look on a display. CI builds the app. The strip in the detail at the largest text sizes and with VoiceOver need a check on a real iPhone.

## D058 · 2026-10-12 · Consistency pass across the app

The maintainer asked to unify the app: the same words, colors, states, and motion for the same thing on every page. The agent made the choices below inside that request. The maintainer can overrule any of them.

Words and states:

- Every alert title uses Title Case: "Not Saved", "Today Changed", "History Changed", "Not Changed", "Maru Couldn’t Save". The words of a state in a row stay in sentence case, for example "Not saved".
- Every empty or error page is a system `ContentUnavailableView` with a Title Case title, no period, an SF Symbol, and an optional one-sentence description. This includes Today, My Items, the archived list, the item detail, History and its logs, and the storage problem page.
- One word for one action in every dialog, menu, and swipe: "Taken", "Skip", "Undo", "Change Time…". The dialog of the record circle no longer says "Mark as Taken" or "Mark as Skipped". A skipped as-needed dose says "Skipped", as a skipped row of Today does.
- A footer is one short sentence. "Your Data" in Settings keeps two, because it must say that the files are not encrypted. The footers of "Share Usage Statistics", the test notification, "Send Feedback", and "Support Maru" are shorter. The footer of the statistics switch no longer says that turning it off clears the queue, so the sentence stays short. The switch still does it.
- A state shows in the text color with its symbol, never in gray (design principle 6): "Archived" and the reminders-off line in the item detail, "Reminders off", "Notifications off", the taken or skipped as-needed dose, and "Not Available" in the reminder choice sheet. A date with no record to make is a plain row with no button, so the system does not dim it.
- "Notifications off" replaces "Notifications are off". It has the pattern of "Reminders off" and the same color.
- The mark of an unsaved change in the banner is red, as every other unsaved mark.
- The editor section with the times and the repeat days is named "Plan", as in the item detail.
- The day of the graph selection, the title of the log of a day, and the day sections of the log of an item use one format: "Tue, Aug 18". Today and Yesterday keep their words only in the day sections of the log of an item.
- History rows show the item photo, with the form icon as the fallback, as every other page does.

Layout and size:

- The small sheets (the time wheel of a new or a changed time, the reminder choice list, and the share sheet) use the detents medium and large. The edit screen and the settings stay full sheets. One modifier, `smallSheet()`, holds the rule.
- The dose row of an as-needed item aligns with the name by the same icon column as the item row, at every text size, with no fixed 44 points.
- Card margin and card padding use `Tile.margin`. The second line of a list row has 2 points of spacing.

Code:

- The alert title and the message of a failed record are one helper, `FailureAlert`, for Today, the as-needed section, and History. `AsNeededFailure.Kind` is the same type as `TodayFailure.Kind`.
- Dead code is gone: the record symbol state "no record", the unused `day` of the history row, and the unused time zone of the as-needed item row.
- Every key of the String Catalog has a translator comment, and the keys that were missing (the tips section) are in it, before the translation into zh-Hans, ja, es, de, and ko.

Motion (a change of D030):

- Two new cases in `App/Motion.swift`: press (a scale to 0.98 and back, 0.12 seconds) and fill (a spring of 0.35 seconds with bounce 0.4, after the commit). With Reduce Motion the press shows at once and the fill is the fade of the state case.
- The record circle and the as-needed record button scale to 0.98 while pressed. The circle springs to its size when it fills after the commit, and never at the tap (spec §7.2). A tile of My Items scales to 0.98 while pressed.
- A number or a time that changes in place uses `contentTransition(.numericText())` with the state motion: the count of the banner, the time of a row, and the line under the week strip. With Reduce Motion the text cross-fades. This replaces the rule that text changes at once, and the rule of "no scale" for a tap.

Not verified: no build of the app on this Mac and no look on a display. CI builds the app. The press and fill motion, the dose row alignment at the largest text sizes, and the sheet heights need a check on a real iPhone.

## D059 · 2026-10-12 · Six languages in the String Catalogs

The maintainer asked for the six languages of D051. English stays the source. The agent made the choices below. A native speaker has not read the text yet.

- Languages: `zh-Hans`, `ja`, `es`, `de`, and `ko`, for every key of `App/Localizable.xcstrings`, `Widget/Localizable.xcstrings`, and `Packages/MaruKit/Sources/MaruNotifications/Resources/Localizable.xcstrings`. Each value has the state "translated". This replaces the "English only" notes of D017, D048, and D053. Spec §13.2 lists `zh-Hant` and `fr` too. D051 chose the six languages, so the first release has neither of them.
- Reminders: they were localizable already (`String(localized:bundle:locale:)` with the package catalog). They now have the five translations, so the notification title, body, action, and test text use the language of the user. The package has `defaultLocalization: "en"` and the resource folder, so `Package.swift` did not change.
- Info.plist: `App/InfoPlist.xcstrings` holds the camera permission text in six languages. The display name stays "Maru" in every language.
- Plurals: `ja`, `ko`, and `zh-Hans` have the category `other`. `de` and `es` have `one` and `other` for "changes not saved". The other counted keys read right for every number, so they have one form.
- Register: `ja` uses です and ます in sentences and plain words in labels. `ko` uses 해요체 in sentences. `de` and `es` use "du" and "tú". `zh-Hans` uses "你".
- Words: each language follows the words of Apple Health, Reminders, and Settings in that language. `ko` uses "미리 알림" for a reminder and "알림" for a notification. `de` uses "Erinnerung" and "Mitteilung". `es` uses "Ajustes". `zh-Hans` uses "存储" for "Save". `ko` uses "내역" for History, because "기록" is the word for a record.
- Medical safety: the text has no advice. "Taken", "Skipped", and "No record" keep their meaning. A follow-up reminder says that the dose is still to take, and a first reminder never says that it is not taken (D047).
- The tip is "赞赏" (zh-Hans), "チップ" (ja), "propina" (es), "Trinkgeld" (de), and "후원" (ko).
- The new key "Data" is the name of a parameter of the widget intent. It was not in the catalogs.
- Project: `project.yml` sets `developmentLanguage: en`. XcodeGen reads the regions from the catalogs, so the project lists `en`, `zh-Hans`, `ja`, `es`, `de`, and `ko` as known regions. No tool or dependency is new.
- Stays English: the supplement and medicine name lists of the quick add (D038), the CSV column titles and file names of the export (a file format), the city name in a medication time zone (it comes from the zone ID), and the debug tools. App Store Connect holds the tip names, the store text, and the screenshots, so they are separate work. `PRIVACY.md` and `site/` have no translation yet.
- Review: `docs/localization-review.md` lists the 25 riskiest strings in each language for a native speaker.

Not verified: no build of the app ran on this Mac. CI builds the app. Nobody saw the text on a display. Needs a check on a real iPhone in each language: the longest German and Spanish text in buttons, rows, the widgets, and the notification, the Japanese and Korean line breaks, and the camera prompt.

## D060 · 2026-10-13 · No "Record All" on Today

Maintainer decision on 2026-10-13, after use on the device.

- A part of the day on Today has no "Record All" button. The user records each row on its own. This replaces the "Record All" rule of D021 and D057.
- The model operation, the header button, its VoiceOver label, and the two catalog keys are gone. `TodaySnapshot.Group.openEntries` is gone, because only the button used it.
- A record is still one event per row, so the store and the record rules do not change.

Not verified: no build of the app on this Mac. CI builds the app.

## D061 · 2026-10-13 · The week strip of the item detail has the icon and the counts

Maintainer request on 2026-10-13, after use on the device.

- The strip of the item detail starts with the form icon of the item, as a row of History does.
- The line under the strip counts the doses of the last 7 days: taken, skipped, and with no record. An as-needed item has only the taken doses. This replaces the line of D057.
- `HistoryItemWeek` has the three counts. They use the same doses as the marks, so a dose that is not due yet does not count.
- A day with nothing planned shows a faint gray capsule in place of an empty slot, in the detail and in History. This replaces that rule of D054. The strip shows all 7 days, so it has no gap.

Not verified: no build of the app on this Mac. CI builds the app.

## D062 · 2026-10-13 · Paid team: time-sensitive reminders and version 1.0.0

The maintainer joined the Apple Developer Program on 2026-10-13. The Team ID is `JBG4XL9NQK`, the same team as the free provisioning. The agent made the changes that waited for the membership (D007, D034, D051).

- Reminders, follow-ups, and the test notification have the interruption level `timeSensitive`. A reminder then shows during a Focus. The user can turn off Time Sensitive alerts for Maru in Settings. The "Not recorded" notice keeps the default level, because it is not a dose.
- `Config/Maru.entitlements` has `com.apple.developer.usernotifications.time-sensitive`.
- `PendingReminder.isTimeSensitive` tells the engines that a pending request has the level. A request from an older build has the default level, so the next refresh replaces it with an add of the same identifier, as for a text change (D029). It takes no new room.
- The App Group stays `group.com.imhangli.maru`. The paid team is the same team, so the group needs no new ID.
- `MARKETING_VERSION` is 1.0.0.
- Not done: iCloud sync stays out (D040). Critical Alerts stay out (D021).

Not verified: the device build needs the maintainer's Apple ID in Xcode, so that automatic signing adds the capability to the App ID. Nobody saw a reminder during a Focus yet.

## D063 · 2026-10-13 · Store needs: an About section and the collected data in the privacy manifest ("not linked" replaced by D069)

Agent decision, after a release audit.

- Settings has a last section "About". "Privacy Policy" and "Support" open `https://maru.day/privacy.html` and `https://maru.day/support.html` after a tap. "Licenses" shows the MIT license of GRDB.swift, as `docs/third-party-licenses.md` requires before a public release. The license text stays in English.
- `App/PrivacyInfo.xcprivacy` declares the data that the usage statistics send (D052): the random install ID as a device ID, product interaction, and other diagnostic data, for analytics, with no tracking. They are "not linked": the ID is random, Maru has no account, and the ID is deleted when the user turns the switch off. A model review called "not linked" for a persistent ID a risk. Apple may count a persistent ID as linked. Change it to "linked" if App Review asks.
- `PRIVACY.md` states that PostHog keeps the data in the United States, because `MARU_ANALYTICS_HOST` is the US host. Change the sentence if the project moves to the EU cloud. A build with no analytics key sends nothing, and the declaration then states more than the build does, which Apple permits.
- `PRIVACY.md` and `site/privacy.html` said "Maru has no purchase yet". Tips exist (D053), so the text now says that Maru does not send the `purchase_result` event yet.

Not verified: no build of the app on this Mac. CI builds the app. The pages on maru.day are not live yet, so the two links show the placeholder until the site deploys.

## D064 · 2026-10-13 · Analytics requests carry the region setting ("not linked" replaced by D069)

Maintainer decision, with agent detail. It adds one field to the events of D052.

- Reason: the maintainer wants to know roughly where the users are, to decide which markets and languages to work on.
- Value: the region setting of the iPhone, `Locale.current.region?.identifier`, in the property `region` of each event. The app reads the setting one time and gives the same value to the consent rule (D051) and to the sender, so the two always agree.
- Guard: `PostHogClient` changes the value to upper case and accepts exactly two letters `A` to `Z`. For a missing value or any other form, such as the UN M.49 code `419`, the event has no `region` field. The guard does not check that the two letters are an assigned ISO 3166 code.
- The field is in the sender, next to the app version and the iOS version. The service makes a sender only when analytics is active, so the field cannot leave the device before the notice and the consent rule allow it. The list of fields stays closed: `AnalyticsEvent` for the event fields, and the fixed fields of the sender.
- What Maru still does not send or use: no Location Services, no city, no language list, no time zone, no currency, and no full locale identifier. Each event keeps `$geoip_disable: true` and `$process_person_profile: false`, so PostHog makes no location from the IP address. The PostHog project exists, with "Discard client IP data" on.
- The limit: the region setting is not the place of the user. A traveler, or an iPhone with another region setting, counts for that setting.
- Privacy label: declare the region as "Other Data" (`NSPrivacyCollectedDataTypeOtherDataTypes`), for analytics, not linked, and with no tracking. `App/PrivacyInfo.xcprivacy` has the entry, and `docs/release-plan.md` has the label list.
  - It is collected data. Apple defines "collect" as a transfer off the device that the developer or a partner can access for longer than the request needs.
  - It is not "Coarse Location". Apple defines that type as "information that describes the location of a user or device with lower resolution than a latitude and longitude", "such as Approximate Location Services". A region setting is a choice of the user in Settings. It is not a measured location, and it can differ from the place of the device.
  - Apple names no type for a region or a locale setting. "Other Data Types" is "any other data types not mentioned". The documentation leaves doubt that a declaration is necessary, so Maru declares it.
  - A "Location" label would tell the user that Maru collects a location, which is false. Change the type to "Coarse Location" if App Review asks.
  - Sources: [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/) and [NSPrivacyCollectedDataType](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype).
- `PRIVACY.md` and `site/privacy.html` name the field in the sentence about the app version and the iOS version.
- The maintainer does not register for GST for now, so supporter tips may not be for sale in the Australian storefront. Check the state of the Paid Apps Agreement before the first release.

Not verified: no build of the app on this Mac. CI builds the app. Nobody sent an event to the PostHog project, and nobody checked the packets (T42). The "Discard client IP data" setting is the report of the maintainer.

## D065 · 2026-10-13 · Every few days, and days on and off

Maintainer decision on the direction, with agent detail. The maintainer approved more schedule types on 2026-10-13: a cycle with a pause, and "every N days" only if it costs little. The feature must not delay the first release. If it is not ready, it ships in 1.1. It changes spec 1, 2.1, 8.1, 8.2, 8.3, 8.5, and 15 (new acceptance ID T52, and a note on T22). It replaces two lines of D036: "Only this rule. No cycles", and "no date picker".

The rule:

- One rule serves the three schedules. A schedule version can have a day cycle: a start date, a number of days with a dose (`daysOn`), and a number of days with none (`daysOff`). A date is due when it is on or after the start date and its count of calendar days from the start date, modulo `daysOn + daysOff`, is less than `daysOn`.
- Every other day is 1 and 1. Every N days is 1 and N - 1. 21 days on and 7 days off is 21 and 7. The every-other-day rule of D036 is this rule with 1 and 1, so its dates did not change.
- The other rules of D036 stay. The rule counts calendar dates in the calendar and the time zone of the plan, so a clock change, a time zone change, a missed dose, and a skip do not move the rhythm. An edit of a time or of the amount keeps the cycle. A change of a number or of the first day makes a new version from today. A day of the pause has no occurrence, so the item is not on Today, History has no "No record" row for it, and the widgets do not show it.
- The start date can be before today, for a cycle that the user already started.
- Hourly intervals and changing amounts stay out of scope (spec 1).

The database:

- Migration `v5` gives the column `scheduleVersion.everyOtherDayFrom` the name `cycleStart`, and adds `cycleDaysOn` and `cycleDaysOff`. A version with a start date gets 1 and 1. A version with no start date keeps `NULL` in the three columns. The store loads all three values or none, and any other row is invalid data.
- The migration only renames, adds, and fills the new columns. It rebuilds no table and deletes no row (spec 7.3).
- A backup from before `v5` restores: the restore applies `v5` to its copy of the backup, as it does for each later migration (D040). The backup format version stays 1.
- The record export did not change. It has one line for each dose, and a day of the pause has no dose.

The reminders:

- No second mechanism. A plan with a day cycle gets the dated requests of D036: one request for each of its next 7 due dates at each of its times, set again at each run. The budget of 48, the order of the budget, the "all 7 or none" rule, the shared request of D047, and the tap resolver did not change. The plan now steps one day at a time and keeps the due dates, in place of a step of two days.
- A day of the pause is not a due date. It gets no request, so no notification names the item on that day.
- The limit is the same text as D036: "Maru sets the reminders of the next 7 dose days each time you open it." For every other day the 7 due dates cover 13 days. For a plan with a pause they can be 7 days in a row. So its reminders can stop after one week with no open of Maru.

The screens:

- The repeat page has four choices in the first section: "Every Day", "Every Other Day", "Every Few Days", and "Days On and Off".
- "Every Few Days" has a menu "Interval" with 3 to 30 days. Two days is "Every Other Day", so the menu does not have it. "Days On and Off" has two menus, "Days On" and "Days Off", with 1 to 99. Each menu starts on "Choose". The app picks no number (spec 2.1). Save stays off, and the plan line says "Choose the number of days.", until the user chooses.
- The first day of the two new choices: "Starting Today", "Starting Tomorrow", or a system date picker "Another Date". The app picks no first day. Until the user chooses, the date picker shows today, the draft has no date, the footer says "Choose the first day.", and Save stays off. A change of the choice in the first section clears the numbers and the first day.
- Every other day keeps its two first-day choices and no date picker (D036), because it has only two possible rhythms.
- The plan line names the first day as a date, also a past one, because the first day decides which days have a dose: "21 days on, 7 days off at 8:00 AM, from Tue, Oct 13, with no end date".
- The item detail shows the rule under "Days", and "Next Dose" for each plan with a day cycle. "Next Dose" shows a date when the dose is 7 or more days away, because a weekday alone does not tell the week after a pause.
- A stored cycle of 1 day on and 2 to 29 days off opens as "Every Few Days". The two forms give the same dates.
- A draft file from before this change keeps its rule: the file names the cycle with the old key, and a cycle with no kind is every other day.
- A save keeps the stored cycle only when the choice gives the same due dates from today on. A first day that the user moves to a later date is a new version from today, also when the date is in the rhythm of the stored cycle: the days before it then have no dose. This is from the review, which found that such a save kept the old first day.
- The numbers of a cycle are 1 to 99, in the domain (`DayCycle.dayCounts`), in the checks of `v5`, and in the menus. Stored data or a backup with another number does not load, so a restore refuses the file before it replaces the data. This is from the review: a backup with a very large number passed, and the next due calculation overflowed.

Rejected:

- A second column set or a second rule type for cycles. One rule with two numbers gives all three schedules, and one migration.
- More than 7 due dates for a plan with a pause. Each time of such a plan would use more of the 48 requests (D036).
- A stepper or a number field for the days. A stepper needs a start value, which is a default. A number field with the number pad has no Return key, and nobody can check its commit behavior without a display.
- "Every Few Days" from 2 days. It would give two choices for the same plan.
- A change of `site/compare.html`, which says that Maru has no cycles. The site is published text, and it must follow the build that the store has.

Tests (D016): four new tests. The rhythm and the pause across a clock change, the dated requests around a pause, the migration with a restore of an older backup, and the refusal of a backup with a number outside the limits.

Not verified: no build of the app on this Mac. CI builds the app. Nobody saw the repeat page, the menus, the date picker, the plan line, or the item detail on a display, in any language. The translation is not reviewed by a native speaker. Nobody saw the reminders of a plan with a pause on a real iPhone.

## D071 · 2026-10-13 · A first Apple Watch app: the list of today, and records through the iPhone (not in 1.0: D074)

Maintainer decision on the direction, on 2026-10-13, with agent detail. It follows spec 6, 7.2, 9, and 10. It moves "Apple Watch" from the later list of `docs/roadmap.md` into work. It must not delay the first iPhone release, and the Watch app may ship in 1.1.

Scope:

- One screen, "Today": the doses of today by part of the day, with the capsule of the widgets (D048). A tap on an open dose records "Taken". A swipe gives "Skip" on an open dose and "Undo" on a recorded dose, with the words of the iPhone (D058).
- Not in this change: complications, a Watch-only mode, iCloud, as-needed items, a change of the intake time, and adding or editing items on the Watch.

Where the data lives:

- The iPhone database stays the only store. The Watch app has no database and does not link `MaruDatabase` or GRDB. It links only `MaruCore`, so `Package.swift` now also names watchOS 10.
- The iPhone sends the list of today as the WatchConnectivity application context after each read of the app, after each commit, and after a change of the tint. The system keeps the last context on the Watch, so the Watch app opens with the last list and shows its time ("Updated 8:07 AM"). A list of an earlier day does not show as today.
- When the Watch app comes to the front, it also asks the iPhone for the list of now. The system starts Maru on the iPhone in the background for the request.
- This changes one stated rule of spec 10: the names, the amounts, the times, and the states of the doses of today now leave the iPhone, to the user's own paired Watch. WatchConnectivity sends them between the two devices, and Maru has no server in between. Nothing goes to the Watch until the Watch app is installed. Analytics get no new event and no new field, and the Watch app sends no analytics and writes no log.

Where the record runs:

- The Watch sends a request with the occurrence ID, the schedule version ID, the action, the revision of the row (the last event of the record that the row shows), and an intent ID. It carries no name. `AppModel.answerWatch` reads today again from the store, finds the dose, and records with `commitAndWait`, the record transaction, with the generation check of D040. The source of the event is `app`, as for the widget. A new source would change the schema and the export format.
- The reply says "recorded" only after the commit, and it has the list after the request. The Watch never changes the state of a dose by itself: the capsule fills and the success haptic plays only for a reply that says "recorded" (spec 7.2).
- A stale row records nothing (review finding). The record must end with the revision that the Watch sent. A change on the iPhone in between, for example a new intake time, gives the reply "changed" and a new list. The event also revises that revision, so the store rejects it in the transaction on another state.
- One intent applies one time (review finding, T18). The intent ID is the ID of the event. The Watch keeps it for the same choice on the same row after a request with no reply. When that event is the end of the record already, the reply is "recorded" with no new event, after a flush, as for the widget. When a later choice came after it, the reply is "changed", and the later choice stays. `OccurrenceRecord.watchStep` has the rule.
- The day is checked two times (review finding). The read must still be of today when it ends, and the transaction checks that the dose is of today in its own time zone and in the plan of now (`requiresCurrentPlan`, as for the widget). So a tap before midnight records nothing after it. The cost: a dose whose plan changed after its record cannot be undone from the Watch.
- A list ends at its `expiresAt` also while the screen stays in front, with no iPhone in reach (review finding).
- After a commit the iPhone waits for the reminder run (D047) before it replies, as for the widget.
- Nothing is recorded, and the Watch says so in plain words, when: the iPhone is not reachable, no reply comes, the iPhone is locked, the dose is not in the list of today any more, the plan or the record changed, the dose has an event that the store did not confirm (D014), or the commit fails. A failed commit shows on the iPhone as on Today.
- The message format is in `MaruCore/WatchMessage.swift`. A message that does not decode records nothing, so a Watch app and an iPhone app of different versions fail safe.

Limits that the maintainer must know:

- The database had complete file protection (spec 10), so the Watch app recorded only while the iPhone was unlocked. D066 changes the level. The case that remains: an iPhone that restarted and was not unlocked yet. The Watch then shows the last list and "Not recorded. Unlock your iPhone and try again."
- The app embeds the Watch app. An archive of the iPhone app from this state includes it, and App Store Connect then asks for Watch screenshots and reviews the Watch app. To ship 1.0 without it, archive 1.0 before this change merges, or remove the `MaruWatch` dependency of the `Maru` target for that archive.
- `PRIVACY.md` and the privacy pages of the site have the sentence about the Watch (D066).

Notifications: nothing new. The iPhone reminders mirror to the Watch with the "Taken" action of D034. The category has one background action, registered on the iPhone at each launch. For a notification that the iPhone forwards, watchOS gives a background action to the iPhone app, so the response goes to `ReminderTapDelegate`, and `takeReminder` records with the same transaction. This is a reading of the code and of the watchOS rule, and a device must confirm it. The Watch app has no notification code, so a tap on the reminder itself opens the Watch app at its list.

Project: the target `MaruWatch`, bundle ID `com.imhangli.maru.watchkitapp`, watchOS 10, automatic signing with the team of the app. It compiles four shared files: the slot words, the tint, the time format, and the capsule. Its String Catalog has six languages (D059). The app icon set has one more entry for watchOS with the same image. CI: the `app` job builds the Watch app with the app, because the app embeds it.

Not verified: no build on this Mac. Nobody ran the Watch app on a Watch or in a simulator. A real iPhone and Watch must confirm:

- The install of the Watch app with the iPhone app, and the signing of the new App ID.
- The list after a launch, after a record on the iPhone, and on the next day.
- A tap, a skip, and an undo with the iPhone unlocked: the record on the iPhone, the haptic, and no follow-up after it.
- The same with the iPhone locked: a record (D066). With the iPhone restarted and not unlocked, off, or out of range: no record, and the text.
- A reminder on the Watch with the iPhone locked: the "Taken" action is there, and what it does. With D066 the expected result is a record.
- The icon in the round mask, the rows at the largest text size, VoiceOver, and each language.

## D066 · 2026-10-13 · The database is readable on a locked iPhone after the first unlock

Maintainer decision on 2026-10-13, with agent detail. It replaces the file protection level of D014 and D048, and the unlock rule of D034 for an action on the Watch. It changes spec 10.

- Reason: the user wears the Watch while the iPhone is locked in a pocket. With complete protection, a record from the Watch app (D071) and the "Taken" action of a reminder on the Watch could not write then.
- Change: the database directory has the level "complete until first user authentication": the database, the WAL file, the SHM file, the rollback journal, the restore epoch file, and a staged backup. iOS still encrypts the files. After a restart, nothing reads them until the first unlock.
- What keeps complete protection: the item photos, the export files, an exported backup, and the draft file of the edit screen. A record does not need them.
- Existing installs: each open sets the level on the directory and on the files that exist, as it did before for a weaker file. It changes one attribute. It copies and rebuilds nothing (spec 7.3). The first launch of the new build must run on an unlocked iPhone to change the files. Until then the old level stays, and a locked iPhone records nothing, as before.
- The earlier copy of the database in Application Support (D048) keeps complete protection. The app does not read it when the container has a database.

What else reads the same files on a locked iPhone now:

- The widgets. A timeline reload on a locked iPhone now reads the data. Before, it gave "Open Maru to update." A timeline that the system made before the lock already stayed on the display, so "Take Now" could show names on a locked display before this change too, for example in StandBy. The widgets have no change. If the names must hide on a locked display, mark them as privacy sensitive in a later change.
- The "Taken" action of a reminder (D034). It keeps the option `authenticationRequired`, so on the iPhone it still needs an unlock, and a person who holds a locked iPhone cannot write a record. On the Watch that the user wears, the action can now record with the iPhone locked. This is the wanted result. The rules of the action do not change: it records only when the reminder gives exactly one open dose of today, and never for another day, a late delivery, an older plan, two or more items, or a skipped dose (T15, T24). In those cases the "Not recorded" notice still comes.
- The reminder engine can run on a locked iPhone after a background record. It sets the same requests as on an unlocked iPhone, and the reminder text still follows the privacy setting of D029. The text of a notification was never protected by the database level.
- The tap on a reminder itself still opens Maru after an unlock. The "can't open your records while your iPhone is locked" alert now shows only after a restart with no unlock.

The Watch keeps one plain sentence for the case that remains: "Not recorded. Unlock your iPhone and try again."

`PRIVACY.md` states the new level, and it has one sentence that the list of today goes to the user's own Apple Watch. The maintainer approved both texts. `site/build.py` builds the privacy page of each language from `PRIVACY.md`, so the pages have the same text. The site publishes it when this change merges.

Not verified: no device ran this. A real iPhone must confirm that the level of the existing files changes at the first launch, that a record from the Watch works with the iPhone locked, that it fails with the plain sentence after a restart, and what the widgets show on a locked display.
## D068 · 2026-10-13 · Copy review: text states the record, not the intake

Agent decision, after a copy review of all user-facing text by a different model. It changes text in the six languages, and it replaces parts of D048. The number leaves D065 to D067 for the branches that are open at the same time.

- Maru knows a record, not an intake. A dose with no record is "Not recorded" or "No record", never "Not taken". The follow-up reminder has the title "No record yet" in place of "Still to take".
- The action that records an as-needed dose is "Record Dose" in place of "Take Now". The widget that records with a tap has the same name. Its type name and its kind string do not change, so an installed widget stays.
- The capsule of a widget gets the record state. VoiceOver says "Taken", "Not recorded", or "Skipped". The count of the "Today" widget stays "4 of 7" on the display, because a longer text does not fit the small widget, and VoiceOver reads "4 of 7 taken".
- The header of the small "Today" widget has no "·". The tint and the gray color separate the slot from the time. A second line does not fit above two rows of capsules.
- A day with no planned dose says "Nothing Planned Today", with the word "planned" of History. It does not say that there is nothing to take.
- The restore alerts name Maru: "Replace Maru Data?" and "This backup replaces all items and records in Maru." A restore that the storage did not confirm has the title "Restore Not Confirmed".
- The footer of "Your Data" says what a backup holds: items, records, and some settings, and no photos (`docs/export-format.md`).
- The statistics text says "how you use the app" in place of "counts of what you use", because the daily summary has yes-or-no flags and no count.
- The menu of the item detail is "Item Options…". "End This Item" can read as advice to stop an intake.
- Japanese and Korean "Drops" use the pharmacy words for the dosage form, 滴剤 and 점적제, in place of the loanwords. Apple's word in Health was not found. A native speaker must confirm both.
- `PRIVACY.md` and `docs/faq.md` lose the implementation words and the streak words. The camera paragraph of `PRIVACY.md` now also names the item photo. `site/` is not part of this change.
- Every changed string in Japanese, Korean, Spanish, and German is a draft until a native speaker reads it. `docs/localization-review.md` lists them.

- The item detail shows its three counts (D061) as separate labelled values with space between them, and one under the other when the row is too narrow. This was the last "·" separator in the app, the widgets, the reminders, and the String Catalogs.

Not verified: no build of the app on this Mac, and nobody saw the text on a display.

## D069 · 2026-10-13 · Usage statistics are "linked to the user" on the privacy label

Maintainer decision on 2026-10-13, after two model reviews.

- Every data type that the usage statistics send is "Linked to the user: Yes" in `App/PrivacyInfo.xcprivacy` and on the App Store privacy label. Each event carries the same random install ID, and Apple counts data that a persistent device-level ID ties together as linked. "Used for tracking" stays "No". This replaces the "not linked" part of D063 and of the region entry.
- The app does not change. The install ID stays random, Maru has no account, and the ID is deleted when the user turns the switch off.

## D070 · 2026-10-13 · Name lists in each language

Maintainer request: in each language, the names of supplements and medicines are the names that people in that market use. Agent decisions on the details. Parts of D038 and D043 change.

- zh-Hans, ja, ko, es, and de each get two lists in `App/Resources`: `SupplementNames-<language>.txt` and `MedicationNames-<language>.txt`. Each list has about 150 to 250 common names in the local script and spelling. They are not translations of the English lists.

| Language | Supplements | Medicines | Supplements with an English twin |
|---|---|---|---|
| Simplified Chinese (zh-Hans) | 176 | 247 | 86 |
| Japanese (ja) | 183 | 219 | 67 |
| Korean (ko) | 166 | 198 | 68 |
| Spanish (es) | 165 | 210 | 83 |
| German (de) | 167 | 215 | 80 |

- Medicines are generic names: 通用名 in Chinese, 一般名 in katakana in Japanese, 성분명 in Korean, DCI in Spanish, and Wirkstoffe in German. Everyday traditional medicines are in the medicine list by their formula names: Chinese patent medicines, Kampo formulas with their reading in hiragana, and Korean herbal formulas. No brand names.
- The app reads the lists of its language first, then the English lists, because people type Latin names too. English has no extra list.
- The search keeps the rules of D038 and adds three for Chinese, Japanese, and Korean. One character of these scripts is enough. Hiragana matches katakana, so a typed reading finds a katakana name or a Kampo name. In a Hangul syllable that the keyboard did not complete yet, the last consonant ends that syllable or starts the next one: "아토ㅁ" and "아톰" find 아토목세틴 and not 아토르바스타틴. The consonant narrows the result. There is no pinyin or romaji search.
- Smart completion (D043): a field `= <English name>` in a supplement line names the entry of `SupplementCompletions.txt` that the local name uses. A local name gets the form and the candidates of its English twin, and no data of its own. The candidate amounts stay in English words, as before.
- Two names for the same product are one entry with an alias: 对乙酰氨基酚 with 扑热息痛. A local product with no exact English equivalent has no twin: 酵素, 녹즙. A brand ingredient name is replaced by its generic description: 락티움 is 유단백가수분해물.
- Controlled and high-risk medicines stay in the suggestions: opioids, sedatives, stimulants, insulin, anticoagulants, and methotrexate. People who take them on a prescription need reminders the most. A suggestion is a spelling aid and gives no advice, so the app shows no warning for these names.
- An alias never leads to another name. A test reads the real lists of each language with the English lists, and checks that each name and alias belongs to one name only, and that each twin exists.
- The debug sample data follows the app language, with six items that many people in that market take, in the same forms and at the same times as the English sample.
- Sources: general knowledge of the generic names and label names of each market, with the public national naming systems (Chinese 通用名, Japanese 一般名, Korean 성분명, INN/DCI) as the reference for spelling. No database or list was copied, so no license applies and `docs/third-party-licenses.md` does not change.

Not verified: no native pharmacist read the lists. A first review corrected some names on 2026-10-13. Every name still needs that check, and `docs/localization-review.md` lists the names to check first. No build of the app on this Mac, and nobody saw the suggestions on a display.

## D072 · 2026-10-13 · The app also runs on iPad

Maintainer decision, with agent detail. The maintainer asked for iPad support before the first release, if it is ready. It must not delay the release.

- Both targets have the device families iPhone and iPad. The iPhone stays portrait only. The iPad has the four orientations, in `Config/Maru-Info.plist`, and the generated launch screen. The app does not require the full screen, so Split View, Slide Over, and windows work.
- Layout (`docs/design.md`, "iPad"): the iPad uses the layout of the iPhone at a larger width. It has the same tab bar, the same pages, and one navigation stack in each tab. Today opens History and the item detail as a push, as on the iPhone. My Items keeps the grid of two columns. The content fills the width of the window.
- The maintainer first asked for a list and its detail side by side. A first version had two pages side by side at a regular width and a readable column of 672 points. Before the merge, the maintainer chose one layout for both devices: the iPad must look and work like the iPhone, only wider. The code of the two columns was removed.
- Settings, the add and edit screen, the scanner, and the time sheets stay system sheets. The system gives a sheet a fixed width on an iPad. The system shows the tab bar at the top on iPadOS 18 and later, with names and no icons. This is the system form of the rule of D026.
- No presentation needs a new anchor. Each `confirmationDialog` is on its button: the record circle, the as-needed dose, and "Cancel" of the edit screen. SwiftUI shows it as a popover from that button on an iPad. The share sheet is a `UIActivityViewController` inside a SwiftUI sheet, so UIKit does not present it and it needs no source view. The file picker, the photo picker, and the camera are system presentations.
- Text: 13 strings name the iPhone. Each has a device variation for the iPad in the String Catalog, in the six languages. The iPad text is the iPhone text with the other device name, and Korean has the particle for the new word. A native speaker did not check them.
- Widgets: the small and the medium family exist on the iPad, and the layouts do not change. The large and the extra large family need a new design, so Maru does not offer them.
- Each iPad has its own local database. Maru has no sync (D040). The backup file moves the data between an iPhone and an iPad, without the photos (D056).
- Not done: no sidebar, no keyboard shortcuts, no pointer effects of its own, and no iPad family of the widgets.
- `PRIVACY.md` and `docs/faq.md` say "iPhone or iPad" or "device" where the text is true for both, and say that each device has its own data. The site builds its privacy page from `PRIVACY.md`. Its FAQ answer about the Apple Watch now says that Maru is an app for iPhone and iPad, in the six languages.
- The stop rule: if the check on a real iPad fails before the first upload, set `TARGETED_DEVICE_FAMILY` to `"1"` in both targets. The other parts of this change do nothing on an iPhone. After a version with iPad support is on the App Store, Apple does not let an update remove the iPad.
- The store page then needs iPad screenshots (`docs/release-plan.md`).

The two-column version was seen in the simulators iPad Pro 13-inch and iPad mini, in portrait and landscape, light and dark, and at the largest text size: Today with History, the day log and the item log, the item detail, My Items, add and edit, the photo picker, Settings, and the share sheet of the export. Not seen: Split View and Slide Over, the scanner and the camera (the simulator has no camera), restore, the tip section with products, and a real iPad. The camera may not be available in Split View or Slide Over. Nobody saw the layout of the iPhone on an iPad display. CI builds it.

## D073 · 2026-10-13 · Photo icons line up, the photo choice is beside the form, and the sample items have photos

Maintainer decision on the concept, with agent detail. The maintainer approved a concept of three supplement jars with invented brand labels (Driftholm Omega-3, daywick Vitamin D3, Quietfield Magnesium Glycinate) as item photos.

- Icon column: a photo was 1.4 times the icon size, and the drawn icon was 1 time. In a list with both, the names did not line up, by about 7 points at the default text size. `FormIcon` now gives both one square frame of 1.4 times the icon size, with a limit of 44 points. The drawn icon keeps its size in the middle. This covers Today, History, the item detail, and the archived list. The My Items tile already used one size for both. The widgets show no photo.
- Edit screen: the photo was the last section, "Photo (Optional)", under the note. It moves into the section of the form and the color, because both choose the icon. The first row of the section shows the current icon or photo. "Choose Photo" and "Take Photo" follow "Form" and "Color". The camera permission, the background removal, the switch "Remove Background", and "Remove Photo" do not change. The header "Photo (Optional)" and its string are removed. The section uses only existing strings.
- Debug sample data: vitamin D3, omega-3, and magnesium get the jar photos, in each app language. They are stored by `ItemPhotos`, as the edit screen stores a cut-out: a PNG of at most 512 pixels, made with the Vision steps of `PhotoProcessor`. Medications never get a photo. The other sample items keep drawn icons.
- To give the same three supplements in each language, magnesium replaces the probiotic in zh-Hans, ja, and ko. The names that match the labels are "Vitamin D3" and "Magnesium Glycinate" in English, with the local names in the other languages. This differs from the probiotic choice of the store research for Korea. The site mock (`site/src/mock/`) still has the old names.
- The PNGs are in `App/Debug/SamplePhotos/`. The Release configuration of the app target sets `EXCLUDED_SOURCE_FILE_NAMES` to `sample-photo-*.png`, so a release build does not copy them. A CI step reads the Release build settings and fails when the setting is missing.
- Image sources: Unsplash photos by Supliful under the Unsplash License, with invented labels. The brand names had no hit in the US trademark register. A TMview check is still open before a public use of the images.

## D074 · 2026-10-13 · Watch app waits for 1.1 until a real-device test

Maintainer decision, with agent detail. The goal is a fast first release. It replaces the "embedded in the app" part of D071 for version 1.0.

- Version 1.0.0 ships for iPhone and iPad, without the Apple Watch app. Nobody ran the Watch app on a real Watch, and a build with it needs Watch screenshots.
- `project.yml`: the `Maru` target no longer depends on the `MaruWatch` target, so an archive does not embed the Watch app. This is the only change to the build. The `Watch/` code, the `MaruWatch` target, and its scheme stay.
- CI builds the Watch app in its own step, for the watchOS Simulator, because the app build no longer includes it.
- The iPhone code that answers the Watch stays in the app. It does nothing when no Watch app is installed.
- `PRIVACY.md` no longer has the sentence about the list of today on the Watch, and the privacy pages of the site are built again. Add the sentence back in the change that embeds the Watch app. The site FAQ and `site/llms.txt` already say that Maru has no Watch app. The store text does not name the Watch.
- To embed the Watch app in 1.1: add `- target: MaruWatch` to the dependencies of `Maru`, restore the privacy sentence, and add Watch screenshots.

Not verified: no build ran on the Mac of the maintainer before the merge. CI builds the app and the Watch app.

## D075 · 2026-10-13 · The App Store Connect record

The maintainer approved the setup of the App Store Connect record and asked for the best version of each setting. Agent decisions on the details. `docs/release-plan.md`, section 7, has each value and its reason.

- Primary category Health & Fitness, secondary category Medical. Price free. All territories except mainland China. Manual release after approval.
- Age rating answers: "Medical or Treatment Information" is "Infrequent or Mild", "Health or Wellness Topics" is "Yes", and every other answer is "None" or "No".
- Maru is declared as not a regulated medical device.
- The privacy label is that of D069, and it is published.
- The tips have the names "A Small Thanks", "A Warm Thanks", and "A Big Hug", at USD 0.99, 2.99, and 9.99. D053 had no names and no prices. `Config/Maru.storekit` has the same names and prices.
- The store URLs use the paths of the live site: `/support/` and `/privacy/`, with the language folder.

## D076 · 2026-10-13 · Row text in the text color, no test notification, and a progress bar in the "Today" widget

Maintainer decisions after the test of the TestFlight build, for the build that goes to App Review. Agent decisions on the details.

- The app tint is for icons, controls, and state, not for row text. Tinted text on a row looked like a warning. A row that is an action or a link has the text color: in Settings ("Open Settings", "Export Records", "Back Up", "Restore from Backup…", "Send Feedback", the tips, "Privacy Policy", "Support"), on the add and edit screen ("Scan Label", the name proposals, "Use Softgel", "Choose Photo", "Take Photo", "Add a Time"), and on the item detail ("Item Options…", "Restore", "Open Settings"). A row that is off is gray.
- The value of a menu row has the text color: "Remind Again", "Every", "App Color", "Form", "Color", "Note", and the day counts of "Repeat". The form icon of the menu keeps the app tint, as an image with its own color. The smart completion candidates are gray capsules with the text color.
- Symbols keep the tint. Toolbar buttons, switches, check marks, and the filled button of the scanner keep the tint. "Clear" on the scanner card is not a row and keeps the tint. A destructive row ("Remove Photo", "Start Over", "Delete Item…") stays red.
- "Send a Test Notification" is removed from Settings, with its code, its footers, and its strings in the six languages. It was a user feature of D023, and the maintainer read it as test UI. This replaces that part of D023. The follow-up reserve of 2 requests (D039) stays, so the request budget does not change. One of the two is now spare.
- Every other test tool was already in `App/Debug/` or `App/DebugLaunch.swift` inside `#if DEBUG`: the Debug section of Settings, the test scenarios, the data banner, the launch arguments, and the sample data. The sample photos are not in a Release build (D073).
- The medium "Today" widget shows a progress bar in place of the count "4 of 7": a track in the system fill and a fill in the app tint for taken doses divided by all doses. The system fill has an alpha value, so the track stays quiet in the light, dark, tinted, and clear looks. The fill takes the accent of a tinted Home Screen. VoiceOver reads "Today, 4 of 7 taken".
- The small "Today" widget gets no bar. Its first line holds the slot word and the time, and a bar did not fit beside them in a capture. It keeps the large "7 of 7" when every dose is done. "Record Dose" shows no count of taken doses.
- The columns of the medium "Today" widget end at the bottom edge, so the space over the title equals the space under the capsules.
- Checked in an iPhone 17 Pro simulator, light and dark, with a view of the widget layout inside the app. Nobody saw the widget on a Home Screen, in the tinted or clear look, or the item detail row. They need a check on a real iPhone.

## D077 · 2026-10-14 · More usage statistics for product decisions

Maintainer request on 2026-10-14, with agent detail. Build 3 sends four events, and the maintainer cannot judge the product from them. This change adds events and fields that answer the questions of spec §11.1. Every value is a fixed word, a flag, or a coarse range. The rules of spec §10 and §11 stay.

- `setup_step`: the steps `editor_opened`, `item_saved`, `editor_closed`, `scan_opened`, `scan_used`, and `scan_blocked`, with `mode` (`new`, `edit`, `replace`). A save adds the kind of plan, a range of the count of reminder times (`0`, `1`, `2`, `3_plus`), three flags for an amount, a note, and a photo, the source of the name (`typed`, `suggestion`, `scan`), a flag for a tapped smart-completion candidate, a flag for the first item, and a range of the time on the screen. A close with no save adds `had_changes` and the time range. The event is not called "abandoned", because the user can come back (spec §11.1).
- `daily_usage_summary`: eight more flags (reminder action, skip, undo, correction, as-needed, My Items, item detail, Settings), a range of the count of opens of the day, a range of the count of active items, and a flag for a widget on the Home Screen. A day with an open or a flag has a summary. A record from a reminder action with no open gives `app_opens` = `0`.
- `core_error`: the operations `schedule` and `scan`, and three codes of the reminder state of a save: `too_many`, `not_set`, `not_confirmed`.
- New events: `notification_permission` (sent only when the state that the app reads differs from the state that it sent last), `setting_changed` ("Remind Again", "Show Names in Reminders", the app color), and `data_action` (export, backup, restore, with a result).
- Each request also has `app_language` (one of the six app languages, else `other`) and `device` (`iphone`, `ipad`, `other`), next to the app version.
- No event goes out at the moment of a record. A skip, an undo, a correction, and a reminder action are only flags of the daily summary, so no event time tells an intake time.
- Not sent, and why:
  - The type of an item (supplement or medication). It tells that the user takes a medication, which is health data. The privacy label would then need "Health".
  - A count of doses, a time, a weekday, and an item ID (spec §11.5).
  - The analytics switch. After "off" nothing goes out, and an "on" event alone gives no rate.
- Privacy label: no new data type. The new events are "Product Interaction". The codes of `core_error` and `device` are "Other Diagnostic Data". `app_language` is "Other Data Types", with the region. `App/PrivacyInfo.xcprivacy` already declares these types. App Store Connect needs no change of the types, and the purpose stays "Analytics".
- Tests: the schema test sends each new factory result through the checked init (D016). No other new test.

Not verified: the app build on this Mac and the screens. CI builds the app. Nobody sent an event to the PostHog project. The packet check (T42) waits for a build with the key.

## D078 · 2026-10-14 · No notice for usage statistics outside the opt-in regions

Maintainer decision on 2026-10-14. It replaces the notice part of D051 and D052.

- Outside the EU, the EEA, the UK, and Switzerland, usage statistics are on from the first launch, with no notice and no question. Before, they started only after a one-time notice.
- Inside those regions nothing changes: the statistics are off until the user opts in, with a one-time question after the first save, or with the switch in Settings.
- Every region keeps the switch "Share Usage Statistics" in Settings. "Off" still stops the client, clears the queue, deletes the install ID, and clears the local usage state (T43).
- The app no longer has the notice with "OK" and "Turn Off", and its two strings are removed. The key `analytics.noticeShown` stays, because the question of the opt-in regions uses it.
- `PRIVACY.md` and the site privacy page say that Maru shows no notice outside the opt-in regions. The App Store review notes need a new sentence, which the maintainer changes in App Store Connect.
- The limit: the region setting is not the place of the user (D052).

Not verified: the app build on this Mac. CI builds the app. Whether another storefront needs a notice or an opt-in for this data is a legal question. The model review of this change gave an opinion, and it is not legal advice.

