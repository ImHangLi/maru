# Privacy

Maru keeps your health data on your iPhone. This file describes the app in this repository as it is today.

## What Maru stores

- Your items, schedules, notes, and records, in a local SQLite database.
- Your settings, in the app's local preferences.
- An unsaved draft of the add or edit screen, in a local file. Maru deletes it when you save or cancel.
- The photo of an item, if you add one, in a local file. See "Item photos".

Maru asks iOS to encrypt the database file while your iPhone is locked. When Maru cannot open your records because the iPhone is locked, it records nothing and asks you to unlock.

## What Maru does not do

- It makes no network requests by itself. It has no server and no account.
- It contains no analytics, advertising, or crash-reporting code.
- It does not read your contacts, your location, or the advertising identifier.
- It does not read from or write to Apple Health.

## Camera

Maru uses the camera only while you scan a label on the add screen. Your iPhone reads the text, and Maru keeps only the name that you tap. A label scan saves no photo and sends nothing. iOS asks for the camera the first time that you tap "Scan Label" or "Take Photo".

## Item photos

An item can have a photo that you take or choose on the add or edit screen. It is optional.

- Maru makes a small copy of the photo, at most 512 pixels on the longest side, and keeps only that copy. It does not keep the original photo. The copy has no location and no camera data (EXIF).
- Maru can remove the background of the photo on your iPhone. It uses Apple's Vision framework, and nothing leaves the iPhone.
- The photo files are in the Maru data folder of your iPhone, next to the database, with the same file protection. Maru deletes a photo file when you remove the photo or delete the item.
- "Take Photo" does not save to your photo library. "Choose Photo" uses the system photo picker, so Maru sees only the photo that you pick.
- The Maru backup file (see below) does not contain the photos. After a restore on another iPhone, items show the form icon, and you can add the photos again.
- The record export has no photos.

The name suggestions on the add screen come from a list inside the app. The name suggestions are a typing aid. They are not medical advice.

## Feedback

Settings has a "Send Feedback" button. It opens a web form of Tally (tally.so) in the system browser. Nothing happens before you tap it, and Maru sends no data of the app to the form. What you write there, and your email address if you give one, goes to Tally and to the maintainer. Tally's privacy policy applies to that page, and the page can use its own cookies. Please leave health details out of a message.

## Notifications

Reminders are local notifications. iOS schedules and shows them on your iPhone, and they do not go through a server. To hide reminder text on the Lock Screen, turn off previews in the iOS notification settings.

## Export and backup files

Settings has "Export Records", "Back Up", and "Restore from Backup…". Maru makes a file only when you tap one of the first two.

- The record export is a CSV file. It has your item names, your amounts, and your records.
- The backup is a full copy of the database and of three settings: the app color, the names in reminders, and "Remind Again". It does not include the item photos.
- The files are not encrypted. Anyone with a file can read it.
- Maru sends no file by itself. The share sheet of iOS opens, and you choose where the file goes. The app or the service that you choose then handles the file.
- Maru keeps the file in a protected temporary folder and removes it when the share sheet closes.
- A restore reads the backup file that you pick. It replaces the data of Maru on the iPhone, after you confirm. The backup file stays where you keep it.

`docs/export-format.md` describes both files.

## iPhone backups

Your iPhone backup, in iCloud or on a computer, can include Maru's data and the item photos, the same as other app data. Apple's backup settings control this.

## Changes

A future version may add optional usage statistics. If it does, they will be off until you turn them on, and they will never include item names, doses, or intake times. This file will change before the app does.
