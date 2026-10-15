# Export and backup formats

Maru makes two files, from "Your Data" in Settings (D040). Neither file is encrypted. The code is in `Packages/MaruKit`: `RecordExport.swift`, `LocalStore+Export.swift`, and `LocalStore+Backup.swift`. Change this file with the code.

## Record export

A file for a person: a CSV file that Numbers and Excel open. The name is `Maru Records YYYY-MM-DD.csv`.

- Encoding: UTF-8, with a byte order mark at the start. Excel needs the mark to read UTF-8.
- Each line ends with CR LF. The first line is the header (RFC 4180).
- A field with a comma, a quotation mark, or a line break is in quotation marks. A quotation mark in such a field is written two times.
- The words in the header, in "Type", and in "State" are fixed English text. They do not change with the language of the iPhone.
- A field that starts with `=`, `+`, `-`, `@`, a tab, or a carriage return gets an apostrophe (`'`) in front. A spreadsheet app can run such a text as a formula, and the apostrophe makes it plain text. The name and the amount in Maru do not change.

One line is one dose, with the state that is valid now. The lines are in the order of the date, then of the planned time. The as-needed doses of a date come after its planned doses.

| Column | Content | Example |
|---|---|---|
| Date | The plan date of the dose. For an as-needed dose, the date of the record. `YYYY-MM-DD` | `2026-03-01` |
| Planned Time | The planned clock time, `HH:MM`, 24 hours. Empty for an as-needed dose | `08:00` |
| Item | The name of the item | `Vitamin D` |
| Type | `Supplement` or `Medication`. Empty when the item has neither type | `Supplement` |
| Amount | The amount as you wrote it, with no conversion. Empty for a dose with no amount. An as-needed dose has the amount that the item had when you recorded it | `1000 IU` |
| State | `Taken`, `Skipped`, or `No record` | `Taken` |
| Time Taken | When you took the dose, `YYYY-MM-DD HH:MM`. Empty for a dose that is not taken | `2026-03-01 08:05` |
| Time Zone | The IANA name of the zone of the date and of the two times | `Asia/Shanghai` |

Which doses are in the file:

- Every dose that History shows: a dose with a record, and a planned dose with no record.
- The doses of today or of a later date that have a record. A dose in a fixed time zone, or a dose of a stay in another zone, can have a date after the date of the iPhone. A dose of today or a later date with no record is not in the file, because the day did not end.
- A record that you took back counts as no record. An as-needed dose that you took back is not in the file.
- The doses of an archived item are in the file: its recorded doses, and its planned doses with no record up to the day before it was archived. An item archived before the app kept the archive time has only its recorded doses. The doses of a deleted item are not.

## Backup

A file for Maru: a full copy that a restore reads. The name is `Maru Backup YYYY-MM-DD.marubackup`.

The file is one SQLite database file in rollback journal mode, with no file next to it.

| Part | Content |
|---|---|
| `PRAGMA application_id` | `0x4D617275`, the ASCII codes of "Maru". It marks the file as a backup of Maru |
| `PRAGMA user_version` | The format version. It is `1` |
| Tables of the app | A consistent copy of every table of the database, made with `VACUUM INTO`. `Schema.swift` has the tables |
| `grdb_migrations` | The migrations that the database has. A restore reads the schema version from it |
| `backupSetting` | One row for each setting, as a key and a text value |

The settings:

| Key | Value |
|---|---|
| `appColor` | The app color: `pink`, `orange`, `yellow`, `green`, `mint`, `blue`, `purple`, or `brown` |
| `reminderNames` | `showNames` or `hideNames` |
| `remindAgainMinutes` | Version 1.0 only (D079). The time between follow-ups in minutes: `0` for off, or `5`, `10`, `15`, `30`, or `60`. Version 1.1 writes no such row. A restore copies a value above `0` to every restored item |
| `remindAgainCount` | Version 1.0 only (D079). The number of follow-ups: `1`, `2`, `3`, or `5`, or `0` for "Until Recorded". A backup with no such row restores "1 Time" |

The follow-ups and the alarm of each item are columns of the `item` table since migration `v6` (D079): `followUpCount` (`0` for "Until Recorded", else the number) and `followUpMinutes` (both empty for off), `followUpChanged` (an instant, or empty), and `alarm` (`0` or `1`). A backup from before `v6` has none of them. The restore applies `v6` to its copy, so every item has no follow-up and no alarm, and then it copies the two settings of version 1.0 above to the items.

A backup does not hold the notification permission, the pending reminders, or an unsaved draft. They belong to one iPhone.

A backup does not hold the item photos (D056). The `item` table has the column `imageReference` with the name of the photo file, and the files are not in the backup. A restore keeps the names. An item shows its photo only when the file is still on the iPhone, and else it shows the form icon. After a restore, Maru removes the photo files that no restored item uses. The record export has no photo.

### What a restore accepts

- The format version is 1 or lower, and the application ID is the one of Maru.
- The file has the first migrations of the app with no gap. A file with a migration that this version does not know comes from a newer version, and the restore refuses it.
- A file from an older version is accepted. The restore applies the later migrations to a copy, never to the file.
- A restore ignores a setting key or a value that it does not know.

### Format changes

- A new table or column comes with a new migration. The format version does not change, because the migration list already tells a newer file from an older one.
- Raise the format version only when an older version of the app can read a newer file wrong with no new migration, for example after a change of the meaning of `backupSetting`.
