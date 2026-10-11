# Visual direction study, 2026-10-10

The owner chose variant B (time cards) for the Today screen and asked for an orange accent, less text, and a style near Superpower, Everlab, and the AI companies. This note records the references, the Apple rules that apply, and the effect on the prototype. The samples are small. Each brand has only one site and one App Store listing in the sample.

## References

| Source | What it uses |
|---|---|
| Superpower: [site](https://superpower.com/), [App Store](https://apps.apple.com/us/app/superpower/id6747997159) | White and near-white surfaces. One vivid orange for the brand object, a thin outline on the one card that needs attention, and photo gradients. One grotesque typeface (NB International Pro) at regular weight. Near-black text (#18181B) and gray secondary text (#71717A). Pill buttons and 11 to 15 px card corners. |
| Everlab: [site](https://www.everlab.com.au/), [App Store](https://apps.apple.com/au/app/everlab/id6636471569) | Warm paper backgrounds (#F4EFED, #F3F2E8) with white cards. A serif for screen titles and a sans (Saans) for the interface. Orange only for counts and small status marks. Hairline card borders, 12 to 24 px corners, black primary buttons. |
| Anthropic: [site](https://www.anthropic.com/), [Claude](https://claude.com/product/overview) | Ivory backgrounds (#F0EEE6, #FAF9F5), warm near-black (#141413), and one clay orange (#D97757). A serif for reading text and a sans for the interface. 8 to 24 px corners. |
| X search | Two searches for health and habit app designs gave no useful sample. No conclusion comes from X. |

Shared pattern: a warm neutral surface, near-black text, one orange that marks one thing, a serif for the large text, a plain sans for the rest, and few words on each screen.

## Apple rules that apply

Source: Human Interface Guidelines for [typography](https://developer.apple.com/design/human-interface-guidelines/typography), [color](https://developer.apple.com/design/human-interface-guidelines/color), [materials](https://developer.apple.com/design/human-interface-guidelines/materials), and [layout](https://developer.apple.com/design/human-interface-guidelines/layout).

- Fonts: use the system text styles so Dynamic Type works. San Francisco and New York are both system families. New York is the serif. Keep the number of typefaces small. Do not use weights lighter than Regular. The minimum size on iOS is 11 pt and the default is 17 pt.
- Letter spacing: the system fonts apply the tracking for each point size. Do not set tracking by hand on system text styles.
- Color: do not use one color for two meanings. Supply light, dark, and increased-contrast values for each custom color. Do not use color as the only signal.
- Liquid Glass: it belongs to the control layer (tab bar, toolbar). Do not use it in the content layer. Apply color to it sparingly.
- Layout: group related items with space and container shapes. Keep content inside the safe area.
- Corners: nested corners look correct when the outer radius equals the inner radius plus the padding. With more than about 24 pt of padding, each radius is independent.

## User needs that the screen must serve

From spec §0 and §3 (P01) and the market scan:

1. See what to take now, at a glance, during a busy moment.
2. Record one item with one tap.
3. See later that a record exists, and its real time.

The user does not open the app daily to read. Words that repeat what a shape already says are cost.

## Effect on the prototype (variant B2)

The variant was built in a disposable prototype that is not in this repository.

- Text removed: the "Not recorded" and "Recorded" sentences, the slot names, the count dots, and the row dividers. The circle shows the state. A recorded row shows only the time beside the filled circle. VoiceOver labels keep the full words.
- Hierarchy: the current slot has the large time, a thin accent outline, and a "Now" mark. The other slots use a smaller, gray time. All three slots now fit on one screen.
- Color: the accent marks only the current slot and a recorded circle. Circles in other slots have a neutral ring. Small text never uses the accent, because orange on white is near 3:1 contrast.
- Surfaces: warm paper background with white cards, in light and dark values.
- Type: New York for the title and the clock times, San Francisco for the rest. No manual tracking.
- Accent candidates in the palette menu: Persimmon #E8612C (3.4:1 on white), Clay #D97757 (3.1:1), Ember #C2501F (4.7:1).

## Open points

- New York has no Chinese glyphs. The title "今天" falls back to the system sans. The clock times stay serif in every language.
- The prototype has no "skipped" state. Spec §4 requires a visible difference between "no record" and "confirmed not taken".
- Increased-contrast color values are not defined yet.

## Result: the owner rejected B2 (same day)

The owner disliked the serif, the large clock times, the colored outline, and the amount of text, and asked for the Apple system style (D011). The warm surface and serif findings above are not in use. The Apple rules section still applies.

Reference for the new direction: the [Apple Health](https://apps.apple.com/us/app/health/id1242545199) summary screen uses a bold San Francisco title, white cards on the system gray background, a colored semibold header on each card, and gray secondary text. Reminders uses a leading circle that fills on completion and a title that turns gray.

The prototype got two replacement variants: "Cards" (one card per time slot, trailing circle) and "List" (system grouped list, leading circle). Both show the slot name in place of the clock time, mark the current slot with an orange header, and show only the name and the dose in a row.

## Accent, font, and recorded-row study (same day, after D011)

The owner said the system orange is too energetic, asked for accent options, asked about fonts with more design character, and asked whether a recorded row needs a strikethrough.

### Accent

- Evidence: in [Valdez and Mehrabian (1994)](https://pubmed.ncbi.nlm.nih.gov/7996122/), saturation and brightness had stronger effects on emotion than hue. Arousal rose with saturation and fell with brightness. Only the abstract was read. A less saturated orange is thus a direct answer to "too energetic", with no change of hue.
- Contrast of a white check mark on the fill (WCAG ratio, 3:1 is the minimum for a graphic): system orange #FF9500 2.2, terracotta #C4623A 4.1, rust #A9502F 5.4, sage #5E8C76 3.8, teal #1F6F78 5.8, indigo #5B63C7 4.8, ink #1C1C1E 17.
- Category icons (App Store, 2026-10-10): Medisafe, Bearable, and Things are blue. MyTherapy is red. Streaks is bright orange. Apple Health and Reminders are white. A muted warm color is not in this sample.
- Recommendation given to the owner: terracotta.

### Font

- Anthropic uses its own typefaces (Anthropic Sans and Anthropic Serif). They are not available for license.
- Options shown: the system font (recommended), the system rounded design, Instrument Sans, and Instrument Serif for headings only. Both Instrument families have the SIL Open Font License, so the cost is zero. A custom Latin font does not cover Chinese, so Chinese text stays in the system font. Instrument Sans is wider, and a long name wraps to two lines.

### Recorded rows

- No controlled study of strikethrough against dimming was found. Practitioner reports say that a strikethrough makes a finished item hard to read again and can read as "cancelled" ([Day One forum](https://forums.dayoneapp.com/forums/topic/text-strikethrough/)), and that strong dimming can fail contrast ([GitLab issue](https://gitlab.com/gitlab-org/gitlab/-/issues/385172)).
- This app has a second task that a to-do list does not have: the user reads a finished row again to answer "did I take it?". That favors a readable name.
- Recommendation: dim the name, do not strike it. When every item of a slot has a record, show the slot as one line the next time the user returns to the app. The rows do not move at the moment of a record (spec §4).
- Slot names in place of clock times: in [Keller et al. (2021)](https://findanexpert.unimelb.edu.au/scholarlywork/1489428-habit-formation-following-routine-based-versus-time-based-cue-planning--a-randomized-controlled-trial), routine-based and time-based cue plans formed habits equally well. The trial was about nutrition, not medication. The evidence does not argue against slot names.

## Icons and dose display (2026-10-11)

### Default icons

- Libraries checked on GitHub on 2026-10-11: [Phosphor](https://github.com/phosphor-icons/core) (MIT, six weights with duotone), [Lucide](https://github.com/lucide-icons/lucide) (ISC, outline), [Tabler](https://github.com/tabler/tabler-icons) (MIT, outline), and Apple SF Symbols (Apple license, Apple platforms only).
- All have a pill, a leaf, and a drop. Lucide and Tabler also have tablets, a pill bottle, a capsule, a syrup bottle, and candy. None has a powder scoop.
- Recommendation: SF Symbols in the filled style on a tile with the accent at low opacity. One default for medication (`pills.fill`) and one for supplements (`leaf.fill`). The icon never guesses a pill shape (spec §5.1). SF Symbols match the system weight, scale with Dynamic Type, and need no extra license. The icon goes gray when the row has a record.
- A full set by dosage form (capsule, tablet, softgel, powder, liquid, drops, gummy, spray) needs custom symbols, because no library covers powder. That is separate design work.

### What a Today row shows

- The prototype showed the product strength ("2000 IU", "5 mg") in every row. The strength is what the label says. It is not what the user takes each time.
- No study was found that tests strength or amount in a reminder list. Related evidence: explicit and simple instructions are understood better than instructions that need a calculation ([AHRQ on the Universal Medication Schedule](https://www.ahrq.gov/health-literacy/improve/pharmacy/instructions.html)). A review of 229 reminder apps found that they rely on timer alerts and do not support routines ([Stawarz, Cox, and Blandford 2014](https://discovery.ucl.ac.uk/id/eprint/1418104), abstract only).
- Recommendation, in line with spec §2.1: a Today row shows the name. It shows the amount for one intake only when the user entered one. The amount is free text with any unit (capsules, tablets, scoops, grams, millilitres, drops), so a powder or a liquid works. The app does not fill "1" and does not convert units. The strength stays in the detail view and in My List. When two items have the same name, the row needs the strength to tell them apart (spec §5.3).

## Own style and own icons (2026-10-11)

The owner said that the leaf icon is wrong for supplements and that the app looks like Apple Reminders. The owner wants the Apple quality with a style of its own, and named Linear, Notion, Luma, Anthropic, and OpenAI as references.

### References (App Store screenshots, 2026-10-11)

- Linear Mobile: dark, dense rows, small text, small colored status icons, hairlines, no cards.
- Notion: white, plain lists with a small icon per row, hand-drawn illustration as the brand mark.
- Luma: warm gradient backgrounds and colorful covers on a simple list.
- ChatGPT: white surface with a soft pastel gradient around it and very few controls.
- Claude: warm photography and a serif.
- Things 3: white, no cards, small colored icons, bold section titles, much white space.

Shared pattern: each keeps the content plain and puts the identity in one surface treatment and one icon language.

### Three directions in the prototype

In the prototype, the settings sheet has a Style picker.

- Glow (recommended): a soft wash of the accent behind the title, cards with slight transparency, a hairline, and a soft shadow. The page takes the mood of the accent that the user picks.
- Ink: the plain system background, no cards, small uppercase slot labels, hairlines between rows, black icons.
- Paper: a warm sheet with warm white cards and a warm hairline.

All three share: the system font, the user's accent, a row of small circles under the title that shows the day (one circle per item, grouped by slot), and one soft ripple when a record commits.

### Own icons

Six icons drawn for this app, two tones of one color, as template SVG in `App/Prototype/Icons.xcassets`: capsule, tablet, softgel, powder scoop, drop, and a jar for an unknown form. The user picks the form. The app does not guess it (spec §5.1). For release, convert them to custom SF Symbols so they follow Dynamic Type and weight, and add gummy, sachet, spray, and injection if users ask.

## Icon placement and an adaptive paper surface (2026-10-11, later)

Owner feedback on the three directions: Glow looks machine-made, Ink is too plain, and a change of surface alone is not a style. Paper is acceptable, but it must work with every accent and in dark mode, because about half of the users use each mode. The own icons are good. The owner wants them larger and with no plate behind them.

### References (App Store screenshots, 2026-10-11)

- Streaks: the icon sits inside a ring, and the ring is the action.
- Structured: an icon in a colored shape leads each row, and a small ring at the end marks it done.
- (Not Boring) Habits: a row of small check circles shows the days.
- Things 3 and Amie: plain rows where the craft is in spacing and small icons.

### Prototype

- One surface: paper that takes about 4% of the accent, with separate light and dark values. Orange gives a warm sheet, blue gives a cool sheet, and graphite stays neutral. Cards take about 1% and have a hairline. No gradient, glow, or shadow.
- Three icon placements, with a picker in the settings sheet:
  1. In the circle (recommended): the icon sits inside the record circle, so the picture and the button are one 40 pt element. The current slot has the accent on its circles and icons. The other slots stay neutral. A record fills the circle and shows a check mark. The amount moves to the end of the line.
  2. Color icon: a bare 28 pt icon in the accent leads the row, and the record circle ends it.
  3. Ink icon: the same with the icon in the text color.

## Surface without tint, and large text (2026-10-11, third round)

Owner feedback: the color icon with the trailing circle is the chosen row. The accent-tinted paper also looks machine-made. The owner named three ways out: almost no tint, color in blocks, or plain black and white. The owner asked how the text size setting affects the row and where the amount belongs.

### References (App Store screenshots, 2026-10-11)

Things 3, Bear, Mela, Overcast, Timery, Carrot Weather, Fantastical, Halide, and Apple's Sports, Invites, and Journal. In this sample the app surfaces are plain white or plain black. Color appears as small strong marks (Bear red, Overcast orange, Things blue) or as one solid block (Carrot's header, Timery's frames). None uses a tinted background or a glow inside the app.

### Prototype (settings sheet, "Surface")

- White (recommended): system background with gray wells. Color only in the icons, the record mark, and the current slot title.
- Contrast: the same, and the current slot is a solid ink card with the opposite color scheme inside. In dark mode this card is white, which is bright at night.
- Block: a flat block of the accent behind the title with ink text, and a white sheet with round top corners below it.
- Faint: the earlier paper with 1.5% of the accent.

### Amount position and text size

- The amount stays on a second line under the name. Beside the name it competes for width with the name and the circle. In an earlier build "Magnesium glycinate" with "2 capsules" beside it already fell back to two lines at the default size.
- Tested with `xcrun simctl ui content_size` at extra-extra-extra-large, accessibility-large, and accessibility-extra-extra-extra-large. The row keeps its shape. The name wraps and never truncates (spec §5.3). The icon and the circle scale with the text up to 44 pt and 40 pt. From accessibility size 3 the icon is hidden and the name takes its width. The circle keeps a 44 pt hit area.
- Not tested at large sizes: My List, the settings sheet, the detail sheet, and Chinese text.

## Layout study from to-do and reminder apps (2026-10-11, fourth round)

The owner chose the white surface and asked for layouts that differ in structure, with to-do and reminder apps as references. Colors stay as decided.

### References (App Store screenshots, 2026-10-11)

- Apple Reminders: the Today list has the sections Morning, Afternoon, and Tonight, with a plain row and a leading circle.
- Clear: full-width bands with no chrome. A finished item leaves the list.
- Actions by Moleskine: each task is one solid block under large day titles.
- Structured (earlier sample): a vertical rail with a node per task.
- Streaks (earlier sample): a grid with a large icon per habit.
- Todoist, TickTick, Any.do, Microsoft To Do, Superlist, Sorted, Twodos, Tweek: standard lists. No structure to borrow that the list above does not already have.

### Prototype (settings sheet, "Layout")

- Cards: one gray well per time slot. The baseline.
- Timeline: the same cards on a rail with one node per slot. The rail has the accent down to the current slot, so the day reads from top to bottom with no clock times.
- Blocks: one block per item under plain slot titles. A recorded item keeps only an outline, so the filled blocks are what is left to take.
- Tiles: a two-column grid with a larger icon in each tile. One column at the accessibility text sizes.

## Timeline with a Now mark, and two layouts from X (2026-10-11, fifth round)

Owner feedback: Cards and Timeline are both liked. The owner asked for a Timeline version that marks the present, for no color on the card titles, for no day row in the Timeline (agreed), and for two more layouts with strong design character, with a wider search on X.

### X search (2026-10-11)

X search results for general design terms are mostly unrelated posts. Three queries with a minimum like count gave five relevant posts. Two of them led to a layout:

- [@thebtjackson, a minimal to-do app](https://x.com/thebtjackson/status/1881325871304421532) (about 3,700 likes): the days are full-width bands in steps of gray with heavy condensed uppercase titles. The current day is open and the other days are folded.
- [@_DanielsSharon, a daily planner](https://x.com/_DanielsSharon/status/1947623500379988104) (about 690 likes): a "tasks ladder" where the status circles sit on one vertical line and the task cards sit beside them.
- Also seen: [@heysatya_](https://x.com/heysatya_/status/1892168099937611799) (cards per list, as in our Cards layout) and [@heyXdave](https://x.com/heyXdave/status/1724089989615469012) (a week strip above sections named Morning and Afternoon).

### Prototype (settings sheet, "Layout")

- Card titles are in the text color in every layout. The current slot has no colored title.
- Timeline with Now: the rail has the accent down to a "Now" mark, which is a ring on the rail, one word, and a thin line. The mark sits after the last slot that is due. Above the mark is due. Below it is ahead. The day row is removed in both Timeline layouts.
- Stack: full-width bands in steps of gray with heavy condensed uppercase titles. A slot that is not due yet is folded and shows its circles. A tap on a title opens or folds a band. Limits: the condensed uppercase title exists only for Latin text, and a folded band hides its item names.
- Ladder: the record circles sit on one line at the leading edge and are the nodes of the day. The name and icon sit in a well beside each circle. It has the same "Now" mark.
- The Blocks and Tiles layouts are removed.

## High-like design posts on X (2026-10-11, sixth round)

The owner chose the Cards layout (D015) and asked for an X search for "app design" and similar terms, with the high-like posts as the sample.

### Method

X search, "Top" tab, with a minimum like count. Three queries: the exact phrase "app design" with at least 3,000 likes (5 results, none useful), a group of design phrases with at least 1,200 likes since 2024 (20 results), and posts with media from 12 known interface designers with at least 1,500 likes since mid 2024 (74 results). 15 images were read.

### What the best-liked craft posts share

- [@jsngr, "a new aesthetic"](https://x.com/jsngr/status/1838947760663409070) (about 7,700 likes) and ["glass ui"](https://x.com/jsngr/status/1839661637499843060) (about 4,700): one soft neutral gray surface, with depth only from a soft shadow and an edge line. Controls look like objects to press.
- [@jsngr, "software is art"](https://x.com/jsngr/status/1933542243484184580) (about 3,300): a white sheet with a large radius, large color icons, and wide spacing between rows.
- [@salungprastyo](https://x.com/salungprastyo/status/2009555096418533396) (about 1,800) and [@marcelkargul](https://x.com/marcelkargul/status/1966716765137781080) (about 1,700): white and gray cards, black for the main elements, and color only in small data marks.
- [@adriankuleszo, font sizes for mobile](https://x.com/adriankuleszo/status/1863230079163400430) (about 2,900): few text sizes, with section titles near 16 pt and secondary text near 13 to 14 pt.
- The pastel gradient "glass card" style also has high like counts (for example a healthcare concept with about 2,000). The owner already rejected that style.

This agrees with the decided surface: neutral page, gray wells, and color only in the icons and the record mark.

### Applied in the prototype as "Cards, refined" (for comparison with "Cards")

- The open record circle is a raised white disc with a hairline and a soft shadow, in place of an empty ring. It reads as a button and differs from the Reminders check ring.
- The card title uses the headline size (17 pt semibold) in place of 20 pt, so the item names lead.

## appshot.gallery (2026-10-11, seventh round)

The owner chose the original Cards over the refined variant and pointed to [appshot.gallery](https://www.appshot.gallery/), a gallery of App Store screenshot sets from 821 apps with filters for category, tone, color, and font. The style keyword pages returned 404 on this date. The category, color, and tone pages work.

Sample: 139 apps listed under Health & Fitness, Medical, Productivity, Lifestyle, black, white, and orange. 12 screenshot sets were read closely: Bevel, WaterDuo, Grit, Haptic, Daily Habit Tracker: Checker, Habit Tracker, Alto Pharmacy, Hatch Sleep, Zone, Sincerely, Senda, and Sunlitt.

What the strong sets share:

- The app interface inside the phone is plain. The identity sits around it: one background color or one illustration language, and one caption typeface.
- One idea per screenshot, with a caption of two to five words.
- Sunlitt and Daily Habit Tracker: Checker use one flat block of a bright color with black type. Zone uses black with white type. Alto Pharmacy uses flat pastel fields with hand-drawn illustration and shows a medication list.
- The sets that look generic use a blue or purple gradient with a centered phone.

Effect on Maru: this supports the decided split. The app stays black and white with small color marks, and the accent is the brand color outside the app (icon and store screenshots). Three sketches of store screenshots with the real Today screen are in the chat of 2026-10-11. They are not release material. Store material belongs to a later milestone and is an owner gate.

## Last style pass and the pink question (2026-10-11, eighth round)

The owner asked for one last style pass with ideas from appshot.gallery, asked whether pink can be the color (Apple Health is pink), and decided that the first release and its store screenshots are in English (D017).

Style pass in the prototype (settings sheet, "Style pass"), each option changes one thing on the decided cards:

- Bold type: heavier title, card titles, and names. From Zone, Senda, and Sunlitt, where the type carries the design.
- Day ring: one ring beside the title shows the progress of the day, in place of the row of small circles. From Bevel and RISE. The ring is the brand circle.
- Large icons: the own dosage-form icons at 1.3 times the size. From Alto Pharmacy, Finch, and one year, where the illustration carries the identity.

Pink: the system pink (#FF2D55) is close to the system red (#FF3B30) that iOS uses for destructive actions and errors. In the screenshots the pink record mark reads as red. In a medication app, a red mark on "recorded" can read as a warning. Pink is also the color of Apple Health and of several cycle trackers in the gallery sample (Flo, Mia). The agent recommends orange as the default and pink as one of the user's choices. The owner did not decide yet.

## The header wash of Apple Health (2026-10-11, ninth round)

The owner asked for a study of the background gradient of Apple Health and for the same effect in the prototype.

### Measurement

Apple Health, Summary screen, on an iOS 27 simulator (iPhone 18 Pro, 1206 x 2622 px), light and dark mode. Pixel colors were read at three x positions and every 44 px.

- One color across the full width. No second hue and no left-to-right change.
- Light mode: #FFB08A at the top edge of the screen, fading to the page background #F2F2F7. Dark mode: #933813 at the top, fading to black.
- The fade ends at about 32% of the screen height (about 280 pt). It starts slowly (96% of the color is left at 5% of the height, 90% at 8.5%), falls almost in a straight line from 12% to 27%, and ends with a soft tail.
- The wash belongs to the scroll content. It scrolls away with the content, and the page background shows after it.
- The cards are opaque (white in light mode) and sit on top of the wash. The first card starts where about 40% of the color is left.
- The page is the gray grouped background with white cards.

### In the prototype (`HeaderWash` in `TodayView.swift`)

- The same fade curve as ten gradient stops over 280 pt from the top edge of the screen, in the scroll content, with solid color above it for the pull-down.
- The top color keeps the hue of the user's accent and takes the relative luminance of Apple's two colors (0.54 in light mode, 0.09 in dark mode). So every accent gives a wash of the same strength. A fixed saturation made the pink much heavier than Apple's peach.
- Two prototype switches in the settings sheet: the wash on or off, and the page as gray with white cards (as in Apple Health) or white with gray wells (D013).

The earlier "Glow" option, which the owner rejected, used two blurred circles with a hue shift, translucent cards, and a shadow. This wash has one hue, a measured curve, and opaque cards.
