# User feedback on medication and supplement reminder apps, Chinese sources

Date: 2026-10-11. Scope: comments under Xiaohongshu posts about medication and supplement reminder apps. The goal is to find the problems that Maru should solve.

Summary:

- Users compare every new reminder app with Apple Health Medications and with the phone alarm. An app must show its advantage in one sentence.
- The three most frequent needs are a schedule that is not daily, a reminder that is hard to miss, and a sure answer to "did I take it?".
- Maru already covers the answer to "did I take it?", the free core, and the fast record. Maru does not cover "every other day", and the reminder has no "Taken" action yet.
- Requests for inventory and expiry dates are more frequent than `2026-10-market-scan.md` states. The scope freeze excludes them. The owner must decide if the freeze stays.

## 1. Sources

### What I read

Xiaohongshu was readable. The agent browser profile was already signed in, so there was no login wall and no CAPTCHA. I only read. I did not post, like, follow, or send a message.

| Query | Posts opened | Comment lines read |
|---|---|---|
| 用药提醒APP | 26 | about 480 |
| 补剂 打卡 app | 12 | about 190 |
| 保健品 提醒 | 8 | about 140 (80 of them from two posts that are not relevant) |
| 吃药提醒 app | 6 | about 75 |
| Total | 52 | about 890 |

- 50 of the 52 posts are relevant. Two posts are about the new Health app in iOS 27.2 and say nothing about reminders.
- 9 relevant posts had no comments. Their post text is still evidence, because the author describes a personal problem.
- About 800 comment lines belong to relevant posts. This count includes the replies of the post authors.
- For four long threads, I read the first 40 to 60 comments only. The threads had 68 to 203 loaded comments.
- About 20 posts come from developers who show their own app and ask for feedback.

### What was blocked or not done

- Nothing was blocked on Xiaohongshu.
- I did not run the query "独立开发 用药提醒". The other queries already returned about 20 developer posts, and the time limit came first.
- I did not read App Store China reviews, Zhihu, V2EX, Douban, or Weibo. These were the fallback sources, and the fallback was not necessary.

### How to read the counts

The counts are hand counts of posts and comments that make the same point. They are approximate. A count shows the order of the themes, not a share of all users.

## 2. Themes and verdicts

The themes are in order of frequency. Each theme has what users say, the count, the links, and a verdict for Maru.

### Theme 1. "Why not Apple Health or the alarm?" (about 37 mentions, 14 posts)

What users say:

- Doubt about new apps (about 17 comments). "What is the point of a feature that the system already has?" "I ignore these like the system apps that I never use" (9 likes). "The phone alarm is enough." One developer wrote: "I made one too. I could not beat Apple Health."
- Praise for Apple Health (4 posts with 115 to 2,407 likes, about 8 comments). Many users did not know that the feature exists: "I used an iPhone for years and did not know."
- Complaints about Apple Health (about 20 comments):
  - The path is too deep. "I must open Health, then the section. And there is no alarm, so I set one too."
  - Five users could not find where to change the dose.
  - The schedule made errors. "It often shows one dose too many" (9 likes). Three users saw a 21-day cycle that ended one day late.
  - The cycle option needs a recent iOS.
  - Four users keep a phone alarm next to it. "After some time I ignored the banner, or I cleared all lock-screen messages at once."
  - One user could not add traditional Chinese medicine. One user needs more than one schedule for one item.

