import SwiftUI

struct FocusDisplayModePicker: View {
    @Binding var selection: FocusDisplayMode
    var compact = false

    var body: some View {
        LazyVGrid(columns: columns, spacing: 9) {
            ForEach(FocusDisplayMode.selectableCases) { mode in
                Button {
                    selection = mode
                } label: {
                    VStack(spacing: 8) {
                        if !compact { DisplayModePreview(mode: mode) }
                        HStack(spacing: 9) {
                            Image(systemName: mode.symbol).frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.japaneseTitle).font(.caption.weight(.semibold)).lineLimit(1)
                                if !compact {
                                    Text(mode.englishTitle)
                                        .font(OrbitDesign.Typography.spaceLabel)
                                        .tracking(0.8)
                                        .foregroundStyle(AppTheme.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            if selection.resolved == mode {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.blue)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: compact ? 44 : 116)
                    .padding(compact ? 12 : 9)
                    .background(
                        selection.resolved == mode ? AppTheme.blue.opacity(0.13) : AppTheme.panel.opacity(0.68),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selection.resolved == mode ? AppTheme.blue.opacity(0.8) : AppTheme.line)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "focus_display_mode.accessibility_label", defaultValue: "表示モード、\(mode.japaneseTitle)"))
                .accessibilityAddTraits(selection.resolved == mode ? .isSelected : [])
            }
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: compact ? 150 : 160), spacing: 9)]
    }
}

private struct DisplayModePreview: View {
    let mode: FocusDisplayMode

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.01, green: 0.02, blue: 0.05), .black], startPoint: .top, endPoint: .bottom)
            switch mode.resolved {
            case .cockpit:
                Image("CockpitIntegratedReady").resizable().scaledToFill().opacity(0.85)
                CelestialBodyView(kind: .destination(.mars), rotationSpeed: 0)
                    .frame(width: 24, height: 24)
            case .cinematic:
                CelestialBodyView(kind: .destination(.mars), rotationSpeed: 0)
                    .frame(width: 42, height: 42)
                    .shadow(color: .orange, radius: 8)
            case .simple:
                VStack(spacing: 3) {
                    Text("25:00").font(.system(size: 17, weight: .light, design: .rounded)).monospacedDigit()
                    Capsule().fill(AppTheme.blue).frame(width: 54, height: 2)
                }
            case .audioOnly:
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(.white.opacity(0.45))
            case .minimal:
                EmptyView()
            }
        }
        .frame(height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.08)))
        .accessibilityHidden(true)
    }
}

#Preview {
    FocusDisplayModePicker(selection: .constant(.cockpit))
        .padding()
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
}
