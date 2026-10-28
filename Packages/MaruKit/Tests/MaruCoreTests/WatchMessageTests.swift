import Foundation
import Testing
@testable import MaruCore

struct WatchMessageTests {
    /// D071: a request and a reply come back from their message data as they went in, and data that is
    /// no message gives no request and no reply, so it can never show as a record.
    @Test func aMessageKeepsItsContent() throws {
        let dose = WatchDay.Dose(
            id: OccurrenceID(), scheduleVersionID: ScheduleVersionID(), name: "Vitamin D", amount: nil,
            status: .skipped, revision: IntakeEventID(), time: try Date("2026-03-01T00:05:00Z", strategy: .iso8601)
        )
        let request = WatchRequest.record(
            dose.id, scheduleVersionID: dose.scheduleVersionID, action: .undo,
            revision: dose.revision, intent: IntakeEventID()
        )
        let reply = WatchReply(
            outcome: .recorded,
            day: WatchDay(
                sentAt: dose.time, expiresAt: dose.time.addingTimeInterval(60), tint: .mint, isPro: true,
                slots: [WatchDay.Slot(part: .evening, doses: [dose])]
            )
        )

        #expect(WatchRequest(message: try #require(request.message)) == request)
        #expect(WatchReply(message: try #require(reply.message)) == reply)
        #expect(WatchReply(message: Data("taken".utf8)) == nil)
        #expect(WatchRequest(message: Data()) == nil)
    }

    /// D071, T18: the Watch writes only on the record that its row showed, and one intent applies one time.
    /// A row from before a change on the iPhone, and an intent with a later choice after it, write nothing.
    @Test func anIntentAppliesOneTimeToTheRecordThatTheWatchShowed() throws {
        let now = Date()
        var record = OccurrenceRecord(occurrenceID: OccurrenceID())
        let intent = IntakeEventID()
        #expect(record.watchStep(intent: intent, revision: nil) == .write)

        try record.record(IntakeEvent(
            id: intent, occurrenceID: record.occurrenceID, action: .taken, occurredAt: now, recordedAt: now, source: .app
        ))
        #expect(record.watchStep(intent: intent, revision: nil) == .applied)
        #expect(record.watchStep(intent: IntakeEventID(), revision: nil) == .changed)

        try record.record(IntakeEvent(
            occurrenceID: record.occurrenceID, action: .skipped, occurredAt: now, recordedAt: now, source: .app,
            supersedes: intent
        ))
        #expect(record.watchStep(intent: intent, revision: nil) == .changed)
    }
}
