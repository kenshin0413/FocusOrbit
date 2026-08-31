import SwiftUI

struct FocusDurationPicker: View {
    @Binding var selection: Int
    let savedDurations: [Int]
    @State private var showingCustomPicker = false
    @State private var draftHours = 0
    @State private var draftMinutes = 25

    var body: some View {
        VStack(spacing: 10) {
            if !savedDurations.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(savedDurations, id: \.self) { minutes in
                        durationButton(minutes)
                    }
                }
            }
            Button {
                syncDraftWithSelection()
                showingCustomPicker = true
            } label: {
                HStack {
                    Label(String(localized: "duration_picker.custom", defaultValue: "カスタム時間"), systemImage: "dial.medium")
                    Spacer()
                    Text(formattedDuration(selection)).monospacedDigit().foregroundStyle(AppTheme.blue)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(AppTheme.secondary)
                }
                .frame(minHeight: OrbitDesign.Size.minimumTap)
                .padding(.horizontal, 14)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: OrbitDesign.Radius.smallCard))
                .overlay(RoundedRectangle(cornerRadius: OrbitDesign.Radius.smallCard).stroke(AppTheme.line))
            }
            .buttonStyle(.plain)
        }
        .onAppear(perform: syncDraftWithSelection)
        .sheet(isPresented: $showingCustomPicker) {
            NavigationStack {
                VStack {
                    HStack(spacing: 0) {
                        Picker(String(localized: "common.hours", defaultValue: "時間"), selection: $draftHours) {
                            ForEach(0...12, id: \.self) { value in
                                Text(LocalizedRuntime.text(ja: "\(value)時間", en: "\(value) hr")).tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker(String(localized: "common.minutes", defaultValue: "分"), selection: $draftMinutes) {
                            ForEach(0...59, id: \.self) { value in
                                Text(LocalizedRuntime.text(ja: "\(value)分", en: "\(value) min")).tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: draftHours) { _, _ in applyDraftSelection() }
                    .onChange(of: draftMinutes) { _, _ in applyDraftSelection() }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(String(localized: "duration_picker.accessibility_label", defaultValue: "カスタム集中時間"))
                }
                .navigationTitle(String(localized: "duration_picker.title", defaultValue: "集中時間を選択"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.confirm", defaultValue: "決定")) {
                            applyDraftSelection()
                            showingCustomPicker = false
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func syncDraftWithSelection() {
        draftHours = selection / 60
        draftMinutes = selection % 60
        if draftHours == 0 && draftMinutes == 0 {
            draftMinutes = 1
        }
    }

    private func applyDraftSelection() {
        let totalMinutes = (draftHours * 60) + draftMinutes
        selection = max(totalMinutes, 1)
    }

    private func formattedDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 && remainder > 0 {
            return LocalizedRuntime.text(ja: "\(hours)時間\(remainder)分", en: "\(hours) h \(remainder) min")
        }
        if hours > 0 {
            return LocalizedRuntime.text(ja: "\(hours)時間", en: "\(hours) h")
        }
        return LocalizedRuntime.text(ja: "\(remainder)分", en: "\(remainder) min")
    }

    private func durationButton(_ minutes: Int) -> some View {
        let selected = selection == minutes
        return Button { selection = minutes } label: {
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Text(formattedDuration(minutes)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    if selected { Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(AppTheme.blue) }
                }
                Text(String(localized: "common.saved", defaultValue: "保存済み")).font(.system(size: 8, weight: .medium)).foregroundStyle(AppTheme.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(selected ? AppTheme.blue.opacity(0.15) : AppTheme.panel, in: RoundedRectangle(cornerRadius: OrbitDesign.Radius.smallCard))
            .overlay(RoundedRectangle(cornerRadius: OrbitDesign.Radius.smallCard).stroke(selected ? AppTheme.blue : AppTheme.line, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(formattedDuration(minutes))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
