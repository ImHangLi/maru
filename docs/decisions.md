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

## D019 · 2026-10-11 · Occurrence window and time zone policy (the freeze after an undo replaced by D095)

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

## D023 · 2026-10-11 · Settings sheet and preference storage (display settings removed by D026 and D032, foreground rule replaced by D027, no-names rule replaced by D029, feedback row added by D037) (test notification removed by D076) (language row added by D097)

Agent decisions from issue #11.

- Preferences live in `UserDefaults.standard`, not in the health database (D014). Display settings use two keys, read with `@AppStorage`. The follow-up setting keeps the key of PR #25. No value means off. Reason: the settings must be readable while the iPhone is locked, and they hold no health data.
- The sheet has three groups: reminders (permission state, "Open Settings" when off or quiet, and the test), follow-up (Off, 15, 30, or 60 minutes), and display (strikethrough, tab bar icons only). All options are off by default.
- The permission shows as On, Quiet (provisional), Off, or Not Asked Yet. Maru reads it at each return to the front and never shows the system prompt from settings or Today (spec 2.2, T13, T14).
- Today shows one small line, "Notifications are off", only while the permission is denied. A tap opens the sheet.
- The test notification is one one-time request with one fixed identifier, `test|settings`, in about 5 seconds. It runs in the notification queue of `AppStore`. Neither engine removes it, and both count it while it waits. At the system limit, it first removes the latest follow-up, then the follow-ups are set again after it fires. It never removes a series request. It shows as a banner while Maru is in front. A tap on it records nothing.
- No "show item names on the lock screen" option. Spec 8.2 makes neutral text the baseline and does not require the option. Names would need new content for each series and each follow-up. The sheet states in one line that reminders show only a time.
- No language row: the first release has only English (D017). No help or feedback row: feedback sending is milestone B.

## D024 · 2026-10-11 · No header wash, app-specific empty text (empty text and tab bar point replaced by D026) (wash returns as an option by D100)

Owner decisions after the first install on a device.

- Remove the pink header wash of D021. Today uses the plain grouped background, the same as My List. The fixed pink tint and the item colors stay.
- The empty Today page does not read like a to-do list. With no items, it says "Add a supplement or medication with the + button." With items but nothing due today, it says "No doses to take today."
- The "tab bar icons only" setting must work. A label style has no effect in the tab bar, so the icon-only item uses an image with an accessibility label.

## D025 · 2026-10-11 · App color setting (colors other than pink need Pro by D114)

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

## D029 · 2026-10-11 · Reminders say what to take (a delivered first reminder stays: replaced by D084)

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

## D033 · 2026-10-11 · Shorter record correction and archive, and delete of an item (the places of "Delete Item…" changed by D098)

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
- A saved draft of version 1.0 has no reminder options. The editor takes them from the stored item and does not read them as "off".

Tests (D016): one new test, for the delete transaction.