Links: [post A](https://www.xiaohongshu.com/explore/695abd92000000001e0145d5), [post B](https://www.xiaohongshu.com/explore/696a60f6000000001a02828c), [post C](https://www.xiaohongshu.com/explore/69cbaaa5000000001f005825), [post D](https://www.xiaohongshu.com/explore/6ab90b5d000000000a02564a), [post E](https://www.xiaohongshu.com/explore/6a72a199000000002701d760), [post F](https://www.xiaohongshu.com/explore/685d4cfd000000001d00f732), [post G](https://www.xiaohongshu.com/explore/693d2785000000001e02cbf8), [post H](https://www.xiaohongshu.com/explore/6a1eaf640000000037035cba).

Verdict: **already solved in the direction, should solve in the message before the first release.**

- D021 already sets the rule: every flow must be simpler than Apple Health. The record takes one tap in Maru and five taps in Health (`2026-10-11-apple-health-gap.md`).
- The store page and the first screen must answer the question in one sentence. Users ask it under almost every developer post.
- Free text names already permit traditional Chinese medicine and any supplement.

### Theme 2. Schedules that are not "every day" (about 18 mentions, 10 posts)

What users say:

- Every other day (5 mentions, all about supplements or simple items). "Every day I do not forget. Every other day I lose the rhythm." One user wrote the date on each capsule blister. One user turned the bottle after each dose.
- Cycles (about 6 mentions). 21 days on and 7 days off for the contraceptive pill. "Where do I set the break period?" (4 likes, on a supplement post). "I take a supplement for some months, then I stop for a time."
- A dose that changes between days (4 mentions). "One day 3 in the morning and 3 at night, the next day 3 and 2. I did not know which one I took yesterday."
- An interval in hours, for example 36 hours (1 post). A time window with the interval from the last dose (1 comment, 2 likes).
- A reminder at wake time, not at a fixed clock time (1 post).

Links: [post A](https://www.xiaohongshu.com/explore/6a13310400000000350225dc), [post B](https://www.xiaohongshu.com/explore/6a9046570000000028005c75), [post C](https://www.xiaohongshu.com/explore/6a4eeccd0000000008030347), [post D](https://www.xiaohongshu.com/explore/6a8904390000000016028a05), [post E](https://www.xiaohongshu.com/explore/6a745b890000000021020431), [post F](https://www.xiaohongshu.com/explore/69e21105000000001a0243fc), [post G](https://www.xiaohongshu.com/explore/69991b4e000000000c036dab), [post H](https://www.xiaohongshu.com/explore/695abd92000000001e0145d5).

Verdict: **split.**

- Every N days: **should solve, as the first schedule addition.** It is the most frequent request from supplement users, who are Maru's main users. Maru has daily and weekday schedules only. A repeating system notification cannot repeat every N days, so the engine needs one-time requests (spec §8.2, §8.4). A device prototype must come first. If the prototype fails, do it later.
- Cycles such as 21 on and 7 off: **should solve later.** The roadmap already lists it with the trigger "repeated requests". This study counts as such requests.
- A dose that changes between days: **should solve later.** Spec §1 excludes step doses from V1.
- Every X hours and wake-time reminders: **will not solve in V1.** Spec §1 and §8.5 exclude every X hours. An app cannot detect the unlock of the iPhone.

### Theme 3. A reminder that is hard to miss, and that arrives (about 18 mentions, 9 posts)

What users say:

- Users want an alarm, not a banner. The top question under the largest post (17 likes): "Does it ring like an alarm?" Another: "A medication reminder must be strong. If not, I tick the notification and then forget."
- Users like a reminder that repeats until they confirm. Three developers sell this as the main advantage. Users praise the second reminder of Apple Health after 30 minutes.
- Focus mode and silent mode hide reminders. One developer advertises Time Sensitive notifications for this.
- "If the system stops the app and the reminder does not come, does the user sue you?" (6 likes).
- Four Android users reported no reminder after they set all permissions. This problem belongs to Android battery rules.
- One user wants the opposite: no sound in a meeting.

Links: [post A](https://www.xiaohongshu.com/explore/695abd92000000001e0145d5), [post B](https://www.xiaohongshu.com/explore/691485ad000000000503b6d4), [post C](https://www.xiaohongshu.com/explore/6a72a199000000002701d760), [post D](https://www.xiaohongshu.com/explore/6a60617f000000001c011d99), [post E](https://www.xiaohongshu.com/explore/6a72f2fc000000003301e248), [post F](https://www.xiaohongshu.com/explore/6aa4105d000000002a006bc5), [post G](https://www.xiaohongshu.com/explore/685d4cfd000000001d00f732).

Verdict: **partly solved, should complete before the first release.**

- Solved: local repeating notifications do not depend on a server or on a background refresh (spec §8.1). The optional follow-up reminder comes after 15, 30, or 60 minutes if an item is still open (D021).
- Before the first release: Time Sensitive reminders. `docs/status.md` already lists this work.
- Later: an alarm sound that passes silent mode. This possibly needs AlarmKit or the Critical Alerts entitlement. I did not check the conditions. Spec §4 excludes a reminder that repeats without limit.
- Do not promise delivery in each case. Spec §8.1 already forbids this claim.

### Theme 4. "Did I take it or not?" (about 16 mentions, 13 posts)

What users say:

- This is the reason that most developers give for their app. "I stand at the pill box and cannot remember if I took the morning one. If I take it, I fear a double dose. If I do not, I fear a missed dose."
- "I do not know if it is recorded or not" (about Apple Health).
- A family version: "Did you take the medicine today?" "I think so, I do not remember."
- One product manager post puts it plainly: the driver is not the record, it is to remove the doubt.
- One app copies a blister pack on the screen, so the user sees the missing pill (55 likes). Critics said that many pills then need many taps.

Links: [post A](https://www.xiaohongshu.com/explore/6a72f2fc000000003301e248), [post B](https://www.xiaohongshu.com/explore/6a72a199000000002701d760), [post C](https://www.xiaohongshu.com/explore/6a93e6fa0000000021030f78), [post D](https://www.xiaohongshu.com/explore/6aa7c86e000000001001cb87), [post E](https://www.xiaohongshu.com/explore/6a520d2f0000000008025556), [post F](https://www.xiaohongshu.com/explore/69f57ea6000000001a02ec7c), [post G](https://www.xiaohongshu.com/explore/6a7e6861000000000801135f), [post H](https://www.xiaohongshu.com/explore/6a0439d00000000007012d49).

Verdict: **already solved.**

- Today keeps a recorded row with the time of the record (spec §3 P01).
- Maru shows "recorded" only after the local transaction commits (spec §7.2). This answers "is it recorded or not".
- "Record All" records a whole time slot with one tap (D021). This answers the criticism of one tap for each pill.
- History separates "no record" from "skipped" (spec §4).

### Theme 5. Paywalls, prices, accounts, and privacy (about 15 mentions, 9 posts)

What users say:

- "I downloaded three apps and each one needs a paid upgrade" (2 likes). "Is there one with free check-ins and no limit?"
- A limit of one or two free items causes complaints in three apps. "I can add only one item. Must I pay for the second?"
- "Too expensive." "Can the lifetime price go lower?" "Does it need a membership? The old people at home cannot operate that."
- One developer gave about 3,000 lifetime licenses in a free period of 48 hours. Free is a strong pull.
- Developers use "no account, no ads, data stays on the phone" as the first sales point. One user asked if the label scan runs on the device.

Links: [post A](https://www.xiaohongshu.com/explore/6a4eeccd0000000008030347), [post B](https://www.xiaohongshu.com/explore/691485ad000000000503b6d4), [post C](https://www.xiaohongshu.com/explore/6a8904390000000016028a05), [post D](https://www.xiaohongshu.com/explore/6a159200000000003502e0ef), [post E](https://www.xiaohongshu.com/explore/6a752b7c000000000600404f), [post F](https://www.xiaohongshu.com/explore/6abb260f000000001403aa6a), [post G](https://www.xiaohongshu.com/explore/696314f10000000022031886).

Verdict: **already solved.** The core is free with no ads, no account, and no item limit, and data stays on the device (spec §1). Say "no limit on the number of items" on the store page, because that limit is the most frequent paywall complaint.

### Theme 6. Android and HarmonyOS (about 15 mentions, 9 posts)

What users say: "When does Android come?" "I cannot find it on Huawei." "Independent developers never think of Android." Two users asked for iOS 17 support when an app needed iOS 18.

Links: [post A](https://www.xiaohongshu.com/explore/6aaa74a7000000002803a8b1), [post B](https://www.xiaohongshu.com/explore/6a93e6fa0000000021030f78), [post C](https://www.xiaohongshu.com/explore/691485ad000000000503b6d4), [post D](https://www.xiaohongshu.com/explore/6aa7c86e000000001001cb87), [post E](https://www.xiaohongshu.com/explore/6a745b890000000021020431).

Verdict: **will not solve** for Android and HarmonyOS. Maru is a native iPhone app. **Already solved** for old iOS versions: the spec targets iOS 17 and later.

### Theme 7. The record costs more effort than the habit (about 14 mentions, 8 posts)

What users say:

- "The record of a habit is now more work than the habit" (post with 102 likes).
- Users praise a Home Screen widget that records with one tap (3 posts about one competitor). "The widget is on my home page. One tap and it is recorded."
- Three users asked one Android developer for a widget.
- Users want buttons on the notification: taken, later, skip. Two developers list this as a feature.
- "Buy an NFC sticker and touch it after the dose" (15 likes).
- Counter view: "I record because I forget if I took it. The full heatmap also gives a sense of achievement" (14 likes).

Links: [post A](https://www.xiaohongshu.com/explore/6ab799370000000002029feb), [post B](https://www.xiaohongshu.com/explore/6a1eaf640000000037035cba), [post C](https://www.xiaohongshu.com/explore/6a72f2fc000000003301e248), [post D](https://www.xiaohongshu.com/explore/6aa4105d000000002a006bc5), [post E](https://www.xiaohongshu.com/explore/693d2785000000001e02cbf8).

Verdict: **partly solved, should complete before the first release.**

- Solved in the app: one tap on the circle, and "Record All".
- Before the first release: the "Taken" action on a reminder, and a widget that records. Both are in `docs/status.md`. This study supports that order.
- Later: Siri and NFC through App Intents. One developer and one thread asked for them.

### Theme 8. Inventory, refill, and expiry date (about 13 mentions, 8 posts)

What users say:

- "I take more than 20 pills a day. The hard part is the stock. I run out with no warning, and the effects of a sudden stop are bad" (2 likes).
- "Why not add inventory?" "Record the expiry date and the amount that remains" (2 likes). "Show how long the stock lasts at my dose."
- "I throw the package away, then I do not know the expiry date."
- Five developers shipped or planned inventory after such requests.

Links: [post A](https://www.xiaohongshu.com/explore/6a1c2a1200000000380342a7), [post B](https://www.xiaohongshu.com/explore/6aaa74a7000000002803a8b1), [post C](https://www.xiaohongshu.com/explore/6a72a199000000002701d760), [post D](https://www.xiaohongshu.com/explore/693d2785000000001e02cbf8), [post E](https://www.xiaohongshu.com/explore/6aa4105d000000002a006bc5).

Verdict: **will not solve.** Inventory and refill reminders are on the "明确不做" list (spec §1).

Note for the owner: `2026-10-market-scan.md` says that inventory has weak demand. This sample does not agree. Most requests come from users with long-term prescription medication, not from supplement users. If Maru keeps its focus on supplements, the freeze is still correct.

### Theme 9. Family and old people (about 12 mentions, 8 posts)

What users say:

- "I wanted to separate the medication of my grandfather and my grandmother, and I could not." Two users asked for one medicine box for each family member.
- Children want to see from a distance if a parent took the dose. Four developers offer this.
- "Old people have trouble with any phone." A post that asked for a hardware pill dispenser got 424 comments. The top answers: "An alarm and a pet feeder" (444 likes).
- One developer added a scale for the whole interface, 80% to 130%, for parents.

Links: [post A](https://www.xiaohongshu.com/explore/6aaa74a7000000002803a8b1), [post B](https://www.xiaohongshu.com/explore/6a8904390000000016028a05), [post C](https://www.xiaohongshu.com/explore/6a520d2f0000000008025556), [post D](https://www.xiaohongshu.com/explore/6a159200000000003502e0ef), [post E](https://www.xiaohongshu.com/explore/6964d8bd000000001a02fa09).

Verdict: **will not solve.** Remote family supervision is on the "明确不做" list and needs a server. Profiles are excluded in spec §1. Large text is **already in scope** through Dynamic Type, but `docs/status.md` says that the largest sizes need a device check.

### Theme 10. Notes, records for the doctor, and medication information (about 10 mentions, 7 posts)

What users say:

- "Add a note after each dose, for example a side effect."
- "My mother asks me to look through the records before each hospital visit." Developers offer a CSV export for the doctor.
- "Add a place for test reports and medical records" (2 users).
- "Add a lookup of the package leaflet." One user suggested a photo of the leaflet. Other users warned: "If the data is wrong and a user is harmed, who is responsible?"
- "The old course date cannot be entered. I need the start date from the doctor for my files."

Links: [post A](https://www.xiaohongshu.com/explore/6aa4105d000000002a006bc5), [post B](https://www.xiaohongshu.com/explore/69f57ea6000000001a02ec7c), [post C](https://www.xiaohongshu.com/explore/6a72a199000000002701d760), [post D](https://www.xiaohongshu.com/explore/6aaa74a7000000002803a8b1), [post E](https://www.xiaohongshu.com/explore/685d4cfd000000001d00f732), [post F](https://www.xiaohongshu.com/explore/6a916902000000001803de07).

Verdict: **split.**

- A note for each item: **already solved** (D006).
- A list or history that a doctor can read: **should solve later**, with the export work. The Apple Health gap study already proposes a plain text share.
- A note for each record: **should solve later**, only if testers ask.
- Leaflet lookup, side-effect data, and report storage: **will not solve.** Maru does not give medical information (spec §0). The liability warnings in the comments support this.

### Theme 11. Trust in a new app: rules and "AI look" (about 12 mentions, 7 posts)

What users say:

- "An individual cannot publish a medical app, how did you solve the qualification?" (asked 3 times). "The domestic version needs many procedures."
- "I am tired of this UI look." "One look and it is AI." "Now I feel sick when I see an app with an AI taste." "You all make the to-do app in new shapes" (7 likes).
- "Do people still download small apps?"
- Developers answered that an app with no treatment advice passes App Review as a tool.

Links: [post A](https://www.xiaohongshu.com/explore/6ab90b5d000000000a02564a), [post B](https://www.xiaohongshu.com/explore/6a1c2a1200000000380342a7), [post C](https://www.xiaohongshu.com/explore/6ab799370000000002029feb), [post D](https://www.xiaohongshu.com/explore/6814731e000000000e007ad1), [post E](https://www.xiaohongshu.com/explore/6a93e6fa0000000021030f78).

Verdict: **should solve later, before a release in China.** The first release is in English (D017). Check the rules of the China storefront before a zh-Hans release. I did not check them. Native system controls (D026) and no medical advice (spec §0) already reduce both risks.

### Theme 12. Entry of an item: scan, forms, and units (about 8 mentions, 4 posts)

What users say:

- "If the scan reads it wrong and the user takes the wrong medicine, the fine can ruin you." "Add a confirmation step."
- "The forms are too few: no capsule, no solution. Let the user type a custom one."
- "Let me enter 1.5 tablets, half a tablet, or a quarter."
- "What if I do not know the unit?"

Links: [post A](https://www.xiaohongshu.com/explore/6aaa74a7000000002803a8b1), [post B](https://www.xiaohongshu.com/explore/696a60f6000000001a02828c), [post C](https://www.xiaohongshu.com/explore/69d25d10000000001a0290e8).

Verdict: **already solved in the spec.** The amount is optional, and a scan result needs a check by the user (spec §2.1). Acceptance T28 covers decimals and units. I did not test the amount field in the app for "0.5" or "1/4".

### Theme 13. Supplement history: when I started, when I stopped (about 6 mentions, 5 posts)

What users say:

- "I want to see when I started, how long I took it, and when I stopped. Then I know if a vitamin works."
- "The monthly heatmap of my intake gives a sense of achievement."
- "On the holiday my supplements went out of order."
- One user dislikes an app that posts a status after each check-in.

Links: [post A](https://www.xiaohongshu.com/explore/696314f10000000022031886), [post B](https://www.xiaohongshu.com/explore/69d25d10000000001a0290e8), [post C](https://www.xiaohongshu.com/explore/6ac77f5500000000180298b9), [post D](https://www.xiaohongshu.com/explore/6ab799370000000002029feb).

Verdict: **should solve later (milestone B).** The passive heatmap is already planned (D006). A "taken since" date and the archive date on the item detail are small additions. No streaks and no social posts stay correct (spec §1).

## 3. Recommendations

In order of value for the effort:

1. **Write the answer to "why not Apple Health?" for the store page and the first screen.** No code. Use three facts: one tap to record, no limit on items, no account. Themes 1 and 5.
2. **Finish the "Taken" action and Time Sensitive reminders before the first release.** Both are in `docs/status.md`. They close the two most frequent complaints about weak reminders and slow records. Themes 3 and 7.
3. **Ship the widget that records with one tap.** It is the feature that users praise most in a competitor. It is in `docs/status.md`. Theme 7.
4. **Make a device prototype of "every N days".** It is the most frequent schedule request from supplement users. It needs a spec change and one-time requests in the engine. Theme 2.
5. **Add a plain text share of the list and the history, and a "taken since" date.** Small work with the export of milestone B. Themes 10 and 13.

One decision for the owner: keep or change the inventory freeze (theme 8).

## 4. Limits of this study

- The sample is one platform and one day. Xiaohongshu users are mostly young and mostly women. Old patients do not write there. Their children do.
- Search results are personal to the signed-in profile and change with time. A second search can show other posts.
- Many comments come from developers who promote their own app. I excluded these from the counts when I saw them, but some possibly remain.
- Several "user" posts about one habit app use the same hashtag and style. They are possibly paid posts. I used them only as evidence for the widget.
- The counts are hand counts. For four long threads I read only the first 40 to 60 comments.
- Most posts are about prescription medication. Only about 12 posts are about supplements, which is Maru's main use.
- A share of the comments is about Android apps. Their delivery problems do not apply to iOS.
- Quotes are my translations, and I shortened them. I removed usernames.
- The links have no access token. Xiaohongshu possibly asks for a sign-in or shows "not available" for a direct link. Search for the post ID in that case.
- I did not test any of the apps. Statements about their features come from their authors.
- I did not check China App Store rules, AlarmKit, or the Critical Alerts entitlement.
