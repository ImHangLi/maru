import MaruCore
import MaruNotifications
import SwiftUI

/// A phone with a picture of the product (D145). It has a fixed size and a fixed text size, as a screenshot has, so each
/// language shares one layout. `OnboardingStage` scales it.
///
/// The pictures use the views and the words of the app. Sample text only: nothing here reads or writes the store.
/// A Lock Screen is a drawing of the system screen, because the app can not show the real one.
struct OnboardingPhone: View {
    /// The size of a 6.1-inch iPhone, in points.
    static let size = CGSize(width: 393, height: 852)

    let page: OnboardingPage
    let step: Int

    var body: some View {
        screen
            .frame(width: Self.size.width - 12, height: Self.size.height - 12)
            .clipShape(.rect(cornerRadius: 54, style: .continuous))
            .overlay(alignment: .top) {
                Capsule().fill(.black).frame(width: 122, height: 35).padding(.top, 10)
            }
            .padding(6)
            .background(.black, in: .rect(cornerRadius: 60, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 60, style: .continuous)
                    .strokeBorder(Color(white: 0.45), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
            .frame(width: Self.size.width, height: Self.size.height)
            .dynamicTypeSize(.large)
    }

    @ViewBuilder private var screen: some View {
        switch page {
        case .reminder: ReminderPicture(step: step)
        case .today: TodayPicture(step: step)
        case .alarm: AlarmPicture(step: step)
        }
    }
}

extension OnboardingPage {
    var script: OnboardingScript {
        switch self {
        case .reminder:
            OnboardingScript(
                focus: CGRect(x: 8, y: 236, width: 377, height: 250),
                beats: [
                    (0.4, .step(1)), (0.9, .close(true)), (2.5, .step(2)),
                    (1.5, .step(3)), (0.7, .step(4)), (0.2, .close(false)), (2.6, .step(0)),
                ],
                stillStep: 2
            )
        case .today:
            OnboardingScript(
                focus: CGRect(x: 8, y: 200, width: 377, height: 240),
                beats: [(1.1, .close(true)), (2.7, .step(1)), (2.2, .close(false)), (3.4, .step(0))],
                stillStep: 1
            )
        case .alarm:
            OnboardingScript(
                focus: CGRect(x: 8, y: 262, width: 377, height: 250),
                beats: [(1.1, .close(true)), (2.9, .step(1)), (1.5, .close(false)), (3.4, .step(0))],
                stillStep: 0
            )
        }
    }
}

/// The sample items of the pictures. They are generic names in the app language.
private enum Sample {
    static let vitamin = String(localized: "Vitamin D", comment: "Onboarding picture: a sample item name. Use the common generic name, not a brand.")
    static let omega = String(localized: "Omega-3", comment: "Onboarding picture: a sample item name. Use the common generic name, not a brand.")
    static let magnesium = String(localized: "Magnesium", comment: "Onboarding picture: a sample item name. Use the common generic name, not a brand.")
    static let softgel = String(localized: "1 softgel", comment: "Onboarding picture: the sample amount of an item.")
    static let softgels = String(localized: "2 softgels", comment: "Onboarding picture: the sample amount of an item.")
    static let capsules = String(localized: "2 capsules", comment: "Onboarding picture: the sample amount of an item.")

    /// The sample time 8:00 with no AM or PM, as a Lock Screen shows it.
    static var clock: String {
        let eight = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
        return eight.formatted(Date.FormatStyle().hour(.defaultDigits(amPM: .omitted)).minute())
    }

    static var reminder: ReminderText {
        SystemReminderCenter().text(for: ReminderContent(kind: .due, names: [ReminderName(item: vitamin)]))
    }
}

/// The wallpaper, the date, and the clock of a Lock Screen. The clock shows the sample time 8:00.
private struct LockScreen<Content: View>: View {
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
            LinearGradient(
                colors: [appColor.tint.opacity(0.14), appColor.tint.opacity(0.42), appColor.tint],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 0) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.system(size: 21, weight: .semibold))
                    .padding(.top, 76)
                Text(verbatim: Sample.clock)
                    .font(.system(size: 92, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                content
                    .padding(.top, 36)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
        }
        .environment(\.colorScheme, .dark)
    }
}

/// Page 1: a reminder arrives on the Lock Screen, its actions open, and "Taken" records the dose.
private struct ReminderPicture: View {
    let step: Int
    private let text = Sample.reminder

    private var now: String {
        let format = RelativeDateTimeFormatter()
        format.dateTimeStyle = .named
        return format.localizedString(fromTimeInterval: 0)
    }

