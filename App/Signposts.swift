import Foundation
import os

/// The signposts of the launch path and of the database reads (spec 9).
///
/// A signpost has the name of a phase and counts. It never has an item name, a dose, an intake time,
/// or an ID (spec 10). Read the signposts in Instruments, or with `log stream --signpost`.
enum Signposts {
    static let signposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "Maru",
        category: .pointsOfInterest
    )

    /// The milliseconds since the system started this process. The time before `main` is part of it.
    static func millisecondsSinceProcessStart() -> Int? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&name, UInt32(name.count), &info, &size, nil, 0) == 0 else { return nil }
        let start = info.kp_proc.p_starttime
        let startSeconds = Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
        return Int(((Date().timeIntervalSince1970 - startSeconds) * 1000).rounded())
    }
}
