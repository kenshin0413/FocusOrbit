import SwiftUI

struct FlightSceneView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let destination: Destination
    var origin: Destination? = nil
    let fallbackProgress: Double
    let scheduledEndAt: Date?
    let totalSeconds: TimeInterval
    let phase: MissionPhase
    let displayMode: FocusDisplayMode
    let isPaused: Bool
    let isActive: Bool
    let darkRoomMode: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AnimatedDeepSpaceView(
                    phase: phase,
                    displayMode: displayMode.resolved,
                    reduceMotion: reduceMotion,
                    darkRoomMode: darkRoomMode,
                    paused: isPaused || !isActive
                )

                if displayMode.resolved != .audioOnly {
                    SmoothCelestialMotionView(
                        destination: destination,
                        origin: origin,
                        fallbackProgress: fallbackProgress,
                        scheduledEndAt: scheduledEndAt,
                        totalSeconds: totalSeconds,
                        isPaused: isPaused,
                        isActive: isActive,
                        cinematicScale: displayMode.resolved == .cinematic ? 1.22 : 1,
                        darkRoomMode: darkRoomMode,
                        reduceMotion: reduceMotion
                    )
                    planetReflection(progress: fallbackProgress)
                    atmosphereVeil(progress: fallbackProgress)
                    if !reduceMotion {
                        AnimatedQuietMeteor(accent: destination.accent, paused: isPaused || !isActive)
                    }
                }

                cockpitLayer(size: proxy.size)

                FinalApproachVisualOverlay(
                    destination: destination,
                    fallbackProgress: fallbackProgress,
                    scheduledEndAt: scheduledEndAt,
                    totalSeconds: totalSeconds,
                    displayMode: displayMode,
                    isPaused: isPaused,
                    isActive: isActive,
                    reduceMotion: reduceMotion
                )

                if displayMode.resolved == .audioOnly {
                    Color(red: 0.002, green: 0.004, blue: 0.009).opacity(0.90)
                }

                if darkRoomMode {
                    Color.black.opacity(0.24).allowsHitTesting(false)
                }
            }
            .background(Color(red: 0.003, green: 0.008, blue: 0.018))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func planetReflection(progress: Double) -> some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: destination.accent.opacity((darkRoomMode ? 0.025 : 0.055) + progress * 0.07), location: 0.52),
                .init(color: .clear, location: 1)
            ],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func atmosphereVeil(progress: Double) -> some View {
        if phase == .atmosphereEntry || phase == .surfaceApproach || phase == .landingPreparation {
            LinearGradient(
                colors: [.clear, destination.accent.opacity(darkRoomMode ? 0.035 : 0.09), .white.opacity(0.025), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(reduceMotion ? 0.42 : 0.72 + sin(progress * 40) * 0.08)
            .blendMode(.screen)
        }
    }

    @ViewBuilder
    private func cockpitLayer(size: CGSize) -> some View {
        if displayMode.resolved == .cockpit {
            ZStack {
                Image("CockpitIntegratedLaunch")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                AnimatedCockpitLighting(
                    accent: destination.accent,
                    reduceMotion: reduceMotion,
                    darkRoomMode: darkRoomMode,
                    paused: isPaused || !isActive
                )
                LinearGradient(
                    colors: [
                        destination.accent.opacity(darkRoomMode ? 0.015 : 0.045),
                        .clear,
                        .white.opacity(darkRoomMode ? 0.008 : 0.018),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)
            }
            .compositingGroup()
        } else if displayMode.resolved == .cinematic {
            Rectangle()
                .fill(RadialGradient(colors: [.clear, .black.opacity(0.52)], center: .center, startRadius: 90, endRadius: max(size.width, size.height) * 0.72))
        } else if displayMode.resolved == .simple {
            LinearGradient(colors: [.black.opacity(0.16), .clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
        }
    }

}

private struct AnimatedDeepSpaceView: View {
    let phase: MissionPhase
    let displayMode: FocusDisplayMode
    let reduceMotion: Bool
    let darkRoomMode: Bool
    let paused: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1 / 30, paused: paused)) { timeline in
            DeepSpaceMotionView(
                time: timeline.date.timeIntervalSinceReferenceDate,
                phase: phase,
                displayMode: displayMode,
                reduceMotion: reduceMotion,
                darkRoomMode: darkRoomMode
            )
        }
    }
}

private struct AnimatedQuietMeteor: View {
    let accent: Color
    let paused: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: paused)) { timeline in
            QuietMeteorView(time: timeline.date.timeIntervalSinceReferenceDate, accent: accent)
        }
    }
}

