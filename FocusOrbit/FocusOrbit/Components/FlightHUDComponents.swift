import SwiftUI

struct FlightRemainingTimeView: View {
    let remainingSeconds: TimeInterval
    var arrivalDate: Date? = nil
    var compact = false
    var subdued = false
    @ScaledMetric(relativeTo: .largeTitle) private var preferredSize: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "flight.remaining_time", defaultValue: "残り時間"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(subdued ? 0.45 : 0.72))
            ViewThatFits(in: .horizontal) {
                countdown(size: compact ? 58 : min(preferredSize, 88))
                countdown(size: compact ? 48 : 64)
                countdown(size: 42)
            }
            if let arrivalDate {
                HStack(spacing: 5) {
                    Image(systemName: "flag.checkered")
                    Text(String(localized: "flight.arrival_time", defaultValue: "到着予定 \(Formatters.time.string(from: arrivalDate))"))
                        .monospacedDigit()
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(subdued ? 0.38 : 0.64))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "flight.remaining_time", defaultValue: "残り時間"))
        .accessibilityValue(accessibilityValue)
    }

    private func countdown(size: CGFloat) -> some View {
        Text(Formatters.countdown(remainingSeconds))
            .font(.system(size: size, weight: .ultraLight, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(.white.opacity(subdued ? 0.62 : 1))
            .contentTransition(.numericText(countsDown: true))
    }

    private var accessibilityValue: String {
        guard let arrivalDate else { return Formatters.countdown(remainingSeconds) }
        return String(localized: "flight.remaining_time.accessibility_value", defaultValue: "\(Formatters.countdown(remainingSeconds))、到着予定 \(Formatters.time.string(from: arrivalDate))")
    }
}

struct FlightRouteProgressView: View {
    let destination: Destination
    let phase: MissionPhase
    let progress: Double
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 5 : 8) {
            HStack {
                Text(phase.japaneseTitle)
                    .font(.subheadline.weight(.semibold))
                Text(phase.englishTitle)
                    .font(.system(size: 8, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.secondary)
                    .lineLimit(1)
                Spacer()
                Text(String(localized: "common.percent_value", defaultValue: "\(Int(progress * 100))%"))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }

            GeometryReader { proxy in
                let barWidth = max(proxy.size.width - 20, 1)
                let shipX = 10 + barWidth * min(max(progress, 0), 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.13)).frame(height: 4)
                        .padding(.horizontal, 10)
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, destination.accent], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, barWidth * progress), height: 4)
                        .padding(.leading, 10)
                    ForEach([0.25, 0.5, 0.75], id: \.self) { marker in
                        Circle()
                            .fill(.white.opacity(0.42))
                            .frame(width: 4, height: 4)
                            .offset(x: 8 + barWidth * marker)
                    }
                    Image(systemName: "location.north.fill")
                        .font(.system(size: compact ? 12 : 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(90))
                        .shadow(color: destination.accent.opacity(0.8), radius: 5)
                        .position(x: shipX, y: proxy.size.height / 2)
                }
            }
            .frame(height: compact ? 16 : 20)

            HStack {
                Text(String(localized: "flight.earth_orbit", defaultValue: "地球軌道"))
                Spacer()
                Text(destination.name)
            }
            .font(.caption2)
            .foregroundStyle(AppTheme.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "flight.progress", defaultValue: "航行進捗"))
        .accessibilityValue(String(localized: "flight.progress.accessibility_value", defaultValue: "\(destination.name)へ\(Int(progress * 100))パーセント、\(phase.japaneseTitle)"))
    }
}

struct FlightTelemetrySummary: View {
    let destination: Destination
    let remainingDistance: Double
    let elapsedSeconds: TimeInterval
    let arrivalDate: Date?
    let detailed: Bool

    var body: some View {
        if detailed {
            HStack(spacing: 0) {
                value(String(localized: "flight.arrival_eta", defaultValue: "到着予定"), arrivalDate.map { Formatters.time.string(from: $0) } ?? "--:--")
                divider
                value(String(localized: "flight.remaining_distance", defaultValue: "残り距離"), Formatters.distance(remainingDistance))
                divider
                value(String(localized: "flight.elapsed_time", defaultValue: "経過時間"), Formatters.clock(elapsedSeconds))
            }
        } else {
            HStack(spacing: 12) {
                Label(String(localized: "flight.remaining_distance.compact", defaultValue: "\(destination.name)まであと \(compactDistance)"), systemImage: "scope")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                Label(String(localized: "flight.status.normal", defaultValue: "航行状態 正常"), systemImage: "checkmark.circle")
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var compactDistance: String {
        if remainingDistance >= 1_000_000 {
            return LocalizedRuntime.format(ja: "%.1f万km", en: "%.1fM km", remainingDistance / 1_000_000)
        }
        if remainingDistance >= 1_000 {
            return LocalizedRuntime.format(ja: "%.1f千km", en: "%.1fK km", remainingDistance / 1_000)
        }
        if remainingDistance >= 1 {
            return LocalizedRuntime.format(ja: "%.0fkm", en: "%.0f km", remainingDistance)
        }
        return LocalizedRuntime.format(ja: "%.0fm", en: "%.0f m", remainingDistance * 1_000)
    }

    private func value(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(AppTheme.secondary)
            Text(value).font(.caption.monospacedDigit().weight(.medium)).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View { Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 26) }
}

struct FlightPauseButton: View {
    let isPaused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(isPaused ? String(localized: "common.resume", defaultValue: "再開") : String(localized: "common.pause", defaultValue: "一時停止"), systemImage: isPaused ? "play.fill" : "pause.fill")
                .font(.subheadline.weight(.semibold))
                .labelStyle(.iconOnly)
                .frame(width: 50, height: 50)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.16)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPaused ? String(localized: "flight.resume", defaultValue: "航行を再開") : String(localized: "flight.pause", defaultValue: "航行を一時停止"))
        .accessibilityHint(isPaused ? String(localized: "flight.resume_hint", defaultValue: "集中タイマーを再開します") : String(localized: "flight.pause_hint", defaultValue: "集中タイマーを一時停止します"))
    }
}

struct FlightPausePanel: View {
    @Binding var displayMode: FocusDisplayMode
    let resume: () -> Void
    let end: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "flight.paused", defaultValue: "航行を一時停止中")).font(.title3.weight(.semibold))
                Text("PAUSED").font(.system(size: 9, design: .monospaced)).tracking(1.8).foregroundStyle(AppTheme.secondary)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text(String(localized: "settings.display_mode", defaultValue: "表示モード")).font(.caption).foregroundStyle(AppTheme.secondary)
                FocusDisplayModePicker(selection: $displayMode, compact: true)
            }
            Button(action: resume) {
                Label(String(localized: "flight.resume", defaultValue: "航行を再開"), systemImage: "play.fill")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.blue)
            .foregroundStyle(.black)
            Button(role: .destructive, action: end) {
                Text(String(localized: "flight.end_mission", defaultValue: "このミッションを終了"))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red.opacity(0.9))
        }
        .padding(20)
        .frame(maxWidth: 520)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))
        .shadow(color: .black.opacity(0.45), radius: 30, y: 12)
        .padding(20)
    }
}
