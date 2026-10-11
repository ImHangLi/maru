# HealthKit Medications API, 2026-10-11

The question (D021, before milestone B): what can a third-party app do with the HealthKit Medications API? Most important: can Maru write "taken" or "skipped" into Apple Health? The answer is no. An app can read medications and dose events that the user selects. It cannot write dose events, create medications, or read schedule times. Apple says that iOS 27 does not change the API.

Each claim has a tag. **Verified** means that a primary source says it, and the link follows. **Inferred** means a conclusion from the sources, which no test confirmed. No code ran on a device for this note.

## Sources

- [WWDC25 session 321, "Meet the HealthKit Medications API"](https://developer.apple.com/videos/play/wwdc2025/321/).
- Apple sample code: [Logging symptoms associated with a medication](https://developer.apple.com/documentation/healthkit/logging-symptoms-associated-with-a-medication). The sample was downloaded and searched for this note.
- Apple docs: [HKUserAnnotatedMedication](https://developer.apple.com/documentation/healthkit/hkuserannotatedmedication), [HKMedicationDoseEvent](https://developer.apple.com/documentation/healthkit/hkmedicationdoseevent), [requestPerObjectReadAuthorization(for:predicate:completion:)](https://developer.apple.com/documentation/healthkit/hkhealthstore/requestperobjectreadauthorization(for:predicate:completion:)).
- The iOS 27.0 SDK headers in Xcode 27.0 (27A266a): `HKMedicationDoseEvent.h`, `HKUserAnnotatedMedication.h`, `HKMedicationConcept.h`, `HKUserAnnotatedMedicationQuery.h`, and the HealthKit Swift interface.
- Apple Developer Forums: [thread 789821](https://developer.apple.com/forums/thread/789821) (June 2025), [thread 803954](https://developer.apple.com/forums/thread/803954) (October 2025), [thread 833045](https://developer.apple.com/forums/thread/833045) (June 2026).
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), 2.5.1 and 5.1.3.
- [GutCheck issue #435](https://github.com/eyeMNaughtReal/GutCheck/issues/435) and the code on its `feat/healthkit-medications-read` branch.

## 1. Reading medications and doses

- An app reads medications with per-object authorization. This is the same mechanism as for vision prescriptions. The system shows a sheet, and the user turns on each medication that the app can see. **Verified** (session 321: "My app will only see medications for which someone has granted authorization").
- When the user allows a medication, the app can also read all dose events of that medication. No separate request for doses is necessary. **Verified** (session 321).
- When the user adds a medication later, the Health app shows a switch to share it with the app. The app needs no extra code for this. **Verified** (session 321).
- The calls are `requestPerObjectReadAuthorization(for: .userAnnotatedMedicationType(), predicate:)` or the SwiftUI modifier `.healthDataAccessRequest(store:objectType:)`. Apple's sample uses the SwiftUI modifier. **Verified** (sample code).
- A query uses `HKUserAnnotatedMedicationQueryDescriptor` for medications and an ordinary sample query on `medicationDoseEventType()` for doses. **Verified** (SDK, sample code).
- Setup: the HealthKit capability and the `NSHealthShareUsageDescription` text. The sample page says only "set the developer team". The sample's entitlements file also lists `com.apple.developer.healthkit.access = health-records`. No Apple document says that medications need this value. **Verified** (sample code). Whether it is necessary is **unknown**. A device test must answer this.

### The GutCheck failure

GutCheck crashed with `NSInvalidArgumentException: Authorization to read the following types is disallowed: HKMedicationDoseEventTypeIdentifierMedicationDoseEvent, HKDataTypeUserAnnotatedMedicationConcept`. The author guessed that a gated entitlement was missing.

- GutCheck passes both medication types to `requestAuthorization(toShare: [], read: readTypes)` (`HealthKitMedicationService.swift`, line 233 on the branch). **Verified** (GutCheck code).
- Apple's docs say: "Using the `requestAuthorization(toShare:read:)` method to request read access to any data types that require per-object authorization fails with an `errorInvalidArgument` error." **Verified** (Apple docs).
- The issue says that `HKHealthStore` has no medication-related authorization method. That is not correct. `requestPerObjectReadAuthorization` exists, and Apple's sample uses the per-object flow. **Verified.**
- Conclusion: the failure is a misuse of the API, not an Apple limitation or an Apple bug. **Inferred**, with strong support. Their `health-records` test also used the wrong call, so it does not show whether that entitlement matters.

## 2. Writing doses, medications, or schedules

- Writing is not possible. An Apple DTS engineer said twice that the Medications API is read-only: "you can't write a dose event to the HealthKit store" (thread 789821), and "Medication data is read-only in HealthKit" (thread 803954). **Verified.**
- The SDK agrees. `HKMedicationDoseEvent`, `HKUserAnnotatedMedication`, and `HKMedicationConcept` have `init` marked unavailable and no public initializer. All properties are read-only. An app cannot build an object to save. **Verified** (iOS 27.0 SDK headers).
- The log statuses (`taken`, `skipped`, `snoozed`, `notInteracted`, `notificationNotSent`, `notLogged`) are values "the system assigns". **Verified** (SDK header comments).
- A request for share (write) access to `medicationDoseEventType()` crashed the app in thread 803954. **Verified** (forum report).
- An app can write related data, such as symptom samples, and show them next to a medication. Apple's sample does this. **Verified** (sample code).
- iOS 27: an Apple engineer said in June 2026, "there are no updates for the Medications API in iOS 27". The iOS 27.0 SDK has no new medication symbols. **Verified** (thread 833045, SDK).

## 3. Reading the schedule

- An app cannot read the schedule times. `HKUserAnnotatedMedication` exposes only `nickname`, `isArchived`, `hasSchedule` (a Boolean), and `medication`. **Verified** (SDK, docs).
- `HKMedicationDoseEvent` has `scheduledDate`, `scheduledDoseQuantity`, `scheduleType` (`schedule` or `asNeeded`), `logStatus`, `doseQuantity`, and `unit`. **Verified** (SDK).
- The system creates a `notInteracted` event for "an untouched reminder slot". **Verified** (SDK header comment). The header does not say when the system writes it. It possibly writes it only after the slot passes, so Maru cannot use it to know today's coming slots. **Inferred.**
- Maru could guess today's times from the `scheduledDate` values of past days. The guess fails when the user changes the schedule, and it is a silent conversion of the schedule, which spec §2 forbids. **Inferred.**
- The API gives no shape, color, or notes of a medication. `HKMedicationConcept` gives a display name, a general form, and codings such as RxNorm. **Verified** (SDK).

## 4. Gains and risks for Maru

Gains:

- Maru could show, read-only, what the user logged in Apple Health, for example "Metformin, taken 08:10, in Apple Health". **Inferred.**
- Maru could offer an import of names from Apple Health into its own list. The user still sets the dose and the time in Maru. **Inferred.**

Risks and costs:

- Two sources of truth. Maru cannot mark an Apple medication as taken, so the user must log it in Health. That conflicts with the one-tap promise of the Today screen. **Inferred.**
- Two reminders. If the user keeps a schedule in Health and in Maru, both send notifications. **Inferred.**
- Privacy: the data stays on the device, so spec §10 still holds. Maru must never send HealthKit data to analytics, logs, or crash reports, and must not store it in iCloud (guideline 5.1.3(ii)). **Verified** (guidelines). Maru's privacy label and policy must name the health data that it reads (5.1.3(i)). **Verified** (guidelines).
- App Review: the app description must state the HealthKit integration (2.5.1). **Verified** (guidelines). If the `health-records` entitlement is necessary, Apple warns that reviewers can reject apps that declare it without a use of clinical records. **Inferred** from the GutCheck report. A device test must check this first.
- Platform: the API needs iOS 26 or later. **Verified** (SDK availability).

## Recommendation for Maru

1. **Do not integrate in V1.** Recommended. The cost is zero. The main hope, Maru as a faster front end that writes to Health, is not possible. Keep the positioning from D021: a supplement-first Today screen that records in one tap. Look at the API again after WWDC27.
2. **Optional read-only import in milestone B or later.** Maru reads the names of the medications that the user allows and copies them into its own list. The user then sets dose and time in Maru. The estimated cost is two to three days: authorization, one import screen, a privacy text, and one device test of the entitlement question. Risk: the `health-records` entitlement, if necessary, can cause App Review questions.
3. **Read-only "logged in Health" rows on Today.** Maru shows the dose events of the current day next to its own items. The estimated cost is about one week, and the design cost is higher: Maru cannot show coming slots or record a dose, so the rows can only show the past. This option conflicts with "simpler than Apple Health". Not recommended.
