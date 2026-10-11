# Apple Health Medications, hands-on test, 2026-10-11

The owner asked what Maru is for when Apple Health already has Medications. This note records one full run of that feature and the answer given to the owner. The run was on an iOS 27.0 simulator (iPhone 18 Pro), with manual entry. It is one run on a simulator. Notification delivery, the Apple Watch app, and the drug search of some regions were not tested.

## The flow

Path: Health, Browse, Medications. The feature has no icon on the Home Screen.

Adding one item ("Vitamin D3") took seven screens:

1. Name, typed by hand.
2. Type: capsule, tablet, liquid, topical, and about twelve more forms.
3. Strength: a number and one of mg, mcg, g, mL, %. No IU. The step can be skipped.
4. Schedule: "Every Day" by default. The time picker starts at the current minute (02:05 in the test). The amount starts at "1 capsule". Start date today, no end date.
5. Shape: about thirty shapes, including a jar and a measurement cup. The step can be skipped.
6. Colors: left side, right side, and background, twelve colors each.
7. Review: schedule, optional display name, optional notes.

Logging from inside the app: the Medications screen has a "Log" group for each clock time. A tap on the plus opens a sheet with "Log All as Taken", and for each item the amount, the time, "Skipped", and "Taken". Then "Done". After that the screen says "All Scheduled Medications Logged Today" and lists the logged time.

Other things on the screen: a week strip, an offer for follow-up reminders and Critical Alerts, as-needed medications, and the list of medications with their pictures.

## What it does that Maru's V1 does not

- Follow-up reminders and Critical Alerts.
- Schedules beyond weekly rules (the frequency choices were not opened in this run).
- Shapes and colors for each item.
- It is on every iPhone, with Apple's trust, iCloud sync, and an Apple Watch app.
- Free, with no account and no ads. This is the same promise that Maru's positioning used against Medisafe.

## Where it is weak for Maru's user

- Seven screens to add one supplement. Maru's spec asks for one edit flow.
- Two defaults that Maru's spec forbids (§2.1): the amount starts at 1, and the time starts at the current minute.
- No IU unit, which many vitamin labels use.
- It is three levels inside Health. Logging in the app is: open Health, Browse, Medications, plus, Taken, Done. Maru's Today screen is the first screen, and a record is one tap.
- It groups by clock time and is framed as medication. The owner did not want clock times on Today.
- No place for "with food" other than free notes on the detail screen.

## Answer given to the owner

Maru has no capability that Apple lacks. "Free, private, no account" is not a reason for Maru to exist, because Apple offers the same. The only honest reason is experience: a dedicated, supplement-first Today screen that opens first and records in one tap, in the way that Things exists next to Reminders. Third-party reminder apps still have many users after Apple shipped this feature in 2022 (see `2026-10-market-scan.md`), which shows that the built-in feature did not end the category. It does not show that a new free app can win users.

Options put to the owner:

1. Continue milestone A as planned, with the positioning narrowed to "supplements and simple routines, at a glance, one tap". Recommended, because the owner also wants the app for personal use and the remaining work is about one week.
2. Study the HealthKit Medications API before milestone B. Since iOS 26, an app can read the user's medications and dose events ([WWDC25 session 321](https://developer.apple.com/videos/play/wwdc2025/321/), [HKUserAnnotatedMedication](https://developer.apple.com/documentation/healthkit/hkuserannotatedmedication)). Whether an app can write dose events is not confirmed, and one developer reports a permission failure ([GitHub issue](https://github.com/eyeMNaughtReal/GutCheck/issues/435)). If writing works, Maru could become a faster front end for the data in Health.
3. Stop, if the goal is a business. A free app with only a supporter purchase, next to a free built-in feature and large incumbents, has a weak business case.
