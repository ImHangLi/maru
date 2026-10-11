# Export and backup formats

Maru makes two files, from "Your Data" in Settings (D040). Neither file is encrypted. The code is in `Packages/MaruKit`: `RecordExport.swift`, `LocalStore+Export.swift`, and `LocalStore+Backup.swift`. Change this file with the code.

## Record export

A file for a person: a CSV file that Numbers and Excel open. The name is `Maru Records YYYY-MM-DD.csv`.

- Encoding: UTF-8, with a byte order mark at the start. Excel needs the mark to read UTF-8.
- Each line ends with CR LF. The first line is the header (RFC 4180).
- A field with a comma, a quotation mark, or a line break is in quotation marks. A quotation mark in such a field is written two times.
- The words in the header, in "Type", and in "State" are fixed English text. They do not change with the language of the iPhone.
- Maru writes a name and an amount as you typed them. It does not change a text that starts with `=`, `+`, `-`, or `@`. A spreadsheet app can read such a text as a formula.

One line is one dose, with the state that is valid now. The lines are in the order of the date, then of the planned time. The as-needed doses of a date come after its planned doses.

| Column | Content | Example |
|---|---|---|
| Date | The plan date of the dose. For an as-needed dose, the date of the record. `YYYY-MM-DD` | `2026-03-01` |
| Planned Time | The planned clock time, `HH:MM`, 24 hours. Empty for an as-needed dose | `08:00` |
| Item | The name of the item | `Vitamin D` |
| Type | `Supplement` or `Medication`. Empty when the item has neither type | `Supplement` |
| Amount | The amount as you wrote it, with no conversion. Empty for an item with no amount and for an as-needed dose | `1000 IU` |
| State | `Taken`, `Skipped`, or `No record` | `Taken` |
| Time Taken | When you took the dose, `YYYY-MM-DD HH:MM`. Empty for a dose that is not taken | `2026-03-01 08:05` |
| Time Zone | The IANA name of the zone of the date and of the two times | `Asia/Shanghai` |

Which doses are in the file:

- Every dose that History shows: a dose with a record, and a planned dose with no record.
- The doses of today that have a record. A dose of today with no record is not in the file, because the day did not end.
- A record that you took back counts as no record. An as-needed dose that you took back is not in the file.
- The recorded doses of an archived item are in the file. The doses of a deleted item are not.

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
| `remindAgainMinutes` | `0` for off, or `15`, `30`, or `60` |

A backup does not hold the notification permission, the pending reminders, or an unsaved draft. They belong to one iPhone.

### What a restore accepts

- The format version is 1 or lower, and the application ID is the one of Maru.
- The file has the first migrations of the app with no gap. A file with a migration that this version does not know comes from a newer version, and the restore refuses it.
- A file from an older version is accepted. The restore applies the later migrations to a copy, never to the file.
- A restore ignores a setting key or a value that it does not know.

### Format changes

- A new table or column comes with a new migration. The format version does not change, because the migration list already tells a newer file from an older one.
- Raise the format version only when an older version of the app can read a newer file wrong with no new migration, for example after a change of the meaning of `backupSetting`.
