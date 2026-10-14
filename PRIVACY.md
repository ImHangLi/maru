# Privacy

Maru keeps your health data on your iPhone or iPad. Each device has its own data, and Maru does not sync between devices. This file describes the app in this repository as it is today.

## What Maru stores

- Your items, schedules, notes, and records.
- Your settings.
- A draft of an item that you add or edit. Maru deletes the draft when you save or cancel.
- The photo of an item, if you add one. See "Item photos".

Maru asks iOS to encrypt the database file. After a restart of your device, nothing can read the file until you unlock the device one time. After that, Maru can read and write the file while the device is locked, so the "Taken" action of a reminder works while the device is locked. When Maru cannot open your records, it records nothing and asks you to unlock.

## What Maru does not do

- It has no server and no account. Its only network requests are the usage statistics below, when they are on, and a request to the App Store for product information when you open Settings. That request carries only product identifiers and none of your item data. Apple's App Store privacy policy applies to it.
- It contains no advertising or crash-reporting code.
- It does not read your contacts, your location, or the advertising identifier.
- It does not read from or write to Apple Health.

## Usage statistics

Some versions of Maru can send usage statistics to PostHog. A version that cannot has no switch and sends nothing. This section applies to a version that can.

- Where it is on: outside the EU, the EEA, the UK, Switzerland, and South Korea, the statistics are on by default. Maru shows no notice and no question about them. The switch "Share Usage Statistics" in Settings turns them off.
- Where it is off: in the EU, the EEA, the UK, Switzerland, and South Korea, the statistics stay off until you turn them on. Maru asks once, after you save an item, and Settings has the same switch.
- How Maru picks the rule: it uses the region setting of your device, not your place. If that setting is missing, Maru uses the opt-in rule. A traveler, or a device with another region setting, gets the rule of that setting.
- What Maru sends: only these events and fields. Each value is a fixed word, a yes-or-no flag, or a range such as "2_3". None is a name, an amount, or a time of day.
  - `setup_step`: a step on the add or edit screen. `step` is one of `editor_opened`, `item_saved`, `editor_closed` (closed with no save), `scan_opened`, `scan_used`, or `scan_blocked` (the camera is off for Maru). `mode` is `new`, `edit`, or `replace`. A save also has:
    - `has_reminder`: yes if the plan has a reminder time. Not the kind of plan, the days, the times, or how many times.
    - `has_alarm`, `has_follow_up`: yes if you turned on the alarm, or "Remind Again", for the item. Not the number of reminders or the time between them.
    - `has_amount`, `has_note`, `has_photo`: yes or no. Not the amount, the note, or the photo.
    - `name_source`, for a new item: `typed`, `suggestion`, or `scan`. Not the name.
    - `used_completion`: yes if you tapped a suggested amount, time, or note.
    - `first_item`: yes if it is the first item on the device.
    - `duration`: the time on the screen, as `under_30s`, `30s_to_2m`, `2m_to_5m`, or `over_5m`.
    - A close with no save has `had_changes` (yes or no) and `duration`.
  - `daily_usage_summary`: one summary for each day that you used the app. Maru sends it the next time that you open the app on a later day, never from the background. It has `day_index`, the day number since the statistics started, and yes-or-no flags for that day: `used_record` (recorded a dose), `used_history` (opened History), `used_notification` (opened the app from a reminder or used a reminder action), `used_widget` (used a widget), `used_reminder_action` (recorded from the "Taken" action of a reminder), `used_skip`, `used_undo`, `used_correction` (changed an earlier record), `used_my_items`, `used_item_detail`, and `used_settings`. It also has `app_opens`, how often the app came to the front that day, as `0`, `1`, `2_3`, `4_6`, or `7_plus`, `active_items`, the number of your active items, as `0`, `1`, `2_3`, `4_6`, or `7_plus`, and `has_widget`, yes if a Maru widget is on your Home Screen. It has no time and no count of doses.
  - `core_error`: `operation`, the operation that failed: `save`, `read`, `schedule` (setting a reminder), or `scan` (the label scanner). `code`, one of eight fixed codes: `locked`, `corrupt`, `newer_schema`, `migration_failed`, `failed`, `too_many`, `not_set`, or `not_confirmed`.
  - `notification_permission`: `state`, the notification permission: `not_asked`, `allowed`, `denied`, or `quiet`. `previous`, the permission that Maru sent before, or `unknown`. Maru sends it once when the statistics start, with `previous` = `unknown`, and after that only when the permission changes.
  - `setting_changed`: a new value of one setting: `show_names` (yes or no), or `app_color` (one of the eight color names).
  - `data_action`: `action`, one of `export`, `backup`, or `restore`, and `result`, one of `done`, `failed`, `cancelled`, `invalid_file`, `newer_file`, or `not_confirmed`. Not the file or its content.
  - `feedback_entry`: `entry` = `settings`, when you tap "Send Feedback".
