import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    let router: AppRouter; let profile: CrewProfile?; let settings: AppSettings?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(title: String(localized: "settings.title", defaultValue: "設定"), subtitle: "SYSTEM PREFERENCES") { router.returnHome() }
                controlSummary
                settingsSection(String(localized: "settings.profile", defaultValue: "プロフィール"), english: "CREW PROFILE", symbol: "person.text.rectangle") {
                    if let profile {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) { Text(String(localized: "settings.crew_name", defaultValue: "クルー名")); Text(String(localized: "settings.crew_name.detail", defaultValue: "航行パスと記録に表示されます")).font(.caption2).foregroundStyle(AppTheme.secondary) }
                            Spacer()
                            TextField(String(localized: "settings.crew_name.placeholder", defaultValue: "CREW"), text: Bindable(profile).crewName).multilineTextAlignment(.trailing).textInputAutocapitalization(.characters).frame(maxWidth: 150)
                        }
                    }
                }
                settingsSection(String(localized: "settings.audio", defaultValue: "音とアナウンス"), english: "CABIN AUDIO", symbol: "waveform") {
                    if let settings {
                        Toggle(isOn: Bindable(settings).ambientSoundEnabled) { settingLabel(String(localized: "settings.ambient_sound", defaultValue: "環境音"), String(localized: "settings.ambient_sound.detail", defaultValue: "エンジン音と船内の空調音")) }
                        Divider()
                        Toggle(isOn: Bindable(settings).voiceAnnouncementsEnabled) { settingLabel(String(localized: "settings.voice_announcements", defaultValue: "音声アナウンス"), String(localized: "settings.voice_announcements.detail", defaultValue: "発射・航行・到着時の客室案内")) }
                        if settings.voiceAnnouncementsEnabled {
                            Divider()
                            Button {
                                AnnouncementService.shared.speak(
                                    String(localized: "settings.voice_announcements.preview_message", defaultValue: "ご搭乗ありがとうございます。音声案内のテストです。"),
                                    clipName: "cabin_cruise",
                                    chime: true,
                                    enabled: true
                                )
                            } label: {
                                HStack { Label(String(localized: "settings.voice_announcements.preview", defaultValue: "アナウンスを試聴"), systemImage: "play.circle"); Spacer(); Text(String(localized: "common.play", defaultValue: "再生")).font(.caption).foregroundStyle(AppTheme.blue) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                settingsSection(String(localized: "settings.notifications", defaultValue: "通知"), english: "NOTIFICATIONS", symbol: "bell") {
                    if let settings {
                        Toggle(isOn: Bindable(settings).completionNotificationEnabled) { settingLabel(String(localized: "settings.completion_notification", defaultValue: "終了通知"), String(localized: "settings.completion_notification.detail", defaultValue: "目的地へ到着したときだけ通知")) }
                            .onChange(of: settings.completionNotificationEnabled) { _, enabled in if enabled { Task { await NotificationService.shared.requestAuthorization() } } }
                    }
                }
                settingsSection(String(localized: "settings.display", defaultValue: "表示と演出"), english: "FLIGHT DISPLAY", symbol: "rectangle.inset.filled") {
                    if let settings {
                        VStack(alignment: .leading, spacing: 10) {
                            settingLabel(String(localized: "settings.display_mode", defaultValue: "標準表示モード"), String(localized: "settings.display_mode.detail", defaultValue: "集中開始前に選択できます"))
                            FocusDisplayModePicker(selection: displayModeBinding(settings), compact: true)
                        }
                        Divider()
                        Toggle(isOn: Bindable(settings).detailedFlightDataEnabled) {
                            settingLabel(String(localized: "settings.detailed_flight_data", defaultValue: "詳細航行データ"), String(localized: "settings.detailed_flight_data.detail", defaultValue: "到着予定、距離、経過時間を数値表示"))
                        }
                        Divider()
                        Toggle(isOn: Bindable(settings).darkRoomModeEnabled) {
                            settingLabel(String(localized: "settings.dark_room_mode", defaultValue: "暗室表示"), String(localized: "settings.dark_room_mode.detail", defaultValue: "夜間向けに反射光と表示輝度を抑えます"))
                        }
                        Divider()
                        Toggle(isOn: Bindable(settings).hapticsEnabled) {
                            settingLabel(String(localized: "settings.haptics", defaultValue: "触覚フィードバック"), String(localized: "settings.haptics.detail", defaultValue: "発進・軌道投入・到着時のみ使用"))
                        }
                    }
                }
                settingsSection(String(localized: "settings.launch_sequence", defaultValue: "開始演出"), english: "LAUNCH SEQUENCE", symbol: "bolt.fill") {
                    if let settings {
                        Toggle(isOn: Bindable(settings).shortenLaunchSequence) {
                            settingLabel(String(localized: "settings.launch_sequence.shorten", defaultValue: "2回目以降は短縮"), String(localized: "settings.launch_sequence.shorten.detail", defaultValue: "3・2・1から約2秒の上昇演出へ進みます"))
                        }
                        Divider()
                        Toggle(isOn: Bindable(settings).skipLaunchSequence) {
                            settingLabel(String(localized: "settings.launch_sequence.skip", defaultValue: "開始演出をスキップ"), String(localized: "settings.launch_sequence.skip.detail", defaultValue: "パス認証後、すぐに集中を開始します"))
                        }
                    }
                }
                settingsSection(String(localized: "settings.weekly_goal", defaultValue: "週間目標"), english: "WEEKLY GOAL", symbol: "scope") {
                    if let settings {
                        Toggle(isOn: Bindable(settings).weeklyGoalEnabled) {
                            settingLabel(String(localized: "settings.weekly_goal.show", defaultValue: "週間目標を表示"), String(localized: "settings.weekly_goal.show.detail", defaultValue: "ホームと集中記録に進捗を表示します"))
                        }
                        if settings.weeklyGoalEnabled {
                            Divider()
                            Picker(String(localized: "settings.weekly_goal.target_time", defaultValue: "目標時間"), selection: Bindable(settings).weeklyFocusGoalMinutes) {
                                ForEach([60, 90, 120, 150, 180, 240, 300, 420, 600], id: \.self) { minutes in
                                    Text(String(localized: "settings.weekly_goal.minutes", defaultValue: "週\(minutes)分")).tag(minutes)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                Button {
                    router.show(.introduction)
                } label: {
                    HStack {
                        Label(String(localized: "settings.show_introduction", defaultValue: "アプリの使い方をもう一度見る"), systemImage: "sparkles.rectangle.stack")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(AppTheme.secondary)
                    }
                    .spacePanel()
                }
                .buttonStyle(.plain)
                Text("Planet imagery: NASA / NASA JPL-Caltech / USGS").font(.caption2).foregroundStyle(.secondary)
                Text("FOCUS ORBIT  1.0.0").font(.caption2).tracking(1.5).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 30)
            }
            .padding(20)
            .padding(.bottom, 110)
        }.onDisappear { try? context.save() }
    }

    @ViewBuilder private var controlSummary: some View {
        if let settings {
            VStack(alignment: .leading, spacing: 14) {
                Text("CONTROL STATUS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.blue)
                Text(String(localized: "settings.control_summary.title", defaultValue: "集中を邪魔しない設定だけをここに集約"))
                    .font(.headline)
                Text(String(localized: "settings.control_summary.detail", defaultValue: "音声、触覚、通知、開始演出の状態を一目で確認できます"))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondary)
                HStack(spacing: 10) {
                    summaryChip(String(localized: "settings.summary.voice", defaultValue: "音声"), enabled: settings.voiceAnnouncementsEnabled)
                    summaryChip(String(localized: "settings.summary.haptics", defaultValue: "触覚"), enabled: settings.hapticsEnabled)
                    summaryChip(String(localized: "settings.summary.notifications", defaultValue: "通知"), enabled: settings.completionNotificationEnabled)
                    summaryChip(String(localized: "settings.summary.short_launch", defaultValue: "短縮開始"), enabled: settings.shortenLaunchSequence)
                }
            }
            .spacePanel()
        }
    }

    private func settingsSection<Content: View>(_ title: String, english: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(AppTheme.blue)
                Text(title).font(.headline)
                Spacer()
                Text(english).font(.system(size: 7, design: .monospaced)).tracking(1).foregroundStyle(AppTheme.secondary)
            }
            VStack(spacing: 16) { content() }.spacePanel()
        }
    }

    private func settingLabel(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
            Text(detail).font(.caption2).foregroundStyle(AppTheme.secondary)
        }
    }

    private func displayModeBinding(_ settings: AppSettings) -> Binding<FocusDisplayMode> {
        Binding(
            get: { settings.flightDisplayMode },
            set: { settings.flightDisplayMode = $0; try? context.save() }
        )
    }

    private func summaryChip(_ title: String, enabled: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "minus.circle")
            Text(title)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background((enabled ? AppTheme.success : .white).opacity(enabled ? 0.14 : 0.05), in: Capsule())
        .overlay(Capsule().stroke((enabled ? AppTheme.success : .white).opacity(enabled ? 0.22 : 0.08)))
        .foregroundStyle(enabled ? AppTheme.success : AppTheme.secondary)
    }
}
