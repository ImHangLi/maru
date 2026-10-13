import Foundation
import Testing
@testable import MaruCore

struct WatchMessageTests {
    /// D065: a request and a reply come back from their message data as they went in, and data that is
    /// no message gives no request and no reply, so it can never show as a record.
    @Test func aMessageKeepsItsContent() throws {
        let dose = WatchDay.Dose(
            id: OccurrenceID(), scheduleVersionID: ScheduleVersionID(), name: "Vitamin D", amount: nil,
            status: .skipped, time: try Date("2026-03-01T00:05:00Z", strategy: .iso8601)
        )
        let request = WatchRequest.record(dose.id, scheduleVersionID: dose.scheduleVersionID, action: .undo)
        let reply = WatchReply(
            recorded: true,
            day: WatchDay(
                sentAt: dose.time, expiresAt: dose.time.addingTimeInterval(60), tint: .mint,
                slots: [WatchDay.Slot(part: .evening, doses: [dose])]
            )
        )

        #expect(WatchRequest(message: try #require(request.message)) == request)
        #expect(WatchReply(message: try #require(reply.message)) == reply)
        #expect(WatchReply(message: Data("taken".utf8)) == nil)
        #expect(WatchRequest(message: Data()) == nil)
    }
}
