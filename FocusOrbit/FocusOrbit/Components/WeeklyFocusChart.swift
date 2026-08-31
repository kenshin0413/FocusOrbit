import SwiftUI

struct WeeklyFocusChart: View {
    let records: [MissionRecord]

    private var days: [DailyFocus] { StorageService.lastSevenDays(records) }
    private var maximum: TimeInterval { max(days.map(\.seconds).max() ?? 0, 25 * 60) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 9) {
            ForEach(days) { day in
                VStack(spacing: 7) {
                    GeometryReader { proxy in
                        VStack {
                            Spacer(minLength: 0)
                            Capsule()
                                .fill(barGradient(for: day))
                                .frame(height: max(4, proxy.size.height * day.seconds / maximum))
                        }
                    }
                    Text(dayLabel(day.date))
                        .font(.system(size: 8, weight: Calendar.current.isDateInToday(day.date) ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(Calendar.current.isDateInToday(day.date) ? .white : AppTheme.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 82)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(LocalizedRuntime.text(ja: "直近7日間の集中推移", en: "Focus activity over the last 7 days"))
    }

    private func barGradient(for day: DailyFocus) -> LinearGradient {
        LinearGradient(
            colors: day.seconds > 0 ? [AppTheme.blue, .purple.opacity(0.72)] : [.white.opacity(0.08), .white.opacity(0.035)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: date)
    }
}
