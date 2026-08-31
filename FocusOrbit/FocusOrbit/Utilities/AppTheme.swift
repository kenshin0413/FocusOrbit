import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.015, green: 0.025, blue: 0.055)
    static let panel = Color(red: 0.035, green: 0.06, blue: 0.105)
    static let panelElevated = Color(red: 0.05, green: 0.085, blue: 0.145)
    static let line = Color(red: 0.30, green: 0.55, blue: 0.78).opacity(0.35)
    static let blue = Color(red: 0.42, green: 0.72, blue: 1.0)
    static let secondary = Color(red: 0.63, green: 0.70, blue: 0.80)
    static let navigation = Color(red: 0.42, green: 0.72, blue: 1.0)
    static let transit = Color(red: 0.38, green: 0.84, blue: 0.96)
    static let destination = Color(red: 0.94, green: 0.50, blue: 0.29)
    static let success = Color(red: 0.35, green: 0.82, blue: 0.55)
    static let warning = Color(red: 0.94, green: 0.32, blue: 0.32)
}

enum OrbitDesign {
    enum Spacing {
        static let screenHorizontal: CGFloat = 20
        static let card: CGFloat = 12
        static let section: CGFloat = 24
        static let compact: CGFloat = 8
    }

    enum Radius {
        static let largeCard: CGFloat = 18
        static let smallCard: CGFloat = 12
        static let button: CGFloat = 14
    }

    enum Size {
        static let primaryButtonHeight: CGFloat = 54
        static let minimumTap: CGFloat = 44
        static let contentMaxWidth: CGFloat = 760
    }

    enum Typography {
        static let largeMetric = Font.system(size: 42, weight: .light, design: .rounded)
        static let sectionTitle = Font.headline
        static let body = Font.body
        static let caption = Font.caption
        static let spaceLabel = Font.system(size: 8, weight: .medium, design: .monospaced)
    }
}

struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: OrbitDesign.Radius.largeCard, style: .continuous)
        content
            .padding(16)
            .background(
                ZStack {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.panelElevated.opacity(0.96), AppTheme.panel.opacity(0.86)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    shape
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.09), .clear],
                                center: .topLeading,
                                startRadius: 8,
                                endRadius: 220
                            )
                        )
                        .blendMode(.screen)
                }
            )
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.16), AppTheme.line, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 10)
    }
}

extension View {
    func spacePanel() -> some View { modifier(PanelModifier()) }
}