private struct AnimatedCockpitLighting: View {
    let accent: Color
    let reduceMotion: Bool
    let darkRoomMode: Bool
    let paused: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1 / 15, paused: paused)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                CockpitLampGlow(
                    time: time,
                    accent: accent,
                    reduceMotion: reduceMotion,
                    darkRoomMode: darkRoomMode
                )
                CockpitInstrumentLights(time: time, accent: accent, darkRoomMode: darkRoomMode)
            }
        }
    }
}

private struct FinalApproachVisualOverlay: View {
    let destination: Destination
    let fallbackProgress: Double
    let scheduledEndAt: Date?
    let totalSeconds: TimeInterval
    let displayMode: FocusDisplayMode
    let isPaused: Bool
    let isActive: Bool
    let reduceMotion: Bool

    private var startProgress: Double {
        MissionVisualGeometry.arrivalStartProgress(totalSeconds: totalSeconds)
    }

    private var shouldActivate: Bool {
        displayMode.resolved != .audioOnly && fallbackProgress >= max(0, startProgress - 2 / max(totalSeconds, 1))
    }

    var body: some View {
        if shouldActivate {
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 15 : 1 / 60, paused: isPaused || !isActive)) { timeline in
                let missionProgress = currentProgress(at: timeline.date)
                let arrivalProgress = MissionVisualGeometry.arrivalProgress(
                    missionProgress: missionProgress,
                    totalSeconds: totalSeconds
                )
                if arrivalProgress > 0 {
                    ArrivalVisualScene(
                        destination: destination,
                        progress: arrivalProgress,
                        startingFlightProgress: startProgress,
                        displayMode: displayMode,
                        reduceMotion: reduceMotion
                    )
                    .opacity(MissionVisualGeometry.eased(min(arrivalProgress / 0.12, 1)))
                }
            }
        }
    }

    private func currentProgress(at date: Date) -> Double {
        guard isActive, !isPaused, totalSeconds > 0, let scheduledEndAt else {
            return min(max(fallbackProgress, 0), 1)
        }
        return min(max(1 - scheduledEndAt.timeIntervalSince(date) / totalSeconds, 0), 1)
    }
}

private struct CockpitInstrumentLights: View {
    let time: TimeInterval
    let accent: Color
    let darkRoomMode: Bool

    var body: some View {
        let leftPulse = 0.25 + (sin(time * 1.7) + 1) * 0.13
        let rightPulse = 0.22 + (sin(time * 1.31 + 1.8) + 1) * 0.12
        HStack {
            lightBank(opacity: leftPulse)
            Spacer()
            lightBank(opacity: rightPulse)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 126)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .opacity(darkRoomMode ? 0.48 : 0.82)
        .allowsHitTesting(false)
    }

    private func lightBank(opacity: Double) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == 1 ? Color.cyan : accent)
                    .frame(width: 2.5, height: 9)
                    .shadow(color: accent, radius: 5)
                    .opacity(opacity * (index == 1 ? 1 : 0.7))
            }
        }
    }
}

