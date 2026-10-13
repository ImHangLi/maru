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

- Where it is on: outside the EU, the EEA, the UK, and Switzerland, the statistics are on by default. Maru shows a short notice once, after you save an item, and it sends nothing before the notice shows. Settings has the switch "Share Usage Statistics".
- Where it is off: in the EU, the EEA, the UK, and Switzerland, the statistics stay off until you turn them on in the notice or in Settings.
- How Maru picks the rule: it uses the region setting of your device, not your place. If that setting is missing, Maru uses the opt-in rule. A traveler, or a device with another region setting, gets the rule of that setting.
- What Maru sends: only these events and fields.
  - `setup_step`: that an item was saved.
  - `daily_usage_summary`: the day number since the statistics started, and four yes-or-no flags for one day: recorded a dose, opened History, opened the app from a reminder, opened the app from a widget.
  - `core_error`: whether a save or a read failed, with one of five fixed codes.
  - `feedback_entry`: that you tapped "Send Feedback".
- What Maru never sends: item names, doses, intake times, item IDs, notes, photos, or the text of a message. It sends no time of a single dose and no count of doses.
- Each request also has the app version, the major version of iOS, a random install ID, and the region setting of your device as a two-letter code such as AU. The region is a setting, not your place. Maru does not use your location. Apple's privacy label lists the install ID as a device ID. The ID is not linked to your name, your email, or an item. It is a pseudonym, not proof of anonymity. The server sees your IP address as any server does. Maru asks PostHog not to build a person profile and not to look up a location. PostHog keeps the data on its servers in the United States.
- No session recording, no screen capture, and no automatic capture of taps or screens.
- If you turn the switch off, Maru stops sending, deletes the events that wait, deletes the install ID, and deletes the local usage flags. A new ID is made if you turn it on again. Maru cannot delete data that PostHog already holds. The maintainer cannot find your data without the install ID, and Maru does not show the ID today, so a request to delete earlier data is not possible yet.
- Events wait in memory, at most 100, for at most 3 days. If the network fails, Maru drops them after that limit and tries again no more than once every 5 minutes, and only when you use the app. Your records do not depend on it.

## Camera

Maru uses the camera only when you scan a label or take a photo of an item. Your device reads the text of the label, and Maru keeps only the name that you choose. A label scan saves no photo and sends nothing. iOS asks for the camera the first time that you tap "Scan Label" or "Take Photo".

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

## Export and backup files

Settings has "Export Records", "Back Up", and "Restore from Backup…". Maru makes a file only when you tap one of the first two.

- The record export is a CSV file. It has your item names, your amounts, and your records.
- The backup is a full copy of the database and of three settings: the app color, the names in reminders, and "Remind Again". It does not include the item photos.
- The files are not encrypted. Anyone with a file can read it.
- Maru sends no file by itself. The share sheet of iOS opens, and you choose where the file goes. The app or the service that you choose then handles the file.
- Maru keeps the file in a protected temporary folder and removes it when the share sheet closes.
- A restore reads the backup file that you pick. It replaces the data of Maru on the device, after you confirm. The backup file stays where you keep it.

`docs/export-format.md` describes both files.

## iPhone and iPad backups

Your iPhone or iPad backup, in iCloud or on a computer, can include Maru's data and the item photos, the same as other app data. Apple's backup settings control this.

## Changes

This file will change before the app does.
