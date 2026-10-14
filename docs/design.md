# Design

The visual rules for the app. The decisions behind them are D010–D013, D015, D018, D020, D021, D024, D025, D026, D028, D030, D032, D033, D036, D038, D041, D043, D044, D048, D050, D055, D056, D058, D065, and D072 in `docs/decisions.md`. The study is in `docs/research/2026-10-10-visual-direction.md`.

## Principles

1. Simpler than Apple Health Medications in every flow that both apps have (D021). Count screens and taps.
2. Apple system style: native SwiftUI system components only, the system font only, system colors (D011, D012, D026). A custom control needs a recorded reason.
3. Few words. A row shows the name, the amount, and the time. The circle shows the state (D011, D044).
4. Do not choose for the user: no default amount and no default reminder time (spec §2.1). The type, the form, and the color of a new item are not health choices, so they have a start value that the user can change (D032). A known supplement gets amount, time, and note candidates that fill nothing until a tap (D043).
5. No repeated information, and no "·" separator in any text of the app. Use natural words or a second line (D032).
6. No gray text for a state. A title or a name looks the same in each state (D032). A state line shows its SF Symbol and the text color, for example "Reminders off", "Notifications off", and "Archived" (D058).

## Color

- One app tint for the whole app. The user picks it from the eight item colors in Settings, under "App Color" (D025). The default is pink, the system pink (#FF2D55 in light mode).
- The tint marks: buttons, and the record circle when filled. A slot title stays in the text color (D050). Sheets get the same tint.
- The tint is for icons, controls, and state, not for row text (D076). A row that is an action or a link has the text color, and its symbol keeps the tint. The value of a menu row has the text color. A destructive row stays red.
- In light mode, the tint has at least 3:1 contrast on white. Orange, yellow, green, and mint are darker when they are the tint: #D97F00, #B49000, #2CAA4C, and #00A69F. Dark mode uses the system colors. The item colors do not change.
- A label on a filled tint, such as the check mark of the record circle, is white when white has at least 3:1 contrast on the fill. Otherwise it is black (D025).
- Item colors: pink, orange, yellow, green, mint, blue, purple, brown. Use the system colors with the same names, and a system-like brown. Each color has a light value and a dark value. The item color appears only on the form icon. It is never the only signal of a state (spec §5.3).
- A new item gets the first color in that order that no active item uses. If all are in use, it gets pink.
- Errors and destructive actions use the system red.

## Surface

- Every page is a system grouped list or form. The custom cards are the tile of My Items and the graph of History (D026, D032, D041).
- Today and My Items use the plain grouped background, with no header wash (D024).
- Every page is the gray grouped background with white cards, as in Apple Health and Settings. This includes a page that loads or shows an error (D028).
- An empty page or an error page is one system empty view: a title in Title Case with no period, an SF Symbol, and at most one sentence of description. A button follows only when the user can act (D058).
- A small sheet has the detents medium and large: a time wheel, a short list of choices, and the share sheet. The edit screen and the settings are full sheets. The modifier `smallSheet()` holds the rule (D058).
- The card margin and the card padding are 16 points (`Tile.margin`). The second line of a list row sits 2 points under the name (D058).

## Feedback

- No toast and no notice card. A save closes the sheet, and the list shows the change in place, as in Apple Health (D028).
- A failure uses a system alert. Every alert title uses Title Case, for example "Not Saved", "Today Changed", "History Changed", "Not Changed", and "Maru Couldn’t Save" (D058). A failed reminder after a save or a change also gets an alert. Notifications that are off show as the row "Notifications off" on Today and My Items, with no alert.
- A reminder for one item has one action, "Taken". It records with no open of Maru. When it can not record, a notification says "Not recorded" (spec §8.3, D034).
- The item detail shows the reminder state in the plan: "On", "Not Set", or "Not Confirmed", and the reason in the footer (spec §8.1, T03).
- The item detail has a section "Last 7 Days" with the strip of 7 capsules of History (D054), drawn by the same view, after the form icon. A line under it counts the doses as three labelled values with space between them and no separator: "Taken: 5", "Skipped: 1", "No record: 1". They stand one under the other when the row is too narrow (D068). An as-needed item has only "Taken". It has no list of records and no tap. The item log is in History (D057).
- For a plan that counts days (every other day, every few days, or days on and off), "On" has a limit, and the footer states it: Maru sets the reminders of the next 7 dose days at each open (D036, D065).

## Today

- The large title "Today" with the date under it. No ring (D026).
- A gear button at the top left opens the settings sheet. An add button sits at the top right (D020). Both tabs have them. Today also has a History button with a calendar symbol, beside the add button (D026).
- One list section per time slot, in time order. The section header is the slot name, for example "Morning", not a clock time (D011).
- The header has no button. Each row records on its own (D060).
- Row: the form icon in the item color, the name, a second line in small gray text, and the record circle at the end. The name area opens the detail. The circle is a separate hit target (spec §3 P01). The circle is an SF Symbol: an empty circle, a filled check, a gray dash for skipped, or a red mark for not saved.
- The second line has the amount and the time that the user set: "2 capsules, 8:00 AM", or "8:00 AM" with no amount. A taken row shows the intake time: "2 capsules, Taken at 8:07 AM". A skipped row shows "2 capsules, Skipped". A skipped as-needed dose says "Skipped" too (D058). A medication that keeps another time zone names the city: "9:00 AM Shanghai time" (D044).
- A recorded row and an open row differ only by the circle and the time. The name, the icon, and the amount keep the normal look. No dim and no strikethrough (D032, D044).
- A slot always shows its rows, also when every row is done. Nothing folds or opens. The header is the plain title (D057, D060).
- The same words name an action in the dialog of the circle, in the menu, and in the swipe: "Taken", "Skip", "Undo", and "Change Time…" (D058). Swipe right on a row: "Taken". Swipe left: "Skip" on an open row, "Undo" on a recorded row. Only the first action of the right swipe runs with a full swipe (D028).
- A long press opens a system context menu with the same actions, plus "Details", "Edit", and "Archive…". An as-needed item offers "Record Dose" (D068). Every action uses the same record transaction as the circle (D028).
- The menu of a recorded row has "Change Time…". The menu of an open row has "Taken Earlier…". Each opens the time sheet directly. The sheet shows the time wheel at once, and "Save" records the dose as taken at that time. The wheel does not go past the current time. So a change of a record time needs three taps (D033).
- An "As Needed" section at the end lists items with no schedule. Each row has a record button that records a dose at the current time (D021). A dose of today shows under its item as "Taken at 8:07 AM" or "Skipped" in the text color. It lines up with the name, past the icon column, at every text size (D058).
- With no item, the empty view in the middle of the page says "No Items Yet" and "Tap + to add a supplement or medication." With items and nothing due today, it says "Nothing Planned Today" (D026, D058, D068).
- Success text and the success haptic come only after the local transaction commits (spec §7.2).

## History

A graph of squares at the top, and a section "Last 7 Days" in a system grouped list under it, with one row for each item (spec §3 P05, D032, D041, D054). Today opens it from the History button. A row opens the log of the item, and a tap on a day of the graph opens the log of the day.

### Graph

- One square for each day. One column is one week. The rows are the weekdays, in the first weekday order of the user's calendar. Time runs from left to right, and today is at the right end of the filled part.
- No title, no legend, no count, and no sentence. The navigation title "History" is the only title.
- Steps: 13 weeks from the week of the first day. 26 weeks when 13 are full. 52 weeks when 26 are full, as two bands of 26 columns with the older band above. The step changes on the first day of a week that does not fit. After 52 weeks the graph shows the last 52 weeks.
- The graph fills the card width. Side = (width − left labels) ÷ (columns + (columns − 1) × gap share). The gap share is 0.19 at 13 columns and 0.3 at 26 columns. The corner is 22% of the side, continuous.
- Sizes on a screen of 402 points (graph width 338): 13 weeks, side 21.2 and gap 4.0. 26 weeks, side 10.1 and gap 3.0. On a screen of 320 points (graph width 256): 13 weeks, side 15.8 and gap 3.0. 26 weeks, side 7.6 and gap 2.3. 52 weeks uses the sizes of 26.
- The card: the grouped card color, the corner of an inset grouped cell, margins of 16 points, and padding of 16 points. It stays above the list on the grouped background and does not scroll. Its height on 402 points is 222 points at 13 weeks, 138 at 26, and 256 at 52.
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
- Selection: a ring of 1.5 points in the tint, with a gap of 1 point around the square. The date of the day, for example "Tue, Aug 18", in semibold caption 2 in the label row over its column. The title of the log of that day has the same format (D058). Month labels under it do not show. No dark border, no shadow, no magnifier, and no band behind the week.
- A touch or a drag selects the nearest day. A day that is not here yet gives today. A light selection haptic comes when the selected day changes.
- At the end of the touch, the log of the selected day opens as a push (D054). The ring stays until the log closes.
- VoiceOver reads the graph as one adjustable element: a summary of the days by level, or the selected day with "2 of 3 taken". Swipe up or down moves the day. The default action opens the log of the selected day.

### Last 7 Days

- One section with the title "Last 7 Days", under the graph. One row for each item that had a planned dose or a taken as-needed dose in the last 7 days. An archived item shows only when it had one. Order: the first planned time, then the name. As-needed items come last.
- Row: the form icon in the item color, or the item photo (D056, D058), the name, the part of the day or "As Needed" on a second line, and at the trailing edge a strip of 7 small capsules, oldest at the left and today at the right. The system chevron shows that the row opens.
- Capsule: 0.4 times the height of the body text wide, and 1 times high. Filled in the item color: every planned dose of the day taken, or an as-needed dose taken. The item color at 40%: some taken. A hollow outline of 1.5 points in the item color: planned and none taken. A faint gray capsule: nothing planned (D061). A skipped dose is not taken.
- A planned dose of today that is not due yet and has no record counts as nothing planned until its time.
- At the accessibility text sizes the strip goes under the words.
- A capsule that changes after a record fades with the state motion.
- VoiceOver reads the name, the second line, and a summary such as "Taken on 5 of the last 7 days". The strip is hidden.
- A tap opens the log of the item. With no row and no graph, the page shows "No History Yet".

### Logs

The log of an item and the log of a day use the timeline rows below. The log of an item lists its days, newest first. The log of a day lists one day and has its date as the title. Undone and replaced actions stay in both.

### Timeline rows

- Newest first, one section per day in the log of an item: "Today", "Yesterday", then the weekday and the date in the format "Tue, Aug 18". The day is the day of the dose.
- One row per action of the user: taken, skipped, time changed, or undone. An undone action and a replaced action stay in the list.
- Row, like Recents in Phone: the form icon in the item color, or the item photo (D056, D058), the name, the action in plain words under it, and the time of the action at the end. The words name the intake time when it is not the time of the record, for example "Taken at 8:00 AM".
- A planned dose of a past day with no record shows as "No record", with its part of the day in place of a time. An open dose of today shows on Today only.
- The newest row of a dose offers the corrections with a swipe and a long press, as on Today: "Taken", "Change Time…", "Skip", "Undo", and "Try Again" for a change that is not saved. A tap on "No record" opens the time of the intake. A replaced row offers none.
- "Change Time…" opens the same time sheet as on Today, with the time wheel on the display at once (D033).
- A change that is not saved shows as a red "Not saved" row, and the banner at the top of the list retries every one (D014).
- Older days load when the end of the list comes on the display, 30 days per load. The history does not load at launch (spec §9).
- At the accessibility text sizes the time goes under the action.

## My Items

A grid of tiles, so the user sees at once which items they have (spec §3 P02, D032). It replaces the list of D020.

- Two columns. One column at the accessibility text sizes. The iPad has the same grid (D072).
- A tile shows two things: the form icon, large, in the item color, and the name in the headline weight under it. No plan line, no amount, and no other text. The plan is in the item detail.
- The name wraps and never truncates. A tile has room for two lines, and a longer name makes its row taller. The tiles of one row have the same height.
- Order: the first time of day of the plan, then the name. As-needed items come last. No section titles.
- A tap opens the item detail. A long press opens a context menu with "Edit" and "Archive…".
- "Archived" is one plain row under the grid. "Notifications off" is one plain row above it, with the symbol and the text color of the line "Reminders off" (D058).
- The archived list has "Restore" on each row. A swipe to the left or a long press offers "Delete Item…" (D033).
- The tile is a kept custom control (D026), because the system has no grid card. It uses the system grouped card color, the continuous corner of an inset grouped list cell (26 points from iOS 26, 10 points before), margins of 16 points, and a gap of 12 points.
- A tile scales to 0.98 while it is pressed (D058).
- The empty state is a system empty view with a button "Add Item".

## Archive and delete

One confirmation for each, and no second dialog before it (D033).

- "Archive…" is in the context menu of a Today row and of a My Items tile, and in the menu of the item detail. Long press, "Archive…", "Archive": three taps.
- The archive alert names the item. It says that the reminders stop, that the item leaves Today and My Items, that the records stay, and that this is not advice to stop.
- The item detail ends with the row "Item Options…" (D068). It opens a system menu, not a dialog: "Replace with a New Product…", the reminder switch, "Archive…", and "Delete Item…".
- "Delete Item…" is in that menu, on the detail of an archived item, and in the archived list. The delete alert names the item. It says that the item, its plan, and all its records are deleted, and that the user cannot undo this.
- After the commit, the item leaves every page with the layout motion. A reminder that the system did not confirm as removed gets the alert "Reminders May Still Be On", for an archive and for a delete.

## Settings

The sheet behind the gear button. A "Done" button at the top right closes it. The sections, in order:

- "Reminders": the row "Notifications" with its state ("On", "Quiet", "Off", "Not Asked Yet"), and the row "Open Settings" when the state is "Off" or "Quiet". Settings has no test notification (D076). The footer explains a state that needs words.
- A row with the switch "Show Names in Reminders". Turn it off to keep item names out of the notification text (D029).
- "Display": "App Color".
- A row with the switch "Share Usage Statistics". It shows only in a build that has an analytics key (D052).
- "Your Data", then "Send Feedback" (D037), then "Support Maru": three optional tips of a consumable purchase. A tip unlocks nothing (D053).
- "About" is the last section (D063): "Privacy Policy" and "Support" open the pages on maru.day, and "Licenses" shows the license of GRDB.swift.
- "Remind Again" is on the add and edit screen, not in Settings (D079). It is two menu rows in the section "Reminders", after the plan, and only when the item has a time. The first row is the number of follow-ups: "Off", "1 Time", "2 Times", "3 Times", "5 Times", or "Until Recorded". The second row, "Every", is the time between them: "5 min", "10 min", "15 min", "30 min", or "1 hr". It comes and goes with the layout motion, and it shows only when the number is not "Off".
- "Until Recorded" has a limit, and the footer states the number and the last time: "Maru reminds you up to 12 times for each dose, until 1:00 AM at the latest." The time uses the time format of the device.
- Below it, from iOS 26, is a section with the switch "Alarm" (D079). Its footer is one sentence: it rings like the Clock app, also in silent mode and Focus, and follow-ups stay notifications. The first turn-on asks the system. A refusal turns the switch off and shows the alert "Maru Can’t Set Alarms" with "Open Settings" and "Cancel".
- A footer or a helper text is one short sentence (D032, D058). "Your Data" is the one section that may have two.
- The strikethrough setting is gone (D032).
- "Your Data" is the section before "Send Feedback" (D040). It has three rows: "Export Records", "Back Up", and "Restore from Backup…". A tap on one of the first two opens the system share sheet with the file. The third opens the system file picker.
- The footer of "Your Data" has two sentences, because it must say that the files are not encrypted (D058).
- A restore has one alert, "Replace Maru Data?", with a destructive button "Replace". After a restore, the sheet closes and Today shows the restored data. No message says so (D028). A failure is a system alert that says that the data did not change.
- The share sheet is the one of UIKit, `UIActivityViewController`, in a system sheet. `ShareLink` needs the file before the tap and does not say when the sheet closes, and Maru must remove the file then (D026, D040).

## Widgets

Two Home Screen widgets, small and medium each (D048). They use the capsule of the app icon, tilted by 45 degrees, and no list rows.

- One capsule is one dose. Taken: filled with the app tint (D025) as a gradient. Open and skipped: light gray (`systemGray5`) with a thin edge (`systemGray3`). VoiceOver says "Taken", "Not recorded", or "Skipped" (D068), so the color is never the only signal.
- The background is the system background: white in light mode, black in dark mode. Text uses the system font and the system colors.
- "Today" has no names and no buttons. Small: the slot word in the tint, then the time in gray. Under it a large "2 left", and the capsules of the slot at the bottom right. When every dose is done: "All done" in the tint and "Next 8:00" in gray, "7 of 7", filled capsules. Medium: "Today" and, at the top right on its line, a progress bar (D076), then a column for each slot with its title, its time, and its capsules. The bar is a rounded track of 96 by 8 points in the system fill, with a fill in the tint for the share of the doses that are taken. It has no border, no segments, and no text. VoiceOver reads it as "Today, 4 of 7 taken". The columns end at the bottom edge, so the space over "Today" equals the space under the capsules. The slot of the clock has the title in the tint. A tap opens Today at the slot.
- "Record Dose" shows only the current slot, with its title in the tint. Small: up to 2 rows (capsule, name, amount). Medium: up to 4 columns (capsule, name, amount). A tap on a gray capsule records the dose. A taken dose shows a filled capsule and a gray name. This is the one place where a name is gray for a state (the owner asked for it). The widget has no undo. A tap elsewhere opens Today at the slot.
- The widget never shows a success before the record commits. When the record can not be made, the system asks to open Maru.
- The words "Today", "Morning", "Noon", and "Evening" match the app. The header of the small "Today" widget has no "·": the color separates the two parts (D068).

## iPad

The iPad uses the layout of the iPhone at a larger width (D072). It has the same tab bar, the same pages, and the same navigation: Today opens History and the item detail as a push, and My Items pushes the detail on top of the grid.

- The content fills the width of the window. There is no readable column in the middle and no second pane.
- My Items keeps two columns of tiles, and one at the accessibility text sizes. The History graph fills the width.
- Settings, the add and edit screen, the scanner, and the time sheets are system sheets. A dialog of choices shows as a popover from its button.
- The iPad has the four orientations. The iPhone is portrait only. Split View and Slide Over show the same pages at their width.

## Watch

One screen, "Today", with system list rows on the black background of watchOS (D071).

- One section per part of the day, with the slot word as its header, as on the iPhone.
- Row: the capsule of the widgets, the name, and a second line in small gray text with the amount and the time. A taken dose shows its intake time, and a skipped dose shows "Skipped". The capsule is gray for a dose that is open or skipped, as in the widgets.
- A tap on an open row records "Taken". A swipe left gives "Skip" on an open row and "Undo" on a recorded row, with the words of the iPhone.
- A row is half transparent while its request runs. The capsule fills and the success haptic plays only after the iPhone confirms the commit (spec §7.2).
- A failure is a first row with a warning symbol and one plain sentence, and the error haptic. It stays until the next request.
- The last line is "Updated 8:07 AM", the time of the list. With no list of today: "Open Maru on your iPhone to update."

## Motion

One motion language for the whole app (D030, D058). The same kind of change uses the same motion on every page. `App/Motion.swift` has the cases. A view or the model names a case and never a curve or a duration.

| Case | Motion | Where | With Reduce Motion |
|---|---|---|---|
| Layout | The system `snappy` spring | A change that moves the layout | No motion. The change shows at once |
| State | A fade of 0.2 seconds, with the system replace effect on a symbol, and the system numeric text effect on a number | A change in place, with no move | The same fade. A symbol and a number cross-fade with no scale |
| Press | A scale to 0.98 and back, 0.12 seconds | A press on the record circle, the as-needed record button, and a tile of My Items | No scale. The press shows at once |
| Fill | A spring of 0.35 seconds with bounce 0.4, from a scale of 0.85 to 1 | The record circle, when it fills after the commit | The fade of the state case, with no scale |

- Layout applies to: a row or a section that comes or goes on Today, the archived list, the item detail, History, and Settings. A row or a footer that comes or goes in the add and edit form, including the candidates of the smart completion. The section under the repeat rule. A line that comes or goes in a row. The change between an empty page and a list. The scroll to the slot of a tapped reminder. A tile or a row that comes or goes on My Items. A row of History that comes or goes after a correction or a load of older days. The scan card when a tapped text adds its words.
- State applies to: the record circle and the as-needed record button. The mark of an as-needed dose. A word on the scan card that the user chooses or removes (D042). A number or a time that changes in place: the count of the banner of unsaved changes, the line under the name of a Today row, the time of a dose or of a log row, and the line under the week strip of the item detail.
- The History graph has no motion. A change of step happens when the page opens. The selection ring and the date label change at once, as a text value does. A capsule of the strip of an item row uses the state motion when a record changes it (D054).
- A record changes a row only after the local transaction commits (spec §7.2). No change of a row starts at the tap. The press scale is the one reaction to the touch.
- The system owns the motion of sheets, pushes, menus, alerts, dialogs, swipe actions, pickers, switches, and the keyboard. Maru does not change it.

Maru does not animate:

- The first content of a page: Today at a launch, the item detail, and the first days and the graph of History. The page shows complete, with no entrance (spec §9).
- Text that changes its value in place and is not a number or a time: the plan line and a status word.
- The app color. A new tint shows at once on every control.
- The check mark of a repeat day, as in Clock.
- The storage problem page. An error shows at once.
- A tap, beyond the press and the fill of the table. No shimmer, no confetti, no animated icon, and no custom transition. The press and the fill start after the touch or after the commit and never delay a record (spec §7.2).

## Forms and icons

Six own icons, two tones of one color, as template images: capsule, tablet, softgel, powder scoop, drop, and a jar for an unknown form (D013). The user picks the form. Until the user picks one, a known supplement name or a scanned label sets it (D043). For release, convert them to custom SF Symbols. The source SVG files are in `App/Icons.xcassets`.

## Item photo

An item can have one photo (D056). It is optional, and the form icon stays the fallback.

- The photo replaces the form icon on a Today row, on a My Items tile, on the item detail, and on the archived list. In a row, the photo and the drawn icon share one square frame of 1.4 times the icon size, with a limit of 44 points, so the names in a mixed list line up (D073). The drawn icon keeps its size in the middle of the frame. On a tile, both are 44 points with a limit of 64 points. Both follow the text size. The photo has a corner radius of one fifth of its side. It has no border and no shadow. The color of the item does not tint it.
- The row shows the form icon first. The photo replaces it with no motion when it loads. A missing file keeps the icon.
- At the three largest text sizes the row hides the photo, as it hides the icon (D013).
- The photo is decoration. VoiceOver reads no image name in a row.
- A new product that replaces an item starts with no photo.

## Add and edit

One screen (spec §3 P03), in this order: name, type (supplement or medication, starts on "Supplement"), the look of the item (the icon, the form menu that starts on "Capsule", the color menu, and the photo), amount (optional, with units including IU), time slots, repeat days, note. Apple Health needs seven screens for the same result. Maru needs one.

- A system sheet: "Cancel" at the top left, "Save" at the top right. Save is off until the draft is valid (D026).
- The section with the times and the repeat rule is named "Plan", as in the item detail (D058). The plan line is its footer. It states the full schedule, for example "Every day at 8:00 AM, with no end date", or the problem that keeps Save off. An amount has its own line above it.
- A new item has no amount and no time (spec §2.1, D032). The form has no "choose a type" hint.
- A new item starts with the row "Scan Label", above the name (D038). It has a camera symbol at the start, a small sparkle symbol beside the title, and the line "Point the camera at the bottle." The symbols take the app tint, and the title has the text color (D076). No tutorial and no pop-up.
- The scanner is a system sheet with "Cancel" at the top left. The camera fills it, and the system marks the text that it finds. A card at the bottom, on the system material, holds one decision at a time. First the prompt "Tap the name on the label" with the line "Maru reads only the name." After a tap (D042): the words of the text as capsule buttons in rows, the line "Tap a word to add or remove it.", a text field with the name, "Use This Name" as a large button in the tint, "Clear", and the line "Tap more text to add it to the name."
- A word is a system toggle in the button style. A chosen word shows the on state of the system, in the tint. The words that look like the name start chosen. A number with a unit, a count, and a stock phrase such as "Dietary Supplement" start not chosen (D042).
- The field shows the chosen words. The user can type in it. A tap on a word or on a new text sets the field to the chosen words again.
- "Use This Name" closes the scanner and fills the name. The scan fills no amount and no time. When the label shows exactly one form, it counts as the form of the product (D043).
- While the user types the name, up to four names from the built-in lists show as rows under the name field, in the text color (D076), as buttons of a form. A tap fills the name and closes the keyboard. The rows go when the field loses the focus. They only propose a name.
- The scanner is a kept wrapper of the system scanner view (D026, D038).
- Smart completion (D043): when the name of a supplement is a name of the built-in list, in full, the form changes to the form of the scanned label, else to the usual form. This happens only while the user did not choose a form on the screen. After that, a different form shows as a row under the form menu, for example "Use Softgel". A medication gets only the scanned form, as that row.
- Under the amount field, the "Add a Time" button, and the note menu, a known supplement shows candidates as small bordered system buttons, gray with the text color (D076), in one row: for example "1 softgel" and "2 softgels", "Evening", and "With food". A row that does not fit becomes a column. A tap fills the field or adds the time. Nothing fills before a tap. The footer under the note says "Suggestions come from common labels. Check your own label." The candidates come and go with the layout motion. A change of the type to "Medication" removes them at once.
- "Add a Time" opens a sheet with a time wheel. The time counts only after "Add" (spec §2.1). For the first time of a supplement the wheel starts at a time that the user already confirmed for a supplement, else at 8:00.
- "Repeat" opens a list with check marks, as in Clock. The first section has "Every Day", "Every Other Day", "Every Few Days", and "Days On and Off". Under it are the seven days, or "Starting Today" and "Starting Tomorrow" for every other day. Maru picks no first day, and every other day has no date picker (D036).
- "Every Few Days" has a menu "Interval" from "Every 3 days" to "Every 30 days". "Days On and Off" has two menus, "Days On" and "Days Off", from 1 to 99. Each menu starts on "Choose", and Maru picks no number. Under the menus are "Starting Today", "Starting Tomorrow", and a system date picker "Another Date" for any other first day, also a day in the past. The footers say "Choose the number of days." and "Choose the first day." until the user chooses (D065).
- The plan line of every other day reads "Every other day at 8:00 AM, starting tomorrow, with no end date". The plan line of the other two names the first day as a date: "21 days on, 7 days off at 8:00 AM, from Tue, Oct 13, with no end date".
- The photo is part of the look of the item, in the section of the form and the color (D073). The section has no header. Its first row shows the icon as the lists show it, 56 points, in the middle: the photo, else the form icon in the item color. It changes at once with the form, the color, or a new photo. Then come "Form", "Color", "Choose Photo", "Take Photo", and "Remove Photo" when the item has a photo. The camera asks for permission only at the tap on "Take Photo". After a pick, a row with a progress view says "Removing the background…". When Maru finds one subject, the switch "Remove Background" shows, and it starts on. With no clear subject, the footer says that the photo stays as it is. Save is never off because of the photo.
- The item detail shows "Every other day", "Every 3 days", or "21 days on, 7 days off" under "Days", and a row "Next Dose" with "Today", "Tomorrow", a weekday, or a date when the dose is 7 or more days away (D036, D065).

## Text and accessibility

- Follow the system text size at every size, with no maximum (D013). Names wrap and never truncate.
- The icon has a size limit. The record circle follows the text size. Hide the icon at the three largest accessibility sizes.
- Support VoiceOver, dark mode, Increase Contrast, and Reduce Motion (spec §5.3).
- The tab bar always shows icons with names (D026). On an iPad the system shows it at the top, in its own form (D072).