    var body: some View {
        LockScreen {
            VStack(spacing: 8) {
                if (1...3).contains(step) {
                    banner.transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                }
                if (2...3).contains(step) {
                    actions.transition(.asymmetric(insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity), removal: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var banner: some View {
        HStack(spacing: 12) {
            Image(AppIcon.current.previewName)
                .resizable()
                .frame(width: 42, height: 42)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(verbatim: text.title).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(verbatim: now).font(.footnote).foregroundStyle(.secondary)
                }
                Text(verbatim: text.body).font(.subheadline)
            }
        }
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
        .padding(14)
        .background(platter, in: .rect(cornerRadius: 24, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 0) {
            action(.taken, symbol: "checkmark")
                .background(step == 3 ? Color.black.opacity(0.12) : .clear)
            Divider()
            action(.skip, symbol: "minus.circle")
            Divider()
            action(.snooze, symbol: "clock")
        }
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
        .background(platter)
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
        .frame(width: 270)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func action(_ kind: ReminderActionKind, symbol: String) -> some View {
        HStack {
            Text(verbatim: ReminderAction.action(kind, in: .single, locale: .current).title)
            Spacer()
            Image(systemName: symbol)
        }
        .font(.body)
        .padding(.horizontal, 16)
        .frame(height: 46)
    }

    /// The system glass needs what is behind it. The picture draws as one group, so this is a plain color.
    private var platter: Color { Color(white: 0.97, opacity: 0.95) }
}

/// Page 2: the Today page of the app, and one more dose recorded on it.
private struct TodayPicture: View {
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    let step: Int

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
            HeaderWash.gradient(appColor).frame(height: HeaderWash.height)
            VStack(alignment: .leading, spacing: 0) {
                bar
                    .padding(.top, 64)
                Text("Today")
                    .font(.largeTitle.bold())
                    .padding(.top, 10)
                    .padding(.leading, 4)
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                section("Morning") {
                    row(.softgel, .orange, Sample.vitamin, Sample.softgel, taken: 3)
                    Divider().padding(.leading, 60)
                    row(.softgel, .yellow, Sample.omega, Sample.softgels, taken: step == 1 ? 4 : nil)
                }
                section("Evening") {
                    row(.capsule, .mint, Sample.magnesium, Sample.capsules, taken: nil, planned: (21, 0))
                }
            }
            .padding(.horizontal, 16)
            VStack {
                Spacer()
                tabs
            }
        }
    }

    private var bar: some View {
        HStack(spacing: 10) {
            barButton("gearshape")
            Spacer()
            barButton("calendar")
            barButton("plus")
        }
    }

    private func barButton(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .medium))
            .frame(width: 44, height: 44)
            .background(Color(.secondarySystemGroupedBackground), in: .circle)
    }

    private func section<Rows: View>(_ title: LocalizedStringKey, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
                .padding(.leading, 4)
            VStack(spacing: 0, content: rows)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24, style: .continuous))
        }
        .padding(.top, 20)
    }

    /// `taken` is the minute of the record after 8:00. A row with no record shows the planned time.
    private func row(
        _ form: ItemForm, _ color: ItemColor, _ name: String, _ amount: String, taken: Int?, planned: (hour: Int, minute: Int) = (8, 0)
    ) -> some View {
        HStack(spacing: 12) {
            FormIcon(form: form, color: color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                Text(verbatim: [amount, state(taken: taken, planned: planned)].detailLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .numberMotion(value: taken)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            RecordSymbol(state: taken == nil ? .open : .taken)
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
    }

    private func state(taken: Int?, planned: (hour: Int, minute: Int)) -> String {
        guard let taken else { return SchedulePreview.format(hour: planned.hour, minute: planned.minute) }
        return String(localized: "Taken at \(SchedulePreview.format(hour: 8, minute: taken))")
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            tab("checkmark.circle", "Today", isSelected: true)
            tab("square.grid.2x2", "My Items", isSelected: false)
        }
        .padding(4)
        .background(Color(.secondarySystemGroupedBackground), in: .capsule)
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        .padding(.bottom, 24)
    }

    private func tab(_ symbol: String, _ title: LocalizedStringKey, isSelected: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 20))
            Text(title).font(.caption2.weight(.medium))
        }
        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        .frame(width: 96, height: 50)
        .background(isSelected ? Color(.tertiarySystemFill) : .clear, in: .capsule)
    }
}

/// Page 3: the alarm of an item, with "Stop" and "Taken" as `SystemAlarmCenter` sets them.
private struct AlarmPicture: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    let step: Int

    /// Only iOS 26 or later shows this page, and the system has the effect from iOS 18.
    @ViewBuilder private var bell: some View {
        let bell = Image(systemName: "alarm.fill").font(.system(size: 44))
        if #available(iOS 18, *) {
            bell.symbolEffect(.wiggle, options: .repeat(.continuous), isActive: !reduceMotion)
        } else {
            bell
        }
    }

    var body: some View {
        LockScreen {
            VStack(spacing: 20) {
                bell
                Text(verbatim: AlarmSupport.title(Sample.reminder.title, names: Sample.vitamin))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 28)
                HStack(spacing: 12) {
                    button("Stop", symbol: "stop.circle", fill: .white.opacity(0.22), isPressed: false)
                    button("Taken", symbol: "checkmark", fill: appColor.tint, isPressed: step == 1)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func button(_ title: LocalizedStringKey, symbol: String, fill: Color, isPressed: Bool) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(fill, in: .capsule)
            .scaleEffect(isPressed ? 0.94 : 1)
            .brightness(isPressed ? -0.1 : 0)
    }
}
