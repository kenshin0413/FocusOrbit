import SwiftUI

struct PomodoroSetupView: View {
    @Bindable var model: MissionSetupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Toggle(isOn: $model.usesPomodoro) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "pomodoro.use", defaultValue: "ポモドーロを使う")).font(.subheadline.weight(.semibold))
                    Text(String(localized: "pomodoro.use.detail", defaultValue: "集中と休憩を1セットとして管理します")).font(.caption2).foregroundStyle(AppTheme.secondary)
                }
            }
            .onChange(of: model.usesPomodoro) { _, enabled in
                if enabled { model.applyPomodoroPreset(model.pomodoroPreset) }
            }
            if model.usesPomodoro {
                Picker(String(localized: "pomodoro.preset", defaultValue: "ポモドーロ設定"), selection: $model.pomodoroPreset) {
                    ForEach(PomodoroPreset.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.pomodoroPreset) { _, preset in model.applyPomodoroPreset(preset) }

                if model.pomodoroPreset == .custom {
                    settingPicker(String(localized: "pomodoro.break_duration", defaultValue: "休憩時間"), selection: $model.breakMinutes, range: 1...60, suffix: String(localized: "common.minutes_suffix", defaultValue: "分"))
                    Stepper(String(localized: "pomodoro.cycle_count", defaultValue: "繰り返し \(model.cycleCount)回"), value: $model.cycleCount, in: 1...8)
                    Toggle(String(localized: "pomodoro.use_long_break", defaultValue: "長い休憩を使う"), isOn: $model.longBreakEnabled)
                    if model.longBreakEnabled {
                        settingPicker(String(localized: "pomodoro.long_break", defaultValue: "長い休憩"), selection: $model.longBreakMinutes, range: 5...60, suffix: String(localized: "common.minutes_suffix", defaultValue: "分"))
                    }
                } else {
                    HStack {
                        Label(String(localized: "pomodoro.focus_duration", defaultValue: "集中 \(model.durationMinutes)分"), systemImage: "timer")
                        Spacer()
                        Label(String(localized: "pomodoro.break_duration_value", defaultValue: "休憩 \(model.breakMinutes)分"), systemImage: "cup.and.saucer")
                    }.font(.caption).foregroundStyle(AppTheme.secondary)
                }

                Divider()
                Toggle(String(localized: "pomodoro.auto_start_break", defaultValue: "休憩を自動開始"), isOn: $model.automaticallyStartBreak)
                Toggle(String(localized: "pomodoro.auto_start_focus", defaultValue: "次の集中を自動開始"), isOn: $model.automaticallyStartNextFocus)
                Text(String(localized: "pomodoro.default_behavior", defaultValue: "初期設定では、完了後に自分で休憩を開始します"))
                    .font(.caption2).foregroundStyle(AppTheme.secondary)
            }
        }
        .spacePanel()
    }

    private func settingPicker(_ title: String, selection: Binding<Int>, range: ClosedRange<Int>, suffix: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(Array(range), id: \.self) { Text(String(localized: "pomodoro.setting_picker_value", defaultValue: "\($0)\(suffix)")).tag($0) }
            }
            .labelsHidden()
        }
    }
}
