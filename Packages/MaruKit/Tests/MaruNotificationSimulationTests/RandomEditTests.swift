import Foundation
import Testing
@testable import MaruCore

/// D088: a seeded random sequence of user edits at random clock times. After every step, `Phone.run` fails the test
/// when the reminder run throws (for example `invalidData`), when a schedule is "not set", or when the oracle finds a
/// wrong notification. A row that the app wrote must always read back.
@Suite("Random edits")
struct RandomEditTests {
    struct Generator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    static let seeds = Array(1...40)

    private static let times = [
        "00:00", "00:05", "06:30", "08:00", "09:00", "12:00", "16:00", "20:30", "21:00", "22:59", "23:00", "23:30", "23:59",
    ]
    private static let doses = [nil, "15g", "150mg, 2 tablets ", "1 capsule", "10000 IU"]
    private static let settings: [FollowUpSetting?] = [
        nil, FollowUpSetting(count: .one, interval: .minutes30), FollowUpSetting(count: .three, interval: .minutes30),
        FollowUpSetting(count: .untilRecorded, interval: .minutes5), FollowUpSetting(count: .five, interval: .minutes60),
    ]

    @Test(arguments: seeds) func everyStepKeepsTheRunWorking(_ seed: Int) async throws {
        var random = Generator(state: UInt64(seed))
        let starts = ["2026-10-15 23:30", "2026-10-15 23:50", "2026-10-15 23:53", "2026-10-16 00:05", "2026-10-15 12:00"]
        let p = try await Phone.make(start: starts.randomElement(using: &random)!)
        p.checkOracle = false
        var names: [String] = []
        var archived: Set<String> = []
        var counter = 0
        var asNeeded: [Item] = []
        // Items at one time share one reminder, so the options stay equal for all items, as the oracle expects.
        // "For All Items" changes them for every item at once (D085).
        var setting = Self.settings.randomElement(using: &random)!
        var alarm = false
        // Follow-ups of two zone rules do not merge (D047), so one seed uses one rule for all items.
        let zone: SimZone = switch seed % 3 {
        case 0: .fixed(try NamedTimeZone(identifier: "Asia/Shanghai"))
        case 1: .fixed(try NamedTimeZone(identifier: "Australia/Sydney"))
        default: .device
        }
        for _ in 0..<30 {
            // The clock moves between steps, and sometimes over midnight.
            if Bool.random(using: &random) {
                await p.advance(to: p.now.addingTimeInterval(Double(Int.random(in: 1...120, using: &random)) * 60))
            }
            let live = names.filter { !archived.contains($0) }
            switch Int.random(in: 0..<10, using: &random) {
            case 0, 1:
                counter += 1
                let name = "Item \(counter)"
                var chosen = Self.times.shuffled(using: &random).prefix(Int.random(in: 1...4, using: &random)).map { $0 }
                chosen.sort()
                try await p.addItem(
                    name, at: chosen, zone: zone, followUp: setting,
                    alarm: alarm, dose: Self.doses.randomElement(using: &random)!, startsToday: true
                )
                names.append(name)
            case 2:
                guard let name = live.randomElement(using: &random) else { continue }
                let existing = await p.times(of: name)
                guard let time = Self.times.filter({ !existing.contains($0) }).randomElement(using: &random) else { continue }
                try await p.addTime(name, time)
            case 3:
                guard let name = live.randomElement(using: &random) else { continue }
                let existing = await p.times(of: name)
                guard let time = Self.times.filter({ !existing.contains($0) }).randomElement(using: &random) else { continue }
                try await p.changeTime(name, slot: Int.random(in: 0..<existing.count, using: &random), to: time)
            case 4:
                guard let name = live.randomElement(using: &random) else { continue }
                try await p.archive(name)
                archived.insert(name)
            case 5:
                guard let name = archived.randomElement(using: &random) else { continue }
                try await p.restore(name)
                archived.remove(name)
            case 6:
                setting = Self.settings.randomElement(using: &random)!
                try await p.setAllFollowUp(setting)
            case 7:
                alarm = Bool.random(using: &random)
                try await p.setAllAlarm(alarm)
            case 9 where Int.random(in: 0..<2, using: &random) == 0:
                // An as-needed item and its doses must never stop the run (D088).
                if asNeeded.isEmpty || Bool.random(using: &random) {
                    counter += 1
                    asNeeded.append(try await p.addAsNeededItem("As needed \(counter)"))
                }
                try await p.takeAsNeeded(asNeeded.randomElement(using: &random)!)
            case 8:
                guard let name = live.randomElement(using: &random) else { continue }
                try await p.rename(name, to: name + " B")
                names[names.firstIndex(of: name)!] = name + " B"
            default:
                guard let name = live.randomElement(using: &random) else { continue }
                try await p.record(name, Bool.random(using: &random) ? .taken : .skipped)
                if Int.random(in: 0..<3, using: &random) == 0 { try await p.undo(name) }
            }
        }
    }
}
