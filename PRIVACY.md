# Privacy

Maru keeps your health data on your iPhone. This file describes the app in this repository as it is today.

## What Maru stores

- Your items, schedules, notes, and records, in a local SQLite database.
- Your settings, in the app's local preferences.
- An unsaved draft of the add or edit screen, in a local file. Maru deletes it when you save or cancel.

Maru asks iOS to encrypt the database file while your iPhone is locked. When Maru cannot open your records because the iPhone is locked, it records nothing and asks you to unlock.

## What Maru does not do

- It makes no network requests by itself. It has no server and no account.
- It contains no analytics, advertising, or crash-reporting code.
- It does not read your contacts, your location, or the advertising identifier.
- It does not read from or write to Apple Health.

## Camera

Maru uses the camera only while you scan a label on the add screen. Your iPhone reads the text, and Maru keeps only the name that you tap. Maru saves no photo and sends nothing. iOS asks for the camera the first time that you tap "Scan Label".

The name suggestions on the add screen come from a list inside the app. The name suggestions are a typing aid. They are not medical advice.

## Feedback

Settings has a "Send Feedback" button. It opens a web form of Tally (tally.so) in the system browser. Nothing happens before you tap it, and Maru sends no data of the app to the form. What you write there, and your email address if you give one, goes to Tally and to the maintainer. Tally's privacy policy applies to that page, and the page can use its own cookies. Please leave health details out of a message.

## Notifications

Reminders are local notifications. iOS schedules and shows them on your iPhone, and they do not go through a server. To hide reminder text on the Lock Screen, turn off previews in the iOS notification settings.

## Backups

Your iPhone backup, in iCloud or on a computer, can include Maru's data, the same as other app data. Apple's backup settings control this.

## Changes

A future version may add optional usage statistics. If it does, they will be off until you turn them on, and they will never include item names, doses, or intake times. This file will change before the app does.
