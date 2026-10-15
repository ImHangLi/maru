import GRDB

/// The database schema. A released migration is frozen: change the schema with a new migration (spec 7.3).
enum Schema {
    /// The migrations of the app, in order. It never erases the database to apply a change (T37).
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: v1)
        }
        migrator.registerMigration("v2") { db in
            try db.execute(sql: v2)
        }
        // GRDB runs a migration with foreign key checks off and checks every foreign key before the commit,
        // so `v3` can replace a table that other tables refer to.
        migrator.registerMigration("v3") { db in
            try db.execute(sql: v3)
        }
        migrator.registerMigration("v4") { db in
            try db.execute(sql: v4)
        }
        migrator.registerMigration("v5") { db in
            try db.execute(sql: v5)
        }
        migrator.registerMigration("v6") { db in
            try db.execute(sql: v6)
        }
        migrator.registerMigration("v7") { db in
            try db.execute(sql: v7)
        }
        return migrator
    }

    /// Encodings: an ID is the UUID string. A date is `YYYY-MM-DD` and a wall-clock time is `HH:MM`.
    /// An instant is the number of seconds since 2001-01-01 UTC, which keeps the exact `Date` value.
    /// An enum is its raw value. `position` keeps the append order of the domain arrays.
    static let v1 = """
        CREATE TABLE item (
            id TEXT NOT NULL PRIMARY KEY,
            category TEXT NOT NULL,
            name TEXT NOT NULL,
            isArchived INTEGER NOT NULL,
            imageReference TEXT,
            intakeNotePreset TEXT,
            intakeNoteText TEXT,
            CHECK (intakeNotePreset IS NULL OR intakeNoteText IS NULL)
        ) STRICT;

        CREATE TABLE productVersion (
            id TEXT NOT NULL PRIMARY KEY,
            itemID TEXT NOT NULL REFERENCES item(id),
            name TEXT NOT NULL,
            specification TEXT,
            source TEXT NOT NULL,
            verifiedAt REAL NOT NULL,
            effectiveFrom TEXT NOT NULL
        ) STRICT;
        CREATE INDEX productVersion_itemID ON productVersion(itemID);

        CREATE TABLE schedule (
            id TEXT NOT NULL PRIMARY KEY,
            itemID TEXT NOT NULL REFERENCES item(id),
            isEnabled INTEGER NOT NULL,
            endDate TEXT
        ) STRICT;
        CREATE INDEX schedule_itemID ON schedule(itemID);

        CREATE TABLE scheduleSlot (
            id TEXT NOT NULL PRIMARY KEY,
            scheduleID TEXT NOT NULL REFERENCES schedule(id),
            position INTEGER NOT NULL,
            UNIQUE (scheduleID, position)
        ) STRICT;

        -- `timeZone` has a value only when `timeZonePolicy` is 'fixed'.
        CREATE TABLE scheduleVersion (
            id TEXT NOT NULL PRIMARY KEY,
            scheduleID TEXT NOT NULL REFERENCES schedule(id),
            position INTEGER NOT NULL,
            effectiveFrom TEXT NOT NULL,
            weekdays TEXT NOT NULL,
            dose TEXT,
            timeZonePolicy TEXT NOT NULL,
            timeZone TEXT,
            productVersionID TEXT REFERENCES productVersion(id),
            UNIQUE (scheduleID, position)
        ) STRICT;

        CREATE TABLE scheduleVersionSlot (
            scheduleVersionID TEXT NOT NULL REFERENCES scheduleVersion(id),
            slotID TEXT NOT NULL REFERENCES scheduleSlot(id),
            position INTEGER NOT NULL,
            time TEXT NOT NULL,
            PRIMARY KEY (scheduleVersionID, slotID),
            UNIQUE (scheduleVersionID, position)
        ) STRICT;

        -- One occurrence for each slot and plan date (T17).
        CREATE TABLE occurrence (
            id TEXT NOT NULL PRIMARY KEY,
            slotID TEXT NOT NULL REFERENCES scheduleSlot(id),
            plannedDate TEXT NOT NULL,
            plannedTime TEXT NOT NULL,
            timeZone TEXT NOT NULL,
            scheduleVersionID TEXT NOT NULL REFERENCES scheduleVersion(id),
            UNIQUE (slotID, plannedDate)
        ) STRICT;

        -- Append-only. The primary key is the idempotency key of the record transaction (T18).
        -- An event revises at most one event, and that event belongs to the same occurrence.
        -- An event is revised at most once, so the history of an occurrence cannot fork.
        -- An event does not revise itself.
        CREATE TABLE intakeEvent (
            id TEXT NOT NULL PRIMARY KEY,
            occurrenceID TEXT NOT NULL REFERENCES occurrence(id),
            position INTEGER NOT NULL,
            action TEXT NOT NULL,
            occurredAt REAL NOT NULL,
            recordedAt REAL NOT NULL,
            source TEXT NOT NULL,
            supersedes TEXT UNIQUE,
            UNIQUE (occurrenceID, position),
            UNIQUE (occurrenceID, id),
            UNIQUE (occurrenceID, id, action),
            FOREIGN KEY (occurrenceID, supersedes) REFERENCES intakeEvent(occurrenceID, id),
            CHECK (supersedes <> id)
        ) STRICT;
        -- An occurrence has at most one event that revises nothing.
        CREATE UNIQUE INDEX intakeEvent_firstEvent ON intakeEvent(occurrenceID) WHERE supersedes IS NULL;

        -- The projection: the one valid state of an occurrence. No row means unrecorded.
        -- `status` is the action of the event that the row names, so the two cannot differ.
        -- SQL does not say that the event is the current one. The store checks that on every read.
        CREATE TABLE occurrenceState (
            occurrenceID TEXT NOT NULL PRIMARY KEY,
            eventID TEXT NOT NULL,
            status TEXT NOT NULL,
            FOREIGN KEY (occurrenceID, eventID, status) REFERENCES intakeEvent(occurrenceID, id, action)
        ) STRICT;
        """

    /// The form and the color of an item (D013, D021). An item stored before this migration gets
    /// the form `unknown` and the color `pink`. The checks list the raw values of `ItemForm` and `ItemColor`.
    static let v2 = """
        ALTER TABLE item ADD COLUMN form TEXT NOT NULL DEFAULT 'unknown'
            CHECK (form IN ('capsule', 'tablet', 'softgel', 'powder', 'drop', 'unknown'));
        ALTER TABLE item ADD COLUMN color TEXT NOT NULL DEFAULT 'pink'
            CHECK (color IN ('pink', 'orange', 'yellow', 'green', 'mint', 'blue', 'purple', 'brown'));
        """

    /// As-needed occurrences (D021). An occurrence has either a slot and a schedule version, or an item and
    /// neither of the two. SQLite cannot drop a `NOT NULL` from a column, so the migration copies every row,
    /// with its `rowid`, to a new table and gives the new table the old name. The copy runs in the transaction
    /// of the migration, and a failure rolls it back with the old table and its data (spec 7.3).
    /// The unique key (slot and plan date) stays. SQLite treats each `NULL` slot as distinct, so an item can
    /// have many as-needed occurrences on one date.
    static let v3 = """
        CREATE TABLE newOccurrence (
            id TEXT NOT NULL PRIMARY KEY,
            slotID TEXT REFERENCES scheduleSlot(id),
            plannedDate TEXT NOT NULL,
            plannedTime TEXT NOT NULL,
            timeZone TEXT NOT NULL,
            scheduleVersionID TEXT REFERENCES scheduleVersion(id),
            itemID TEXT REFERENCES item(id),
            UNIQUE (slotID, plannedDate),
            CHECK ((slotID IS NULL) = (scheduleVersionID IS NULL)),
            CHECK ((slotID IS NULL) = (itemID IS NOT NULL))
        ) STRICT;
        INSERT INTO newOccurrence (rowid, id, slotID, plannedDate, plannedTime, timeZone, scheduleVersionID)
            SELECT rowid, id, slotID, plannedDate, plannedTime, timeZone, scheduleVersionID FROM occurrence;
        DROP TABLE occurrence;
        ALTER TABLE newOccurrence RENAME TO occurrence;
        CREATE INDEX occurrence_asNeeded ON occurrence(plannedDate, itemID) WHERE itemID IS NOT NULL;
        """

    /// The start date of a schedule version that repeats every second day (D036). A version stored before
    /// this migration has `NULL`, so it keeps its weekdays and loads unchanged. A version with a start date
    /// has every weekday, as `ScheduleVersion` requires.
    static let v4 = """
        ALTER TABLE scheduleVersion ADD COLUMN everyOtherDayFrom TEXT
            CHECK (everyOtherDayFrom IS NULL OR weekdays = '1234567');
        """

    /// The day cycle of a schedule version (D065): the start date, the days with a dose, and the days of
    /// the pause. The start date is the column of `v4` with a new name, and its check stays. A version that
    /// repeats every second day gets 1 and 1, so it keeps its rhythm. A version with no start date keeps
    /// `NULL` in the three columns and loads unchanged. `ScheduleVersion` loads all three or none.
    /// The checks have the limits of `DayCycle.dayCounts`.
    static let v5 = """
        ALTER TABLE scheduleVersion RENAME COLUMN everyOtherDayFrom TO cycleStart;
        ALTER TABLE scheduleVersion ADD COLUMN cycleDaysOn INTEGER CHECK (cycleDaysOn BETWEEN 1 AND 99);
        ALTER TABLE scheduleVersion ADD COLUMN cycleDaysOff INTEGER CHECK (cycleDaysOff BETWEEN 1 AND 99);
        UPDATE scheduleVersion SET cycleDaysOn = 1, cycleDaysOff = 1 WHERE cycleStart IS NOT NULL;
        """

    /// The reminder options of an item (D079). An item stored before this migration has no follow-up and no alarm,
    /// as before. The app copies the global follow-up setting of version 1.0 to every item one time, after the
    /// migration (`LocalStore.adoptFollowUpSetting`). A count and an interval come together or not at all.
    /// The checks list the raw values of `FollowUpCount` and `FollowUpInterval`.
    static let v6 = """
        ALTER TABLE item ADD COLUMN followUpCount INTEGER CHECK (followUpCount IN (0, 1, 2, 3, 5));
        ALTER TABLE item ADD COLUMN followUpMinutes INTEGER
            CHECK (followUpMinutes IN (5, 10, 15, 30, 60) AND followUpCount IS NOT NULL OR followUpMinutes IS NULL AND followUpCount IS NULL);
        ALTER TABLE item ADD COLUMN followUpChanged REAL;
        ALTER TABLE item ADD COLUMN alarm INTEGER NOT NULL DEFAULT 0 CHECK (alarm IN (0, 1));
        """
    /// The tracker (D091). `archivedAt` is the instant of the archive, so History plans the "No record" doses of an
    /// archived item up to that day. An item archived before this migration has `NULL` and shows only its records, as
    /// before. `asNeededDose` is the usual amount of an as-needed item, and `occurrence.dose` is the amount that one
    /// as-needed dose got when the user recorded it. A scheduled occurrence has no `dose`: its amount is in its
    /// schedule version. Every old row keeps `NULL` and loads unchanged.
    static let v7 = """
        ALTER TABLE item ADD COLUMN archivedAt REAL;
        ALTER TABLE item ADD COLUMN asNeededDose TEXT;
        ALTER TABLE occurrence ADD COLUMN dose TEXT CHECK (dose IS NULL OR itemID IS NOT NULL);
        """
}