## D034 · 2026-10-11 · A "Taken" action on a single-item reminder, and time-sensitive reminders (time-sensitive level done by D062, unlock rule changed by D066, the group clause and "Skip" changed by D090)

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
- The button uses the system `openURL` action, and Safari opens the form. No custom browser view. (Changed on 2026-10-14: the in-app browser sheet did not open over the settings sheet on the maintainer's iPhone.)


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

## D039 · 2026-10-11 · More follow-ups, and "Until Recorded" with a stated limit (the setting moved to each item, and an alarm option came: D079)

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
- An alarm through AlarmKit, for now. It is a different product: a full-screen alarm with its own permission. Maru stays a quiet reminder (spec 4). Replaced by D079: an alarm is a switch of each item in version 1.1.
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

## D041 · 2026-10-11 · History graph (scroll of the timeline to a day replaced by D054, start of the graph replaced by D092, graph scrolls with the list by D109)

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

## D043 · 2026-10-12 · Smart completion for supplements (pet candidates changed by D121)

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

## D047 · 2026-10-12 · One reminder for each fire time, and no reminder for a dose that is recorded (the reach of the dated requests changed by D089)

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

## D053 · 2026-10-12 · Optional supporter tips with StoreKit 2 (replaced by D099)

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

## D058 · 2026-10-12 · Consistency pass across the app (the empty-view title rule changed by D101)

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

## D060 · 2026-10-13 · No "Record All" on Today (a "Take All" on a reminder, not on Today: D090)

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

## D071 · 2026-10-13 · A first Apple Watch app: the list of today, and records through the iPhone (not in 1.0: D074) (a Pro feature: D111) (the owner in the row name: D123)

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
## D068 · 2026-10-13 · Copy review: text states the record, not the intake (the empty Today title replaced by D101)

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

## D074 · 2026-10-13 · Watch app waits for 1.1 until a real-device test (replaced by D111)

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

## D076 · 2026-10-13 · Row text in the text color, no test notification, and a progress bar in the "Today" widget (suggestion color replaced by D082)

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

- `setup_step`: the steps `editor_opened`, `item_saved`, `editor_closed`, `scan_opened`, `scan_used`, and `scan_blocked`, with `mode` (`new`, `edit`, `replace`). A save adds a flag for a reminder time, three flags for an amount, a note, and a photo, the source of the name (`typed`, `suggestion`, `scan`), a flag for a tapped smart-completion candidate, a flag for the first item, and a range of the time on the screen. A close with no save adds `had_changes` and the time range. The event is not called "abandoned", because the user can come back (spec §11.1).
- `daily_usage_summary`: seven more flags (reminder action, skip, undo, correction, My Items, item detail, Settings), a range of the count of opens of the day, a range of the count of active items, and a flag for a widget on the Home Screen. A day with an open or a flag has a summary. A record from a reminder action with no open gives `app_opens` = `0`.
- `core_error`: the operations `schedule` and `scan`, and three codes of the reminder state of a save: `too_many`, `not_set`, `not_confirmed`.
- New events: `notification_permission` (sent only when the state that the app reads differs from the state that it sent last), `setting_changed` ("Remind Again", "Show Names in Reminders", the app color), and `data_action` (export, backup, restore, with a result).
- Each request also has `app_language` (one of the six app languages, else `other`) and `device` (`iphone`, `ipad`, `other`), next to the app version.
- No event goes out at the moment of a record. A skip, an undo, a correction, and a reminder action are only flags of the daily summary, so no event time tells an intake time.
- The summary of a day goes out only at an open of the app. A day that ends while the app works in the background, for example after the "Taken" action of a reminder, waits on the device as one summary with no time. Before, the first background record of a new day sent the summary of the day before, so the event time could tell the time of that record. At most one summary waits, and a newer day replaces it.
- "On" in Settings or in the opt-in question counts one open, because the user is in the app.
- Not sent, and why:
  - The type of an item (supplement or medication). It tells that the user takes a medication, which is health data. The privacy label would then need "Health".
  - The kind of plan (daily, weekdays, every other day, and so on) and the count of reminder times. A first draft sent both. The model review found that they describe the regimen of the user and can give the planned doses of a day, so the label would need "Health". The save sends only `has_reminder`.
  - A flag for a record of an as-needed dose. The second review round classed it as health data, because an as-needed dose tells that the user needed the item on that day.
  - A count of doses, a time, a weekday, and an item ID (spec §11.5).
  - The analytics switch. After "off" nothing goes out, and an "on" event alone gives no rate.
- Privacy label: no new data type. The new events are "Product Interaction". The codes of `core_error` and `device` are "Other Diagnostic Data". `app_language` is "Other Data Types", with the region. `App/PrivacyInfo.xcprivacy` already declares these types. App Store Connect needs no change of the types, and the purpose stays "Analytics".
- Tests: the schema test sends each new factory result through the checked init (D016). No other new test.
- `PRIVACY.md` names each key that the sender adds, and the event time to the millisecond.

Not verified: the app build on this Mac and the screens. CI builds the app. Nobody sent an event to the PostHog project. The packet check (T42) waits for a build with the key.

## D078 · 2026-10-14 · No notice for usage statistics outside the opt-in regions

Maintainer decision on 2026-10-14. It replaces the notice part of D051 and D052.

- Outside the EU, the EEA, the UK, Switzerland, and South Korea, usage statistics are on from the first launch, with no notice and no question. Before, they started only after a one-time notice.
- Inside those regions nothing changes: the statistics are off until the user opts in, with a one-time question after the first save, or with the switch in Settings.
- Every region keeps the switch "Share Usage Statistics" in Settings. "Off" still stops the client, clears the queue, deletes the install ID, and clears the local usage state (T43).
- The app no longer has the notice with "OK" and "Turn Off", and its two strings are removed. The key `analytics.noticeShown` stays, because the question of the opt-in regions uses it.
- `PRIVACY.md` and the site privacy page say that Maru shows no notice outside the opt-in regions. The App Store review notes need a new sentence, which the maintainer changes in App Store Connect.
- The limit: the region setting is not the place of the user (D052).

Not verified: the app build on this Mac. CI builds the app.

Open legal risk, for the maintainer: the model review (GPT-6.1-Sol, 2026-10-14) gave an opinion that is not legal advice. It does not treat "on with no notice" as safe in every storefront, because a random install ID is not anonymity in law, and the data comes from a health app. It named the highest risk in Washington and Nevada (consumer health data laws with prior consent), then South Korea (PIPA), Brazil (LGPD), and Canada, mainly Quebec, if the data counts as health data. California, Japan, and Australia expect at least a notice at collection. On 2026-10-14 the maintainer added South Korea to the opt-in list, because PIPA asks for consent first and Korean is a store language. The other risks stay open.

## D079 · 2026-10-14 · Reminder options of each item: "Remind Again" and an alarm (version 1.1) (Settings got rows for all items in D085) (a repeating alarm and the 28-day reach: D089)

Maintainer decision on 2026-10-14, for version 1.1. Version 1.0.0 is in App Review with build 4 and does not change. It replaces the global setting of D039 and the AlarmKit line of its "Rejected" list. It changes spec 4. The project version is 1.1.0.

The decision:

1. "Remind Again" (the follow-ups of D039) leaves Settings. Each item has its own count and its own interval. The add and edit screen shows them under the plan. Each item is independent. The default is "Off".
2. Each item has a switch "Alarm". The dose time of the item rings like the alarm of the Clock app, also in silent mode and in a Focus. It uses AlarmKit, so it needs iOS 26. The default is off.

Follow-ups of each item:

- The add and edit screen has a section "Reminders" after the plan, when the item has a time. It has the rows "Remind Again" and "Every" of D039, with the same choices and the same footers. The interval row shows only when the count is not "Off". The interval starts at 30 minutes when the user turns the count on.
- Where it is stored: `item.followUpCount`, `item.followUpMinutes`, and `item.followUpChanged` (migration `v6`). Both of the first two are empty for "Off". `followUpChanged` is the time of the last change of the setting of that item, and the editor sets it at a save that changes the setting. `FollowUpSetting` stays the value type, and `Item.followUp` holds it.
- The limit of D039 stays for each item and each dose: at most 12 follow-ups, also across a change. The plan counts the worst case before `followUpChanged`, as before, with the time of each item.
- The system limit of D039 stays: the room is 64 minus a reserve of 2 and minus the series requests, and the groups share it in turns. One dose time can now hold more than 12 requests when the items of the time have different intervals. The room rule decides which requests stay.
- The stop rules stay: before the next dose of the same item, and before 01:00 of the next day. The "Taken" action stays for a group of exactly one item, open or not, with the identity check of D034.
- D047 stays, for one dose time: the follow-ups of one dose time that fire at the same instant are one notification. Follow-ups of two different dose times that fire at the same instant (for example 08:00 plus 30 minutes and 08:15 plus 15 minutes) stay two notifications. A merge would give one request two series and two plan dates, and the identity check of the "Taken" action (D034) needs one. This is accepted. The text names only the items that it still reminds for. So an item with 15 minutes and an item with 30 minutes at one dose time give a notification for the first at +15, and one for both at +30. An item with "Off" is never named in a follow-up.
- The identifier of a follow-up is `followup|<zone>|<date>|<HH:MM>|+<minutes>`, with the minutes from the dose time. A count did not work any more, because items with other intervals share a dose time. All follow-ups of the dose time keep one thread identifier (D039). A pending request of version 1.0 has the old form, and the first run of 1.1 removes it and adds the new one.
- The wait for the removal of the old follow-ups after a change (D039) is gone. The old setting was one value for the whole app, and a change had to confirm the removal of every follow-up. A change now belongs to one item and comes with a save. The run after the save removes the old requests of that item and adds the new ones in the same run. The accepted risk: a pending request that the system does not remove in time can still fire once.

The move of the old setting:

- The first open of the database after the update reads `reminders.followUp.v2` (and the older keys of D021 and D039), copies the setting to every item that has no setting, and removes the keys. So the behavior of an update does not change. The change time of the old setting goes to `followUpChanged` of each item, so the limit of 12 for a dose does not start again. A change that the old app did not confirm (`Date.distantFuture`) stays unconfirmed on the items, and the keys go. The follow-up engine then removes every pending follow-up, and only when the system holds none it writes the time of now as the change time. Until then the plan sets no follow-up for such an item. This is the confirm-after-removal rule of D039, so a stop of the app between the update and the first run cannot start the limit of 12 again. If the write fails, the keys stay and the next open tries again.
- Settings has no "Remind Again" rows, no strings for them in Settings, and no key. The strings moved to the add and edit screen with their translations.
- The backup is the database, so it holds the new columns. It no longer writes `remindAgainMinutes` and `remindAgainCount`. A backup of version 1.0 has these two settings and no new column. The staging of the restore copies the two settings to every staged item, as the update does, before the data is replaced. A failure then fails the restore with no change to the old data. A backup of 1.1 has no such setting, and its items keep their own. A restore never fails for a missing field: an item with no value has no follow-up and no alarm. `docs/export-format.md` says so.

Alarm:

- The switch is in the same section family, after "Remind Again", and shows only from iOS 26 (`if #available(iOS 26, *)`). The deployment target stays iOS 17.
- The first turn-on asks for the AlarmKit permission. The text is `NSAlarmKitUsageDescription` in the six languages. If the user refuses, the switch goes back to off, and an alert says that alarms are off for Maru, with the button "Open Settings". Maru does not ask again, because the system does not.
- One alarm for each dose time that has an open dose of an item with the switch on. Two items with an alarm at the same time share one alarm. The title is "Time to take" and the item names, or only "Time to take" when "Show Names in Reminders" is off (D029). The names follow the same switch as a notification.
- An item with an alarm gets no normal reminder at that time. Other items at the same time keep their notification, and it does not name the alarm item. The follow-ups of the item stay notifications (D039).
- Without the permission, or before iOS 26, the item gets its normal reminder, so a refused permission never leaves a dose with no reminder. The check runs at each engine run. The same holds when the system does not schedule an alarm, for example at its limit: the alarm engine runs first and names the items whose alarm failed, and the notification engines of the same run give those items their normal reminder. The banner of an item is one repeating request, so this is for the whole item and not for one dose. When one alarm of an item fails, the engine cancels the other alarms of that item and of every item that shares an alarm with it, so no dose gets an alarm and a banner together. The next run tries the alarms again. The cover is valid for the run that made it, and it fails open: it holds only the items whose alarms the system confirmed in that run with no error. An error of the alarm read, of a schedule, or of a cancel makes the cover empty for that run, so every item with an alarm gets its normal reminder. No run uses the cover of an earlier run. After a failed cancel, a dose can get an alarm and a banner together. This is accepted, because it is better than no reminder.
- A dose that has a record gets no alarm. The alarm engine runs after the reminder engine and the follow-up engine, at launch, on return to the app, after a save, and after each record, skip, or undo. It cancels each waiting alarm that the plan no longer has. It never stops an alarm that rings now. The plan covers the next seven days, with at most 64 alarms, nearest first, as the follow-ups do. When the app does not run for seven days, no new alarm comes. The identifier of an alarm is a hash of the dose time, the items, the names, and the button, so an edit, a rename, or a record replaces only the alarm that it changes.
- The alarm has the button "Stop" of the system, and a second button. For exactly one item, alone at its dose time, the second button is "Taken". It runs an App Intent in the app process and records through `takeReminder`, the path of the "Taken" action of a notification. So the identity check of D034 applies: the series, the plan date, the item, and the schedule version. It records only after the local transaction commits (spec 7.2). When a second item is at the time, even without an alarm, the button is "Open Maru" and records nothing, as for a notification.
- No countdown, no snooze, and no widget extension for the alarm. AlarmKit needs the extension only for countdowns.

Analytics (D077): `item_saved` has two new flags, `has_alarm` and `has_follow_up`. The event `setting_changed` no longer has `remind_again` and `remind_again_minutes`, because no setting row sends them. Nothing else changed. `PRIVACY.md` lists the two flags, drops the two fields, and says that the backup holds no "Remind Again" setting. The site privacy pages still show the text of 1.0. A maintainer changes them with the release of 1.1.

Rejected:

- A global switch for the alarm. The user wants it for one medication and not for each supplement.
- An alarm for the follow-ups. They would ring many times, and the system alarm is too loud for this.
- A second wait for the removal of follow-ups after a change. It needs a global value, and the setting is not global any more.
- Treating an item with an alarm like an item with a notification. The state of its schedule would then say "permission needed" when only notifications are off. The state is "scheduled" with the alarm alone.

Tests (D016): one test for the move of the global setting to the items (a database of version 5), one for items with different settings at one dose time, and three for the alarm plan (the last one for an alarm that the system refuses). The test of the limit across a change now uses the setting of the item. The other follow-up tests use the new identifier.

Not verified: the app build on this Mac, and AlarmKit. Nobody ran an alarm. The system documents no limit of alarms, so 64 is a safe size and not a measured one. It needs a check on a real iPhone with iOS 26: the permission prompt and the refusal, an alarm in silent mode and in a Focus, the "Stop" button, the "Taken" button with the iPhone locked, the alarm of two items, a record before the time (no alarm), a rename, a change of the time, the alarm after a restart, and the order of the alarm and the notification of another item at the same time.

## D080 · 2026-10-14 · No "Which Reminder?" sheet when every dose already has a record (replaced by D081)

Agent decision, after a test on the maintainer's iPhone. The maintainer tapped an evening reminder after both of its doses were recorded. The reminder came from an older plan, so the app showed "Which Reminder?" with two rows that said "Taken" and the footer "Your plan or the clock changed". The maintainer could not understand it, and the sheet had nothing to ask.

- When every candidate of a tapped reminder is of today and has a record (taken or skipped), the app opens Today on those rows and shows no sheet.
- A candidate of another day, or a candidate with no record, still opens the sheet (spec 8.3, T15, T24).

## D081 · 2026-10-14 · A tap on a reminder always opens Today

Maintainer decision, after a test on the iPhone. The maintainer saw the "Which Reminder?" sheet, could not understand it, and asked why the app has this page at all. D081 replaces D080, which removed the sheet only for doses that already had a record.

- A tap on a reminder always opens Today. It never shows a sheet.
- When some candidates of the reminder are doses of today, Today scrolls to their rows (D028). Otherwise Today opens with no focus.
- The tap records nothing. A dose of an earlier day is recorded from History. An old reminder never writes the dose of today (T15, T24).
- The "Taken" action (D034) does not change. The locked-iPhone path (T40) and the storage-error path do not change. Neither leads to a sheet.
- Removed: the sheet, `ReminderChoice`, the `choice` field of the Today state, the record and retry code of the sheet, and seven String Catalog keys in six languages. `ReminderTapResolver` stays, because the app uses it to find the doses of the reminder and the "Taken" action uses it.
- Spec 8.3 and the rows T15 and T24 follow this rule. The debug scenarios `expiredTap` and `crossDayTap` check it.

Not verified: the app build on this Mac. CI builds the app. The tap needs a check on a real iPhone.

## D082 · 2026-10-14 · Suggestions on the add and edit screen have the app tint

Maintainer decision on 2026-10-14. This replaces the part of D076 about suggestions. The maintainer wants every suggestion on the add and edit screen to show in the app tint, so it reads as a suggestion and not as text that the user typed.

- The name proposals under the name field and the form proposal ("Use Softgel") have the app tint.
- The smart completion candidates of the amount and the note are bordered capsules in the app tint.
- The other rows of D076 keep the text color.

## D083 · 2026-10-14 · A record finishes the reminder run before the system can suspend the app (the open-removal window replaced by D086)

Agent decision, after a test on the maintainer's iPhone. With "Remind Again: Until Recorded", follow-ups kept coming after the user recorded the dose with the circle on Today. The plan and the engine were correct.

- Cause: the reminder run after a record was fire-and-forget. When iOS suspended the app before the run ended, the pending follow-up requests stayed.
- `refreshReminders` holds a background-task assertion until the run ends. The expiry handler also ends it. The run stays off the main actor.
- `takeReminder` (the "Taken" action) awaits the reminder run before it returns, as the widget and Watch paths do. The action limit of `ReminderTapDelegate` bounds the wait.
- `FollowUpEngine` does not change. The ledger can keep an identifier whose removal did not run, if the process stops between the save and the removal. That window stays as it was. A second removal can delete a wanted replacement that has the same identifier, as `ReminderEngine` documents.

Not verified: the app build on this Mac, and the behavior on a real iPhone. CI builds the app. No new test (D016).

## D084 · 2026-10-14 · Every reminder names only the doses that Today shows (the removal ledger and its blocked identifier replaced by D086)

Agent decision, after a bug on the maintainer's iPhone (TestFlight build 4, version 1.0.0). A reminder named an item that the maintainer had archived. The maintainer made this a hard requirement.

The rule:

- Every reminder must be correct and must name only doses that Today shows. This holds for the series reminder, every follow-up, and every alarm, pending or delivered.
- After a change is saved (archive, delete, pause, end date, edit of the time, a record), no pending request and no delivered notification names an item that is archived, deleted, paused, or ended, or a dose that has a record.
- Each run of the notification queue enforces the rule. A save is not complete for the user until its run ends.

Cause:

- The pending requests were correct. A package test with the real plan and both engines (archive one item of two at 08:00) showed that the series request and the follow-ups were replaced with the text of the remaining item.
- The delivered first reminder was not checked. `FollowUpEngine` removed a delivered follow-up with old text, and kept a delivered series notification on purpose (D029: "it was true for its time"). The notification system keeps the text that the app set before, so a first reminder that the user had not cleared kept naming the archived item in Notification Center (`FollowUpEngine.swift`, the filter of `center.delivered()`, before this change).
- The archive, delete, edit, and pause paths ran the engines in an unstructured task with no background assertion. D083 added the assertion only to `refreshReminders` (after a record). The system could suspend the app between the commit and the removal. `AppStore.reconcileReminders` was the one call that every path shares.
- The engines add a replacement before they remove. A replacement that does not land (the system drops it with no error) left the old request with the old names.

Fix:

- `FollowUpPlan.deliveredSeriesContent` gives the names that a delivered series notification may have now: the open items of its time and date whose series request the plan sets. A repeating request has no date, so the date of the delivery gives it (`PendingReminder.deliveredAt`). `FollowUpEngine` removes a delivered series notification whose text differs, and one with no open item left. This replaces the privacy-only rule for delivered first reminders (D029).
- After the adds, each engine reads the pending requests again. For a wanted identifier whose pending request has other `userInfo` or text, the engine first adds the replacement again. If the old request is still there, the engine removes it through the ledger. After the system confirms the removal, the engine adds the replacement in the same run, when its fire time is still to come and there is room. So the dose time does not pass with no reminder. The cleanup of a stale request runs in every authorization state, and only the additions need the permission. With notifications off, the stale request still goes, so it does not fire when the user turns them on. An identifier whose removal the system did not confirm stays blocked, as for every removal. The removal is only for a replacement that did not land twice. It never runs before a replacement that did.
- The expected names of a delivered series notification are the open items of its time and date in the order of the schedules, the order of the series text. So a merged group (a device series and a fixed zone that equals the device zone) gives the same text as the request. Only another set of items, or no open item, makes it stale.
- The date of a delivered repeating notification is the latest date on its weekday whose planned instant is at or before the delivery, with the early tolerance of `ReminderTapResolver`. A 23:59 reminder that the system delivers at 00:01 belongs to the day before.
- `AppStore.reconcileReminders` holds a background-task assertion (`BackgroundAssertion`) until the run ends, so archive, delete, edit, pause, restore, and launch runs all finish before the system can suspend the app. `refreshReminders` keeps its own assertion, which starts before its task.
- Alarms: `AlarmEngine` already cancels a waiting alarm that the plan does not have, and the plan has no alarm for an archived, paused, ended, or recorded dose. A ringing alarm cannot be stopped by a run, and it is not changed.
- Spec 8.2 has an amendment for the delivered first reminder.

Limits:

- If a removal of a stale request is sent and the system does not confirm it in the run, the run cannot add the replacement, and the next run does. The request can go away before. This needs two dropped adds in a row.
- The cross-engine removal race that `ReminderEngine` documents (`pendingCount(afterRemoving:)`, where the series engine removes follow-ups without the ledger) is not changed.
- A delivered notification of an older day (outside the window of the plan, about two days) names no dose that Today shows, so the next run removes it.
- A recorded dose removes a delivered reminder that named it, also when it named other items. The next reminder names the others.

Not verified: the app build on this Mac. CI builds the app. The behavior on a real iPhone needs a check: archive an item that a delivered reminder names, and look at Notification Center. One test (D016) covers the archive of an item in a shared time group, for the pending and the delivered series and follow-up requests.

## D085 · 2026-10-15 · Settings for all items, plain copy, and a short add and edit screen

Maintainer decision on 2026-10-15, after the use of build 5 (version 1.1.0, TestFlight). The maintainer gave four points in one message. This replaces the line of D079 that says Settings has no rows for "Remind Again", and the "Rejected" line of D079 about a global switch for the alarm. A global setting that replaces the setting of each item stays rejected. The new rows only set every item at once, and each item keeps its own value.

1. Settings for all items.
   - Settings has a section "For All Items", after "Reminders". It has a row "Alarm" (from iOS 26), a menu "Remind Again", and a menu "Every". "Every" shows only while at least one item has "Remind Again" on. The menus have the same choices and the same words as the add and edit screen.
   - A row shows the value that every active item with a time has. When the items differ, the row says "Varies". "Alarm" is then a menu with "Varies", "On", and "Off". A choice sets every active item that has a time. "Every" sets only the items that have "Remind Again" on, because an item with it off has no interval to change.
   - "Has a time" means that the item has a schedule. An archived item and an item with no time stay as they are, as on the edit screen (D079).
   - One transaction in `MaruDatabase` writes all items (`LocalStore.apply(_:toTimedItemsAt:)`). Then one run of the reminder engines follows, with the report of a save. An item that already has the value does not change.
   - The follow-up rules of D039 and D079 hold for a bulk change. An item whose "Remind Again" changes gets `followUpChanged` = the time of the change, as a save of the edit screen does, so the limit of 12 for a dose holds across the change. An item whose value is the same keeps its old change time.
   - "Alarm" asks for the AlarmKit permission at the first turn-on, as the item switch does. A refusal changes nothing and shows the alert "Alarms Are Off" with "Open Settings". Below iOS 26 the row is hidden.
   - A new item starts with the value that the user last chose in Settings (`reminders.newItem.*` in `UserDefaults.standard`, D014). It starts with "Remind Again" off, 30 minutes, and "Alarm" off until the user chooses. This is a reminder style and not a dose or a time, so spec 2.1 still holds. The draft shows the value before the save, and the user can change it. The start value does not count as a change of the draft. The alarm start value applies only from iOS 26.
   - Analytics (D077): `setting_changed` has three new fixed fields: `all_alarm` (yes or no), `all_remind_again` (`off`, `1`, `2`, `3`, `5`, or `until_recorded`), and `all_remind_again_minutes` (`5`, `10`, `15`, `30`, or `60`). They hold no item data. `PRIVACY.md` and spec 11 list them.

2. Plain copy. The maintainer said the text of Settings and of the add and edit screen is too formal and hard to understand.
   - The choice "Until Recorded" is now "Until I Record It". "Record" stays, because the button and the circle say "record" and the app records and does not claim intake (D068, D058).
   - The footers that explain how the app works are gone: "Only for doses with no record.", "Turn off to keep item names out of reminders.", and the long text under "Alarm". The one limit that matters stays as one short line under "Remind Again": "Reminds you up to 12 times, until 1:00 AM."
   - The alerts and the footers of "Your Data", "Share Usage Statistics", "Send Feedback", the camera alert, the alarm alert, and the save alert are shorter and use everyday words. The alert titles lose "Maru can’t" and say what is wrong ("Camera Is Off", "Alarms Are Off", "Couldn’t Save").
   - The plan line keeps "with no end date" (spec 2.1, T03).
   - One word for one thing: "Remind Again", "Every", "Alarm", "Reminders", and the counts and intervals come from one place in the code (`ReminderOptionText.swift`), so Settings and the edit screen cannot differ.

3. A short add and edit screen. The first view has: the name and the type, the plan with its times and repeat days, and the section "Reminders" ("Alarm", "Remind Again", "Every"). One row, "More Options", opens a page with the optional details: "Amount", the look of the item (form, color, and photo), and "Note". The row shows the amount and the note as its value. This follows Apple Health Medications, Reminders, and the alarm editor in Clock. The photo work stays on the first page, so it does not stop when the user goes back. The smart completion candidates for the amount and the note are on the page "More Options", and the candidates for the times stay under the times. Settings groups its rows as: "Reminders" (state, names), "For All Items", "Display", usage statistics, "Your Data", feedback, tips, and "About". Each section has at most one footer.

4. Six languages. All changed text is in English, zh-Hans, ja, es, de, and ko, with a translator comment, and the keys that no code uses any more are gone. The voice: zh-Hans like a friendly Chinese app, ja polite and light, ko "해요체", es "tú", de "du". The text is a draft until a native speaker reads it (`docs/localization-review.md`). A second pass followed a review of the zh-Hans text, in every catalog (app, notifications, Watch, widgets, and `InfoPlist`): one term for an item (药品), supplements are 保健品, save is 保存, and the tone is casual (没, 还没, 点, no 请, 尚未, or 无法). The other four languages got a lighter pass: ko uses 해요체 everywhere (the Watch text no longer uses 합니다체), and es and de lose perfect-tense and stiff phrases.

Not verified: the app build and the screens on this Mac. CI builds the app. The layout needs a check on a real iPhone: the page "More Options" (the pickers, the photo section, the candidates, VoiceOver, and the largest text sizes), the Settings section at the largest text sizes, the "Varies" state with items that differ, a change of "Remind Again" for all items with the reminders in Notification Center, and the alarm permission from Settings. One test (D016) covers the bulk write and the change time.

## D086 · 2026-10-15 · Notifications are checked against a simulator, and a lost removal no longer blocks a request for good

Agent decision, after a second report from the maintainer's iPhone (TestFlight build 6, version 1.1.0, with D083 and D084). The maintainer's goal: every notification of the app is always correct.

Evidence on the iPhone, in Sydney time:

- The notification of 21:00 named Magnesium Glycinate, Coenzyme Q10, and Fish Oil. Fish Oil was archived a day before, and Magnesium was recorded at 18:44.
- The notification of 09:00 stayed in Notification Center after the three doses were recorded at 14:17.
- A save of a fourth time (23:00) showed "Reminder Not Set".

Cause, proved with the simulator:

- `ReminderEngine` and `FollowUpEngine` write the identifier of a removal in the ledger (`UserDefaults`) before they call the system. An identifier in the ledger is blocked: the engine does not add it, and it does not send the removal again (`ReminderEngine.remove`, `ReminderEngine.run`, the filter `additions`, D083 "That window stays as it was").
- If the app stops between the ledger write and the system call, the removal never happens. The ledger keeps the identifier, also across a restart and an update of the app, because it is in `UserDefaults`. The old request stays pending with its old text, and no later run replaces it, because the identifier is blocked. A repeating request fires every day, so the stale text comes back every day.
- The run then reports `notRegistered` for the blocked identifier, and the app shows "Reminder Not Set" at each save.
- The simulator stops a run at each of its calls. Before this change, a stop at one call after a record, an archive, a delete, or a change of "Remind Again" left a wrong request that no run repaired (`KillSweepTests`, `StuckRemovalTests`). The record of Magnesium before 21:00 gives exactly the first notification above: the daily request of 21:00 keeps the names of Fish Oil and Magnesium.
- D084 tested only the case where every call of a run ends. D083 and D084 reduce how often a run stops, but they cannot make it zero: the system can end the process at any call.
- Not proved: why the notification of 09:00 stayed. In the simulator, a run that completes removes it, also with a blocked identifier. The simulator does not model a run that never starts or never ends. Two cases remain open: a system call of UserNotifications that never returns, and a hang that the 3-second limit of item 5 does not reach. A hang inside AlarmKit, which would block the queue (every run waits for the run before it), is now limited by item 5. The new log of the runs (below) shows these cases on the next device check.

The design (the engines keep their plan and their rules, and the removal ledger is gone):

1. Every request that the app gives the system has a fresh identifier: the base identifier of the plan and a generation, `<base>|g<counter>r<4 hex>` (`RequestGeneration`, `GenerationCenter`). The counter is durable and only grows: the app saves it in the `UserDefaults` of the App Group before each add, under a lock (`DefaultsGenerationCounter`), so no restart and no change of the clock can repeat or reorder a number. All adds run in the app process. The 4 random hex digits make two identifiers differ also when two counters ever meet. Order is the counter only. A build with no App Group uses the standard defaults. The system never sees an identifier twice, so a removal can name only requests that the system held when the app read them. A removal that the system does late, and a removal that a run sends again, can never delete a newer request with the same base. This removes the race class and the need for a ledger. The ledger, the 5-second rule, and `RemovalLedger` are deleted. The engines keep only a state of the process: the bases that they asked the system to remove and that it still held at the last read. The old keys in `UserDefaults` go at the first open (`LegacyRemovalLedger`).
   - The plan, the tap resolver, and the engines use base identifiers. The generation lives at the border to the system. Each run prunes first: for each base only the request with the highest counter stays, and the older ones are removed. A stop between an add and its removal can leave two generations of one base until the next run. This rare window is accepted: a second banner is better than a missing one. The check of the oracle allows it only while the system holds an open removal. An add gives a fresh identifier, and it removes the older requests of the base only after a read shows that the system holds the new one. A dropped add keeps the old request, and the engine replaces it as before (D084). A removal removes every request of the bases that it names.
   - The limit of 64 counts physical requests. When an add would pass it, the older request of that base goes first (remove, then add, for that base only). If it still does not fit, the add fails, the request is not dropped silently, and the schedule shows as not set. The room rules of the plan keep this rare.
   - Move from build 6: build 6 made requests with no generation. At the first run of this build, a request without a generation, with the prefix of the engine, looks like a request with other content. So the engine adds the request with a generation, and the add removes the old one. A request that the plan does not have is removed. Each engine marks its move as done in `UserDefaults` (`DefaultsLegacyMigration`) when the system holds none of its legacy requests. A removal that build 6 sent and the system did late can name only the old identifier, so it cannot delete a new request. A delivered notification of build 6 follows the same content rules as every delivered notification.
   - Each run removes every pending request that the plan does not have, matched by base, so a removal that the system did not do is asked for again by the next run. No state can block that.
   - "Taken" action identity (D034) is in `userInfo`, not in the identifier. The counting of follow-ups (D039) uses the base. Requests of an older build have no generation, and each is its own base, so the first run of a new build replaces them.
   - Replacement needs room for one more request until the removal of the old one shows. The reserve of 2 in the follow-up plan (spec 8.4) covers this, because a replacement is one request at a time.
2. A delivered notification goes when its dose is not shown by Today. A dose is shown on its day in its own time zone, and on the day after until 01:00 of that zone, because the "Taken" action of a follow-up records it until then (D034, D039). Code: `FollowUpPlan.isShownByToday(_:in:)` and the zone in the identifier.
3. `FollowUpEngine` takes a clock, as `ReminderEngine` does, so a test can run it with a virtual clock.
4. `AppStore.reconcileReminders` logs each failed run with `os.Logger` (subsystem of the app, category `reminders`). It logs the error type and counts of schedules, not-set schedules, open removals, and follow-ups. It logs no item name, dose, time, or ID (spec 10). The error still goes to the caller, as before.
5. Every AlarmKit call of the alarm path (`waiting`, `schedule`, `cancel`) has a limit of 3 seconds (`TimedAlarmCenter`). A call that does not answer throws `AlarmRunError.timedOut`, and `AppStore` logs its name in the category `reminders`. The run then fails open as D079 says: the cover is empty, and every item with an alarm gets its notification. A hang inside AlarmKit can no longer block the one queue of runs. `AlarmCenter.waiting` now throws, and `SystemAlarmCenter` no longer turns a read error into an empty list. The read of `AlarmManager.shared.authorizationState` is a synchronous property and has no limit.
   - Alarms have generations too. An alarm identifier is 12 bytes of content and 4 bytes of generation, taken from the same durable counter. The plan has the content. The engine gives each alarm that it schedules a new generation, and it matches the waiting alarms by content. Each run cancels every waiting alarm whose content the plan does not have, and every older alarm of one content (the highest generation stays). So no cancel, late or repeated, reaches a newer alarm.
   - A call that timed out keeps running in the background. When a `schedule` returns after its limit, `TimedAlarmCenter` checks its exact identifier (content and generation) against `WantedAlarms` and cancels the alarm when the current plan does not hold exactly that alarm. `WantedAlarms` has the ids of the alarms that the system holds and of the alarms that a call of the run is scheduling. So a late older generation is cancelled also when its content matches, and an alarm of a dose that has a record by now is cancelled too. While AlarmKit hangs, a waiting alarm cannot be cancelled, so an alarm and a banner can both ring (D079 accepts this).

Why not rebuild all requests as dated one-shot requests: a repeating request keeps a stable plan correct while the app does not run for days (spec 8.1). Dated requests would stop after their last date, and the user would miss doses. Both kinds have the same limit: the content is true only as long as the run after each change ends. The design makes that limit as short as it can be on iOS: every run compares the whole system state with the database and repairs the difference, and no saved state can block a repair.

A reminder that was delivered and then recorded (maintainer requirement): a reminder is delivered at 12:00, and the dose is recorded at 13:00 in the app, with the "Taken" action, from the widget, or the next morning for yesterday. The run after the record removes the 12:00 notification from Notification Center. If it named two items and one is recorded, the old notification goes, because it names a closed dose. The open item stays on Today, and the run posts no new banner for it. Follow-ups follow their own rules (D039). Scenarios in `ScenarioTests` check this with the oracle.

What no design can guarantee on iOS:

- Between a change and the end of its run, a pending request or a delivered notification can be wrong. If the app is suspended or stopped in that time, the content stays wrong until the user opens the app again. The window is the run, which takes milliseconds to a few seconds. D083 and D084 hold a background-task assertion for it.
- iOS can refuse to start the app. For example, after a restart before the first unlock, the app cannot read the database, so no run happens.
- A notification that fires in this window shows the old content. It can name an item that is recorded or archived.

The failure alerts ("Reminder Not Set", "Reminders May Still Be On"), maintainer decision of 2026-10-15:

- First, the failure must not happen: the change above removes the stuck state that caused it.
- If an alert still shows, it says in one plain sentence what went wrong and what did not get done: "Your change is saved, but the reminder for this item isn't set yet." For a removal: "Your change is saved, but the old reminder may still go off." The title for "not set" and "not confirmed" is "Reminder Not Set". "Reminder Not Confirmed" and the line "Maru checks again when you open it." are gone.
- The alert has two buttons: "OK" and "Send Feedback". "Send Feedback" opens the form of Settings in Safari (D037). Maru attaches nothing. The alert for too many times (`tooMany`) has only "OK", because it is a limit of the plan and not a failure.
- The text is in six languages, in casual tone.

The harness (maintainer request, so it goes beyond the test limit of D016):

- `Packages/MaruKit/Tests/MaruNotificationSimulationTests/`: a simulator of the notification system (`FakeNotificationCenter`) with pending and delivered sets, repeating and dated triggers, delivery by a virtual clock, replace by identifier, removal that completes late or never, dropped adds, the 64 limit, permissions, a time zone change, a process that stops at any call, and an app that does not open for days. The real `ReminderPlan`, `ReminderEngine`, `FollowUpEngine`, `AlarmPlan`, `AlarmEngine`, and a `LocalStore` on a real SQLite file run inside it, in the order of `AppStore.reconcileReminders`.
- `Oracle` compares every pending request, every delivered notification, and every alarm with a list of what the user did. It never reads the engines. It checks after every run of every scenario. The invariant: each notification names exactly the open doses of its occurrence, and each open dose with a time has a reminder before its time.
- The scenarios and the gaps between the simulator and real iOS are in `docs/research/2026-10-15-notification-correctness.md`.

Not verified: the app build on this Mac (CI builds it), the alert in the six languages on a display, and the behavior on a real iPhone. A check on the iPhone: install the build, open the app, and read the log of the category `reminders` in Console after a record and an archive.
## D087 · 2026-10-15 · Today rows are 4 points lower

Maintainer decision on 2026-10-15. The rows of Today had too much space above and below the text. Each row is now about 4 points lower: the row content takes 2 points of the list inset at the top and at the bottom. The text sizes, the icon, the record circle, and the 44-point touch areas do not change. The maintainer checks the height on the iPhone.

## D088 · 2026-10-16 · A dose of an as-needed item stopped every reminder run (the midnight theory was wrong)

Agent decision, after the third report from the maintainer's iPhone (TestFlight build 7, version 1.1.0). The alert "Reminder Not Set" came again after a save at 23:53 (Sydney). The maintainer had added a time at 00:00 to Vitamin B Complex. Build 6 had shown the same alert after a save of 23:00 for Coenzyme Q10.

Evidence:

- The live log of the iPhone (build 7, 23:57) says `Reminder run failed: invalidData`, right after `Got 2 pending notification`. So iOS refused no request. The run stopped before it changed anything, because the read of the plan threw. The iPhone held only 2 requests of Maru.
- The first theory was a request at or near midnight that iOS refuses. The simulator now validates triggers like iOS and has 90 scenarios at 23:50, 23:53, and 00:05 (`MidnightTests`). They all pass on the code of build 7. The theory is rejected.
- `LocalStore.reminderPlan` reads the closed occurrences with a query that decodes `occurrence.slotID` as a required value. An as-needed dose has no slot (D021). Its taken record has a state row, so the query returned it, and the decode threw `invalidData`. One taken as-needed dose in the window of the plan made every run fail. The query of the history already had `slotID IS NOT NULL`. This one did not.
- Reproduced on the code of build 7 by two tests: a store test with one taken as-needed dose (`FaultIsolationTests`), and `UpgradeTests`. `UpgradeTests` opens a database that version 1.0 build 4 left, with an as-needed item and its doses, and runs the whole queue. Both failed with `invalidData` before the fix and pass after it.
- The same cause explains the earlier reports. A stale notification, a missing reminder, and "Reminder Not Set" all follow from a run that fails before it replaces anything. D086 found real faults in the ledger, and its fix stays. But it could not show this fault, because no scenario had an as-needed dose.
- Not proved on the device: that the maintainer's database has an as-needed dose in the window. Ibuprofen-type items are as needed in the maintainer's list, so this is likely. The device check below shows it.

The fix:

1. The query of `reminderPlan` skips occurrences with no slot (`LocalStore+Reminders.swift`).
2. Fault isolation for the reminder run only. `LocalStore.planInputs` loads each item and each schedule for the reminder plans (the series reminders, the follow-ups, and the alarms). An item or a schedule that does not load is skipped and logged. The plan reports each such schedule, and each schedule of a skipped item, as not set (`ReminderProblem.unreadable`, `ReminderPlan.unreadable`). While one exists, the engines remove no request, no delivered notification, and no waiting alarm, because the plan does not know what the schedule wants. The other items keep and change their reminders. Today, History, My Items, the widget, the occurrence generation, and every write keep the strict load: a row that does not load shows the storage problem and hides nothing (spec 7.3). No item changes its kind because its schedule did not load. A first version of this change isolated every read. A review found that it would hide an item with its records and would make an item with a broken schedule look as needed, so it was narrowed.
3. Named rules. `StoredDataRule` (in `MaruCore`) has fixed words such as `version_order`, `item_follow_up`, and `occurrence_row`. A decode failure carries one. The reminder reads throw `PlanReadError` with the storage error and the rule, so the rule comes with the error and not from a global value. The log says `A stored row did not load and the reminder run skipped it. Rule: <word>`, one line for each rule in each process. A failed run logs `Reminder run failed: invalidData. Rule: <word>`. No log line holds a name, a dose, a time, or an ID.
4. One request that iOS refuses does not stop the others. The engine already added each request on its own and read the result. `SystemReminderCenter` now logs the error domain and code of a refused add. `oneRefusedRequestDoesNotStopTheOthers` shows that the other schedules stay and only the refused one is "not set".
5. Analytics. `core_error` gets the codes `invalid_data` (a stored row stopped the run) and `row_skipped`, and an optional `rule` with a fixed word. A skipped row gives one `row_skipped` event for each rule in each process. `PRIVACY.md` and spec section 11 say so. The privacy label does not change: the codes are "Other Diagnostic Data" as before.

Prevention (the maintainer asked that this never happens again):

- Upgrade fixtures. `Fixtures/v5-build4-1.0.sqlite` is a database that version 1.0 build 4 left (built with the code of commit `28c4d70`, see `make-v5-build4-1.0.swift.txt`): seven items, 4 daily times with edits on one day and across midnight, an item with weekdays, an item of every other day, a fixed zone, doses with trailing spaces, records for a week, an archive, and as-needed doses. `Fixtures/v6-build7-1.1.sqlite` is the same database after the first open of build 5 (the global setting copied to the items, not confirmed) and the bulk switches of build 6. `UpgradeTests` opens each file, runs the whole reminder queue with and without a legacy setting, moves the clock over midnight, and runs again. Every future migration adds its own fixture (`docs/process.md`, "Release checks").
- Random edits. `RandomEditTests` runs 40 seeded sequences of 30 user steps at random clock times: add an item with 1 to 4 times (23:xx and 00:xx too), add and change times, archive, restore, rename, bulk "Remind Again" and alarm, records, undo, as-needed items and doses. After each step the run must end with no error and no "not set".
- `DiagnoseDatabaseTests` finds the broken row in a copy of a device database (`MARU_DIAGNOSE_DB=<file>`). It prints rules and dates only.
- Release checks in `docs/process.md`: no fix of a reminder or of stored data is done until the live log of the iPhone shows runs that end with no error.

What failed in our process:

- We fixed what the first theory named and did not read the failure. Build 6 showed "Reminder Not Set". We found a real fault (the ledger), proved it, and shipped. We had no log of the failure from the device. So we could not see that the run threw before it changed anything. The log came only after the third report.
- The simulator tested the logic with data that the tests made. All its items had a schedule. Real databases hold items of every kind, from three versions of the app. A check against only generated data cannot find a fault in how stored data is read. The fixtures and the random edits close this.
- A read that fails for one row failed for all rows. The design had no limit to the damage of one bad row. Now the reminder run has one. The screens keep the strict rule, because hiding stored data is worse than showing the storage problem.
- The alert text did not tell a failed run from a refused request. The log now names the rule, and the statistics tell us before the user does.

What the fake still cannot model:

- Whether iOS gives an error for a calendar or interval trigger that cannot fire. The fake rejects it to be strict. Apple documents the 60-second minimum for a repeating interval trigger and does not document the other case.
- The exact `interruptionLevel` and `userInfo` that `getPendingNotificationRequests` returns, real timing of removals, Focus, and AlarmKit (as in `docs/research/2026-10-15-notification-correctness.md`).
- Data that no fixture has. A database that a person made by a path that no test knows still needs the log and the statistics.

Not verified: the app build on this Mac (CI builds it; the change to `AppStore` and `AppModel` is only compiled there) and the behavior on the iPhone. Device check: install the build, open it, save an item with a time at 00:00, record a dose, take an as-needed dose, and read the live log (`uvx pymobiledevice3 syslog live --udid <UDID>`). The lines must be `Reminder run: ...` and none must say `failed` or `did not load`.

## D089 · 2026-10-16 · Phase A of the reminder plan: nine findings of the Codex cross-check, fixed or narrowed (the old version of an undone dose in N1 changed by D095)

Agent decision, branch `leon/phase-a-correctness`. It follows the audit and the cross-check of 2026-10-16 (`~/Documents/Research/maru/2026-10-16-reminder-and-tracker-audit-claude.md`, section F, and the findings N1 to N9). Each finding was read in the code first. Each has a test. I saw the test fail before the fix for N1, N5, N7, N9, N4, and the day-cycle plan (for the last two, with the longer reach switched off). For N2, N3, and N8 I did not run the test against `main`: the failure follows from the code. It changes spec 4 (alarm), 8.1, and 8.3 by amendment. It narrows part of D047 and D079 (the reach of dated requests and of alarms).

| Finding | Real? | What failed | The fix |
|---|---|---|---|
| N1 | Yes | After an undo and a plan edit on the same day, the stored occurrence keeps its old schedule version (an occurrence with an event never changes, D019). The "Taken" action of a series reminder of the new plan found it by slot and date and recorded into it. A follow-up carried the old version, so its check passed too. | `LocalStore.actionTarget` requires that the stored occurrence has the schedule version that the plan of now gives the dose, for every action. A mismatch records nothing, and the notice says so. Test: `takenActionAfterUndoAndAPlanEditRecordsNothing`. |
| N2, N3 | Yes | An alarm item has no banner (`needs = .alarm`). Its alarms came for 7 days only, so 7 days with no run of the app ended the reminder. The list was cut at 64, and a dose that the cut removed did not mark its item as failed. | A time and a weekday that has the same open items on every date of the next 28 days is one repeating alarm of AlarmKit (`Alarm.Schedule.relative` with `.weekly`, on the clock of the device). It never runs out. A dose of a fixed zone, of a plan with a day cycle, or of a weekday with a record before its time keeps one alarm for each date, for 28 days. The repeating alarms come first in the limit of 64. A dose that the limit cut and that is due within 7 days marks its item as failed, so the item gets its banner (`AlarmPlan.cutItems`). The "Taken" button of a repeating alarm has no date. The button finds today's dose when its time has come (`AlarmRequest.plannedDate(ofSeries:)`) and else records nothing. Tests: `CoverageTests` (daily, weekly, record before the alarm), `AlarmPlanTests`. |
| N4 | Yes | A record before the dose time takes that weekday out of the repeating request. Only the next two dates of the weekday got dated requests, so later weeks had no reminder until the app ran. | The weekday gets dated requests for up to 8 weeks when the budget has room (`ReminderPlan.horizons`). A repeating request cannot skip one date, so a gap after the last date remains, and the plan reports it. See "Limits". Test: `aRecordBeforeTheTimeKeepsTheRemindersOfTheLaterWeeks`. |
| N5 | Yes | With "Alarm" on at the first save, the run that the save starts has no series request, so it never asked for the notification permission. Follow-ups and the banner of a failed alarm then had no permission. | `ReminderEngine` asks when the plan has a reminder or an item with an alarm. Test: `anAlarmItemAtTheFirstSaveAsksForTheNotificationPermission`. |
| Day-cycle plans | Yes | The dated requests stopped after 7 due dates. | Up to 28 due dates, when the series requests of the plan stay within 32 of the 48 (`ReminderPlan.extendedBudget`) and no series that the minimum keeps is lost. The follow-ups keep the rest of the room. The item detail names the date of the last reminder (`ReminderPlan.coverageEnds`). Test: `aDayCyclePlanRemindsOnMoreThanSevenDueDatesWithoutTheApp`, and `datedRequestsReachFurtherWhenTheBudgetHasRoom`. |
| N6 | Yes (by reading) | `AppModel.show` started the reminder run only when Today loaded. One damaged row that Today shows as a storage problem also stopped every reminder. | The run starts when the read ends in a failure too. The plans read their rows with their own isolation (D088). Not tested: it is app code, and CI only builds it. |
| N7 | Yes | The plans decoded every occurrence row in one call. One bad row failed the whole plan with `invalidData`. | The plans skip the row, log its rule (`occurrence_row`), and mark the schedule of its slot as unreadable, so the engines remove nothing for it. Test: `aBadOccurrenceRowDoesNotStopTheReminderPlans`. |
| N8 | Yes | A restore that the system stopped between its two epoch changes leaves the epoch odd, and every widget action refuses an odd epoch for good. | `LocalStore.init` makes an odd epoch even. No restore runs in a process that has just opened its store. Test: `anInterruptedRestoreDoesNotLeaveTheEpochOdd`. |
| N9 | Yes | When an alarm call timed out, the item got its banner, but the id of the late call stayed in the wanted set. The alarm that the system registered later rang beside the banner. | A failed call removes its id from the wanted set, so the late check of `TimedAlarmCenter` cancels the alarm. Test: `aLateAlarmThatTheRunGaveUpOnIsCancelledBesideItsBanner`. |
| "Not recorded" | Yes | The notice said "Open Maru to record it." with no reason. | Two plain lines in six languages: "This reminder no longer matches one dose of today. Open Maru to record it." and "Maru could not save the dose. Open Maru to try again." |

Limits (stated, not hidden):

- A weekday that a record took out of the repeat, a plan with a day cycle, and a dose of a fixed zone have dated requests or dated alarms only. They end at the date of `coverageEnds` (28 days for alarms), until the app runs. Every run of the app sets them again, so the limit matters only when the app does not open for weeks. The item detail states the date when it is near (within 21 days) or when the plan counts days.
- A dose that the 64-alarm limit cut beyond 7 days has no alarm and no banner until a later run.
- A repeating alarm that rings or counts down at the time of a run is not in the list of waiting alarms, so that run can schedule a second one with the same content. The next run cancels the older one (`AlarmEngine` keeps the highest generation of one content). Not seen on a device.
- The tap resolver does not know which items have an alarm. A banner for one item next to an alarm item at the same time can have the "Taken" action, and the action then finds two doses and records nothing. The notice now says why. Not changed here.

Not verified: everything that runs only on a device or in CI. The app code (`SystemAlarmCenter`, `TakeFromAlarmIntent`, `ItemDetailView`, `AppModel`, `ActionNotice`) has no compile or run on this Mac (rule: no `xcodebuild`). The use of `Alarm.Schedule.relative(.init(time:repeats: .weekly(...)))` follows the AlarmKit documentation and was not run. Device checks, with the live log of `docs/process.md`: save an item with the alarm on at a first install (the permission prompt comes); a daily alarm still rings after 10 days with no open of Maru; record before the alarm time (no ring that day, ring on the next day); "Stop" on a repeating alarm and a ring on the next day; "Taken" on the alarm of one item; the detail text of a plan every other day.

Tests added: `CoverageTests` (5), `aLateAlarmThatTheRunGaveUpOnIsCancelledBesideItsBanner`, `anAlarmItemAtTheFirstSaveAsksForTheNotificationPermission`, `takenActionAfterUndoAndAPlanEditRecordsNothing`, `aBadOccurrenceRowDoesNotStopTheReminderPlans`, `anInterruptedRestoreDoesNotLeaveTheEpochOdd`, and 3 unit tests of the plans. The harness got repeating alarms (`FakeAlarmCenter`, `Oracle`) and a permission prompt on the first save (`Phone.addItem`). The unit tests of `ReminderPlan` that state the minimum reach pass `longerReach: false`. The upgrade fixtures and `RandomEditTests` pass.

D089 follow-up after the Codex review of PR #83:

- The identity of an alarm now includes the schedule version that its "Taken" payload carries. An edit of the amount gives a new alarm, so the button passes the check of N1.
- `AlarmCenter.active()` lists alarms that ring or count down (`SystemAlarmCenter`: state `.alerting`). The engine does not register a second repeating alarm while the first rings.
- `TimedAlarmCenter` makes the id unwanted inside the lock that takes the continuation, when the limit wins. A late answer sees that state at once.
- `FaultIsolationTests` is serialized, because the skipped-rule log is global to the process.
- Not changed: with an unreadable schedule, the engine still keeps all obsolete alarms. The plan cannot map an alarm id to a schedule. Not verified on a device: `.alerting` is the only state that counts as active.

D089 follow-up 2: the engine keeps an alarm index (alarm id to schedule IDs, `AlarmIndex`; `DefaultsAlarmIndex` in the App Group defaults). The engine writes it when it schedules an alarm and prunes it when it cancels or when the alarm is gone. A run with an unreadable schedule keeps only the obsolete alarms of that schedule, and alarms with no entry (made by an earlier build). It cancels every other obsolete alarm. The index holds schedule IDs only, on the device. Test: `anUnreadableScheduleKeepsOnlyItsOwnAlarms`. This replaces the "Not changed" line of the first follow-up.

D089 follow-up 3 (Codex round 2): the engine reads the waiting and the active alarms from one call, `AlarmCenter.snapshot()` (`SystemAlarmCenter` reads `AlarmManager.alarms` once), so a "Stop" between two reads cannot hide a repeating alarm. The engine never stops a ringing alarm. An obsolete alarm that rings goes in a durable set (`AlarmIndex.quiet`, App Group defaults). The first run in which it waits again cancels it, also when an unreadable schedule keeps the other obsolete alarms. The Stop button of an alarm (`RunAfterAlarmIntent`) starts a reminder run one second later, so this cleanup comes soon. Tests: `theEngineReadsOneSnapshotOfTheAlarms`, `anObsoleteRingingAlarmIsCancelledAfterStop`. Not verified: the `stopIntent` and the state `.alerting` on a device, and that the app compiles (CI).

D089 follow-up 4 (Codex round 3): (1) The durable cancel-when-quiet set drops every id that the plan wants again, at the start of each run, and the engine removes a cancelled alarm from its own list, so a wanted alarm is scheduled again in the same run (rename A, B, A while the alarm rings). (2) The alarm index becomes complete by a one-time clean slate: until `AlarmIndex.isComplete` (App Group flag, set only after a run with no error), the first run treats every waiting alarm with no entry as obsolete, cancels it, and schedules the alarms of the plan again with entries. After that, an alarm with no entry is never kept, also with an unreadable schedule. An alarm of an unreadable schedule that had no entry is cancelled once, and the normal fail-open rule applies. Tests: `aWantedAlarmInTheQuietSetIsNotCancelled`, `theFirstRunMakesTheAlarmIndexComplete`.

## D090 · 2026-10-16 · Reminder actions: "Take All", "Skip", and "Remind in 10 min" (changes the group clause of D034, spec 8.3, and the "no group record" idea of D060) (group actions for one member only: D123)

Maintainer approval on 2026-10-16 (Phase 1 of `~/Documents/Research/maru/2026-10-16-reminder-tracker-plan.md`). The agent made the design choices below. It changes spec 8.3 and 4 by amendment, and it adds T53 to T55.

What the user sees:

- A reminder that names two or more items, with "Show Names in Reminders" on, has "Take All", "Skip All", and "Remind in 10 min". A reminder that stands for one item has "Taken", "Skip", and "Remind in 10 min". Every other reminder has only "Remind in 10 min". With the names hidden there is no group action, because the user cannot see what the action records. A reminder for one item keeps its actions with the names hidden (D034).
- A reminder with group actions names every item in its body: no "and N more" (review of PR #85). The user must see each dose that "Take All" or "Skip All" records. The short title stays, and the expanded notification shows the whole body. A reminder with no group action keeps the "and N more" form. Test: `aGroupOfFiveNamesEveryItemAndHasTakeAll`.
- "Take All" records every dose that the notification names and that is still open. A dose that has a record stays as it is. A skip is never replaced (D034). "Skip All" never replaces a taken dose.
- A dose that fails its own check is not recorded, and the others are. The notice then says how many were recorded: "Partly recorded", "2 of 3 recorded. Open Maru to check the rest." With no dose recorded, the notice is the "Not recorded" notice of D089. A success is silent, as for "Taken".
- "Remind in 10 min" makes one new reminder for the group, ten minutes later. It names every dose of the group that is still open, also an item with no "Remind Again". Until its time, the "Remind Again" follow-ups of that group wait. Later follow-ups continue. A record or a skip of the last open dose of the group ends the snooze. A second snooze of the same group replaces the first. After 01:00 on the day after the dose, a snooze is not set, and the notice says so.
- AlarmKit has no new button. See "Alarms".

How it works:

- Identity. A first reminder needs no new key: its revision names its doses, so "Take All" records all of them or none (a plan edit that keeps the names makes the delivered reminder older, and the action records nothing). A follow-up or a snooze with a group action carries `members` in `userInfo`: one entry for each named open dose, `<slot ID>=<schedule version ID>`, and no name (spec 10). The action keeps a dose only when the plan of now still has that slot with that version. A dose that does not stay is a dose that failed, and the other doses go on. A follow-up for one item keeps the item and version keys of D034 (the alarm button uses them).
- One category for each set of actions: `reminder.single.v2`, `reminder.group.v2`, and `reminder.snooze.v2`. The system looks a category up by its identifier when it shows a notification, so each identifier names one fixed set. `ReminderAction.register` in `MaruNotifications` registers all of them, because `setNotificationCategories` replaces the whole set. The old category `reminder.single` stays registered with its one action "Taken", so a notification of version 1.1 that is already delivered keeps its button (the legacy identity keys of D034 still work). No new request has it. A pending request of version 1.1 is replaced at the first run (its category is not one that this build knows).
- The record is `LocalStore.recordOpenDoses` in `MaruDatabase`. One transaction reads each named dose and appends an event only for a dose that is open, with the source `notificationAction`. It checks, for each dose, that the stored occurrence exists, that its date is today in its own zone (for a follow-up also the day before until 01:00, D039), and that it has the schedule version of the plan of now (D089). The result has one outcome for each dose: recorded, unchanged (taken or skipped before), or not recorded. A change of one dose between the read and the write does not undo the others. The app, the alarm button, and the harness call this one command.
- The snooze is a `SnoozeEntry` (series ID, plan date, instant) in the App Group defaults (`DefaultsSnoozeStore`). It holds no item ID and no name, and it needs no database change. `FollowUpPlan` turns each entry into one request with the identifier `<group>|snooze`, while the group has an open dose and the instant is before 01:00 on the day after the dose. After the instant, the entry still stands, so the delivered snooze stays while its text is true (I3). `FollowUpEngine` removes every entry that does not stand, at each run. So a record, a skip, an archive, or a delete ends a snooze, and the store needs no clean-up. A snooze is a request of the user: it takes room before the follow-ups under the limit of 64 (spec 8.4). The store keeps at most 12 entries.
- The snooze action does not need an unlock, because it writes no record. After it, the delegate removes the delivered notification, so only the new reminder stays.

Refactors done, with no change of behavior (the harness and the old tests guard them):

- H. `Phone.perform` drives the real use case on the real database. It replaces `takenFromNotification`, which wrote the record by hand. The fake notification center keeps the category and the level of each request. The oracle checks both for every pending request: a group category needs two or more named doses and shown names (I8), and the level is time sensitive (I9). It checks that a snooze of the user has one request, and that the follow-ups of its group wait (I10). `Phone` also checks that the stored state of each dose equals what the user closed (I11). A test seeds a wrong category and a wrong level, and the oracle finds both.
- R1. `ReminderPresentation` (category and level) replaces `hasTakenAction` and `isTimeSensitive`. One function, `PendingReminder.isCurrent`, compares a pending request with a wanted request in `ReminderChanges`, in `FollowUpEngine.isCurrent`, and in both `stale` checks. Before, the `stale` checks did not compare the action or the level. One builder makes the system content of both request types.
- R3. `recordOpenDoses` (above). Today and the widget keep their own paths: they record one dose that the user chose, with a time, an undo, an epoch, or a plan check that the notification action does not have. Moving them would add risk, and no feature needs it.
- R4. `OccurrenceRecord.nextEvent` makes the next event of a record. The notification action, the Today rows, and the widget use it. The Watch and the as-needed paths keep their own builders: the Watch needs an event ID from the request, and the as-needed paths are in the files of another change.

Refactors not done: R2 (one identity for every one-shot request: only the group actions need the list, and the single identity of D034 stays), R5 (the history range reader belongs to the tracker phase).

Alarms: AlarmKit supports a snooze button. `AlarmPresentation.Alert.secondaryButtonBehavior = .countdown` makes the secondary button a "Repeat" button, and `Alarm.CountdownDuration.postAlert` is the snooze time (documentation read on 2026-10-16). The alert has one secondary button, so a snooze button would replace "Taken" (one item) or "Open Maru" (several items). The system, not Maru, then restarts the alarm, so the plan does not own it, and the alarm engine sees a state (a countdown) that it does not model. That can give a second ring after the next run. I did not add it. "Taken" stays for one item, and "Open Maru" for several. A later decision can use `.countdown` for the alarm of several items if a device check shows that the engine copes.

Rare cases, stated and not chased (the maintainer's rule for this phase):

- A first reminder of an older plan, with the same names, gives no group record. A follow-up and a snooze record the doses that still match.
- Another path records a dose between the delivery and the tap: the group action leaves that dose as it is. The next run removes the notification.
- An item with an alarm at the same time as an item with a banner: the banner names only the second item, and its revision comes from both schedules, so the action finds an older plan and records nothing. This is the limit that D089 states. It also applies to "Take All". Not changed.
- A snooze of a notification that names a device-following item and a fixed-zone item in the zone of the device (D047) can give two snooze banners at the same time, one for each group of the follow-up plan.
- A record and an undo with no reminder run between them can bring a snooze back. The run after the record removes the entry, so this needs a stop of the app between them.
- A snooze needs the notification permission. With it off, the app stores the entry, and nothing is delivered. The entry goes at 01:00 on the next day.
- iOS shows at most four actions. The set has three. I did not check how the Watch shows three actions.

Strings (six languages, `MaruNotifications`): "Take All", "Skip", "Skip All", "Remind in 10 min", "Partly recorded", "%lld of %lld recorded. Open Maru to check the rest.", "Reminder not set", and "This reminder no longer matches a dose of today. Open Maru to see your plan." The text is a draft: a native speaker has not read ja, ko, es, and de.

Tests: 16 harness scenarios in `ActionTests` (Take All with one dose recorded, after a plan edit for a follow-up and for a first reminder, a skip kept, a record before the time, Skip and Skip All, a snooze that comes back, a record before the snooze fires, follow-ups that wait, a group snooze with one dose recorded, a late snooze that is refused, hidden names, the seeded fault of the oracle, and the update from 1.1), one database test for `recordOpenDoses`, and two plan tests for the snooze (`SnoozePlanTests`). Two mutations of the code (no pause of the follow-ups, no version check of a member) made the matching tests fail.

Not verified: the app target. No build on this Mac (CI builds it): `AppModel+ReminderAction`, `ReminderTapDelegate`, `AppStore`, `AppModel+Today`, `AppModel+Widget`, `SystemAlarmCenter`, and `MaruApp` changed. Everything that needs a device: the buttons on the lock screen and on the Watch after an unlock, the three actions in one notification, the second banner ten minutes later, a Focus, and the removal of the delivered notification after "Remind in 10 min".

Device check, with the live log of `docs/process.md`: (1) two items at one time, names on: the reminder has "Take All", "Skip All", and "Remind in 10 min". (2) "Take All" on the lock screen after an unlock: both doses are recorded, and the notification goes. (3) Names off: only "Remind in 10 min" shows for the group. (4) "Skip" on one item. (5) "Remind in 10 min" with "Remind Again" on: one banner after ten minutes, and no follow-up before it. (6) "Remind in 10 min", then record the dose in the app: no banner. (7) Update an iPhone that has version 1.1 reminders: the pending requests get the new buttons after the first run.

## D091 · 2026-10-16 · Phase 2 of the reminder plan: the tracker (the PDF reports and the 30-day counts are Pro: D130)

Maintainer decision (approved with the plan of 2026-10-16: "focus on what users meet, keep it simple, do not chase rare races"). D090 is reserved for the parallel notification pull request. Migration `v7`. It changes spec 3 P05 and 7.1 by amendment, and `docs/design.md` (Today, History, item detail, archived list, Settings, widgets).

What the user sees:

1. As-needed items. The item row on Today has a second line with the usual amount and "Last dose 9:12 PM", also from an earlier day. The amount is the item's usual amount (the amount field of the edit screen now saves for an item with no time). A dose copies it when the user records it, so a later change does not rewrite an old dose. History rows and the export show it.
2. History. A past dose with no record offers "Skipped" (swipe and long press), next to "Taken". A row has a third line: "Planned 8:00 AM" and the amount, the amount of an as-needed dose, and the form when another item has the same name. An action that a later action replaced says "Replaced". The newest row of a dose has no mark.
3. Archive. An archived item keeps its past "No record" doses in History, in the graph, and in the export, up to the day before its archive. The archived list opens the item, and the item has "All Records", the full log of the item with every older day. The item detail also has the counts of the last 30 days: "Taken: 26 of 30", "Skipped: 1", "No record: 3".
4. R5. One reader (`historyPage`) and one pure reducer (`History.summary`) feed the item detail, the summary, and the export. The rule "a planned dose of today with no event and a time after now is not counted" is one function, `History.isCounted`. The week strip, the graph, and the summary all use it. This fixes the graph, which counted a dose of the evening at 08:00.
5. Reports. "Share Medication List" and "Share Summary…" in Settings, "Your Data". Each makes a PDF after the tap, in the protected temporary folder, and the share sheet removes it as for the CSV. The list has the name, form, amount, times, and note of each active item, as typed. The summary has a period (7, 30, or 90 days) and a switch for each item, and per item the planned doses, taken, skipped, and "No record". The wording is "No record", never "Missed". It has no percent, no streak, and no score. Dates use the zone of the iPhone, and the note says so. Nothing leaves the iPhone except through the share sheet, so `PRIVACY.md` only got the two new files in its list. The files send no analytics event.
6. Lock Screen widget. "Today" has `accessoryCircular` (gauge of taken doses) and `accessoryRectangular` (next part of the day, open doses, gauge). No names. It reuses the provider and the strings of the widget. It was cheap, so it is in.
7. First save. The first save of a new item with a time asks once "Remind Again?" with "Turn On" and "Not Now". "Turn On" sets 2 times, 30 minutes apart, for that item, and the item can change it. The alert waits for the edit screen, the permission prompt, and the other alerts. It never comes back. It is not a default: nothing turns on by itself, and the app does not choose for a user who says "Not Now".

Schema `v7` (frozen after release): `item.archivedAt REAL`, `item.asNeededDose TEXT`, `occurrence.dose TEXT` (only an as-needed occurrence has it). Every old row keeps `NULL`. An item archived before this build has no archive time. It keeps the old behavior: its records show, and its past "No record" doses do not appear. The export format and the backup need no change (a backup copies every column). Upgrade test: `UpgradeTests.theTrackerColumnsLoadAndAnAsNeededDoseKeepsItsAmount` opens each shipped fixture (v5 and v6) with this code, checks that the old rows load with no new value, records a dose with an amount, and reads it from History and from the export. There is no new fixture file, because no shipped version has `v7` yet. The v6 fixture is the database that updates to `v7`.

Cost and limits:

- The archive time is the instant of the archive. History reads it in the zone of the device when it plans the days. A zone change can move the last planned day by one.
- "All Records" loads 30 days a page and pages back until the first day of the item. A long history takes some scrolling. There is no jump to a date.
- The summary reads at most 90 days in one read. A longer period is not offered.
- Doses of an item whose plan changed show the amount of the schedule version in force on that day.
- The summary of a period before an item existed counts nothing for it. A dose of an archived item before its archive counts.
- Not done: a doctor summary with a chosen date range (7, 30, and 90 days only), a note for each dose, a dose limit or a minimum gap for as-needed doses (advice, D006), and shares from My Items (Settings only).

Tests: `TrackerTests` (3), `HistoryTests.archivedItemKeepsItsNoRecordDays`, `UpgradeTests.theTrackerColumnsLoadAndAnAsNeededDoseKeepsItsAmount`. The tests that expected the old migration list or used `v7` as a newer migration use `v7` and `v8`. The `replace` test checks the archive time.

Not verified: the app code (SwiftUI views, the PDF writer `Report.pdf`, the summary sheet, the Lock Screen widget). Nobody built the app on this Mac, and CI builds it. Device checks: take an as-needed dose with an amount and look at the second line on Today, History, and the export; take one on a later day and read "Yesterday, ..."; skip a past "No record" dose from History (swipe and long press); archive an item with a plan, wait a day, and see its "No record" days before the archive in History and in the graph; open an archived item from the archived list and scroll "All Records" to its first day; two items with the same name in History; "Share Medication List" and "Share Summary…" (the PDF layout in English and one more language, the share sheet, an item switched off, no "Missed"); the Lock Screen widget in light, dark, and a Focus; the offer after a first save (also with the permission prompt of a first install, and after "Not Now").

## D092 · 2026-10-16 · The History graph ends at this week

The maintainer saw empty future months (November to January) on the graph and asked for the best choice. The graph now ends at the week of today, like a contribution graph, and grows to the left: 13, 26, then 52 weeks, as before. Days before the first day stay empty.

Reason: an empty future reads as missing data, and a new user saw more empty months than days. The right edge is now always today, the place where the eye looks for the newest record.

## D093 · 2026-10-16 · An alarm button stops the alarm

On the maintainer's iPhone, the alarm rang, "Stop" worked, and the check button did nothing visible. A secondary alarm button with the custom behavior runs its intent and leaves the alarm alerting: the app must stop it. The "Taken" intent and the "Open Maru" intent now carry the alarm ID and stop the alarm first. The "Taken" intent still records through the same checks as the "Taken" action of a notification (D034, D079).

## D094 · 2026-10-16 · The rectangular Lock Screen widget follows the system layout

On the maintainer's Lock Screen, the rectangular "Today" widget showed a large title line, a plain line, a small "Today" under them (the label of the bar), and the bar. It looked unlike the system widgets next to it. It now follows the layout of the system widgets such as Batteries: a symbol and the bold first line ("Evening 9:00 PM"), one plain line ("2 left"), and a bar with no label. The widget still shows no names (D048).

## D095 · 2026-10-16 · An undone dose follows a time edit of the same day

Agent decision, after a bug on the maintainer's iPhone (TestFlight 1.1.0 build 10). It replaces the clause "an undo also counts" of D019. Spec 7.2 is unchanged: it forbids a second dose only when the dose has a record.

The bug: a daily item with the alarm on. The user recorded today's dose, undid it, and changed the time to a later minute of today. No alarm and no notification came at the new time. After the undo, the stored occurrence still had an intake event, so D019 kept it at its old time. The alarm plan builds today's alarm from the stored occurrence, so the alarm was at the old time, which was over. An alarm item has no banner (D079), so nothing came. An item with no alarm got its notification from the weekly request of the new time, but Today showed the old time, and the "Taken" action recorded nothing (D089, N1).

The rule: a stored occurrence of today or later follows the plan while it has no current taken or skipped record (a row in `occurrenceState`). An undo deletes that row, so the dose moves to the new time and keeps its ID. A dose with a record never changes. The store guard of `replan` uses the same condition.

Effects:

- Today, the alarm, the notification, the follow-ups, and the "Taken" action all use the new time and the new schedule version of an undone dose.
- The History timeline shows the undone action under the dose at its new time and amount. An undone action is not a record, so no record changes.

Test: `aTimeEditAfterAnUndoRingsAtTheNewTimeToday` failed before the fix. Two tests of the old rule now state the new rule: `occurrenceWithAnUndoneRecordFollowsThePlan` and `takenActionAfterUndoAndAPlanEditRecordsOnlyTheNewPlan`.

Not verified: the alarm on a real iPhone. Device check: alarm on, record, undo, change the time to two minutes later; the alarm rings at the new time, and Today shows the new time.

## D096 · 2026-10-16 · Maru is closed source

Maintainer decision. Maru is closed source. Maru's own code has no open-source license. The site, the App Store text from version 1.1.0, and the repository docs make no open-source claim and do not link to the code.

Effects:

- The site has no GitHub button, no "Source code" link, no FAQ answer about open source, and no source link in `llms.txt`. "Free and open source" is now "Free" in each language.
- `LICENSE` is removed. The README says "All rights reserved". Copies of the code from before this decision keep the MIT license.
- Version 1.0.0 stays in review with its "Open source" line, so the review does not start again. The version 1.1.0 text has no such line.
- The repository stays public for now, because private macOS CI minutes cost money. `SECURITY.md` and the GitHub social image stay.
- `CONTRIBUTING.md` and the contact link of the issue form are removed. The README invites no contributions.

## D097 · 2026-10-16 · A Language row opens the iOS Settings page of Maru

Maintainer decision. It replaces "No language row" of D023.

- The "Display" section of Settings has a "Language" row. Its value is the name of the language that the app uses, in that language, for example "English" or "日本語". The name comes from `Bundle.main.preferredLocalizations` and `Locale`.
- A tap opens the iOS Settings page of Maru (`UIApplication.openSettingsURLString`). iOS shows its per-app language choice there.
- Maru has no language choice of its own. Reasons: Apple does not support a switch in the app, a switch needs a restart, and pending notifications and widgets keep the old language.

## D098 · 2026-10-16 · "Delete Item…" in the long-press menus

Maintainer decision. It adds places to the "Delete Item…" clause of D033.

- The long-press menu of a Today row, of an as-needed row on Today, and of a My Items tile has "Delete Item…" as the last entry, after "Archive…".
- The entry is red (destructive role) and opens the same one confirmation as the other places. The swipe rule of D033 does not apply: a context menu does not remove the row before the alert.
- Reason: a user who wanted to delete in one step looked for it there.
- The entry reuses the translated string. It adds no domain code and no store code.

## D099 · 2026-10-28 · No supporter tips. A paid "Pro" tier comes in 1.2

Maintainer decision. It replaces D053.

- The app has no supporter tips. Version 1.1.0 ships with no in-app purchase.
- A paid "Pro" tier comes in version 1.2 and takes the place of the tips. A later decision defines it.
- Removed: `SupportStore`, the "Support Maru" section of Settings, the `Transaction.updates` task at launch, the five strings of the section in all languages, `Config/Maru.storekit` and its reference in the `Maru` scheme, and `metadata/in-app-purchases/tips.json`.
- The analytics allowlist has no `purchase_result` event. Add the event in the change that first sends it.
- The spec text about a supporter purchase (§1, P06, §6, §11.5, §14 C, and T48) stays until the decision about "Pro".
- This change does not touch App Store Connect. The three tip products and the 1.0.0 review notes about the tips are still there. The maintainer removes them before the submission of 1.1.0.

## D100 · 2026-10-28 · "Color Header" brings back the header wash as an option (changes D024) (on by default by D104)

Maintainer decision. The header wash of D021 returns as a switch. D024 removed it as the only look, and the plain look stays the default.

- Settings has a switch "Color Header" in the "Display" section, under "App Color". It is off by default, so the look does not change for anyone. The value is in `UserDefaults` under `display.headerWash`, read with `@AppStorage`, as the app color (D023). A backup does not carry it.
- When it is on, Today and My Items show the same wash behind the large title. History, the item detail, and the sheets do not. The two tab pages are the main pages, and one wash on both keeps them the same.
- The wash keeps the measured curve of D021: ten stops over 280 points from the top edge of the screen, solid color above it for the pull-down, and opaque cards on top of it. On iOS 18 and later it moves with the content and scrolls away, as in Apple Health. On iOS 17 SwiftUI cannot read the scroll distance, so the wash stays in place behind the content.
- The color comes from the app tint (D025), not a fixed pink. In light mode the tint is mixed with white to the relative luminance 0.54. In dark mode it is mixed with black to 0.09. These are the luminances of the top colors of Apple Health. So each app color gives a wash of the same strength, and the title text keeps more than 7:1 contrast. A mix with white in place of the old hue scale keeps green, mint, and yellow soft.
- No change for Reduce Transparency or Increase Contrast. The wash is opaque and has no blur, and the title contrast is above 7:1 in both modes.
- No color picker for the wash and no setting for each page.

## D101 · 2026-10-28 · A warm voice at key moments

Maintainer decision. The copy felt cold and artificial. Maru now speaks like a reliable friend at a few key moments: not a nurse and not a cheerleader. Only text changes. The layout does not change. It replaces the "nothing to take" clause of D068 and, for the warm titles, the empty-view title rule of D058.

Rules:

- Warm words come only at key moments: a day with every dose recorded, the first item, empty states, errors and recoveries, and one line at the bottom of Settings.
- Buttons, settings labels, and record states stay short and exact. The text states the record, not the intake (D068).
- No guilt, no nagging, no streak talk, and no "don't forget". A missed dose gets no judgment.
- Few exclamation marks, no emoji, and nothing cute. No medical promise.
- Where the app speaks as its maker, it says "the Maru team" and never names a person.
- Each language uses its own natural tone: polite but friendly in ja and ko, and 你 in zh-Hans, as the catalog already does.

Changes in `App/Localizable.xcstrings`, in six languages:

| Where | Before | After |
|---|---|---|
| Today, items but nothing planned | Nothing Planned Today | Nothing to take today. Enjoy it. |
| Today and My Items, no item | No Items Yet | Let’s add the first thing you take. |
| Today, every planned dose recorded (new) | the date | All done for today. Nice work. |
| History, empty | What you record shows here. | Your records will appear here, one day at a time. |
| Storage problem, no known cause | Maru did not change or delete your data. | Your data is safe. Nothing changed. |
| Storage problem, disk full | … Maru did not change or delete your data. | … Your data is safe. |
| Storage problem, locked device | … Maru did not change or delete your data. | … Your data is safe. |
| Storage problem, newer or older version | … Maru did not change or delete it. | … It’s safe, and nothing changed. |
| Storage problem, damaged file | … Maru did not change or delete it. | … Maru left it exactly as it was. |
| Alert after a record that did not save | Maru couldn’t save this. Try again. | This didn’t save. Please try again. |
| Alert after a change that did not save | Maru couldn’t save this change. Try again. | This change didn’t save. Please try again. |
| Settings, footer of "About" (new) | none | Made with care by the Maru team. |

Details:

- "All done for today. Nice work." takes the place of the date under the "Today" title (the navigation subtitle, or the first header before iOS 26). Today has no progress ring (D026), so this line is the progress area. It shows when every planned dose of today has a confirmed record, taken or skipped. As-needed doses do not count. The line shows only after the commit (spec 7.2).
- The damaged file does not say "Your data is safe", because Maru does not know that. It says that Maru did not touch the file.
- "No Items Yet" stays as the line of the PDF medication list with no item. A warm invitation does not fit a document.
- Not changed: the notification text, because it lives in the package catalog `MaruNotifications`, and the widget text, because the warm lines do not fit a small widget. The site has none of the changed sentences, so `site/src/strings` does not change. The editor errors already say "Your entries are still here."
- Every new string in zh-Hans, ja, es, de, and ko is a draft until a native speaker reads it (`docs/localization-review.md`).

Not verified: no build of the app on this Mac, and nobody saw the text on a display. CI builds the app.

## D102 · 2026-10-28 · The App Store rating prompt

Maintainer decision.

- Maru uses only the system prompt of `RequestReviewAction` (SwiftUI `@Environment(\.requestReview)`). It has no stars of its own, no "rate 5 stars" text, and no screen before the prompt.
- The trigger is the third distinct calendar day on which every planned dose of that day has a record, taken or skipped. The prompt comes right after the record that completes such a day, 1.5 seconds later, so it does not cover the fill of the record circle.
- Maru asks at most once per app version, and never in the first 3 days after the first launch. The system can still decide to show nothing.
- The state of the day comes from the Today read (`TodaySnapshot`) through `AppModel.isComplete`, the same check as the line of D101.
- A day counts also when a reminder action, a widget, or the Watch completes it. Maru asks only while the app is active, so a record in the background only counts the day.
- The values are preferences in `UserDefaults.standard` (D014), not in the health database: the time of the first launch, at most 3 dates of complete days, and the last version that asked. They hold no item data. `App/ReviewPrompt.swift` has the rule.
- A version before this rule did not keep the first launch, so an update starts the 3 days from the first launch of the update.
- The prompt sends no analytics event.

Not verified: no build of the app on this Mac. The system shows the prompt in a Debug build every time and never in TestFlight, so only an App Store build shows the real behavior.

## D103 · 2026-10-28 · A short first-run onboarding and two first-use tips (tips removed, timing and "Skip" changed by D104)

Maintainer decision for version 1.1, with agent detail. The copy uses the voice of D101.

Onboarding:

- A sheet with three pages shows once, at the first read of the store, and only when the store has no item, active or archived. An update from a build with items never shows it.
- The flag is `onboarding.seen` in `UserDefaults.standard`, as the app color (D023), not in the health database. The first read sets it, also when the store has items. So a user who later deletes every item does not see the pages again. A backup does not carry it.
- Pages: the promise ("Did I take it? Open Maru and you know."), privacy (no account, no ads, the data stays on the device), and a start page with "Add Item", which opens the existing add screen after the sheet closes, and "Later".
- "Skip" is at the top of every page, as the maintainer asked. On the last page it does the same as "Later". A swipe down also closes the sheet. "Continue" under pages 1 and 2 moves to the next page, so a user who does not swipe, and VoiceOver, can go on.
- A paged `TabView` with system fonts, SF Symbols in the app tint, and system buttons. Each page scrolls at the largest text sizes, and the symbol hides at the three largest sizes (D013). The button page change uses the layout motion, so with Reduce Motion it shows at once (D030). The privacy title has an iPad form (D072).
- The onboarding asks nothing: no questionnaire, no age, no goals, and no sign-up (spec §1). It does not ask for the notification permission. The existing rule stays the only one: the reminder run of a confirmed save asks, when the plan has a reminder or an item with an alarm (spec §2.2, `ReminderEngine`, D089 N5).
- The add screen stays one edit flow (spec §3 P03). The onboarding is not a part of it.

First-use tips (TipKit, iOS 17):

- "Record a Dose", on the record circle of the first row of Today: "Tap the circle when you take it. Tap it again to change or undo the record." A tap that records with the circle ends it.
- "More for Each Item", on the first tile of My Items: "Touch and hold an item to edit, archive, or delete it." "Edit", "Archive…", or "Delete Item…" from a long press, on Today or on My Items, ends it.
- Each tip shows once, as a popover, and the close button of the tip ends it too. TipKit keeps the state in its own store in the app container. It holds no item data.
- A tip popover waits while a sheet, an alert, the onboarding, or a question that waits for the display is up (`tipsMayShow` in `RootView`). UIKit presents one of them at a time, and the first save with a time can bring the "Remind Again?" offer (D091) and the opt-in question (D078) at the moment that the first row comes.
- The third candidate, a tip about the actions of a reminder on the Lock Screen, is not in the app. The actions are in the notification, so no view of the app is a fitting anchor, and an inline card on Today would be the notice card that D028 does not allow.
- `Tips.configure` runs in a `.task` of the root view, after the first frame, so the launch path does not wait for it (spec §9).

Debug: `-MaruFirstRun YES` clears the flag and the TipKit store at launch, for a check of both after they showed once. The onboarding still needs a store with no item.

The new strings in zh-Hans, ja, es, de, and ko are a draft until a native speaker reads them (`docs/localization-review.md`). "Skip", "Add Item", and "Record a Dose" reuse their translations, with a wider translator comment.

Not verified: no build of the app on this Mac, and nobody saw the pages or the tips on a display. CI builds the app.

## D104 · 2026-10-28 · No first-use tips, "Color Header" on by default, and exact onboarding timing (changes D100 and D103)

Maintainer decision after a test of TestFlight build 13.

First-use tips:

- The two TipKit tips of D103 are removed: `RecordTip`, `ItemMenuTip`, `FirstUseTips`, the TipKit start at launch, the `tipsMayShow` environment value, and their strings in six languages. The maintainer found them ugly. The app has no first-use tip.
- The tips kept their state in a TipKit store in the app container. A TestFlight install keeps that file, and it holds no item data. Nothing reads it now.

"Color Header" (changes D100):

- The switch is on by default. A missing value of `display.headerWash` means on.
- A user who turned the switch off has the value `false`, so the header stays plain for that user.

Onboarding (changes D103). Each rule below is true in code:

- It shows on the first launch of a new install, before Today, when the store has no item, active or archived, and `onboarding.seen` is not set.
- It never shows again after "Add Item", "Later", or "Skip". The flag is set then, so a relaunch or a delete of all items does not bring it back.
- An update from an older build with items never shows it. Each read that finds an item sets the flag with no page.
- A restore sets the flag with no page, also when the backup has no item.
- The decision waits for the first read. Before it, the window shows the plain background and not Today. The onboarding fills the window in place of the tabs, so Today does not show under it or for a frame before it. A user with the flag set gets Today at once, and the launch waits for nothing new (spec 9).
- It decides only when the window is in front. A launch in the background, for a reminder action or the widget, does not decide.
- A reminder tap or a widget link in the process hides it and leaves the flag unset. The next normal launch with no item shows it. The app has no Shortcut that opens it with no item: the alarm button "Open Maru" needs an item with an alarm.
- With no item, the decision waits 400 ms after the window comes in front, behind the empty page, so a late widget link on a cold launch comes first. The "Record Dose" intent also hides it, because it can continue in front.
- It is a page of the window, not a sheet. On iPad, in Split View, and after a rotation it stays, with the same page.
- It asks for no permission. The notification permission comes only with the reminder run of the first save that has a reminder time (spec 2.2, D089 N5).
- Page 3 has "Add Item" and "Later" only. "Skip" is on pages 1 and 2. A swipe down does not close it, because it is not a sheet.
- "Add Item" shows the tabs and opens the add screen on them.

`AppModel+Onboarding.swift` has the rule. It stays in the app target and has no test (D016).

Not verified: no build of the app on this Mac, and nobody saw the pages on a display. CI builds the app.

## D105 · 2026-10-28 · An "Appearance" setting

Maintainer decision.

- Settings, section "Display", has the menu "Appearance" after "Color Header", with "System", "Light", and "Dark". The default is "System".
- The choice is in `UserDefaults.standard`, with the key `display.appearance`, beside the app color (D014). No value means "System".
- The app sets it on each window with `overrideUserInterfaceStyle`. "System" gives `unspecified`, so the app follows the device. Every window, sheet, alert, and the onboarding follow the choice, also a sheet that is open during the change.
- Correction after the iPhone Duo simulator check (2026-10-28): the first code used `preferredColorScheme` at the app root. A change from "Dark" to "System" kept the open Settings sheet dark, because `preferredColorScheme(nil)` did not reset an open sheet.
- The widgets and the Watch app always follow the system. The backup file does not carry the choice, as it does not carry "Color Header".
- The setting has no preview and no own page.

Not verified: no build of the app on this Mac, and nobody saw the window fix on a display. CI builds the app.

## D106 · 2026-10-28 · Maru runs on iPhone Duo with its current layout

Maintainer request: support iPhone Duo simply, with no special layout. Agent decision on the details.

What iPhone Duo is (Apple sources below):

- iPhone Duo is the first foldable iPhone, on sale from 2026-10-23. It has a compact outer display and a large inner display with the same aspect ratio. A hinge lets it be closed, fully open, or partially folded like a book.
- It is an iPhone. An app for the iPhone runs on it, and needs no new device family and no new Info.plist key. "Your app may react to different size class boundaries, but it is still an iPhone app."
- Size classes: the outer display is like other iPhones (compact width, regular height in portrait). The inner display is regular width and regular height.
- Orientation: the outer display honors the supported orientations. The inner display does not, and the app scales there, also in Split View.
- The system shows navigation bars, toolbars, and tab bars vertically on the side in some poses: always on the outer display, and in landscape on the inner display. System bars do this with no app code.
- SDK: an app built with the iOS 26 SDK or earlier shows in the middle of the inner display with empty space around it. An app built with the iOS 27 SDK resizes. An app built with the iOS 27.1 SDK is "optimized for iPhone Duo" and fills the display.
- The App Store badge "Made for iPhone Duo" shows when the store page has iPhone Duo screenshots. From April 2027, every submission needs iPhone Duo screenshots.
- Apple asks apps to resize: no `UIScreen.main`, no layout by `userInterfaceIdiom` or interface orientation, no fixed iPhone sizes. Arrangement views, reserved regions (the fold), the hinge angle, and a second screen are optional APIs for custom layouts.

What Maru does:

- Nothing in the app code changes. A search of `App/`, `Widget/`, `Shared/`, and `Watch/` found no `UIScreen`, no layout by idiom, orientation, or size class, and no fixed width of a page. The layout of D072 fills the width of the window, so the inner display gets the iPhone layout at a larger width, as an iPad does.
- `userInterfaceIdiom` sets only the device field of analytics (D077). iPhone Duo reports `.phone`, so it counts as an iPhone. The scanner view follows its host with an autoresizing mask. The onboarding text has a maximum width of 560 points, which is a limit and not a fixed size.
- The iPhone stays portrait only. The inner display ignores this, and Apple permits it. Landscape on the outer display is optional, so Maru does not add it.
- My Items keeps two columns of tiles. The HIG prefers an even number of columns, so the fold falls between them.
- No arrangement view, no reserved-region code, no hinge code, and no second-screen scene.
- The toolbars use `ToolbarItem` with semantic placements. "Settings", "History", and "Add Item" have a title and a symbol, so they can go vertical. "Edit" of the item detail and "Skip" of the onboarding are text only. The system keeps a text-only item out of a vertical bar.
- CI builds with Xcode 27.1 and the iOS 27.1 SDK (runner image `xcode-27-arm64`). The Mac of the maintainer has Xcode 27.1, so the next archive is optimized. Version 1.0.0 build 4 is older, and nobody checked its SDK.
- `project.yml` and `docs/design.md` say that the inner display ignores the portrait lock.

Maintainer decision still open: iPhone Duo screenshots for the store. They give the badge now, and they are required from April 2027.

Sources:

- Apple Developer, "Preparing your app for iPhone Duo": https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo
- Apple HIG, "Designing for iPhone Duo" (2026-09-09): https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo
- Apple Developer, "Three steps to make your app shine on iPhone Duo": https://developer.apple.com/iphone-duo/prepare/
- Tech Talk "Prepare your app for iPhone Duo" (size classes, orientation, `UIRequiresFullScreen`): https://developer.apple.com/videos/play/tech-talks/111461/
- Apple Developer News, "Prepare and submit your apps for iPhone Duo" (Xcode 27.1, badge, April 2027): https://developer.apple.com/news/?id=kkphp5qo
- Apple Newsroom, "Developers bring incredible new app experiences to iPhone Duo": https://www.apple.com/uk/newsroom/2026/10/developers-bring-incredible-new-app-experiences-to-iphone-duo/
- SwiftUI `ReservedRegion`: https://developer.apple.com/documentation/swiftui/reservedregion

Not verified: nobody ran Maru in the iPhone Duo simulator or on an iPhone Duo. This Mac does not run a simulator. CI builds the app with the iOS 27.1 SDK. Nobody listed the simulators of the CI image.

## D107 · 2026-10-28 · Maru Pro: the purchase foundation and the paywall (replaces the supporter rule of spec 1, P06, 6, 11.5, 14 C, and T48) (third benefit row and app color changed by D114, look and first-value picture changed by D115, paywall changed by D118) (paywall source `feature` replaced by D127)

Maintainer decisions of 2026-10-28, with agent detail. They follow the two paywall studies of 2026-10-28 in the maintainer's research folder. They define the "Pro" tier of D099.

Free forever:

- Reminders, records, history, undo, widgets, export, backup, and unlimited items. Maru never limits items.

Pro:

- A Lock Screen Live Activity for the next dose, the Apple Watch app, extra app icons, and extra reminder sounds.
- Those features come in later changes. This change builds the purchase, the entitlement `isPro`, the paywall, and its entries. A later Pro feature reads `AppModel.pro.isPro`, and a tap by a free user calls `AppModel.presentPaywall(reason: .feature)`.

Products (prices in App Store Connect, not in code):

- `com.imhangli.maru.pro.yearly`: an auto-renewable subscription in the group "Maru Pro", about USD 9.99 per year, with a free trial of 7 days as the introductory offer.
- `com.imhangli.maru.pro.lifetime`: a non-consumable, USD 19.99 as a founder price for 30 days after the launch, then USD 29.99 (D139).
- Family Sharing is on for both. Apple does not let a developer turn it off again. No monthly plan.
- `Config/Maru.storekit` has both products for local tests. The Run action of the `Maru` scheme uses it (`project.yml`).

Entitlement:

- Pro is active when `Transaction.currentEntitlements` has a verified transaction for one of the two products with no revocation date. This includes a purchase of a family member. A lifetime purchase wins over the yearly plan.
- The app starts a listener of `Transaction.updates` and one read of the entitlements at launch, in tasks that wait for the system. The launch waits for neither (spec 9, T35). Each transaction is finished. Each return to the front reads the entitlements again.
- The yearly plan ends at its end of access: the expiration date of its verified transaction, or the end of the billing grace period when `Product.SubscriptionInfo.Status` reports one. Maru checks this date itself, because the cache of StoreKit can keep an expired transaction while the device has no network. A timer reads the entitlements again at that date. The lifetime plan never expires.
- The last known plan is in `UserDefaults.standard` under `pro.plan`, and the end of access of the yearly plan under `pro.expires`, beside the display settings (D014). A Pro feature reads the plan at launch, so it does not flicker. A cached yearly plan after its end of access is free. StoreKit corrects the cache at each launch, each update, and each return to the front. The backup does not carry it.
- `App/Pro/ProStore.swift` is the only file that imports StoreKit. The rating prompt of D102 moved there as a view modifier, so `RootView` does not import StoreKit. `MaruCore` and `MaruDatabase` never import it. A purchase never reads or writes health data.
- No free feature reads the entitlement. So a failed, cancelled, pending, refunded, or expired purchase changes no free feature (T48).

Paywall (`App/Pro/PaywallView.swift`, one SwiftUI view):

- A custom view. `SubscriptionStoreView` shows one subscription group and cannot sell the non-consumable beside it.
- Top to bottom: the Lock Screen preview (only for the first-value offer), the title "Maru Pro", a line that the current features stay free, three benefit rows, the two plans side by side with `displayPrice`, the trial timeline, "Shareable with Family Sharing", the buy button, "Continue Free", the renewal terms, "Restore Purchases", "Redeem Code" (`offerCodeRedemption`), "Terms of Use" (Apple's standard EULA), and "Privacy Policy" (https://maru.day/privacy/). A close button is in the bar.
- The yearly plan is selected first. Each plan that loaded has its own card. When only one plan loaded, it is selected. The buy button is off for a plan with no product and no price. The trial timeline shows only when StoreKit says that the user can still get the trial: "Today: Free for 7 days" and "Day 7: <price>/year. Cancel any time in Settings." The number of days comes from the offer of the product.
- The price is the largest text of a plan card, larger than the trial words. In the timeline the price is bold, at the size of the trial words (App Review 3.1.2).
- "Continue Free" has the size, the shape, the fill, and the font of the buy button, in a gray fill.
- No countdown, no trial switch, no struck price, no discount, and no offer after a cancel.
- A cancel leaves the paywall as it was. A pending purchase says that it waits for approval. A failure says that it did not go through. A purchase closes the paywall.

Triggers. Maru never shows a paywall at app open, after a record, after a cancelled purchase, or as a notification.

1. First-value offer, once per install. The first save of a new item with an active time plan sets it. It waits until the save's reminder run ends, so the notification permission alert of that save closed first. Then it waits for the edit screen, the reminder alerts, "Remind Again?" (D091), and the opt-in question (D078). It shows a static SwiftUI picture of a Lock Screen with the user's next dose (the name, the amount, and the next time of the plan), and the paywall under it. It is not a real Live Activity. Never during the onboarding. Never in a process that a reminder or a widget opened. Then the flag stays unset, and the next such save offers it. The flag `pro.firstValueShown` is set when it shows. A save of an item with no time does not offer it, because the preview needs a time.
2. The card of Today. An inline section at the bottom of Today, under every dose, never modal. It shows when all of these are true: Maru is not Pro, the device can make payments, at least 7 days passed since the first launch (`review.firstLaunch` of D102), at least 5 doses have a record (taken or skipped, one read of the store, again after an undo, a delete, or a restore), the rating prompt did not ask on this calendar day, no planned dose of Today is due with no record (Today checks again at the planned time of the next open dose), and the card showed on fewer than 3 days or already on this day. Each day that it appears counts once (`pro.cardDays`). "×" hides it for good (`pro.cardDismissed`). "See Maru Pro" opens the paywall.
3. Contextual: `AppModel.presentPaywall(reason:)` for the later Pro features. It shows nothing when Maru is Pro or a paywall is up.
4. Settings: a section at the top. A free user sees the row "Maru Pro", which opens the paywall. A Pro user sees "Active, Yearly" or "Active, Lifetime", and "Manage Subscription" for the yearly plan. "Restore Purchases" and "Redeem Code" are always there. The root view hosts the paywall, and Settings hosts it while Settings is up.

The flags of the offers are in `UserDefaults.standard`, as the onboarding flag (D103). They hold no item data.

Analytics (spec 11, D052). Both events need the same consent as every other event. Neither has item data.

- `paywall_shown`: `source` is one of `first_value`, `day7_card`, `feature`, or `settings`.
- `purchase_result`: `result` is one of `purchased`, `cancelled`, `pending`, `failed`, or `restored`, and `plan` is `yearly` or `lifetime`. A restore that finds no purchase sends nothing. A failed restore has no plan.
- The privacy label needs "Purchase History" (analytics, linked, no tracking) before a build that sends `purchase_result` is released. `App/PrivacyInfo.xcprivacy` lists it now.

Data: `LocalStore.hasRecords(atLeast:)` counts the current records for the card. It reads no name, time, or item.

Spec changes: §1 (commerce row), P06, §6 (purchase row), §11.5 (two events), §11.6, §14 C, and T48.

Risks:

- This change sells Pro features that the app does not have yet. Do not release a build with the paywall before the Pro features are in it. App Review rejects a purchase with no content (3.1.1).
- The store text of 1.1 says "no paywall". Guideline 2.3.2 asks the store text to say what needs a purchase. Change the text of 1.2 before its submission.

Not verified: no build of the app on this Mac, and nobody bought a plan. CI builds the app. The checks with the StoreKit configuration are in `docs/status.md`. App Store Connect has no product yet. `docs/release-plan.md` has the maintainer's steps.

## D108 · 2026-10-28 · A "Last Dose" widget, and Siri and Shortcuts ("Record my doses" with several members: D123, Siri is Pro: D130, Siri and Shortcuts replaced by D140)

Maintainer decision on 2026-10-28, with agent detail. Both features are free. They are not part of Pro (D107). It follows spec 6, 7.2, 9, and 10, and it adds to D048 and D091.

The "Last Dose" widget:

- Families: Home Screen small, and Lock Screen `accessoryRectangular` and `accessoryInline`.
- It shows the newest taken dose of all active items: the item name, the amount if the dose has one, and the time. Today gives the time since the dose ("2 hr. ago", "now" in the first 5 minutes). Yesterday gives "Yesterday, 6:49 PM". An earlier day gives the date and the time. The text changes at timeline entries: every 5 minutes in the first hour, then every hour, and at the next two midnights.
- A skipped dose, an undone dose, and a dose of an archived item do not count. A time change of a taken dose moves it.
- It follows "Show Names in Reminders" (D029). Maintainer decision on 2026-10-28, after a review: the setting applies to the widget and to Siri. With the setting on, the widget shows the name and the amount. With it off, each family shows "Dose recorded" and the time, with no name and no amount, because an amount can tell what the item is. The tap still opens the item.
- The app copies the setting to the defaults of the App Group (`AppGroup.showsNames`) at each launch, at each change, and after a restore, then reloads the widgets. No value hides the names, so a widget that runs before the app writes the value shows no name.
- No taken dose: "Your last dose will show here." (inline: "No records yet"). No judgment (D101).
- A tap opens Today with the item detail on top (`maru://item/<ID>`). The detail goes back to Today when the item is gone. The empty widget opens Today.
- Data: `LocalStore.readLastDoseForWidget` reads the App Group database read-only, in one read transaction, with the restore epoch check of D048. It shares `LocalStore.readOnly` with `readForWidget`. Each dose with an event or a state row goes through the check of the history read (`fetchCheckedRecord`). A state row that does not match the history makes the read fail (`invalidData`, spec 7.3, T20). The widget then says "Open Maru to update.", and Siri gives the read failure. It never says "no dose" for this case. A locked iPhone before the first unlock gives "Open Maru to update." (D066), and the widget tries again in 15 minutes.
- Reload: the app now reloads every widget timeline after each commit of a record (`AppModel.reloadWidgets`), as well as after each read. Before this change, a record in the app reached the widgets only at the next read of the app.

Siri and Shortcuts (App Shortcuts, `App/Siri/MaruShortcuts.swift`):

- "What do I take next in Maru": the open doses of the first part of the day from the clock on that has one, else the first earlier part with one, as the small "Today" widget does (D048). Siri says the names and the planned time, and shows a snippet with the part of the day, the time, and each dose with its amount. With names off, Siri says the number of doses ("Next up: 2 doses, planned for 8:00 AM."), and the snippet shows the number with no name and no amount. With all doses recorded: "All done for today. Nice work." With no planned dose: "Nothing to take today. Enjoy it." It records nothing.
- "Did I take my <item> in Maru": the newest taken record of the item, with the day and the time. The item is an `AppEntity` of the active items, so Siri picks it by name. Siri asks "Which item?" when the user names none. It records nothing. With names off, the answer names no item: "Your last record: taken today at 8:00 AM." The list of "Which item?" still shows the names, because the user picks an item by its name.
- "Record my doses in Maru": the open doses of the part of the day of the clock. Siri asks "Record as taken now: …?" first. With names off, the question and the answer give the number of doses ("Record as taken now: 2 doses?"). After a confirmation, one record transaction records them with the checks of the widget and the Watch (`requiresCurrentPlan`, the event revises the read record, the data generation of D040). Siri says "Recorded as taken: …" only after the commit, and it waits for the reminder run (D047). A record with no confirmed commit says "Maru couldn’t confirm the save. Open Maru to check your records." It does not say that nothing was recorded, because SQLite can commit before `F_FULLFSYNC` fails. After a storage failure, the same event waits on Today for a retry, as in the other record paths (D014). With nothing due: "Nothing is due right now. You’re all set." A dose with an unconfirmed event is left out (D014).
- All three intents need an unlocked iPhone (`requiresAuthentication`). For the record, this is the rule of the "Taken" action of a reminder on the iPhone (D034, D066). For the two questions, a person who holds a locked iPhone can not hear the names through Siri. With names on, the Lock Screen widget shows a name, because the user adds it and keeps the names on.
- A read that fails, for example before the first unlock after a restart, says "Maru can’t open your records right now. If your iPhone restarted, unlock it first, then ask again." The iPad form names the iPad.
- Every intent runs in the app process and calls an operation of `AppModel` (`AppModel+Siri.swift`). No intent writes the database. No intent sends an analytics event.
- The phrases are in `App/AppShortcuts.xcstrings` in the six languages, one translation for each English phrase. The answers are in `App/Localizable.xcstrings`. The app updates the item parameter of Siri after a read that changes an item or a name.

Privacy: Maru sends nothing. The item names go to the on-device index of App Shortcuts. Siri handles the speech by the rules of Apple. `PRIVACY.md` does not mention Siri yet. A change of it is a maintainer decision (`docs/process.md`).

Tests: none. The change adds no record rule. The record uses the existing transaction and its checks.

Not verified: no build of the app on this Mac (CI builds it), and nobody saw the widget or used Siri. Device checks: the widget in the three families in light, dark, and tinted looks, with a long name and the largest text sizes; the time text over one hour and after midnight; a record in the app, from a reminder, and from "Record Dose", each followed by the widget; a tap on the widget; a locked iPhone after a restart. Siri: each phrase in English and one more language, a name with two words, an item name that Siri does not know, "Record my doses" with a confirmation and with "Cancel", with nothing due, on a locked iPhone, and the snippet. The phrases need a native speaker (`docs/localization-review.md`).

## D109 · 2026-10-28 · The History graph scrolls with the list (changes D041)

Maintainer decision: the History graph must not stay at the top of the page. On the iPad and on the inner display of iPhone Duo, the fixed graph covers the rows under it. Agent decision on the gesture. It replaces the point of D041 that the graph stays above the list and does not scroll.

- The graph is the first section of the History list, before the banner of an unsaved record and "Last 7 Days". It scrolls away with the page.
- The card does not change: the grouped card color, the corner of an inset grouped cell, and padding of 16 points. The list cell has no background and no padding. The card has the side margins of the other sections of the list.
- A vertical swipe that starts on the graph scrolls the page.
- A tap on a square selects that day, and the log of the day opens at the end of the touch (D054).
- A press of 0.2 seconds selects the day under the finger. A drag after the press moves the selection across the days, and the end of the touch opens the log of the day.
- A finger that moves before 0.2 seconds scrolls the page, and the press does not start. While a press is active, the page does not scroll.
- The haptic and VoiceOver of D041 and D054 do not change: a light selection haptic when the selected day changes, one adjustable element, and the default action that opens the log.
- A press that the system cancels, for example for a call, clears the selection, and no log opens.

The gesture: a UIKit tap recognizer and a UIKit long press recognizer, on a clear view over the canvas. In a list, UIKit recognizers share a touch with the scroll of the list by the same rules on iOS 17, 18, and 26. The long press fails when the finger moves before its time, so the list scrolls.

Rejected:

- SwiftUI `LongPressGesture` in sequence before `DragGesture`. It gives no point for the press, so a press that does not move has no day. SwiftUI gestures in a scrolling list also behave differently on iOS 17 and on iOS 18 and later, which is the reason of D041 for the fixed graph.
- A drag only in the horizontal direction. A SwiftUI drag cannot fail on a vertical movement after it starts, so it can block the scroll. A diagonal drag across the weeks also needs both directions.
- `UIGestureRecognizerRepresentable`. It needs iOS 18, and Maru supports iOS 17.

No store change, no schema change, and no new test (D016).

Not verified: no build of the app on this Mac, and nobody saw the graph on a display. CI builds the app. It needs a check on a real device: a swipe up and down that starts on the graph, a tap on a square, a press and a drag across the squares, the haptic, and VoiceOver. Check on an iPhone, an iPad, and the inner display of iPhone Duo, on iOS 17 and on iOS 26.

## D110 · 2026-10-28 · "Next Dose on Lock Screen": the Live Activity of Maru Pro ("Taken" for one member only: D123) (paywall source `feature` replaced by D127)

Maintainer decision on 2026-10-28, with agent detail. It is the first Pro feature of D107. It follows spec 6, 7.2, 8, 9, and 10, and it uses the record checks of D034, D048, and D089.

The switch:

- Settings has a switch "Next Dose on Lock Screen" in its own section after "Reminders". The iPad has no Live Activities, so it has no row.
- A free user who turns it on gets the paywall, and the switch stays off. A Pro user who turns it on starts the activity.
- The switch is in `UserDefaults.standard` under `liveActivity.nextDose`, beside the display settings. It holds no item data, and the backup does not carry it.
- When Live Activities are off for Maru in the Settings app, the footer says so and tells the user where to turn them on. The app then starts no activity.

What the activity shows:

- The next dose: the earliest open planned time of today, with every open dose of that time. A dose with an event that the store did not confirm is left out, because it goes again only from Today (D014).
- The part of the day in the tint, the planned time, and the planned time relative to now. It never says "late" or "missed" (D101). Amended on 2026-10-28: see "The relative time" below.
- The item names, when "Show Names in Reminders" is on (D029). It shows at most three names, in a limit of 600 bytes, then the number of the other doses: "Vitamin D, Iron, Zinc, and 2 more". A name that is too long ends with "…". When the setting is off, it shows "2 doses" with no name. A change of the setting updates the activity.
- A "Taken" button, and a tap elsewhere opens Today at the part of the day.
- The Dynamic Island: the pill symbol and the planned time in the compact form, the pill symbol in the minimal form, and the full content in the expanded form. A relative time does not fit in the compact form in all six languages.

The "Taken" button:

- A `LiveActivityIntent`. The system runs it in the app process, also in the background. It needs an unlocked iPhone, as the "Taken" action of a reminder on the iPhone (D034).
- It holds only a token of 8 characters. ActivityKit limits the content of an activity to 4 KB, and a list of IDs for each dose can go above it with many items (Codex review on 2026-10-28). The app keeps the doses of the token in `UserDefaults.standard` under `liveActivity.nextDose.slot`: the IDs of the doses, their schedule versions, and the restore epoch. It holds no name and no amount. A new set of doses, schedule versions, or restore epoch gets a new token. The same set keeps its token, so an update with the same doses changes nothing. The end of the activity removes the slot.
- An unknown or older token records nothing. The activity then asks to open Maru, with no name and no button.
- It records with the checks of the "Record Dose" widget (D048) for each dose: the same restore epoch, the same occurrence and schedule version, today, and open. The record transaction checks the active item and the plan of now (`requiresCurrentPlan`, D089). Each event revises the record that the call read, so a second tap writes nothing (T18). A dose with a record already needs no event.
- The activity changes only after the commit and the reminder run (spec 7.2, D047). Then it shows the next dose, or it ends when every planned dose of today has a record.
- When a check fails, it records nothing and shows the doses of now. When the commit does not confirm, the activity says "Couldn’t confirm the save. Open Maru to check.", and Today keeps the events for a retry (D014).

The lifecycle. Maru has no server, so no push starts, updates, or ends the activity. Only the app process changes it.

- The app starts an activity only while it is in front, because iOS lets only an app in front start one. It never starts one during the onboarding (D103).
- The app updates the activity after each read of Today that shows: at launch, at each return to the front, and after each save, time edit, archive, delete, and restore. It also updates the activity after each record, and after each reminder run in the background. A background run waits for the update before it returns, because the system can suspend the process. The background runs are:
  - the "Taken" button of the activity
  - the actions of a reminder: "Taken", "Take All", "Skip", "Skip All", and "Remind in 10 min". An action that records nothing also reads the activity again, because the activity can show a dose that another path recorded.
  - the "Taken" action of an alarm
  - the "Record Dose" widget
  - Siri "Record my doses"
  - a record from the Watch
- A record that gives every planned dose of today a record ends the activity with an immediate dismissal, in the same background run.
- The content holds the end of the local day of the dose, and the stale date is that time. After it, the activity says "Open Maru to update." and shows no name and no button, so no button records a dose of another day. A stale date at the planned time showed the dose of the day before as "Not recorded yet", with the names and "Taken", after midnight (Codex review on 2026-10-28).
- The relative time (amended on 2026-10-28, maintainer goal: the activity needs as little care as possible). The first version showed the time left with `Text(timerInterval:countsDown:)`, and "Not recorded yet" after the planned time. The system draws the activity only at each update and at the stale date. So from the planned time to the next update, the time left stayed at zero. Now the activity shows the planned time and a relative time that the system moves on the screen with no update:
  - iOS 18 and later: `Text(.currentDate, format: .reference(to:allowedFields:))`, with the hour and the minute. It reads "in 12 minutes" before the planned time and "12 minutes ago" after it, in the language of the system. Under one minute it reads "now".
  - iOS 17: `Text(_:style: .relative)`. It shows only the distance, "12 min", with no direction. The planned time beside it tells before from after.
  - The text "Not recorded yet" is removed. The activity needs no update at the planned time.
- The app ends the activity when every planned dose of today has a record, when the switch goes off, and when Maru Pro ends. The activity of the next day starts at the next open of Maru.
- No refresh at midnight (2026-10-28). The maintainer asked for one background app refresh near local midnight, only if Maru supports background app refresh already. It does not: `project.yml` has no `UIBackgroundModes` and the app has no `BGTaskScheduler` task. So Maru does not add it. A refresh would also give little:
  - An app in the background cannot start an activity, so a refresh cannot start the activity of the new day.
  - The system chooses the time of a refresh. It can run hours late, or not at all, for example in Low Power Mode or with Background App Refresh off.
  - The stale date already changes the activity of the day before at midnight: "Open Maru to update.", with no name and no button.
- An open dose stays on the activity until it has a record or the day ends. Doz moves its card to the next dose a set time after the planned time (the device walkthrough of 2026-10-28 in the maintainer's research folder). Maru cannot do that with no server and no app code at that time.
- The system ends an activity 8 hours after its start. It can stay on the Lock Screen for 4 more hours with its last content, 12 hours in total. So each open of Maru starts a new activity when the current one is older than 1 hour. The activity then lasts until 8 hours after the last open of Maru. When Maru does not open for 8 hours, the system ends it, and the next open starts it again.
- The calls to ActivityKit run one after the other, so an older update never comes after a newer one. An update with the same content does nothing.

Maru Pro:

- The switch reads `AppModel.pro.isPro`. A free user who taps it gets `presentPaywall(reason: .feature)`. The maintainer's message named a reason `.liveActivity`. D107 defines `feature` as the source of every Pro feature, and `PRIVACY.md` lists only the four sources of D107. A new source needs a change of the privacy text, which is a maintainer decision.
- After each read of StoreKit and each purchase, a loss of Pro (an expiry or a refund) ends the activity and turns the switch off. The cached plan at launch does not turn it off, because a renewal can come after the cached end of access (D107).

Privacy: the activity is on the device. With the names on, a person who sees the Lock Screen sees the names, as with a reminder that shows names. `PRIVACY.md` says so in the section about reminders. No analytics event is new, and no event has item data.

Files: `Shared/NextDoseActivity.swift` (the attributes and the intent), `App/AppModel+LiveActivity.swift` (the rules and the calls to ActivityKit), `Widget/NextDoseLiveActivity.swift` (the views), and `INFOPLIST_KEY_NSSupportsLiveActivities` in `project.yml`.

Tests: none (D016). The record uses the existing transaction and its checks.

Not verified: no build of the app on this Mac (CI builds it), and nobody saw the activity. It needs a real iPhone (spec 14 A). Device checks:

1. The switch as a free user (the paywall, the switch stays off) and as a Pro user. The footer with Live Activities off in the Settings app.
2. The Lock Screen and the Dynamic Island before the planned time ("in 12 minutes"), and after it with no open of Maru ("12 minutes ago"). The same on iOS 17, if a device is available ("12 min"). The names off. Light and dark, a long name, two items at one time, five items at one time ("and 2 more"), and the largest text sizes.
3. "Taken" on a locked iPhone (the unlock comes first), the move to the next dose, and the end after the last dose. A second fast tap.
4. A record on Today, from a reminder ("Taken", "Take All", "Skip", "Skip All"), from an alarm, from the "Record Dose" widget, from Siri, and from the Watch, each followed by the activity with Maru in the background. "Remind in 10 min". The last record of the day ends the activity at once. A time edit, an archive, a delete, and a restore.
5. A refund in the StoreKit transaction manager: the activity ends and the switch goes off.
6. An activity across midnight ("Open Maru to update.", no name, no button), and an activity after 8 hours with no open of Maru.

## D112 · 2026-10-28 · Maru Pro: app icons and reminder sounds (icons extended by D132, sounds replaced by D120)

Maintainer decision on 2026-10-28, with agent detail. It adds two Pro features of D107. It does not change a reminder rule. Only the sound of a request changes.

App icons:

- Six icons: "Default" (the primary pink icon), "Blue", "Purple", "Green", "Night", and "Mono". "Blue", "Purple", and "Green" use the app colors of D025, with the darker light-mode green of the tint. "Night" is the pink capsule on #121212 in every mode. "Mono" is a graphite capsule on white, and a light gray capsule on #121212 in dark mode.
- Each alternate icon has a light look, a dark look, and the tinted look of the primary icon. "Night" has no separate dark look. iOS 17 shows only the light look.
- `docs/brand/make_icons.py` draws them from vector geometry that it fits to the shipped `AppIcon.png`. It writes `App/AppIcons.xcassets`: the five alternate icon sets and a preview of each of the six icons. A second run gives the same files. The primary icon does not change. `project.yml` names the alternate icons (`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`). The Watch app does not get the new catalog.
- Settings, section "Display": the row "App Icon" after "App Color", with the current icon. It opens a page with a grid of the six icons, the name under each, and a ring in the tint on the current icon. The grid is a custom control, because SwiftUI has no native icon picker.
- Every user sees every icon. This is the free preview. A Pro user's tap changes the icon with `UIApplication.setAlternateIconName`, and iOS shows its own alert. A free user's tap on an icon other than "Default" opens `presentPaywall(reason: .icons)`, and the icon does not change. "Default" is free.
- When Pro ends, Maru keeps the icon and does not change it. iOS shows an alert for each change, so a change that the user did not ask for would surprise. Further changes need Pro again. Only "Default" stays free.
- The system keeps the choice, so Maru stores nothing. A reinstall shows the primary icon. When the system refuses a change, the alert "Not Changed" says "The icon didn’t change. Please try again."

Reminder sounds:

- (Replaced by D120.) Six sounds: "Dewdrop", "Petal", "Breeze", "Pebble", "Sunrise", and "Lantern". Each is a soft chime, pluck, or bell of 1.0 to 3.0 seconds, with no alarm sound. No name is the name of an Apple tone.
- `docs/brand/make_sounds.py` synthesizes them from sine waves with numpy, and `afconvert` writes them to `App/Sounds/maru-<name>.caf`: 16-bit linear PCM, 44.1 kHz, mono, with a peak of about -3 dBFS. A second run gives the same files. Together they are about 1.1 MB.
- Settings, section "Reminders": the row "Reminder Sound" after "Show Names in Reminders", with the sound in use. It opens a page with "Default" and the six sounds, a check mark on the sound in use, and a play button on each of the six. The preview is free. It plays once, also with the ring switch on silent, and it mixes with other audio.
- A Pro user's choice plays the sound once and replaces the pending reminders in one run, as a change of "Show Names in Reminders" does. A free user's choice of a sound other than "Default" opens `presentPaywall(reason: .sounds)`, and nothing changes. "Default" is free.
- The choice is in `UserDefaults.standard` under `reminders.sound` (D014). The backup does not carry it.
- The sound in use is the choice while Pro is active, and the default sound of the system when it is not. It reads the cached plan of D107 (`pro.plan` and `pro.expires`), so a reminder run off the main actor can read it. Each run reads it again. The choice stays, so it comes back when Pro comes back.
- A change of Pro starts one reminder run: a refund, an expiry, a restore, a purchase, or a change of Family Sharing. `ProStore` calls `entitlementDidChange` when `isPro` changes after a read of StoreKit or a purchase, and `AppModel.proDidChange` runs the engines when the user chose a sound. A run before StoreKit answers uses the cached plan. The launch does not wait for StoreKit (T35). (Codex review on 2026-10-28.)
- `SystemReminderCenter` gives each request `UNNotificationSound(named:)` and writes the file name in the `userInfo` under `maru.sound`. The system does not tell the sound of a pending request, so the request keeps it there. A request with the default sound has no key, so the requests of earlier builds stay. The key leaves the `userInfo` before the engines compare it. The plan, the identifiers, the triggers, the text, the category, and the level do not change.
- The sound is not part of a correct request. `PendingReminder.hasCurrentSound` is separate from `isCurrent`, so no run removes a request with the correct dose, text, category, and level because of its sound. Both engines give such a request the new sound with `GenerationCenter.refreshSound`: an add with a new identifier, and a removal of the old request only after the system holds the new one. At the system limit it removes nothing first. A failed add keeps the old request with its old sound, and the next run tries again. The first version of D112 treated another sound as a wrong request, so a failed add could remove a correct reminder (Codex review on 2026-10-28).
- The first reminders, the follow-ups, and "Remind in 10 min" use the sound. The notice after a reminder action (D034) keeps the default sound.
- Alarms (D079) keep the default sound of AlarmKit. AlarmKit can take a named sound, but these sounds are 1 to 3 seconds long, and an alarm rings until "Stop". Nobody checked on a device how AlarmKit repeats a short file. A later decision can add an alarm sound after that check.

Analytics: `paywall_shown` gets the sources `icons` and `sounds` (spec 11.5). No event tells which icon or sound the user chose. `PRIVACY.md` lists the two sources. A change of the privacy policy is a maintainer decision (`docs/process.md`).

Licenses: Maru made every icon with `make_icons.py`. It uses no third-party image. (The sounds are replaced by D120.)

No store change and no schema change. The change adds no record rule. One test (D016): `ReminderEngineTests.newSoundNeverRemovesACorrectReminder` shows that a failed add for a new sound keeps the reminder, and that a later run gives it the new sound.

Not verified: no build of the app on this Mac (CI builds it). Nobody heard the sounds on a device or saw the two pages. Device checks:

1. Each icon on the Home Screen, in light, dark, and tinted mode (iOS 18 and later), on an iPhone and an iPad, with the alert of iOS. Spotlight and the Settings app show the same icon.
2. A free user: a tap on an icon or a sound other than "Default" opens the paywall, and nothing changes. A tap on a play button plays the sound.
3. A Pro user: a new sound, then a reminder, a follow-up, and "Remind in 10 min" each play it, also on a locked iPhone and in a Focus.
4. A refund in the StoreKit transaction manager: the icon stays, a tap on another icon opens the paywall, and "Default" still works. When Maru reads the refund, the pending reminders get the default sound with no other step. A restore brings the chosen sound back.
5. Each sound at full ringer volume, in silent mode, and with music: no sound is harsh, loud, or clipped.
6. The grid in the six languages and at the largest text sizes, and VoiceOver on a tile and on a play button.

## D113 · 2026-10-28 · A free "Next Dose" Lock Screen widget

Maintainer decision on 2026-10-28, with agent detail. The widget is free. It is not part of Pro (D107), and it shows no price, no offer, and no mention of Pro. It follows spec 6, 7.2, 9, and 10, and it adds to D048, D094, and D108. It is not the Live Activity "Next Dose on Lock Screen" of Maru Pro (D110). The user adds the widget once and does not have to open Maru to keep it current.

What it shows:

- Families: Lock Screen `accessoryRectangular`, `accessoryCircular`, and `accessoryInline`.
- The next open dose of today: every open dose at one planned time. A dose stays until it has a record or the time of the next open dose comes. Before the first open dose, it is the first one.
- Rectangular, in the layout of D094: the pill symbol, the part of the day, and the planned time in bold. Then the time left ("In 2 hr, 5 min", a relative date that the system counts), or "Not recorded yet" after the planned time. Never "late" or "missed" (D101). Then the names. The Live Activity of D110 removed "Not recorded yet", because nothing draws it again at the planned time. The widget has an entry at each planned time, so the text changes on time.
- Circular: a ring of the doses of today that are taken, with the planned time in it. The time has no AM or PM, so it fits. VoiceOver reads the full time and "2 of 5 taken".
- One line: the planned time and the names.
- Names: at most three, then the number of the other doses ("Vitamin D, Iron, Zinc, and 2 more"), as in D110. With "Show Names in Reminders" off (D029, D108), "2 doses" takes the place of the names.
- When every planned dose of today has a record: "All done for today", with a check mark, until midnight. The ring is then full, or it shows the share of the taken doses when a dose has a skip. With no planned dose today: "Nothing Planned Today".
- Before the first unlock after a restart, or when the read fails: "Open Maru to update." (D066, D108). The widget reads again in 15 minutes.
- A tap opens Today at the part of the day of the dose (D048).

How it updates itself:

- The widget reads the database in the App Group read-only, in one read transaction, with `LocalStore.readForWidget`, as the "Today" widget does. It plans the doses of today in memory and stores nothing (D048).
- The timeline has one entry for now, one at each open dose time of today, and one at midnight with the first dose of tomorrow. So it moves to the next dose and to the next day with no reload. The system reads again at midnight.
- `TodaySnapshot.expiresAt` can come before midnight: 12 hours after the read, or at a midnight in the zone of a plan with a fixed zone. The timeline then plans the same read again from that time.
- The app already reloads every widget after each commit of a record (D108), so a recorded dose leaves the widget at once. A record from a reminder action, the "Record Dose" widget, Siri, or the Watch goes through the same reload.

Privacy: the names show on the Lock Screen only when the user adds the widget and keeps "Show Names in Reminders" on, as with "Last Dose" (D108). Maru sends nothing.

Copy: "%lld doses" and "%lld more" are the strings of the Live Activity (D110), with the same text. The new strings are drafts in five languages (`docs/localization-review.md`).

Tests: none (D016). The widget only reads, and no record rule changes.

Not verified: no build of the app on this Mac (CI builds it), and nobody saw the widget. Device checks:

1. Each family in the gallery and on the Lock Screen, also in StandBy, with a long name, two and five items at one time, the names off, and the largest text sizes.
2. The move to the next dose at its time with no open of Maru, the "Not recorded yet" state, and the time left.
3. A record in the app, from a reminder, from the "Record Dose" widget, and from Siri: the dose leaves the widget.
4. "All done for today" after the last record, and the first dose of tomorrow after midnight, with no open of Maru.
5. A restart with no unlock ("Open Maru to update."), and a tap on each family.

## D114 · 2026-10-28 · Maru Pro: the app color (changes D025 and the paywall rows of D107) (paywall source `feature` replaced by D127)

Maintainer decision on 2026-10-28, with agent detail. Personalization is part of Pro.

App color (D025):

- Pink, the default, stays free. Every other color of the "App Color" menu needs Pro.
- A free user can choose another color. The Settings sheet then shows it as a preview, and `presentPaywall(reason: .feature)` opens. The app color stays pink. Only the Settings sheet has the preview tint. Today, the other pages, the header wash, the widgets, and the Watch keep pink.
- While the preview shows, the footer of "Display" says "This is a preview. With Maru Pro, the whole app uses this color." The preview ends when the sheet closes or when the user chooses pink or the current color.
- A purchase while the preview shows makes the preview color the app color, also a purchase from the "Maru Pro" row.
- When Pro ends, Maru keeps the chosen color and does not change it. Further changes need Pro again. Only pink stays free. This is the same rule as the icons of D112. A user who chose a color before this change keeps it under the same rule.
- A restore of a backup (D040) sets the color of the backup, as before. It is the user's own earlier choice, so it does not need Pro.
- The source of `paywall_shown` is `feature`, as for the Live Activity (D110). So the events, the analytics schema, and the privacy policy do not change. A Pro user's change sends `setting_changed` with `app_color` as before. A preview sends no event of its own.
- Widgets, the Live Activity, alarms, and the Watch follow the stored color as before.

Stays free:

- "Appearance" (D105), because it is about readability.
- "Color Header" (D100, D104), because it follows the current tint.
- Item colors and item photos, because they tell items apart.

Paywall (D107): the third benefit row changes from "Icons and Sounds" with "More app icons and reminder sounds." to "Make It Yours" with "App colors, icons, and reminder sounds." The symbol stays `paintpalette`. The text of the card of Today changes to "Maru Pro adds this, an Apple Watch app, and more colors, icons, and sounds. Everything else stays free.", because its last sentence was not true with a paid color. The six languages are drafts (`docs/localization-review.md`).

No store change, no schema change, and no test (D016). The change adds no record rule.

Not verified: no build of the app on this Mac (CI builds it). Nobody saw the menu, the preview, or the paywall. Device checks with the StoreKit configuration:

1. A free user chooses blue: the Settings sheet turns blue, the paywall opens, and the footer shows. Close the paywall: the sheet stays blue. Close Settings: the app is pink.
2. A free user chooses blue, then buys in the paywall: the whole app turns blue.
3. A refund in the transaction manager: the color stays. Another color opens the paywall. Pink still works.
4. The footer in the six languages and at the largest text sizes.

## D111 · 2026-10-28 · The Apple Watch app is a Pro feature, and the app embeds it again (replaces D074) (paywall source `feature` replaced by D127)

Maintainer decision of 2026-10-28, with agent detail. The Apple Watch app is a Maru Pro feature (D107), and it ships in the first public release. It replaces D074. The rules of D071 and D066 for the list and the record stay.

Build:

- `project.yml`: the `Maru` target depends on `MaruWatch` again. XcodeGen puts the Watch app in the phase "Embed Watch Content", so an archive of the app has `Maru.app/Watch/MaruWatch.app`.
- CI builds the Watch app as part of the app build, and it checks that the project embeds the Watch app. The separate Watch step of D074 is gone. The `MaruWatch` scheme stays for a run of the Watch app alone.
- The Watch app keeps the bundle ID `com.imhangli.maru.watchkitapp` and `WKCompanionAppBundleIdentifier` = `com.imhangli.maru`. It needs no App Group and no entitlement: it has no database, and WatchConnectivity needs no capability.
- The Watch app has no privacy manifest. It uses no API that needs a reason, has no third-party code, and collects no data. `App/PrivacyInfo.xcprivacy` does not change.

The gate:

- `WatchDay` has a new field `isPro`, from `ProStore.isPro` on the iPhone. The iPhone sends it in the same application context and in each reply, after each read, each commit, each change of the tint, and each change of Maru Pro.
- A free user's list has no dose. So no name, amount, or time leaves the iPhone for a free user. Only the Pro state, the tint, and the times of the list go.
- The Watch shows the locked screen when the last list says free, also for a list of an earlier day: "Maru Pro", "See and record today's doses on your wrist.", "Unlock with Maru Pro on your iPhone.", and the button "Open on iPhone". The Watch sells nothing and has no purchase.
- "Open on iPhone" sends the request `WatchRequest.showPro`. The iPhone keeps it in `UserDefaults.standard` (`pro.watchAsked`), because the request can start Maru in the background. The root view shows the paywall the next time that Maru is in front, after the onboarding, the edit screen, and the alerts, once for each request. The source of `paywall_shown` is `feature`. This is the one paywall that can show when Maru comes to the front, because the user asked for it. When the iPhone is not reachable, the Watch says so, and the user opens Maru on the iPhone.
- When Pro ends (a refund, the end of the yearly plan, or a revoked family share), the next list says free, and the Watch shows the locked screen again.
- The iPhone checks Pro again for each record request (`recordFromWatch`). A free user's request records nothing, also from a Watch that still shows an old Pro list. All the checks of D071 still apply to a Pro request.
- The reminders on the Watch are not part of the gate. They are the iPhone notifications that watchOS mirrors, with the "Taken" action of D034, and they stay free.

Debug: `-MaruDebugPro YES` makes `ProStore.isPro` true in a debug build, for a check of the Watch app in a simulator. A release build does not have the code.

`PRIVACY.md` has a section "Apple Watch" again, and the privacy pages of the site are built again. The site build needed headings for "Maru Pro" (D107) and "Apple Watch" in each language. The privacy pages are not deployed. The FAQ, `site/llms.txt`, and `DEVICES` in `site/build.py` still say that Maru has no Watch app, because that is true for the version in the App Store. Change them on the day of the release with the Watch app.

Check: after the merge, on 2026-10-29, the merged code ran in paired simulators (iPhone 17 Pro with iOS 27.0, Apple Watch Series 12 with watchOS 27.0), with the maintainer's permission of 2026-10-28. These passed: the locked screen of a free user, "Open on iPhone" (the iPhone in front showed the paywall), the Pro list, "Taken", "Undo", and "Skip" from the Watch with the record on the iPhone, and the locked screen again after Pro ended. The locked iPhone was not tested, because the simulator cannot lock a device. Pro came from `-MaruDebugPro YES`, not from a purchase. The screenshots, a video, and the report are in the maintainer's research folder, `maru/watch-check/`. CI builds the embedded Watch app.

Not verified: nobody ran the Watch app on a real Watch. The checks of D071 and D066 for a real iPhone and Watch stay open. App Store Connect needs Apple Watch screenshots before a submission with the Watch app, and App Review needs a way to see the Watch app with Pro (a sandbox purchase).

## D115 · 2026-10-28 · A plain Apple look for Maru Pro: the paywall, the Settings row, the Today card, and the thank-you (changes the look of D107; the paywall part is replaced by D118)

Maintainer request on 2026-10-28, in two rounds. First, the paywall looked plain. A serif, a glow, and a preview card followed, and the maintainer rejected them: the paywall was "very ugly", it must be simpler and more direct, a reader of another language must understand it at once, it may use only the app font, and everything must look like Apple. This decision changes the look only. The StoreKit code, the entitlement rules, the offers, and every price rule of D107 stay as they are. The paywall still has no countdown, no trial switch, no discount, no urgency text, and a "Continue Free" button with the size and shape of the buy button.

Research: Apple Music, Fitness+, and News+ sheets, the HIG pages "Apple In-App Purchase" and "Offering subscriptions", and Apple's `SubscriptionStoreView` share one shape: an icon, one title, a short value, a plan list with a check circle, one terms line above one capsule button, a close button in the corner, and small links. None has a glow, a serif, or a preview card. The notes are in `~/Documents/Research/maru/paywall-redesign/references.md`.

- Type: SF Pro only, with text styles (`.largeTitle.bold()`, `.headline`, `.body`, `.subheadline`, `.footnote`). The New York helper, the glow, and the badge view (`ProStyle.swift`) are gone. Dynamic Type works through the text styles.
- Background: `systemGroupedBackground` with `secondarySystemGroupedBackground` cards, as in Settings. No material, no shadow, no gradient, no motion.
- First screen, from top to bottom: a close button, the app icon in use (64 points), "Maru Pro", three benefit rows, two plan rows, one terms line, the buy button, "Continue Free", and the four small links. It fits on an iPhone 17 Pro and on an iPhone 17e (390 by 844 points) at the default text size, with no scroll. At an accessibility text size, the page scrolls and the plan rows stack the price under the name.
- Benefits: an SF Symbol in the tint and a label of at most four words. "Dose on Lock Screen" (`lock.iphone`), "Apple Watch" (`applewatch`), and "Colors, Icons, Sounds" (`paintpalette`). The symbol says the same as the label to a reader of another language. The benefit sentences and the colors, icons, and sounds preview card are gone. The sounds still play in Settings (D112).
- Plans: one grouped card with two rows, "Yearly" and "Lifetime". Each row has a check circle, the name, a short note ("7 days free" and "No subscription"), and the price with its period at the end. The price is the same size as the name and larger than the note (App Review 3.1.2). The selected row has the filled check circle and the selected trait for VoiceOver.
- Terms: one footnote line under the plans, for the selected plan, with the price and the period. "Free for 7 days, then $9.99 per year. Renews until you cancel." Without a trial: "$9.99 per year. Renews until you cancel." For the lifetime plan: "One payment. It does not renew." The trial timeline is gone, because the line says the same and the system confirmation sheet shows the dates (HIG: do not replace that sheet).
- Buttons: "Try It Free" for the yearly plan with a trial, "Subscribe Yearly" without a trial, and "Buy Lifetime". "Continue Free" under it has the same size, font, and shape, with a gray fill and the text color. The close button in the corner also dismisses.
- Links: "Restore Purchases" and "Redeem Code" in one row, "Terms of Use" and "Privacy Policy" in the next row. The line "Shareable with Family Sharing" and the 24-hour cancel sentence are gone. The renewal fact stays in the terms line, and the App Store sheet states the rest.
- Thank-you: after a purchase, a full-sheet system background shows a check circle (one bounce, none with Reduce Motion), "Welcome to Maru Pro", and "Thank you. Your extras are ready.", with the success haptic. The paywall closes after 1.6 seconds. The purchase has already finished by then, so no confirmation comes before the commit (spec 7.2).
- Settings: the row "Maru Pro" has the app icon in use (40 points), a headline title, and "Lock Screen, Apple Watch, and more", with a chevron. For a Pro user it shows "Active, Yearly" or "Active, Lifetime". "Restore Purchases" and "Redeem Code" did not change.
- Today card: a `lock.iphone` symbol in the tint, a headline title, one sentence, the borderless button "See Maru Pro", and "×", on the normal row background. It still sits at the bottom of the list, never pushes a dose, and "×" hides it.
- First-value offer: it shows the same paywall. The static Lock Screen picture with the first item is gone, with `NextDosePreview` and the `preview` field of `PaywallRequest`. The offer rules did not change: once per install, after the first save of an item with a time, after the alerts of the save. The offer no longer copies the name, the amount, or the time of an item into view state.
- `SubscriptionStoreView` was not used. It shows only auto-renewable subscriptions of one group, so the lifetime plan (a non-consumable) cannot sit beside the yearly plan, and the compact picker has no room for "Continue Free". A custom view from system parts has the same look as the Apple sheets and keeps D107. `StoreView` for the lifetime plan would put it one screen deeper.
- New strings: "Dose on Lock Screen", "Apple Watch", "Colors, Icons, Sounds", "Try It Free", and three terms lines, in the six languages. The strings of the removed rows, timeline, and preview card left the catalog. `docs/localization-review.md` lists the new ones.

Evidence: simulator captures of the Today card, the paywall in light, dark, and zh-Hans, the Settings row, and an iPhone 17e (the smallest simulator here), at the default size and at the accessibility size "Extra Large", and a recording of the open, are in `~/Documents/Research/maru/paywall-redesign/v2/`. The simulator cannot attach `Config/Maru.storekit` when it starts from the command line, so a copy of the code in `/tmp`, not in the repository, set the two prices ($9.99 with a 7-day trial and $19.99) and forced the Today card. The real StoreKit path was not run.

Not verified: no check on a real iPhone, on an iPad, with VoiceOver, or with Reduce Motion. The purchase with the StoreKit configuration (the thank-you, then the close), a restore, a pending purchase, and the long German and Spanish lines are open. The smallest iPhone that iOS 17 supports (iPhone SE, 667 points high) was not available as a simulator, so the first-screen rule is proven only down to 844 points. On a 667-point screen the two small link rows are under the first screen, and the buy button is above them.

## D116 · 2026-10-28 · Paywall style B: a gradient picture, one headline, and a button that names the plan (an option next to D115, lower half redesigned by D117, replaced by D118)

Maintainer feedback on the plain paywall of D115, on 2026-10-28: it is too plain and boring, a user would not want to buy it, and it has no focal point. The maintainer asked for a look at the ChatGPT and Claude upgrade pages, and for a very abstract, modern gradient picture as the look of the paywall, and maybe of other places. The earlier rules stay: very simple and direct, understandable at first look by a reader of another language, the system font only, and an Apple look. This decision adds a second paywall ("style B") so the maintainer can compare the two on a display and keep one. It changes no StoreKit code, no entitlement rule, no price rule, and no trigger of D107.

Research: the notes are in `~/Documents/Research/maru/paywall-redesign/references.md`. I found no first-hand screenshots of the current ChatGPT or Claude pages, only captions: both use a plain screen with one primary button that names the plan, a marked selected plan, and a visible way out ("Stay on Free"). They have no decorative hero, so a picture is a focal point that they do not have. The article that the maintainer shared (a study of 1700+ apps) asks for a clear paywall: a headline and a supporting line with the outcome, the paid thing shown, free and paid obvious, the price, trial, renewal, and cancel text up front, a button that names the plan, the price next to the button, a visible close and restore, and a test of small screens, large text, and long translations.

- Where: `App/Pro/PaywallStyleB.swift`, a separate view. `PaywallView` (D115) is unchanged, except that `PaywallHost` shows style B in a debug build with the launch argument `-MaruPaywallStyleB YES` (`DebugLaunch.wantsPaywallStyleB`). A release build shows only the plain paywall until the maintainer picks a style. The purchase code is a copy of the code of `PaywallView`. When the maintainer picks one style, delete the other view, and make the winner the only paywall.
- Picture: `ProHero` in `App/Assets.xcassets`, a 1024 by 1536 JPEG of 177 KB. The image generation of Codex made it (four candidates, one chosen): soft flowing rose, magenta, coral, and cream color fields with a fine grain, no text, no object, no logo. It uses the palette of the app color (the pink of D025). It is in `docs/third-party-licenses.md` as a generated image with no third-party license. The four candidates are in `~/Documents/Research/maru/paywall-redesign/style-b/art/`.
- Hero: the picture fills the top of the sheet, from edge to edge, with the bottom corners rounded. Its height is 34 percent of the sheet, at least 220 and at most 320 points, and it grows with the text size. A dark scrim at its foot keeps the white text readable in light and dark mode. The picture drifts slowly (10 seconds, a few points). With Reduce Motion it stands still.
- Headline: "Your next dose, at a glance." in the large bold system font, over the picture. Over it, a small "Maru Pro". Under it, one supporting line: "Add Lock Screen, Apple Watch, and your own look. Reminders stay free." The headline names the result, and the line makes free and paid clear. Both lines are short, with a plain word order, so they translate well.
- Paid features: three tiles in a row, each with an SF Symbol in the tint on a rounded square and two to four words: "Dose on Lock Screen", "Apple Watch", and "Colors, Icons, Sounds" (the strings of D115). At an accessibility text size the tiles become rows.
- Offer: two plan cards with a check circle, the name, a note, and the price with its period. The selected card has a border in the tint. The price is as large as the name and larger than the note (App Review 3.1.2). The yearly plan is selected first.
- Terms and button: directly above the buttons, one footnote line for the selected plan, with the price next to the button: "Free for 7 days, then $9.99 per year. Renews automatically. Cancel anytime.", "$9.99 per year. Renews automatically. Cancel anytime.", or "One payment. It does not renew." The buy button names the plan: "Start Free Trial" (yearly with a trial), "Subscribe Yearly", or "Buy Lifetime". A change of plan changes the card, the terms line, and the button together.
- Free and close: "Continue Free" has the size, font, and shape of the buy button, in a gray fill (D107). A close button sits on the picture at the top right and stays in view when the page scrolls. "Restore Purchases", "Redeem Code", "Terms of Use", and "Privacy Policy" are under the buttons, as in D115.
- Not added: no countdown, no trial switch, no struck price, no discount, no "best value" badge, no other font, and no extra animation. The thank-you after a purchase is the one of D115.
- Other places: the picture could tint the Settings row or the Today card of Maru Pro. This decision does not do that. It waits for the maintainer's choice.
- New strings, in the six languages: "Your next dose, at a glance.", "Add Lock Screen, Apple Watch, and your own look. Reminders stay free.", two terms lines, and "Start Free Trial". `docs/localization-review.md` lists them.

Evidence: simulator captures and a recording are in `~/Documents/Research/maru/paywall-redesign/style-b/`. The simulator cannot attach `Config/Maru.storekit` when it starts from the command line, so a copy of the code in `/tmp`, not in the repository, set the two prices ($9.99 with a 7-day trial and $19.99) and opened the paywall at launch. The real StoreKit path was not run.

Not verified: no check on a real iPhone, on an iPad, with VoiceOver, or with Reduce Motion. The purchase, a restore, a pending purchase, and the long German and Spanish lines are open. The smallest iPhone that iOS 17 supports (iPhone SE, 667 points high) is not a simulator here, so the first-screen rule is proven only down to 844 points.

## D117 · 2026-10-28 · Paywall style B, second round: two calm looks for the lower half, B1 "Immersive" and B2 "Clean sheet" (replaces the tiles and plan cards of D116, replaced by D118)

Maintainer feedback on style B, on 2026-10-28: the picture and the headline "Your next dose, at a glance." are good. Everything under the picture is "very, very ugly": some icons and fonts look generated, and the layout is messy. A second message: the join of the picture and the content is abrupt, and the page must flow as one piece. This decision replaces the lower half with two looks, so the maintainer can choose one. It changes no StoreKit code, no entitlement rule, no price rule, no string, and no trigger of D107.

Why the old lower half looked wrong: three colored icon badges on gray tiles, gray plan cards, a pink outline, a gray "Continue Free" with the weight of the buy button, and pink links gave too many container types and fills. The hero was left aligned, and the tiles and terms were centered. The type had too many sizes. The picture ended in a rounded card with a hard edge above a white page.

Shared rules of both looks:
- One margin (20 points) and one left edge for the headline, the benefits, the plan list, the terms, and the links. Buttons are full width.
- One type scale of Apple text styles: `largeTitle.bold` (headline), `headline` (name, plan name, price, button, "Maru Pro"), `body` (supporting line, benefits, "Continue Free"), and `footnote` (notes, period, terms, links). At an accessibility size, the headline and supporting line are one step smaller, as in D116.
- One radius (20 points, continuous) for the plan list. No gray tile, no icon badge, no outline.
- Benefits: three rows with a monochrome SF Symbol and the labels of D115. The symbol column has one width, so the labels line up.
- Plans: one list with two rows, a check circle (filled for the selected plan), the name and note, and the price with its period. The yearly plan is selected first. The price has the size of the name and is larger than the note (App Review 3.1.2).
- Actions: the terms line of the selected plan, one prominent capsule button that names the plan, "Continue Free" as a quiet text button (a full-width target, `body`, primary color), and four small links in secondary gray, in two rows. The headline has a narrow measure, so it breaks as "Your next dose," and "at a glance." The break is the only change to the headline.
- Accent: the app tint colors the symbols, the selected check, and the buy button (B2). B1 uses white for the same three. Links are never pink.
- The close button is a dark translucent circle on the picture at the top right, in view when the page scrolls. Restore, Redeem Code, Terms, and Privacy stay. The purchase code, the notices, and the thank-you did not change.

B1 "Immersive": the picture is the whole page (`HeroArt` behind the scroll view, full-bleed under the status bar). Two layers darken it toward the foot: a blurred copy of the picture (radius 32) that a gradient mask fades in from 30 to 90 percent of the height, and a black wash from 12 to 55 percent opacity. The page forces the dark color scheme, so all text is white and vibrant. The plan list is an ultra-thin material. The buy button is a white capsule with black text. On a tall screen, the headline stays at the top and the rest sits at the foot.

B2 "Clean sheet": the picture is the top of the page, full-bleed from the top edge (under the status bar and the close button). It is the background of the headline block and ends in a fade into the system background (white in light mode, black in dark mode). The fade is an alpha mask on the picture: a solid rectangle, then a 120-point gradient with eight eased stops from opaque to clear (no linear ramp, so no visible start or end). The picture extends 60 points below the headline block, under the first benefits, and a dark wash (10 to 45 percent) under the headline keeps white text readable in light mode. The headline sits on the solid part and the start of the fade. The benefits start right below with no card frame. The plan list is one `secondarySystemBackground` group.

Debug launch arguments (a release build shows only the plain paywall): `-MaruPaywallStyleB1 YES` and `-MaruPaywallStyleB2 YES`. They replace `-MaruPaywallStyleB YES` of D116. When the maintainer picks one look, delete the other look, `PaywallView` (D115) if style B wins, and the launch arguments.

Fit: at the default text size, the first screen with no scroll shows the headline, the benefits, both prices, the terms, the buy button, "Continue Free", and the links on an iPhone 17 Pro and an iPhone 17e. At the accessibility size "Extra Large" the page scrolls, and the plan rows stack the price under the name.

Evidence: simulator captures (light, dark, zh-Hans on an iPhone 17 Pro, light and "Extra Large" on an iPhone 17e) and `compare.png` (old B, B1, B2, light and dark) are in `~/Documents/Research/maru/paywall-redesign/style-b2/`. As in D116, a copy of the code in `/tmp`, not in the repository, set the two prices and opened the paywall at launch.

Not verified: a real iPhone, an iPad, VoiceOver, Reduce Motion, the purchase with the StoreKit configuration, and the long German and Spanish lines. The smallest iPhone that iOS 17 supports (667 points high) is not a simulator here. The white "Continue Free" and link rows were not checked for contrast with a tool. The text on the fade of B2 is black on a pink tint for the first benefit row in light mode, and it is readable in the captures only.

## D118 · 2026-10-28 · The final Maru Pro paywall: a calm page and a pinned purchase area (replaces the paywall of D115 and style B of D116 and D117, replaced by D119)

Maintainer decision on 2026-10-28: keep style B2 "Clean sheet" of D117, then make it as clean as the paywall of Doz (a pill reminder app), with an Apple look. Keep the gradient picture and the headline "Your next dose, at a glance." This decision removes the plain paywall of D115, the style B option of D116, and the look B1 "Immersive" of D117, with their code, strings, and the debug switch. It changes no StoreKit code, no entitlement rule, no price rule, no trigger of D107, and not the thank-you. The Today card and the Settings row did not change.

What I took from Doz, and why:
- A soft tinted page. The tint of the app washes the whole background, very faint (14 percent in light mode, 20 percent in dark mode, fading to 3 percent at the foot). The picture fades into it, so the page is one piece.
- Benefit rows with a thin symbol in the tint, a semibold title, and one gray line. The lines are new: "See your next dose without opening Maru.", "Record a dose from your wrist.", and "Pick your app color, icon, and reminder sound."
- A pinned purchase area at the foot of the sheet, on the same tint wash as the page, with no flat color of its own, and the page fades out above it over 28 points, so the page scrolls away softly. It holds two plan tiles, the line "Share with your family" (symbol `person.2`, Family Sharing is on), the terms of the selected plan, one capsule button, and one line with a check mark under the button: "Cancel anytime" for the yearly plan, "One payment" for the lifetime plan. The terms line stays beside the button (App Review 3.1.2).
- Plan tiles side by side: the name, the price as the largest text, and a small line ("7 days free", "One time"). The selected tile has an outline in the tint. A per-month price is not shown, because it adds a second price that the user must compare.
- "Restore Purchases", "Redeem Code", "Terms of Use", and "Privacy Policy" end the scrolling page, after the note "Maru is made by one independent developer. Thank you for your support."

What I did not take: laurel wreaths, a countdown, a struck-through price, "SAVE" badges, user reviews (Maru has none), a large app icon (the picture is the focal point), and centered body text. The text column is left aligned with one 20 point margin.

Other rules:
- The type is SF Pro with text styles. The one accent is the app tint (symbols, the selected outline, the button).
- The supporting line under the headline and "Continue Free" are gone. The close button at the top right ends the paywall, and the benefit lines now say what Pro adds. The page says "Reminders stay free" nowhere, because the free app is the app that the user already has.
- At an accessibility text size, the purchase area scrolls with the page, so it never covers the screen. The tiles stack.
- Terms lines are the ones of D115 ("Renews until you cancel."). The lines of D116 with "Renews automatically. Cancel anytime." are removed, because the new line under the button says "Cancel anytime".
- Removed strings: "Try It Free", "Continue Free", "No subscription", "per year", "one time", the supporting line of D116, and the two terms lines of D116.
- Debug launch arguments `-MaruPaywallStyleB1` and `-MaruPaywallStyleB2` are gone. A debug build shows the paywall as a release build does.

Fit: on an iPhone 17 Pro and an iPhone 17e at the default text size, the first screen shows the headline, the three benefits, both prices, the terms line, the button, and the reassurance line.

Evidence: captures (light, dark, zh-Hans, scrolled, an iPhone 17e, and "Accessibility Extra Large") and `compare.png` (Doz, B2, final) are in `~/Documents/Research/maru/paywall-redesign/final/`. A copy of the code in `/tmp`, not in the repository, set the two prices and opened the paywall at launch.

Not verified: a real iPhone, an iPad, VoiceOver, Reduce Motion, the purchase with the StoreKit configuration, the long German and Spanish lines, the iPhone SE size, and the contrast of the gray lines on the wash with a tool.

## D119 · 2026-10-28 · The Maru Pro paywall, third round: system parts, less text, one line each, and a plain background (replaces D118, plan tiles changed in a fourth round below, price and benefit copy changed in a sixth round below, small polish in a seventh round below, lifetime price replaced by D139)

Maintainer feedback on 2026-10-28 about the paywall of D118. This decision replaces the paywall of D118. It changes no StoreKit code, no entitlement rule, no price rule, and no trigger of D107. The thank-you and the first-value offer are as before.

What changed, and why:
- System parts. The paywall is a normal system sheet with a `NavigationStack`. The close button is in the navigation bar, at the top right. On iOS 26 and later it is `Button(role: .close)`, the system glass "X". Before iOS 26 (the deployment target is 17.0), it is a plain `xmark` button. The custom circle is gone. The bar has no background, so the picture runs under it.
- Less text. These are gone: "Maru is made by one independent developer. Thank you for your support.", "Share with your family" (the maintainer did not understand it there), the line with a check mark under the button ("Cancel anytime", "One payment"), "Restore Purchases", and "Redeem Code". Their strings are removed from the catalog. Family Sharing stays on in the products. The paywall only does not mention it.
- Restore and Redeem are in Settings only. The "Maru Pro" section of Settings already has "Restore Purchases" and "Redeem Code" with the same logic, so the paywall calls neither. App Review 3.1.1 needs a Restore control somewhere in the app, and Settings has it.
- Terms and Privacy stay on the paywall, because App Review 3.1.2 needs working links to both in the purchase flow. They are two small gray links on one line at the very bottom of the purchase area, in `caption2`, with a dot between them. Settings has "Privacy Policy" in "About". It has no "Terms of Use", and this decision does not add one.
- One terms line, directly above the button, for the selected plan: "Free for 7 days, then $9.99 per year. Cancel anytime.", "$9.99 per year. Cancel anytime." (no trial), or no line for the lifetime plan (D119, fifth round). Each subscription line states the price and the period. It may shrink to 90 percent. Nothing else shrinks.
- One line each. The third benefit line is now "Choose your app color, icon, and sound." and the German line of the first benefit is "Dosis sehen, ohne Maru zu öffnen.". Each benefit title, each benefit line, the terms line, and each button label fit on one line at the default text size on an iPhone 17e and an iPhone 17 Pro in English, zh-Hans, German, and Spanish.
- Black text on white. The benefits start under the end of the picture fade, on the plain background. No dark text sits on the picture or on the fade.
- No wash. The page background is the plain system background, white in light mode and the system dark color in dark mode. The tint wash is gone. The fade of the picture is longer (96 points under the headline) and eased (smootherstep), and it ends before the first benefit. The page also fades into the plain background above the purchase area.

Fourth round, plan tiles (maintainer decision of 2026-10-28): the maintainer likes the page, and the two tiles felt "not exciting". The maintainer confirmed that Maru Pro has no monthly plan. It keeps the yearly plan ($9.99, 7-day free trial) and the lifetime plan ($19.99 then, $24.99 since the sixth round). Only the tiles changed, with true information:
- Yearly tile: the name, the billed price, and a line "≈ $0.83/month". The number is the price of the StoreKit `Product` divided by 12, in its `priceFormatStyle`, and no code sets it. The free trial is a tag, "7 days free", on the top edge of the tile. It shows only when StoreKit says that the user can still get the trial (the rule of D107).
- Lifetime tile: the name, the billed price, and "Pay once. It’s yours." (seventh round).
- (The eighth round removed this gradient fill.) The selected tile is filled with a smooth linear gradient, from the top leading corner to the bottom trailing corner, in the brand colors of `ProHero`: a pink a little darker than the tint (`#E01F4D`) and the deep crimson of the picture (`#73083D`). It has no image and no noise. The text is white. The pink end is darker than the tint, so white semibold text has a contrast of about 4.7 to 1. The other tile keeps the quiet gray fill and the normal text. The change animates for 0.25 seconds and does not animate with Reduce Motion. It looks the same in light and dark mode, because the colors are fixed. (First, the tile used the picture with a dark veil. The maintainer did not like the picture in the tile, so the fifth round replaced it with this gradient.)
- Fifth round: with the lifetime plan selected, the terms line is blank, because the tile already says "Pay once. It’s yours." (seventh round). The blank line keeps the height, so the button does not move. The yearly terms line stays (App Review 3.1.2). The string "One payment. Yours to keep." left the catalog.
- The price stays the largest text in each tile (App Review 3.1.2 and D107). The tag and the monthly line are smaller. There is no "Most popular", "Best value", "Save xx%", countdown, or strikethrough.
- Strings: "One time" is gone, and so is "One payment. Yours to keep." (fifth round). "Pay once, keep forever" (now "Pay once. It’s yours.", seventh round) and "≈ %@/month" are new, in six languages. Every line of the tiles and the terms line fits one line at the default text size on an iPhone 17e and an iPhone 17 Pro in en, zh-Hans, de, es, ja, and ko (captures). Not verified: an accessibility text size with the new tiles, a real iPhone, VoiceOver, Reduce Motion, and the contrast of the white tag text on the tint with a tool.
- Evidence: captures and `compare.png` (D119 next to the new tiles) are in `~/Documents/Research/maru/paywall-redesign/final-v3/`. The captures of the gradient tile (fifth round) are in `final-v4/`. A copy of the code in `/tmp` set the prices.

Sixth round, price and benefit copy (maintainer decision of 2026-10-28). Only text and one price changed. No layout, StoreKit code, entitlement rule, or trigger changed.
- The lifetime price is $24.99, not $19.99. The yearly plan stays $9.99 with a 7-day free trial, and there is no monthly plan. `Config/Maru.storekit` has the new lifetime price for local tests. The app has no price in code: every tile and terms line reads `Product.displayPrice` from StoreKit (`ProStore`). The product `com.imhangli.maru.pro.lifetime` does not exist in App Store Connect yet. Create it at USD 24.99 (`docs/release-plan.md`, section 7).
- The three benefit rows have new plain copy (title / line), each on one line on an iPhone 17e:
  - "Right on your Lock Screen" / "See dose and time without opening Maru."
  - "Record from your wrist" / "Tap Taken on Apple Watch. Needs iPhone."
  - "Make Maru yours" / "App colors, icons, and reminder sounds."
- Why these words. The titles do not repeat the headline "Your next dose, at a glance." The first draft of the maintainer's proposal had three claims that are not true or too strong: "always in sight" (the Live Activity ends when the day is done, and the system ends it about 8 hours after the last open of Maru), "No unlocking" (the "Taken" button records after an unlock), and "Phone stays put" (the Watch asks the iPhone to write each record, so it needs the iPhone). Two Codex reviews with five simulated personas (a student with basic English, a busy parent, a 60-year-old on blood-pressure medicine, a fitness person, and a design-minded iPhone user) also found two idioms ("in sight", "stays put"), the unclear verb "Log it", and "your" three times in the third row. The final lines have none of these. The lines make no health claim and no promise of adherence (App Review 1.4.1). The reviews are in `~/Documents/Research/maru/paywall-redesign/copy-review/`.
- A description fits one line at about 40 characters on an iPhone 17e. Captures showed that 43 and 44 characters wrap, so the lines have 39.
- The six old strings left the catalog ("Dose on Lock Screen", "See your next dose without opening Maru.", "Apple Watch", "Record a dose from your wrist.", "Colors, Icons, Sounds", and "Choose your app color, icon, and sound."). The six new strings are in six languages (`docs/localization-review.md`). The settings rows, the card of Today, and the Watch app keep their own strings.
- Evidence: captures on an iPhone 17 Pro (yearly and lifetime selected) and on an iPhone 17e (en, zh-Hans, de, ja, es, ko) are in `~/Documents/Research/maru/paywall-redesign/final-v5/`. A copy of the code in `/tmp` set the two prices. The real StoreKit path was not run. No native speaker read the translations.

Seventh round, small polish (maintainer request of 2026-10-28). Only `PaywallView` and one string changed. No StoreKit code, entitlement rule, price, or trigger changed.
- Benefit symbols. Each symbol sits at the vertical center of its row, the block of the title and the line (`HStack(alignment: .center)`). Before, it sat on the first text baseline, so it looked high. The symbol column keeps its fixed, scaled width, so the text stays aligned at every text size.
- Selection ring. The selected plan tile gets a ring of 1.5 points in the tint pink (the eighth round keeps the ring and removes the gradient). The ring lies outside the tile with a gap of 3 points, with continuous corners (the radius of the tile plus the gap). It is an overlay with a negative inset, so it never changes the size of the tile or moves the layout. The other tile has no ring. The ring fades with the 0.25 second animation of the tile, and not with Reduce Motion.
- Lifetime line. "Pay once, keep forever" is now "Pay once. It’s yours." and fits one line in all six languages (`docs/localization-review.md`). The old string left the catalog.
- Evidence: captures are in `~/Documents/Research/maru/paywall-redesign/final-v6/`.

Eighth round, no gradient in the tile (maintainer request of 2026-10-28). Only `PaywallView` changed. No StoreKit code, entitlement rule, price, string, or trigger changed.
- The selected tile has the same fill as the other tile (`secondarySystemBackground`) and the same text colors (primary and secondary, not white). The gradient fill, its two colors, and the white text are gone from the code.
- The selection ring stays: 1.5 points, 3 points outside the tile, in the tint pink (the app tint, `.tint`), with the 0.25 second animation and no animation with Reduce Motion. The "7 days free" tag stays as it was.
- Evidence: captures are in `~/Documents/Research/maru/paywall-redesign/final-v7/`.

Fit: the first screen at the default text size on an iPhone 17 Pro and an iPhone 17e shows the headline, the three benefits, both prices, the terms line, the button, and the two links.

Evidence: captures (light and dark on an iPhone 17 Pro, zh-Hans on both phones, light, German, and Spanish on an iPhone 17e, and the Settings section) and `compare.png` (D118 next to D119) are in `~/Documents/Research/maru/paywall-redesign/final-v2/`. A copy of the code in `/tmp`, not in the repository, set the two prices and opened the paywall at launch.

Not verified: a real iPhone, an iPad, VoiceOver, Reduce Motion, the purchase with the StoreKit configuration, the plain `xmark` button before iOS 26, an accessibility text size after this change, the iPhone SE size, ja and ko line fit, and the contrast of the gray lines with a tool. The two privacy links differ: the paywall opens `https://maru.day/privacy/` and Settings opens `https://maru.day/privacy.html`. The maintainer must check that both open the page.

## D120 · 2026-10-29 · Reminder sounds: eight CC0 sounds (replaces the sound part of D112)

The maintainer listened to eight candidate sounds on 2026-10-29 and liked them. The sounds replace the six sounds that Maru generated in D112. The icon part of D112 does not change.

- Eight sounds, in this order after "Default": "Rising Chime", "Marimba", "Soft Bell", "Glass", "Chime Bars", "Hand Bell", "Music Box", and "Synth Bell". The names are localized in en, zh-Hans, ja, es, de, and ko. The Chinese names are 上升风铃, 马林巴, 柔和钟声, 玻璃, 音条风铃, 手摇铃, 八音盒, and 合成铃声.
- Each sound is a CC0 1.0 file from another author: seven from Freesound and one from Kenney. `docs/third-party-licenses.md` lists the author, source URL, license, and edits of each. CC0 needs no credit, so the app shows no notice.
- Each file is `App/Sounds/maru-<name>.caf`: 16-bit linear PCM, 44.1 kHz, about -16 LUFS (Chime Bars is about 3 dB quieter), 0.67 to 2.23 seconds long. This is far below the 30 seconds that iOS allows for a notification sound, and CAF with linear PCM is a supported format. Together the files are about 1.6 MB. Six of them are stereo.
- All eight sources are lossy: seven are public Freesound previews (Ogg Vorbis, about 160 kbps), and one is an Ogg Vorbis file of Kenney. The edit to 16-bit PCM does not add loss. A later build can use the original Freesound files after a login. This is acceptable for a short reminder sound.
- The stored value of a sound is its file name without `maru-` and `.caf`, for example `rising-chime`. The Marimba sound has the value `marimba-hello`, because its file keeps the name of the source.
- A stored choice of a removed sound ("dewdrop", "petal", "breeze", "pebble", "sunrise", or "lantern") has no match in `ReminderSound`, so `ReminderSound.chosen` returns no choice. It means "Default". Nothing crashes, and no migration step runs. The old value stays unread in `UserDefaults`, and the next choice overwrites it. A pending request that still names a removed file has a wrong sound, so the next reminder run replaces it (`hasCurrentSound`, D112). Until then the system plays its default sound, because the file is not in the bundle.
- The Pro gating, the free preview, the settings page, the reminder run, the alarms, and the analytics of D112 do not change.
- `docs/brand/make_sounds.py` and the six generated files are removed. `make_icons.py` stays. The six old names leave `App/Localizable.xcstrings`.

Not verified: nobody heard the sounds on a device. Nobody checked on a device that each file plays as a notification sound, at full ringer volume, in silent mode, on a locked iPhone, or in a Focus. The device checks 3 and 5 of D112 apply to the new sounds.

## D121 · 2026-10-29 · Family: several people and pets on one iPhone (changes the "Profile" line of spec 1, member color changed by D128)

Maintainer decisions of 2026-10-28, with agent detail. The design is in `~/Documents/Research/maru/family-mode/design.md`. Its Codex reviews are in the same folder.

- Maru can hold several people and pets on one iPhone. The UI name is "Family". A member is a local label on this iPhone. It is not an account, not a health profile, and not a login. Remote view, sharing, and sync between phones are not planned (spec 1).
- The approved scope replaces these spec clauses: §1 "Profile" and "家庭远程监督", §8.3 "two or more items", and §11.5 the paywall source list. Remote supervision stays excluded. Local members are allowed. Group actions require one member. The source list gains `family`.
- There is no mode switch. Every database has one member "Me". The app looks as before until the user adds a second member (T57).
- One table `person` holds the members: `id`, `kind` (`me`, `person`, or `pet`), `name` (`NULL` only for `me` before a rename, and the app shows its own word "Me"), `symbol` (the animal of a pet), `imageReference` (an optional photo, D124), and `archivedAt`. A member has no color: every avatar uses the app tint (UI v2 of the design).
- Each item belongs to exactly one member: `item.personID`. Schedules, versions, occurrences, and events belong to the member through their item. No other table has a member column, so there is one source of truth.
- `item.ownerChangedAt` is the instant of the last owner change (D123). The store sets it in the same write as the change. A caller cannot set or erase it for a stored item.
- Pet items receive no human amount, time, or note candidates in the editor. Name suggestions stay. This changes D043 and spec 4.
- An owner change is a correction ("I set it up under the wrong person"). The records, schedules, and history move with the item. No record is copied or rewritten (T64).
- Store operations (`MaruDatabase`): `people()`, `save(_:)` for a member, `archive(person:)`, `restore(person:)`, `delete(person:)` (D125), and `setOwner(_:of:)`. Each is one write transaction with the generation check (D040). The store never reads Maru Pro (D122).
- Invariants that the store keeps: exactly one `me`, at least one active member, and no active item of an archived member. A save, an owner change, or a restore that breaks one is `StorageError.conflict`. The SQL has a CHECK for each rule of a row, a unique index for `me`, and two triggers that refuse an item with no owner.
- A stored item with no owner or an owner that is not an ID is a row that does not load: `StoredDataRule.itemPerson` (D088). A member row that does not load is `personRow`. The other items keep their reminders.
- Today, the widgets, the Watch list, and the item list carry the member ID and the owner of each dose (`TodaySnapshot.ItemLook.personID` and `owner`), so the UI can filter Today by member after the merge of the pending and the as-needed rows. The filter UI is not in this change.
- Analytics: `daily_usage_summary` gets `family_size` as a bucket (`1`, `2`, or `3_plus`). No name, no ID, no kind, and no count of pets leaves the iPhone (spec 10, 11.5, T68).

Not in this change (the UI work does them): the Family page, the add and edit sheet, the switcher and the Today filter, the "For" row in the editor, the History filter by member, the per-member summary PDF, the CSV column "Person", `PRIVACY.md`, and the store text.

## D122 · 2026-10-29 · Family is a Maru Pro feature, and a member that exists never locks

Maintainer decision of 2026-10-28. Free: "Me" and every item, always. Pro: the creation of a second or later member. A member that exists never locks after Pro ends. A free user can use, rename, change, archive, restore, and delete an existing member, add items for it, and restore a backup with members (T58, T59). This follows D107 ("a purchase never blocks a local feature") and D114.

- The one gate is `AppModel.addMember(_:)`. A free user gets the paywall with the new source `family` (`AnalyticsEvent.PaywallSource.family`), and nothing is saved. Every other Family operation has no gate.
- The store has no gate, because the store never reads Pro. The free edit path calls `update(_:)`, which refuses a missing member in the write transaction.
- Family does not unlock the Watch app (D111) or the Live Activity (D110).

## D123 · 2026-10-29 · Reminder text with members, no group action across members, and no quick action after an owner change (changes D090, D110, D108, and the Watch row name of D071, Siri record rule changed by D129, Siri parts replaced by D140)

Maintainer decision 4 of 2026-10-28, with agent detail from the design and its two Codex reviews.

Text:

- A text names the owner of a dose only when the Family has two or more active members (`Family.namesOwners`). With one active member every text is as before (T57).
- `ReminderContent.names` and `AlarmRequest.names` hold `ReminderName` (an item name and an optional owner). A notification body with owners has one line for each member, for example "Me: Vitamin D3" and "Mochi: Methimazole and Flea Drops". The line pattern is one String Catalog entry, so each language chooses its colon. An alarm title joins the lines into one list.
- "Show Names in Reminders" off (D029) hides the member names too (T62). The Watch list is the exception, as for the item names (D071): with two or more members, each row name has the owner ("Mom: Levothyroxine"), so an old Watch list tells two rows of one item name apart.
- The Lock Screen widgets, the Live Activity, the Last Dose widget, and Siri use the same "owner: item" text when names show. The Home Screen widgets "Today" and "Record Dose" always showed the item names (D048), so they always show the owner too. Without it, two rows of one item name for two members look the same, and a tap could record for the wrong member.
- No member name or member ID goes to `userInfo`, a log line, or analytics.

Actions:

- A request that names doses of two or more members has only "Remind in 10 min" (`ReminderCategory.choose`, `membersCount`). One tap must not record a dose for another member (T60).
- A request that names doses of one member keeps its actions: "Taken" and "Skip" for one dose, and "Take All" and "Skip All" for two or more doses with the names shown (D090, T61).
- The category and the identity of a follow-up come from the doses that the request names. Example: Mom and the cat share 08:00, and only Mom has follow-ups. The follow-up names only Mom, so it has "Taken" (`DoseGroups.single(of:among:)`). The identity is then the list of its doses (`membersKey`).
- The Live Activity shows "Taken" only when its doses belong to one member (`canRecord`), and the record path checks the same rule again. This changes D110.
- Siri "Record my doses" records nothing when the Family has two or more active members. It says "Several people and pets use Maru, so Siri can't record for them. Open Maru to record each dose." A member parameter for Siri is later work. This changes D108.

An owner change and old actions:

- An owner change does not change the identity of a dose. So each quick action carries the instant of the list that the user saw, and the record transaction refuses a dose of an item whose `ownerChangedAt` is later (`RecordFailure.ownerChanged`, nothing written, T70):
  - A notification action and the "Taken" button of an alarm: the request carries `ownerChanged`, the latest `ownerChangedAt` of the items that it names, only when one of them changed its owner. It holds no ID and no name, so a single-person user's requests do not change (T57). The transaction refuses a dose whose item changed its owner after that value, or after the delivery date. A request with no value records only an item whose owner never changed. This also covers a pending request that the system delivers after an owner change before the reminder run replaced it, and a follow-up of yesterday after midnight (D039).
  - The Watch: `WatchRequest.record` carries `listedAt`, which is `WatchDay.sentAt` of the list that the user saw. The iPhone sets `sentAt` to the read time of the list, not later.
  - A widget capsule: `TakeDoseIntent.readAt`, the instant before the widget read.
  - The Live Activity: `NextDoseSlot.listedAt`, the read time of the doses. A new owner also gives a new token.
  - Siri: an instant before the read. The count of active members comes from the same read as the doses, after the items, so a member that comes back during the read stops the record.
- The store takes the instant of an owner change inside its write transaction. A read that starts during that transaction still sees the old owner, so a list instant less than 5 seconds after the change also counts as before it (`ownerChangeMargin`). The user then records from a new list.
- Rare cases, accepted after the second Codex review (`~/Documents/Research/maru/family-mode/core-codex-review-2.md`). Each needs an owner change and a quick action from an old list in one short time:
  - The clock of the iPhone moves back after a Watch, widget, or Live Activity list, and the owner changes before a new list. The list instant is then later than the change.
  - An owner change transaction that takes longer than 5 seconds.
  - A restore of a backup in which an item has another owner, followed by a tap on a Watch row, a widget capsule, or a notification from before the restore. A restore already replaces the lists and the requests.
  A check of the member that the user saw (its ID in each quick action, compared in the record transaction) closes all three. It is a later step if a device check finds one of them.
- Today records with the owner on the screen and sets no instant. The future Family UI must refresh owner labels before a record.
- An as-needed dose has no quick action, so it needs nothing.
- A change of a member name, an owner, or an archive starts one reminder run, as a rename of an item does (D084, D086). The run replaces the pending requests whose text changed.

A pending request can keep its old text until the next reminder run. Its old `ownerChanged` value refuses the record, also with the names hidden. The record transaction also refuses an action whose doses belong to two or more members now, also for a request with an old category.

## D124 · 2026-10-29 · The avatar of a member: a photo, an animal, or the initial (the "no member color" rule replaced by D128)

Maintainer decision 5 of 2026-10-28 (the switcher UI is designed elsewhere). A member has an optional photo from the library or the camera. The core stores it as an item photo (D056): `person.imageReference` holds the file name, and the file is in the photo folder of the items. The avatar shows the photo when the file is on the iPhone, else the animal of a pet, a person symbol for "Me", or the initial of the name. An avatar has no gradient and no member color.

- The backup does not hold the photo files, as for items. A restore keeps the names, and the app removes the files that no item and no member uses.
- A replaced photo file and the photo of a deleted member are removed after the save.

## D125 · 2026-10-29 · Archive, restore, and delete of a member (follows D033 and D084)

- Archive: one transaction sets `person.archivedAt` and archives each active item of the member with the same instant. Reminders stop with the next run (D084). History keeps the past doses (D091).
- Restore: one transaction clears `person.archivedAt` and restores only the items with the same `archivedAt`. An item that the user archived on its own keeps its own archive.
- Delete: one transaction deletes every item of the member with its versions, schedules, occurrences, and events, as `deleteItem` (D033), then the member. The user asks and confirms. It is never a recovery from an error (spec 7.3).
- `me` cannot be deleted. The last active member cannot be archived or deleted. Each is `StorageError.conflict`, and nothing changes (T63).

## D126 · 2026-10-29 · Migration `v8`: one plain migration, because Maru has no public users yet

Maintainer decision of 2026-10-28: version 1.0.0 will not be released. The first public release has Maru Pro, the new paywall, and Family. The maintainer's iPhone and the TestFlight testers have data, and spec 7.3 forbids a clear and rebuild. So the migration is plain, and there is no special work for old public backups.

- `v8` runs in one transaction: it creates `person`, inserts "Me", adds `item.personID` and `item.ownerChangedAt`, and gives every item to "Me", also an archived item. SQLite cannot add a `NOT NULL` column with a `REFERENCES` clause, so the column is nullable and two triggers refuse a `NULL` after the migration. No table is copied or rebuilt. A failure rolls back the whole migration, so the database stays at `v7` with its data (T37, T56).
- A new database runs `v1` to `v8` and gets "Me" with no item.
- Restore of a backup of this version: the restore stages the backup on a copy and migrates the copy to the level of the backup, which seeds a "Me". When the backup has a `person` table, the stage deletes the seeded members before it copies the rows of the backup, so there is no second "Me" (T69). The check of the staged copy then needs exactly one `me`, at least one active member, and no active item of an archived member.
- Restore of an older backup: it has no `person` table, so the seed stays, and the later migration gives every item to "Me" (T67).
- An older app refuses a backup of `v8` as a newer schema (T38). The backup format version stays 1 (`docs/export-format.md`).

Tests (D016): the upgrade fixture gives every item to "Me" (T56), an older backup restores with "Me", a backup with members restores with one "Me" and the owners (T69), an action listed before an owner change records nothing (T70), and a request for two members has no group action (T60). The archive test covers T63.

## D127 · 2026-10-29 · Analytics for the features since D099: Pro state, new surfaces, onboarding, and the paywall close (changes spec 11.5, `used_siri` replaced by D140)

Lead decision for the maintainer, who asked for usage and Pro conversion data before the first public release. Each new field is a fixed choice or a flag in the strict schema of `AnalyticsEvent` (T45). No field holds an item, a member, a dose, a time, an ID, a date, a price, an icon name, or a sound name (spec 10, 11.2, T42, T68).

- `daily_usage_summary` gets three usage flags: `used_live_activity` (the "Taken" button of the Live Activity, or a tap on it), `used_watch` (a record request from the Watch), and `used_siri` (a Siri or Shortcuts question or record). A record from these paths also sets `used_record` after the commit, through the one commit path. A tap on the Live Activity has the link of the widget with the mark `?from=activity`, so it does not count as `used_widget`.
- `daily_usage_summary` gets the Pro state at the last check of the day: `pro_plan` (`none`, `yearly`, or `lifetime`), and the flags `has_live_activity` ("Next Dose on Lock Screen" is on), `custom_icon` (the icon is not the default icon), and `custom_sound` (the reminders use a sound other than the default). Each open, each read of StoreKit, and each change of one of these checks again. A plan from Family Sharing counts as the plan. StoreKit tells the two apart, and this change does not.
- `setting_changed` gets `header_wash` (a flag, D100) and `appearance` (`system`, `light`, or `dark`, D105). Only a change of the user sends it, not a restore.
- A new event `onboarding_result` has `result`: `add_item`, `later`, `skipped`, or `yielded` (a reminder tap or a widget link opened Today while the onboarding showed). An onboarding that never showed sends nothing. In an opt-in region analytics is not active yet at the onboarding, so it sends nothing there (spec 11.3).
- `paywall_shown` replaces the source `feature` with three sources: `app_color` (D114), `live_activity` (D110), and `watch` (D111). Every source has a caller, except `family`: the Family UI does not call `addMember` yet (D122).
- `purchase_result` gets `dismissed`: the paywall closed while Pro is not active. So each showing has an end that counts. A close after a pending purchase sends `pending` and then `dismissed`.
- A restore at launch, a renewal, a code, an approved purchase, and Family Sharing go through `refreshEntitlement` and send no `purchase_result`. Only a purchase from the paywall sends `purchased`. So an approved "Ask to Buy" purchase shows only as `pending` and a later `pro_plan`.
- `PRIVACY.md` lists every new field. The site pages come from `PRIVACY.md` and change when the maintainer publishes the site. `docs/release-plan.md` names `onboarding_result` under Product Interaction and `pro_plan` under Purchase History.
- Not in this change: the Supporter lifetime product (`com.imhangli.maru.pro.supporter`). When it comes, `PurchasePlan` and `pro_plan` need a value for it.

Tests (D016): the factory check of `AnalyticsTests` sends the new factories through the checked init. No other test.

## D128 · 2026-10-29 · The Family UI: member colors, the person menu, and "Add for" (replaces the color rule of D121 and D124, "not in this change" list done by D129)

Maintainer decisions of 2026-10-29 on the design prototype (`~/Documents/Research/maru/family-mode/apple-style/`), with team defaults for the open points. The captures of the real UI are in `~/Documents/Research/maru/family-mode/real-ui/`.

Avatar colors (style "C"):

- Each member has a color. The avatar is a soft fill of the member color (about 16% opacity) with the initial, the person silhouette ("Me"), or the animal of a pet in the full member color. It has no gradient and no ring. A photo from the library or the camera replaces the fill, also for a pet.
- "Me" always uses the app color. A member with no stored color also uses the app color.
- A new member gets the first `ItemColor` that no member uses. It skips the current app color when another color is free (`ItemColor.forNewMember`). The user changes it on the page of the member.
- Migration `v9` adds `person.color` (`NULL` or an `ItemColor` raw value). It adds one column and copies no table (spec 7.3). A backup of `v8` restores through `v9` with no color.
- Color is never the only signal: the name, the initial, or the animal is always there (spec 5.3).

Today and Settings:

- A person menu at the top right of Today, as the profile picture of Health: "Everyone", each active member, and "Add Person or Pet". It shows only with a second active member. With only "Me", Today is as before (T57).
- In "Everyone", a row of another member has the small avatar of the owner before the record circle. A row of "Me" has no avatar (team default). A view of one member has the name of the member as its title, for example "Mom" (team default). The parts of the day stay.
- The choice of the menu lives in memory. A new launch and a tapped reminder show "Everyone" (team default).
- Settings has a row "Family" under "Maru Pro", with overlapping avatars. The Family page lists the members, "Add Person or Pet", and the archived members. The add page is in the style of a new contact: photo, person or pet, name, and the animal of a pet. The page of a member also has the color, archive or restore, and delete.
- The item editor has a row "For" with a second active member. A change of a stored item says "Records move with the item." A new item belongs to the member that Today shows, else to "Me".

Pro:

- The add of a second or later member stays the only gate (D122). The paywall with the source `family` has the headline "Everyone you care for, in one place."

"Add for" (copy for another member, changes "Copy this item to another member" in the "Cut and later" list of the design):

- The item detail has a row "Add for…" with a second active member. It opens a system menu of the other active members.
- A choice opens the editor for a new item with the values of the item: name, type, form, color, amount, times and plan, alarm, follow-ups, note, and photo. The owner is the chosen member. Nothing saves until the user taps Save (spec 2, spec 7.2).
- The copy is a new item with its own IDs, schedule, and records. It copies no record. The first item does not change.
- The save copies the photo file to a new file, so a delete of one item never removes the photo of the other.
- It adds no Pro gate. The usage statistics count it as a new item (`mode` `new`), because the event schema needs no new value. No member data leaves the iPhone.

Not in this change: the History and summary filter by member (T65), the per-member PDF, the CSV column "Person", the My Items filter and tile avatars, the "For" row on the item detail, the footer of "Show Names in Reminders", a member parameter for Siri, and `PRIVACY.md`.

## D129 · 2026-10-29 · Family follow-ups: History, My Items, the summary, the CSV column, and Siri for one member (changes the Siri rule of D123, Siri part replaced by D140)

Maintainer approval of 2026-10-29 for the "not in this change" list of D128, with team defaults for the open points. Simulator captures are in `~/Documents/Research/maru/family-mode/follow-ups/`.

One choice for three pages:

- History and My Items have the person menu of Today. The three pages share one choice in memory (`TodayState.member`), as section 7.1 of the design says. A new launch and a tapped reminder show "Everyone" (D128).
- History of one member: the store reads take `owner` (`history`, `historyCounts`, `summary`). The filter limits the items, the schedules, the stored and the as-needed doses, the graph counts, and the first day (T65). An item belongs to its current owner, so the records move with it (T64). A change of the menu, an owner change, or an archive reads the page again. The log of an item from its detail reads every member. While the History of one member is open, a log of an item of another member shows "Everyone".
- History hides the "not saved" banner in the view of one member, as Today does (D128). Its retry sends the events of every member.
- My Items of one member shows only the active items of that member. "Archived" stays one list for everyone. A member with no item shows "No Items Yet" with "Add Item". In "Everyone", a tile of another member has the avatar of the owner at its top corner. A tile of "Me" has none, as a row of Today. VoiceOver reads the tile as "Mom: Levothyroxine".

Item detail:

- The detail has a row "For" with the avatar and the name of the owner, only with a second active member (T57). The row only shows the owner. "Edit" changes it, so the user reads "Records move with the item." before the save. This replaces "tap changes it" of the design.

Reports and export:

- The summary sheet has a "For" menu with "Everyone" and each active member. It starts at the member of the person menu. The item list and the counts then have only that member, and the PDF title is "Summary for Mochi" (T65).
- "Share Medication List" becomes a menu "Share Medication List…" with "Everyone" and each active member, only with a second active member. The title of a list of one member is "Medication List for Mochi".
- The CSV export has a new last column "Person": the name of the current owner, or `Me` in fixed English for "Me" before a rename. The column is always there, also with one member, so a parser reads one header. The backup format does not change (`docs/export-format.md`). An older parser that reads the columns by position still reads the first eight.

Settings:

- With a second active member, the footer of "Reminders" says "With names on, reminders also name the person or pet." With one member it shows nothing new (T57).

Siri (changes D123):

- "Record my doses" has an optional parameter "For" (`MemberEntity`, the active members). With two or more active members and no member, Siri asks "For whom?" and lists the members. It then reads the doses again and records only the open doses of the items of that member. One confirmation never records for two members (D123).
- The confirmation names the member and the items: "Record as taken now for Mom: Levothyroxine?". With "Show Names in Reminders" off, Siri says only the count, with no member name and no item name (T62). The list of members of the question shows on the unlocked iPhone, because the user must choose one.
- The record keeps the checks of D108 and D123: the read instant refuses a dose whose owner changed after it. The phrases do not change.
- The refusal text of D123 ("Several people and pets use Maru…") is removed.

Analytics: nothing new. No member name, ID, or photo goes to an event (T68).

Tests (D016): one store test checks that the history, the graph counts, the first day, and the summary of one member never count another member, and that the export names the member of each line (T65). The CSV test has the new column. No UI test.

Checks: the upgrade from `v7` to `v9` is covered by package tests, so no device-style upgrade check ran. `FamilyTests.version7BackfillsMeWithoutChangingRecords` migrates a `v7` database with records to the current schema. `UpgradeTests` opens the shipped fixtures of 1.0 (`v5`) and 1.1 (`v6`) and runs the whole reminder queue through `v9`.


## D130 · 2026-10-29 · Siri and Shortcuts, the PDF reports, and the 30-day counts are Maru Pro features (changes D108 and D091, Siri parts replaced by D140)

Maintainer decision of 2026-10-29. Three free features of D091 and D108 move into Maru Pro. The safety features stay free: reminders, alarms, follow-ups, records, undo, skip, the widgets, the CSV export, the backup, and the restore.

Siri and Shortcuts (changes D108):

- The three App Shortcuts are Pro: "Next Dose", "Last Dose of an Item", and "Record Due Doses". Each intent checks Pro first, before it reads or records anything.
- The check is `confirmedPro()` of the Watch (D111): the cached plan, and for a free answer one more read of StoreKit. A failed read gives the free answer and records nothing. The next request reads again, so a paying user is not locked out for good.
- A free user hears one line: "Siri and Shortcuts are part of Maru Pro. Open Maru to take a look?". "Open" brings Maru to the front, and the paywall shows with the source `siri` after the onboarding, the edit screen, and the alerts, as the request of the Watch does. "Cancel" opens nothing. iOS 26 and later use `continueInForeground`. iOS 17 to 25 use `ForegroundContinuableIntent`.
- The item of "Last Dose" is now an optional parameter, so a free user hears the line before Siri asks "Which item?".
- The item and member queries of Siri and Shortcuts give nothing to a free user, so no name is read before the Pro check. A change of Pro makes the system read them again.
- A failed read of the subscription status keeps the end of access of the last good read. Before, it removed a billing grace period, and the new gates then locked a paying user out until a good read.
- The widget buttons (`TakeDoseIntent`) and the Live Activity button (`TakeNextDoseIntent`) are separate intents, so no intent serves both a widget and Siri. The widget buttons stay free. `TakeDoseIntent` is no longer offered in Shortcuts, because only the widget runs it. The alarm intents were not offered before.
- The Watch request and the Siri request share one stored key, `pro.askedSource`, in place of `pro.watchAsked`. The rule that shows the stored offer compared a `Bool` with `nil`, so it never showed the offer of the Watch. It now reads the flag of the first-value offer.

PDF reports (changes D091):

- "Share Medication List" and "Share Summary…" stay in Settings for every user. For a free user, "Share Medication List" opens the paywall with the source `report`. The summary sheet opens, says "Sharing a PDF summary is part of Maru Pro.", and "Share" closes it and opens the paywall.
- "Export Records", "Back Up", and "Restore from Backup…" stay free.

Insights (changes D091):

- The item detail keeps "Last 7 Days" free, and History keeps its graph, "Last 7 Days", and every log free. The graph shows each day of the records, and it is the way to the log of a day, so it stays free.
- In "Last 30 Days" of the item detail, a free user sees one row "30-Day Counts" with "Maru Pro", which opens the paywall with the source `insights`. "All Records" stays in the section for every user. No record is hidden.

Paywall:

- Four benefits, in this order: "Right on your Lock Screen", "Record by wrist or voice" ("Apple Watch, Siri, and Shortcuts."), "Reports for your doctor" ("PDF summaries and 30-day counts."), and "Make Maru yours". Siri shares the row of the Watch, so the list has one new row.
- New headlines: `siri` "Just ask Siri.", `report` "A clear summary for your doctor.", and `insights` "Your last 30 days, at a glance.". The insights headline has the form of the default one and uses its narrow measure.
- No paywall after a record and none at app open. A Siri request shows it only after the user chooses "Open".

Analytics: `paywall_shown` has three new sources, `siri`, `report`, and `insights` (spec 11.5, `PRIVACY.md`). No other field. A free Siri request does not set `used_siri`, because no Siri operation runs.

`-MaruDebugPro YES` covers the new gates, because each gate reads `ProStore.isPro`.

Tests (D016): none. The gate is in the app target, and the project has no app test target. The rule that a free Siri request records nothing is in the order of `perform()`: the Pro check returns before the read of the doses.

Review: one Codex review (gpt-6.1-sol, high) found the two defects above, the item query and the grace period. A re-check of both found them fixed.

Not checked: no simulator captures. The device tools of this session did not list a dedicated simulator, and the rules do not allow `simctl` captures. Nobody used Siri, saw the paywall rows, or saw the new rows on a display. The new strings are drafts in five languages (`docs/localization-review.md`).

## D131 · 2026-10-29 · No Supporter tier. The paywall icons follow the item forms

The maintainer decided:

- Maru Pro has two plans: yearly and lifetime. There is no Supporter tier. The product `com.imhangli.maru.pro.supporter` was never in the app and never submitted. It is deleted in App Store Connect.
- The benefit rows of the paywall use two-tone vector icons in the style of the item form icons (`Icons.xcassets`), in the app color, with no background. The maintainer rejected tinted tiles.

## D132 · 2026-10-29 · Three ceramic icons for Maru Pro (extends D112)

The maintainer chose Rose Ceramic, Qinghua Lotus, and Rose and Sage from the round 2 concepts.
All three are normal Maru Pro icons under D131. The picker names are "Rose Ceramic", "Blue Lotus", and "Rose and Sage".

- The chosen concepts supply the light artwork without a crop. Image generation edits supply the dark artwork on a dark background.
- Each icon has an opaque 1024 × 1024 PNG for light, dark, and tinted appearances. The tinted artwork keeps grayscale material detail on black.
- Each preview has light and dark images. The picker adds the three choices after the five existing Pro icons.
- Names cover en, zh-Hans, ja, es, de, and ko. The gate stays in `AppModel.chooseAppIcon`. Default stays free.
- `project.yml` names all eight alternate icons. The vector generator preserves the material assets when it runs again.
- The artwork belongs to the project. The research folder holds the generation records and the comparison image.

Scope: spec §13.3 and the icon rules of D112. No record, reminder, purchase, or schema rule changes. No new tests (D016).

Checks pass: `xcodegen generate`, `swift build`, the app build, and checks of PNG dimensions, opacity, grayscale, catalog entries, and six locales.
The compiled iPhone and iPad Info.plist entries include all eight alternate icons.

These assets follow the existing PNG asset catalog path. They do not add Icon Composer layers or prove live Liquid Glass effects.
The dark edits retain the visible patterns. Fine floral details merge at small sizes, especially in the tinted artwork.

The simulator capture is blocked. Device tools report "No device" for the dedicated simulator, including after a device list refresh.
The dedicated simulator was deleted. The existing simulator named "iPhone 18 Pro" was not used.
Home Screen switching, system appearances, the Pro purchase flow, and localized layout still need device checks.

## D133 · 2026-10-29 · A quiet "PRO" badge marks each Maru Pro entry for a free user (extends D107) (look and place changed by D134)

The maintainer decided:

- Each Maru Pro feature stays in its place. There is no separate Pro section.
- For a free user, a small "PRO" badge shows at the trailing edge of the entry, before a value, a switch, or a chevron. A Pro user sees no badge. The debug override `-MaruDebugPro` and Family Sharing count as Pro.
- A tap keeps its action. It opens the paywall with the source of the entry.

The badged entries:

- Settings: "App Color", "App Icon", "Reminder Sound", "Next Dose on Lock Screen", "Share Medication List", and "Share Summary…".
- The Family page: "Add Person or Pet". The Family row of Settings has no badge, because the page is free to open (D122).
- Item detail: "30-Day Counts". The badge replaces the text "Maru Pro" (D130).

Settings has no entry for Apple Watch or for Siri and Shortcuts, so they have no badge. The Lock Screen, the widgets, the Watch, the notifications, and the Live Activity show no badge (D107).

The design: one view `ProBadge` in `App/Pro/ProBadge.swift`. It shows "PRO" in `caption2` semibold, in the secondary color, on a `quaternary` capsule. It uses the system font (D012) and Dynamic Type. "PRO" is a brand mark and stays in English. VoiceOver reads "Maru Pro" as a part of the row, from the existing String Catalog entry. Each item of a menu or a picker stays as before.

Scope: the UI of D107, D110, D112, D114, D122, and D130. No record, reminder, purchase, or analytics rule changes. No new tests (D016).

## D134 · 2026-10-29 · The "PRO" badge is a filled capsule right after the title (changes D133)

The maintainer rejected the gray capsule at the trailing edge and chose the style of a competitor app.

- The badge is a filled capsule in the app color with "PRO" in bold, in the readable label color of that app color.
- It sits right after the title of the row. The value, the toggle, or the chevron stays at the trailing edge.
- The rest of D133 stays: free users only, no badge outside the app, and a tap keeps the action of the row.

## D135 · 2026-10-29 · Settings is a short list of pages with a search field (changes D107, D121, D133)

The maintainer said that the Settings sheet was messy and asked for a tidy layout, as in iOS Settings, with a search field. The look waits for the approval of the maintainer.

The root is a short list. Each row has a symbol in the app tint, the title, an optional value, and a chevron. There are no colored tiles.

1. The Maru Pro card. Under it, the row "Purchases" opens "Manage Subscription" (yearly plan only), "Restore Purchases", and "Redeem Code".
2. "Family", "Reminders" (value: the notification state), and "Lock Screen" (value: On or Off, iPhone only).
3. "Display" (value: the appearance) and "Language".
4. "Your Data" and "Privacy".
5. "Send Feedback" and "About".
6. "Debug", in debug builds only.

The pages:

- "Reminders": "Notifications", "Open Settings" when needed, "Show Names in Reminders", "Reminder Sound", and the section "For All Items" ("Alarm", "Remind Again", "Every").
- "Lock Screen": "Next Dose on Lock Screen". The whole page is Maru Pro, so its root row has the "PRO" badge (D134). No other root row has a badge.
- "Display": "Appearance", "App Color", "App Icon", and "Color Header". The page is called "Display", not "Appearance", so that the page and its first row do not have the same name.
- "Your Data": the export, the two reports, the backup, and the restore. "Privacy": "Share Usage Statistics" and the privacy policy.
- "About": the version and build, "Support", "Privacy Policy", "Terms of Use" (the same link as the paywall), and "Licenses".

The search field is always visible at the top of the root. It finds every setting by its title in the app language or in English, and by a few localized keywords, for example "dark" for "Appearance". A result shows the title and its place, for example "Reminders › For All Items". A tap opens that page. "Maru Pro" opens the paywall for a free user. "Language" and "Send Feedback" do the same as their rows. With no match, the system "No Results" view shows.

Every switch, menu, permission flow, paywall source, analytics event, backup, and restore works as before. No record, reminder, or database rule changes. No new tests (D016).

## D136 · 2026-10-29 · One size and one column for the Settings root symbols (refines D135)

The maintainer asked for smaller symbols of one size that line up with Maru Pro. Each root symbol now has one point size and sits centered in a column as wide as the Maru Pro icon. The titles start at the same x as "Maru Pro". "Display" uses `sun.max`.

## D137 · 2026-10-29 · Settings symbols match the item icons, and the Maru Pro card uses the paywall art

- The root symbols of Settings use the box of an item icon (28 points), so the icons of the app have one size (refines D136).
- For a free user, the Maru Pro card is one thin row: a small app icon and "Maru Pro" in white on the slow art of the paywall with a dark wash. It has no feature line and no light sweep (the maintainer rejected both). Reduce Motion stops the drift. A Pro user sees the plain card.

## D138 · 2026-10-29 · Each group on the Settings root has a header

The maintainer asked for a header on every group, as other apps show. The headers are "Membership", "General", "Personalization", "Data and Privacy", and "Support". The Debug group keeps its own header.

## D139 · 2026-10-30 · The lifetime plan costs $19.99 for 30 days after the launch, then $29.99 (replaces the lifetime price of D119, sixth round)

The maintainer set a founder price on 2026-10-28. The lifetime plan costs USD 19.99 for 30 days after the launch. Then the price changes to USD 29.99. The change is real and the app shows no countdown. The yearly plan stays USD 9.99 with a 7-day free trial.

- App Store Connect has the lifetime product at USD 19.99 in 174 territories, with new territories included.
- `Config/Maru.storekit` has 19.99 for local tests.
- Schedule the change to USD 29.99 in App Store Connect before the launch. Then update the lifetime answer of the site FAQ on the day of the change.

## D140 · 2026-10-30 · Remove Siri and Shortcuts, a new thank-you line, and two Family UI fixes (replaces the Siri parts of D108, D123, D127, D129, and D130)

Maintainer decisions of 2026-10-30. The maintainer said that Siri was "sooo stupid".

Siri and Shortcuts:

- Maru has no App Shortcuts, no Siri phrases, and no Siri answers. The app deletes `App/Siri/MaruShortcuts.swift`, `App/AppShortcuts.xcstrings`, `App/AppModel+Siri.swift`, and their strings in six languages.
- The paywall loses the source `siri` and the headline "Just ask Siri.". The daily summary loses the flag `used_siri` (spec 11.5, `PRIVACY.md`).
- The Watch keeps its request for the paywall (D111) and the stored key `pro.askedSource`.
- The intents that a widget, the Live Activity, or an alarm runs stay: `TakeDoseIntent`, `TakeNextDoseIntent`, `TakeFromAlarmIntent`, `OpenFromAlarmIntent`, and `RunAfterAlarmIntent`. Each one has `isDiscoverable` set to `false`, so Shortcuts and Siri do not offer it. The widget configuration intents stay too.
- The "Last Dose" widget stays free. Its store read keeps only the form for all items, because only Siri asked for one item.
- The paywall benefit row of the Watch is "Record from your wrist", with the line "Apple Watch shows and records each dose.".

Other changes:

- The thank-you after a purchase keeps "Welcome to Maru Pro" and says "Thank you. Your journey starts here.". The translations follow the meaning, not each word.
- The "For" pickers of the editor and of the summary sheet have clear space beside the avatar, so the avatar and the name do not touch.
- The person menu on Today has the button style of Settings: its own bar button with the system background and a 28 point avatar inside it. Before, it was a 36 point avatar with no background.

Tests (D016): none new. No package test covered only Siri.

The new strings are drafts in five languages (`docs/localization-review.md`).
