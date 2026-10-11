# Design

The visual rules for the app. The decisions behind them are D010–D013, D015, D018, D020, D021, D024, D025, D026, D028, D030, D032, D033, D036, D038, D041, D043, and D044 in `docs/decisions.md`. The study is in `docs/research/2026-10-10-visual-direction.md`.

## Principles

1. Simpler than Apple Health Medications in every flow that both apps have (D021). Count screens and taps.
2. Apple system style: native SwiftUI system components only, the system font only, system colors (D011, D012, D026). A custom control needs a recorded reason.
3. Few words. A row shows the name, the amount, and the time. The circle shows the state (D011, D044).
4. Do not choose for the user: no default amount and no default reminder time (spec §2.1). The type, the form, and the color of a new item are not health choices, so they have a start value that the user can change (D032). A known supplement gets amount, time, and note candidates that fill nothing until a tap (D043).
5. No repeated information, and no "·" separator in any text of the app. Use natural words or a second line (D032).
6. No gray text for a state. A title or a name looks the same in each state (D032).

## Color

- One app tint for the whole app. The user picks it from the eight item colors in Settings, under "App Color" (D025). The default is pink, the system pink (#FF2D55 in light mode).
- The tint marks: buttons, the record circle when filled, and the opening highlight of the current slot title. Sheets get the same tint.
- In light mode, the tint has at least 3:1 contrast on white. Orange, yellow, green, and mint are darker when they are the tint: #D97F00, #B49000, #2CAA4C, and #00A69F. Dark mode uses the system colors. The item colors do not change.
- A label on a filled tint, such as the check mark of the record circle, is white when white has at least 3:1 contrast on the fill. Otherwise it is black (D025).
- Item colors: pink, orange, yellow, green, mint, blue, purple, brown. Use the system colors with the same names, and a system-like brown. Each color has a light value and a dark value. The item color appears only on the form icon. It is never the only signal of a state (spec §5.3).
- A new item gets the first color in that order that no active item uses. If all are in use, it gets pink.
- Errors and destructive actions use the system red.

## Surface

- Every page is a system grouped list or form. The custom cards are the tile of My Items and the graph of History (D026, D032, D041).
- Today and My Items use the plain grouped background, with no header wash (D024).
- Every page is the gray grouped background with white cards, as in Apple Health and Settings. This includes a page that loads or shows an error (D028).

## Feedback

- No toast and no notice card. A save closes the sheet, and the list shows the change in place, as in Apple Health (D028).
- A failure uses a system alert. A failed reminder after a save or a change also gets an alert. Notifications that are off show as a row on Today and My Items, with no alert.
- A reminder for one item has one action, "Taken". It records with no open of Maru. When it can not record, a notification says "Not recorded" (spec §8.3, D034).
- The item detail shows the reminder state in the plan: "On", "Not Set", or "Not Confirmed", and the reason in the footer (spec §8.1, T03).
- For a plan of every other day, "On" has a limit, and the footer states it: Maru sets the reminders of the next 7 dose days at each open (D036).

## Today

- The large title "Today" with the date under it. No ring (D026).
- A gear button at the top left opens the settings sheet. An add button sits at the top right (D020). Both tabs have them. Today also has a History button with a calendar symbol, beside the add button (D026).
- One list section per time slot, in time order. The section header is the slot name, for example "Morning", not a clock time (D011).
- The header has "Record All", which records every open item of the slot as taken, in one transaction (D021). It shows only when the slot has two or more open items.
- Row: the form icon in the item color, the name, a second line in small gray text, and the record circle at the end. The name area opens the detail. The circle is a separate hit target (spec §3 P01). The circle is an SF Symbol: an empty circle, a filled check, a gray dash for skipped, or a red mark for not saved.
- The second line has the amount and the time that the user set: "2 capsules, 8:00 AM", or "8:00 AM" with no amount. A taken row shows the intake time: "2 capsules, Taken at 8:07 AM". A skipped row shows "2 capsules, Skipped". A medication that keeps another time zone names the city: "9:00 AM Shanghai time" (D044).
- A recorded row and an open row differ only by the circle and the time. The name, the icon, and the amount keep the normal look. No dim and no strikethrough (D032, D044).
- A finished slot folds to its header the next time the user returns to the app. The header shows a chevron and no check mark. The title looks the same folded and open. A tap opens it. A second tap folds it. Only a finished slot folds (D012, D032).
- The record that finishes a slot folds it after about 0.7 seconds, so the user sees the last check first. The fold uses the layout motion, the same as a tap on the header (D028, D030).
- Swipe right on a row: "Taken". Swipe left: "Skip" on an open row, "Undo" on a recorded row. Only the first action of the right swipe runs with a full swipe (D028).
- A long press opens a system context menu with the same actions, plus "Details", "Edit", and "Archive…". An as-needed item offers "Take Now". Every action uses the same record transaction as the circle (D028).
- The menu of a recorded row has "Change Time…". The menu of an open row has "Taken Earlier…". Each opens the time sheet directly. The sheet shows the time wheel at once, and "Save" records the dose as taken at that time. The wheel does not go past the current time. So a change of a record time needs three taps (D033).
- When the app opens or returns to the front, the title of the current slot takes the tint for about six seconds (D020).
- An "As Needed" section at the end lists items with no schedule. Each row has a record button that records a dose at the current time (D021).
- With no item, a system empty view in the middle of the page says "No Items Yet" and "Tap + to add a supplement or medication." With items and nothing due today, it says "Nothing to Take Today" (D026).
- Success text and the success haptic come only after the local transaction commits (spec §7.2).

## History

A graph of squares at the top, and one timeline in a system grouped list under it (spec §3 P05, D032, D041). Today opens it from the History button.

### Graph

- One square for each day. One column is one week. The rows are the weekdays, in the first weekday order of the user's calendar. Time runs from left to right, and today is at the right end of the filled part.
- No title, no legend, no count, and no sentence. The navigation title "History" is the only title.
- Steps: 13 weeks from the week of the first day. 26 weeks when 13 are full. 52 weeks when 26 are full, as two bands of 26 columns with the older band above. The step changes on the first day of a week that does not fit. After 52 weeks the graph shows the last 52 weeks.
- The graph fills the card width. Side = (width − left labels) ÷ (columns + (columns − 1) × gap share). The gap share is 0.19 at 13 columns and 0.3 at 26 columns. The corner is 22% of the side, continuous.
- Sizes on a screen of 402 points (graph width 338): 13 weeks, side 21.2 and gap 4.0. 26 weeks, side 10.1 and gap 3.0. On a screen of 320 points (graph width 256): 13 weeks, side 15.8 and gap 3.0. 26 weeks, side 7.6 and gap 2.3. 52 weeks uses the sizes of 26.
- The card: the grouped card color, the corner of an inset grouped cell, margins of 16 points, and padding of 16 points. It stays above the timeline on the grouped background and does not scroll. Its height on 402 points is 222 points at 13 weeks, 138 at 26, and 256 at 52.
- Levels by the share of the planned doses of the day that are taken. A skipped dose is not taken. An as-needed dose does not count.

| Day | Look |
|---|---|
| Every planned dose taken ("all") | The tint |
| More than half taken ("most") | The tint at 60% |
| Half or less taken ("some") | The tint at 30% |
| Planned, nothing taken | The tertiary system fill |
| Nothing planned | The quaternary system fill |
| Not here yet | An outline of 1 point in the tertiary system fill |
| Before the first day | No square |

- The tint is the app tint of D025, with the darker light values of orange, yellow, green, and mint. Over a white card the luminance contrast of "all" to "most" is 1.5:1 or more for each of the eight colors, and 1.9:1 or more over the dark card. Each step from "some" to "most" is 1.35:1 or more in light mode.
- Today has no mark. Its place at the end of the filled squares is clear.
- Month labels: the short month name above the column where the month starts, in the caption 2 style and the secondary color. When no month starts in the first three columns of a band, the first column gets its month. A label that would touch the one before it does not show. Weekday letters for Monday, Wednesday, and Friday at the left, only at 13 weeks and not at the accessibility text sizes.
- The squares keep their size at every text size. The labels grow.
- Selection: a ring of 1.5 points in the tint, with a gap of 1 point around the square. The date of the day, for example "Tue, Aug 18", in semibold caption 2 in the label row over its column. Month labels under it do not show. No dark border, no shadow, no magnifier, and no band behind the week.
- A touch or a drag selects the nearest day. A day that is not here yet gives today. A tap on the selected day clears it. A light selection haptic comes when the selected day changes.
- At the end of the touch, the timeline scrolls so that the selected day is the first section under the graph. Older days load as needed. A day with no rows gives the nearest older day. A clear scrolls back to today. A scroll by hand clears the selection (iOS 18 and later).
- VoiceOver reads the graph as one adjustable element: a summary of the days by level, or the selected day with "2 of 3 taken". Swipe up or down moves the day.

### Timeline

- Newest first, one section per day: "Today", "Yesterday", then the weekday and the date. The day is the day of the dose.
- One row per action of the user: taken, skipped, time changed, or undone. An undone action and a replaced action stay in the list.
- Row, like Recents in Phone: the form icon in the item color, the name, the action in plain words under it, and the time of the action at the end. The words name the intake time when it is not the time of the record, for example "Taken at 8:00 AM".
- A planned dose of a past day with no record shows as "No record", with its part of the day in place of a time. An open dose of today shows on Today only.
- The newest row of a dose offers the corrections with a swipe and a long press, as on Today: "Taken", "Change Time…", "Skip", "Undo", and "Try Again" for a change that is not saved. A tap on "No record" opens the time of the intake. A replaced row offers none.
- "Change Time…" opens the same time sheet as on Today, with the time wheel on the display at once (D033).
- A change that is not saved shows as a red "Not saved" row, and the banner at the top of the list retries every one (D014).
- Older days load when the end of the list comes on the display, 30 days per load. The history does not load at launch (spec §9).
- At the accessibility text sizes the time goes under the action.

## My Items

A grid of tiles, so the user sees at once which items they have (spec §3 P02, D032). It replaces the list of D020.

- Two columns. One column at the accessibility text sizes.
- A tile shows two things: the form icon, large, in the item color, and the name in the headline weight under it. No plan line, no amount, and no other text. The plan is in the item detail.
- The name wraps and never truncates. A tile has room for two lines, and a longer name makes its row taller. The tiles of one row have the same height.
- Order: the first time of day of the plan, then the name. As-needed items come last. No section titles.
- A tap opens the item detail. A long press opens a context menu with "Edit" and "Archive…".
- "Archived" is one plain row under the grid. "Notifications are off" is one plain row above it.
- The archived list has "Restore" on each row. A swipe to the left or a long press offers "Delete Item…" (D033).
- The tile is a kept custom control (D026), because the system has no grid card. It uses the system grouped card color, the continuous corner of an inset grouped list cell (26 points from iOS 26, 10 points before), margins of 16 points, and a gap of 12 points.
- The empty state is a system empty view.

## Archive and delete

One confirmation for each, and no second dialog before it (D033).

- "Archive…" is in the context menu of a Today row and of a My Items tile, and in the menu of the item detail. Long press, "Archive…", "Archive": three taps.
- The archive alert names the item. It says that the reminders stop, that the item leaves Today and My Items, that the records stay, and that this is not advice to stop.
- The item detail ends with the row "Change or End This Item…". It opens a system menu, not a dialog: "Replace with a New Product…", the reminder switch, "Archive…", and "Delete Item…".
- "Delete Item…" is in that menu, on the detail of an archived item, and in the archived list. The delete alert names the item. It says that the item, its plan, and all its records are deleted, and that the user cannot undo this.
- After the commit, the item leaves every page with the layout motion. A reminder that the system did not confirm as removed gets the alert "Reminders May Still Be On", for an archive and for a delete.

## Settings

- "Remind Again" is one menu row. Its value says the delay after the first reminder: "Off", "After 15 min", "After 30 min", or "After 1 hr" (D032).
- A footer or a helper text is one short sentence (D032).
- "Display" has only "App Color". The strikethrough setting is gone (D032).

## Motion

One motion language for the whole app (D030). The same kind of change uses the same motion on every page. `App/Motion.swift` has the three cases. A view or the model names a case and never a curve or a duration.

| Case | Motion | Where | With Reduce Motion |
|---|---|---|---|
| Layout | The system `snappy` spring, the one of the fold | A change that moves the layout | No motion. The change shows at once |
| State | A fade of 0.2 seconds, with the system replace effect on a symbol | A change in place, with no move | The same fade. A symbol cross-fades with no scale |
| Attention | A fade of 1.2 seconds | The opening highlight of the current slot title | The same fade |

- Layout applies to: a slot that folds or opens, by a tap, after its last record, or on a return to the app. A row or a section that comes or goes on Today, the archived list, the item detail, History, and Settings. A row or a footer that comes or goes in the add and edit form, including the candidates of the smart completion. The section under the repeat rule. A line that comes or goes in a row. The change between an empty page and a list. The scroll to the slot of a tapped reminder. A tile or a row that comes or goes on My Items. A row of History that comes or goes after a correction or a load of older days. The scan card when a tapped text adds its words.
- State applies to: the record circle and the as-needed record button. The chevron and "Record All" in a slot header. The mark of an as-needed dose. A word on the scan card that the user chooses or removes (D042).
- The History graph has no motion. A change of step happens when the page opens. The selection ring and the date label change at once, as a text value does. The scroll of the timeline to a selected day uses the layout motion, the same as the scroll to the slot of a tapped reminder.
- A record changes a row only after the local transaction commits (spec §7.2). No motion starts at the tap.
- The system owns the motion of sheets, pushes, menus, alerts, dialogs, swipe actions, pickers, switches, and the keyboard. Maru does not change it.

Maru does not animate:

- The first content of a page: Today at a launch, the item detail, and the first days and the graph of History. The page shows complete, with no entrance (spec §9).
- Text that changes its value in place: a time, a count, the plan line, a status word.
- The app color. A new tint shows at once on every control.
- The check mark of a repeat day, as in Clock.
- The storage problem page. An error shows at once.
- A tap. No bounce, no scale, no shimmer, no confetti, no animated icon, and no custom transition.

## Forms and icons

Six own icons, two tones of one color, as template images: capsule, tablet, softgel, powder scoop, drop, and a jar for an unknown form (D013). The user picks the form. Until the user picks one, a known supplement name or a scanned label sets it (D043). For release, convert them to custom SF Symbols. The source SVG files are in `App/Icons.xcassets`.

## Add and edit

One screen (spec §3 P03), in this order: name, type (supplement or medication, starts on "Supplement"), form menu (starts on "Capsule"), color menu, amount (optional, with units including IU), time slots, repeat days, note. Apple Health needs seven screens for the same result. Maru needs one.

- A system sheet: "Cancel" at the top left, "Save" at the top right. Save is off until the draft is valid (D026).
- The plan line is the footer of the reminder section. It states the full schedule, for example "Every day at 8:00 AM, with no end date", or the problem that keeps Save off. An amount has its own line above it.
- A new item has no amount and no time (spec §2.1, D032). The form has no "choose a type" hint.
- A new item starts with the row "Scan Label", above the name (D038). It has a camera symbol at the start, a small sparkle symbol beside the title, and the line "Point the camera at the bottle." The symbols take the app tint. No tutorial and no pop-up.
- The scanner is a system sheet with "Cancel" at the top left. The camera fills it, and the system marks the text that it finds. A card at the bottom, on the system material, holds one decision at a time. First the prompt "Tap the name on the label" with the line "Maru reads only the name." After a tap (D042): the words of the text as capsule buttons in rows, the line "Tap a word to add or remove it.", a text field with the name, "Use This Name" as a large button in the tint, "Clear", and the line "Tap more text to add it to the name."
- A word is a system toggle in the button style. A chosen word shows the on state of the system, in the tint. The words that look like the name start chosen. A number with a unit, a count, and a stock phrase such as "Dietary Supplement" start not chosen (D042).
- The field shows the chosen words. The user can type in it. A tap on a word or on a new text sets the field to the chosen words again.
- "Use This Name" closes the scanner and fills the name. The scan fills no amount and no time. When the label shows exactly one form, it counts as the form of the product (D043).
- While the user types the name, up to four names from the built-in lists show as rows under the name field, in the tint, as buttons of a form. A tap fills the name and closes the keyboard. The rows go when the field loses the focus. They only propose a name.
- The scanner is a kept wrapper of the system scanner view (D026, D038).
- Smart completion (D043): when the name of a supplement is a name of the built-in list, in full, the form changes to the form of the scanned label, else to the usual form. This happens only while the user did not choose a form on the screen. After that, a different form shows as a row under the form menu, for example "Use Softgel". A medication gets only the scanned form, as that row.
- Under the amount field, the "Add a Time" button, and the note menu, a known supplement shows candidates as small bordered system buttons in one row: for example "1 softgel" and "2 softgels", "Evening", and "With food". A row that does not fit becomes a column. A tap fills the field or adds the time. Nothing fills before a tap. The footer under the note says "Suggestions come from common labels. Check your own label." The candidates come and go with the layout motion. A change of the type to "Medication" removes them at once.
- "Add a Time" opens a sheet with a time wheel. The time counts only after "Add" (spec §2.1). For the first time of a supplement the wheel starts at a time that the user already confirmed for a supplement, else at 8:00.
- "Repeat" opens a list with check marks, as in Clock. The first section has "Every Day" and "Every Other Day". Under it are the seven days, or "Starting Today" and "Starting Tomorrow" for every other day. Maru picks no first day, and it has no date picker (D036).
- The plan line of every other day reads "Every other day at 8:00 AM, starting tomorrow, with no end date".
- The item detail shows "Every other day" under "Days", and a row "Next Dose" with "Today", "Tomorrow", or a weekday (D036).

## Text and accessibility

- Follow the system text size at every size, with no maximum (D013). Names wrap and never truncate.
- The icon has a size limit. The record circle follows the text size. Hide the icon at the three largest accessibility sizes.
- Support VoiceOver, dark mode, Increase Contrast, and Reduce Motion (spec §5.3).
- The tab bar always shows icons with names (D026).