- What Maru never sends: item names, doses, amounts, intake times, reminder times, item IDs, notes, photos, or the text of a message. It sends no event at the moment of a record, no time of a single dose, and no count of doses.
- Each event also has these fields: `app_version`, `ios_major` (the major version of iOS), `distinct_id` (a random install ID), `app_language` (`en`, `zh-Hans`, `ja`, `ko`, `es`, `de`, or `other`), `device` (`iphone`, `ipad`, or `other`), `region` (the region setting of your device as a two-letter code such as AU, when it has one), and `$process_person_profile` and `$geoip_disable`, which ask PostHog for no profile and no location. Each event also has the time when the app made it, to the millisecond. The region is a setting, not your place. Maru does not use your location. Apple's privacy label lists the install ID as a device ID. The ID is not linked to your name, your email, or an item. It is a pseudonym, not proof of anonymity. The server sees your IP address as any server does. Maru asks PostHog not to build a person profile and not to look up a location. PostHog keeps the data on its servers in the United States.
- No session recording, no screen capture, and no automatic capture of taps or screens.
- If you turn the switch off, Maru stops sending, deletes the events that wait, deletes the install ID, and deletes the local usage data, also a daily summary that waits. A new ID is made if you turn it on again. Maru cannot delete data that PostHog already holds. The maintainer cannot find your data without the install ID, and Maru does not show the ID today, so a request to delete earlier data is not possible yet.
- Events wait in memory, at most 100, for at most 3 days. If the network fails, Maru drops them after that limit and tries again no more than once every 5 minutes, and only when you use the app. Your records do not depend on it.

## Camera

Maru uses the camera only when you scan a label or take a photo of an item. Your device reads the text of the label, and Maru keeps only the name that you choose. A label scan saves no photo, and it sends no image and no text. With usage statistics on, Maru sends only the steps of the scan (see `setup_step`). iOS asks for the camera the first time that you tap "Scan Label" or "Take Photo".

## Item photos

An item can have a photo that you take or choose on the add or edit screen. It is optional.

- Maru makes a small copy of the photo, at most 512 pixels on the longest side, and keeps only that copy. It does not keep the original photo. The copy has no location and no camera data (EXIF).
- Maru can remove the background of the photo on your device. It uses Apple's Vision framework, and nothing leaves the device.
- The photo files are in the Maru data folder of your device, next to the database. iOS encrypts them while your device is locked. Maru deletes a photo file when you remove the photo or delete the item.
- "Take Photo" does not save to your photo library. "Choose Photo" uses the system photo picker, so Maru sees only the photo that you pick.
- The Maru backup file (see below) does not contain the photos. After a restore on another device, items show the form icon, and you can add the photos again.
- The record export has no photos.

The name suggestions on the add screen come from a list inside the app. The name suggestions are a typing aid. They are not medical advice.

## Feedback

Settings has a "Send Feedback" button. It opens a web form of Tally (tally.so) in the system browser. Nothing happens before you tap it, and Maru sends no data of the app to the form. What you write there, and your email address if you give one, goes to Tally and to the maintainer. Tally's privacy policy applies to that page, and the page can use its own cookies. Please leave health details out of a message.

## Notifications

Reminders are local notifications. iOS schedules and shows them on your device, and they do not go through a server. To hide reminder text on the Lock Screen, turn off previews in the iOS notification settings.

An alarm (iOS 26 and later, when you turn on "Alarm" for an item) also runs on your device, through Apple's AlarmKit, and does not go through a server. It shows the item names on the Lock Screen, unless you turn off "Show Names in Reminders" in Settings.

## Export and backup files

Settings has "Export Records", "Back Up", and "Restore from Backup…". Maru makes a file only when you tap one of the first two.

- The record export is a CSV file. It has your item names, your amounts, and your records.
- The backup is a full copy of the database and of two settings: the app color and the names in reminders. The database holds the "Remind Again" and alarm choices of each item. The backup does not include the item photos.
- The files are not encrypted. Anyone with a file can read it.
- Maru sends no file by itself. The share sheet of iOS opens, and you choose where the file goes. The app or the service that you choose then handles the file.
- Maru keeps the file in a protected temporary folder and removes it when the share sheet closes.
- A restore reads the backup file that you pick. It replaces the data of Maru on the device, after you confirm. The backup file stays where you keep it.

`docs/export-format.md` describes both files.

## iPhone and iPad backups

Your iPhone or iPad backup, in iCloud or on a computer, can include Maru's data and the item photos, the same as other app data. Apple's backup settings control this.

## Changes

This file will change before the app does.
