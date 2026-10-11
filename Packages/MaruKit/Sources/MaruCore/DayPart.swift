/// The part of the day of a planned time. Today groups its rows by it and shows no clock time (D011).
/// The smart completion of a supplement names a time with it (D043).
public enum DayPart: CaseIterable, Sendable {
    case morning, noon, evening

    /// Morning ends at 11:00, and evening starts at 17:00. Issue #7 can move these limits.
    public init(_ time: WallClockTime) {
        self = switch time.hour {
        case ..<11: .morning
        case ..<17: .noon
        default: .evening
        }
    }
}