private struct DeepSpaceMotionView: View {
    let time: TimeInterval
    let phase: MissionPhase
    let displayMode: FocusDisplayMode
    let reduceMotion: Bool
    let darkRoomMode: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.006, green: 0.015, blue: 0.035),
                    Color(red: 0.003, green: 0.006, blue: 0.016),
                    Color(red: 0.001, green: 0.002, blue: 0.006)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.indigo.opacity(darkRoomMode ? 0.004 : 0.009), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 480
            )
            if displayMode != .audioOnly {
                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                    drawStars(context: &context, size: size)
                }
            }
        }
    }

    private func drawStars(context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.38)
        let speed = reduceMotion ? 0 : phase.starFlowSpeed
        let maxRadius = hypot(size.width, size.height) * 0.72
        let count = displayMode == .simple ? 12 : 18
        for index in 0..<count {
            let angle = Double((index * 137 + 29) % 360) * .pi / 180
            let seed = Double((index * 73 + 19) % 101) / 101
            let cycle = speed == 0 ? seed : (seed + time * speed).truncatingRemainder(dividingBy: 1)
            let radius = (0.12 + cycle * 0.88) * maxRadius
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius * 0.78
            let brightness = 0.14 + cycle * 0.22
            let length = phase.starStreakLength * cycle
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))
            context.stroke(path, with: .color(.white.opacity(brightness)), lineWidth: index % 7 == 0 ? 0.75 : 0.42)
        }
    }
}

private struct CockpitLampGlow: View {
    let time: TimeInterval
    let accent: Color
    let reduceMotion: Bool
    let darkRoomMode: Bool

    var body: some View {
        let pulse = reduceMotion ? 0.28 : 0.22 + (sin(time * 0.55) + 1) * 0.06
        HStack {
            lamp
            Spacer()
            lamp
        }
        .padding(.horizontal, 17)
        .padding(.top, 112)
        .frame(maxHeight: .infinity, alignment: .top)
        .opacity(darkRoomMode ? pulse * 0.45 : pulse)
    }

    private var lamp: some View {
        Capsule()
            .fill(accent)
            .frame(width: 3, height: 18)
            .shadow(color: accent, radius: 7)
    }
}

private struct QuietMeteorView: View {
    let time: TimeInterval
    let accent: Color

    var body: some View {
        let cycle = time.truncatingRemainder(dividingBy: 47)
        GeometryReader { proxy in
            if cycle < 1.6 {
                Capsule()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.36), accent.opacity(0.08)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 72, height: 0.7)
                    .rotationEffect(.degrees(-22))
                    .position(
                        x: proxy.size.width * (0.12 + cycle * 0.42),
                        y: proxy.size.height * (0.24 + cycle * 0.08)
                    )
                    .opacity(sin(cycle / 1.6 * .pi) * 0.55)
            }
        }
        .allowsHitTesting(false)
    }
}

private extension MissionPhase {
    var starFlowSpeed: Double {
        switch self {
        case .launch: 0.020
        case .orbitDeparture: 0.010
        case .cruising: 0.0032
        case .approaching: 0.0045
        case .decelerating: 0.0018
        case .atmosphereEntry, .surfaceApproach, .landingPreparation: 0.0012
        case .docking, .orbitalInsertion: 0.0015
        case .landed: 0
        }
    }

    var starStreakLength: CGFloat {
        switch self {
        case .launch: 8
        case .orbitDeparture: 4
        case .cruising, .approaching: 1.6
        default: 0.7
        }
    }

    var cockpitFloatAmplitude: CGFloat {
        switch self {
        case .launch: 1.8
        case .orbitDeparture: 1.1
        case .cruising: 0.65
        case .approaching, .decelerating: 0.85
        case .atmosphereEntry, .surfaceApproach, .landingPreparation: 1.25
        case .docking, .orbitalInsertion: 0.8
        case .landed: 0
        }
    }
}

#Preview("Cockpit Scene") {
    FlightSceneView(
        destination: .mars,
        fallbackProgress: 0.56,
        scheduledEndAt: Date().addingTimeInterval(1_200),
        totalSeconds: 2_700,
        phase: .cruising,
        displayMode: .cockpit,
        isPaused: false,
        isActive: true,
        darkRoomMode: false
    )
}
