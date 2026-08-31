import ActivityKit
import SwiftUI
import WidgetKit

struct FocusOrbitLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusOrbitActivityAttributes.self) { context in
            LockScreenMissionView(context: context)
                .activityBackgroundTint(Color(red: 0.015, green: 0.025, blue: 0.055))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("目的地").font(.caption2).foregroundStyle(.secondary)
                        Text(context.attributes.destinationName).font(.caption).fontWeight(.semibold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownView(state: context.state, compact: true)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phaseJapanese).font(.caption).fontWeight(.medium)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(value: context.state.progress)
                            .tint(.cyan)
                        HStack {
                            Text(context.state.phaseEnglish).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(context.state.progress * 100))%").font(.caption2).monospacedDigit()
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "location.north.fill")
                    .foregroundStyle(context.state.isPaused ? .orange : .cyan)
            } compactTrailing: {
                CountdownView(state: context.state, compact: true)
            } minimal: {
                ZStack {
                    Circle().stroke(.white.opacity(0.2), lineWidth: 2)
                    Circle().trim(from: 0, to: context.state.progress).stroke(.cyan, lineWidth: 2).rotationEffect(.degrees(-90))
                    Image(systemName: context.state.isPaused ? "pause.fill" : "location.north.fill").font(.system(size: 8))
                }
            }
            .widgetURL(URL(string: "focusorbit://session/\(context.attributes.sessionID.uuidString)"))
            .keylineTint(.cyan)
        }
    }
}

private struct LockScreenMissionView: View {
    let context: ActivityViewContext<FocusOrbitActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.cyan.opacity(0.12))
                Image(systemName: context.state.isPaused ? "pause.fill" : "location.north.fill")
                    .foregroundStyle(context.state.isPaused ? .orange : .cyan)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.destinationName).font(.headline)
                Text(context.state.phaseJapanese).font(.caption).foregroundStyle(.secondary)
                ProgressView(value: context.state.progress).tint(.cyan)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                CountdownView(state: context.state, compact: false)
                Text(context.state.phaseEnglish).font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}

private struct CountdownView: View {
    let state: FocusOrbitActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        Group {
            if state.isPaused {
                Text(formatted(state.remainingAtPause))
            } else {
                Text(timerInterval: Date.now...max(state.scheduledEndAt, Date.now), countsDown: true)
            }
        }
        .font(compact ? .caption2.monospacedDigit() : .title3.monospacedDigit())
        .foregroundStyle(state.isPaused ? .orange : .primary)
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let value = max(Int(seconds.rounded(.up)), 0)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
