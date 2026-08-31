import SwiftUI

enum LaunchVisualPhase {
    case standby, ignition, ascent, orbit
}

struct LaunchVisualScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let phase: LaunchVisualPhase
    let phaseProgress: Double
    let destination: Destination
    let throttlePosition: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                launchExterior(size: proxy.size)

                if phase == .ignition {
                    RadialGradient(
                        colors: [.white.opacity(0.72), .orange.opacity(0.48), .clear],
                        center: .bottom,
                        startRadius: 0,
                        endRadius: proxy.size.width * 0.7
                    )
                    .blendMode(.screen)
                }

                Image("CockpitThrottleBase")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                movableThrottle(size: proxy.size)

                cockpitReflections(size: proxy.size)
                launchInstrumentLights(size: proxy.size)
            }
            .offset(x: shake.width, y: shake.height)
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func launchExterior(size: CGSize) -> some View {
        switch phase {
        case .standby, .ignition:
            Image("LaunchPadExterior")
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .scaleEffect(phase == .ignition ? 1.018 : 1)
        case .ascent:
            ZStack {
                let climb = MissionVisualGeometry.eased(phaseProgress)
                let skyDarkening = MissionVisualGeometry.eased(min(max((phaseProgress - 0.12) / 0.88, 0), 1))
                LinearGradient(
                    colors: [
                        Color(red: 0.035 * (1 - skyDarkening), green: 0.10 * (1 - skyDarkening), blue: 0.22 * (1 - skyDarkening)),
                        Color(red: 0.0863 * (1 - skyDarkening), green: 0.2431 * (1 - skyDarkening), blue: 0.4235 * (1 - skyDarkening)),
                        Color(red: 0.02 * (1 - skyDarkening), green: 0.05 * (1 - skyDarkening), blue: 0.10 * (1 - skyDarkening))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Image("LaunchPadExterior")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(1.02 + climb * 0.10)
                    .offset(y: climb * size.height * 0.64)
                    .opacity(max(0, 1 - MissionVisualGeometry.eased(min(phaseProgress / 0.68, 1))))

                AscentCloudDeck(progress: phaseProgress)

                if phaseProgress > 0.68 {
                    SparseTransitionStars(opacity: (phaseProgress - 0.68) / 0.32, fillsBackground: false)
                }

                if phaseProgress > 0.46 {
                    let insertion = MissionVisualGeometry.eased((phaseProgress - 0.46) / 0.54)
                    CelestialBodyView(kind: .earth)
                        .frame(width: size.width * CGFloat(3.4 - insertion * 2.53))
                        .position(
                            x: size.width * 0.5,
                            y: size.height * CGFloat(0.84 - insertion * 0.09)
                        )
                        .opacity(min(insertion * 1.35, 1))

                    LinearGradient(
                        colors: [.clear, .cyan.opacity(0.05 * insertion), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        case .orbit:
            ZStack {
                SparseTransitionStars(opacity: 1)
                CelestialBodyView(kind: .earth)
                    .frame(width: size.width * 0.87)
                    .position(x: size.width * 0.5, y: size.height * 0.75)

                CelestialBodyView(kind: .destination(destination))
                    .frame(width: MissionVisualGeometry.destinationWidth(destination, progress: 0))
                    .position(x: size.width * 0.5, y: size.height * MissionVisualGeometry.destinationY(destination, progress: 0))
                    .opacity(MissionVisualGeometry.eased(min(max((phaseProgress - 0.28) / 0.72, 0), 1)))
            }
        }
    }

    private var shake: CGSize {
        guard phase == .ignition || phase == .ascent else { return .zero }
        let baseIntensity = phase == .ignition ? 9.5 : max(2.4, 7.2 - phaseProgress * 4.8)
        let intensity = reduceMotion ? baseIntensity * 0.24 : baseIntensity
        return CGSize(
            width: sin(phaseProgress * 196) * intensity,
            height: cos(phaseProgress * 241) * intensity
        )
    }

    private var throttlePull: Double {
        switch phase {
        case .standby: throttlePosition
        case .ignition, .ascent, .orbit: 1
        }
    }

    private func movableThrottle(size: CGSize) -> some View {
        let leverWidth = min(size.width * 0.087, 36)
        let leverHeight = leverWidth * 1.853
        let handleHeight = leverWidth * 0.383
        let pivotX = size.width * 0.5 - 2.5
        let pivotY = size.height * 0.807 - 3
        let angle = throttlePull * 82
        let projectedReach = leverHeight * 0.88 * cos(angle * .pi / 180)
        return ZStack {
            Image("CockpitThrottleStem")
                .resizable()
                .scaledToFit()
                .frame(width: leverWidth, height: leverHeight)
                .rotation3DEffect(
                    .degrees(angle),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .bottom,
                    perspective: 0.72
                )
                .position(x: pivotX, y: pivotY - leverHeight / 2)

            Image("CockpitThrottleHandle")
                .resizable()
                .scaledToFit()
                .frame(width: leverWidth, height: handleHeight)
                .scaleEffect(1 + throttlePull * 0.30)
                .position(x: pivotX, y: pivotY - projectedReach)
                .shadow(color: .black.opacity(0.72), radius: 4 + throttlePull * 3, y: 2 + throttlePull * 3)
        }
        .allowsHitTesting(false)
    }

    private func cockpitReflections(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [.cyan.opacity(phase == .ignition ? 0.12 : 0.035), .clear, .orange.opacity(phase == .ignition ? 0.08 : 0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [.white.opacity(phase == .ignition ? 0.08 : 0.018), .clear],
                center: .bottom,
                startRadius: 0,
                endRadius: size.width * 0.9
            )
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    private func launchInstrumentLights(size: CGSize) -> some View {
        let ignition = phase == .ignition ? min(phaseProgress * 2.2, 1) : 0
        let stable = phase == .ascent || phase == .orbit
        return HStack {
            launchLightBank(activeCount: stable ? 4 : Int(ceil(ignition * 4)))
            Spacer()
            launchLightBank(activeCount: stable ? 4 : Int(ceil(ignition * 4)))
        }
        .padding(.horizontal, 21)
        .padding(.bottom, 128)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }

    private func launchLightBank(activeCount: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index < activeCount ? (phase == .ignition ? Color.orange : Color.cyan) : Color.white.opacity(0.08))
                    .frame(width: 2.5, height: 10)
                    .shadow(color: phase == .ignition ? .orange : .cyan, radius: index < activeCount ? 6 : 0)
            }
        }
    }
}

struct ArrivalVisualScene: View {
    let destination: Destination
    let progress: Double
    let startingFlightProgress: Double
    var displayMode: FocusDisplayMode = .cockpit
    var reduceMotion = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SparseTransitionStars(opacity: max(0.08, 1 - surfaceTransition))

                CelestialBodyView(kind: .destination(destination))
                    .frame(width: destinationRenderSize(proxy.size), height: destinationRenderSize(proxy.size))
                    .scaleEffect(destinationSize(proxy.size) / destinationRenderSize(proxy.size))
                    .position(destinationPosition(in: proxy.size))
                    .opacity(1 - surfaceTransition)

                if destination == .moon {
                    surfaceView(name: "MoonSurfaceNASA", size: proxy.size)
                } else if destination == .mars {
                    surfaceView(name: "MarsSurfaceNASA", size: proxy.size)
                } else if destination == .pluto {
                    plutoSurfaceView(size: proxy.size)
                }

                if destination == .station {
                    dockingGuides(size: proxy.size)
                    DockingCaptureView(progress: progress)
                        .position(x: proxy.size.width * 0.5, y: proxy.size.height * dockingTargetY)
                    dockedInterior(size: proxy.size)
                }

                if destination.isOrbitalDestination {
                    OrbitalInsertionView(progress: progress, accent: destination.accent)
                        .position(x: proxy.size.width * 0.56, y: proxy.size.height * 0.45)
                }

                if isSurfaceLanding && progress > 0.985 {
                    LandingDust(progress: (progress - 0.985) / 0.015, color: destination == .mars ? .orange : .gray)
                }

                if displayMode.resolved == .cockpit {
                    Image("CockpitIntegratedLaunch")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .offset(y: landingShake)
                } else if displayMode.resolved == .cinematic {
                    RadialGradient(colors: [.clear, .black.opacity(0.48)], center: .center, startRadius: 80, endRadius: max(proxy.size.width, proxy.size.height) * 0.72)
                } else if displayMode.resolved == .audioOnly {
                    Color.black.opacity(0.88)
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    private var isSurfaceLanding: Bool { destination.isSurfaceDestination }
    private var surfaceTransition: Double {
        guard isSurfaceLanding else { return 0 }
        return MissionVisualGeometry.eased(min(max((progress - 0.02) / 0.92, 0), 1))
    }
    private func destinationSize(_ size: CGSize) -> CGFloat {
        let widthScale = min(max(min(size.width, size.height * 0.9) / 390, 0.82), 1.75)
        let modeScale: CGFloat = displayMode.resolved == .cinematic ? 1.22 : 1
        let lateScale = 1 + CGFloat(MissionVisualGeometry.eased(min(max((startingFlightProgress - 0.88) / 0.12, 0), 1))) * 0.42
        let initial = MissionVisualGeometry.destinationWidth(destination, progress: startingFlightProgress) * widthScale * modeScale * lateScale
        if destination.isOrbitalDestination {
            let finalWidth = min(size.width * (destination == .saturn ? 1.02 : 0.72), size.height * 0.58)
            return initial + (max(finalWidth, initial) - initial) * CGFloat(MissionVisualGeometry.eased(progress))
        }
        if destination == .station { return initial + CGFloat(pow(progress, 8) * 2_200) }
        return initial + CGFloat(pow(progress, 1.7) * 700)
    }
    private func destinationRenderSize(_ size: CGSize) -> CGFloat {
        let widthScale = min(max(min(size.width, size.height * 0.9) / 390, 0.82), 1.75)
        return (destination == .station ? 1_000 : 900) * widthScale
    }
    private var destinationY: CGFloat {
        if destination == .station { return dockingTargetY }
        if isSurfaceLanding { return CGFloat(0.26 + MissionVisualGeometry.eased(progress) * 0.22) }
        if destination.isOrbitalDestination { return CGFloat(0.35 + MissionVisualGeometry.eased(progress) * 0.08) }
        return CGFloat(0.342 + MissionVisualGeometry.eased(progress) * 0.22)
    }
    private var destinationX: CGFloat {
        guard destination.isOrbitalDestination else { return 0.5 }
        return CGFloat(0.5 - MissionVisualGeometry.eased(progress) * 0.15)
    }

    private func destinationPosition(in size: CGSize) -> CGPoint {
        guard destination == .station else {
            return CGPoint(x: size.width * destinationX, y: size.height * destinationY)
        }
        // The source port center is 1.4% above the bitmap center.
        let rendered = destinationSize(size)
        return CGPoint(
            x: size.width * 0.5,
            y: size.height * dockingTargetY + rendered * 0.014
        )
    }

    private var dockingTargetY: CGFloat { 0.42 }

    private func surfaceView(name: String, size: CGSize) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .scaleEffect(0.84 + surfaceTransition * 0.28, anchor: .bottom)
            .offset(y: surfaceVerticalOffset(size: size) + touchdownBounce)
            .opacity(surfaceTransition)
            .saturation(0.92 + surfaceTransition * 0.16)
            .contrast(0.95 + surfaceTransition * 0.11)
            .blur(radius: max(0, CGFloat(1 - surfaceTransition) * 4.0))
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: max(0, 0.66 - surfaceTransition * 0.52)),
                        .init(color: .white, location: min(1, 0.84 - surfaceTransition * 0.42)),
                        .init(color: .white, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private func plutoSurfaceView(size: CGSize) -> some View {
        Image("PlutoSurfaceNASA")
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
            .scaleEffect(1.02 + surfaceTransition * 0.08)
            .opacity(surfaceTransition)
            .saturation(0.92 + surfaceTransition * 0.16)
            .contrast(0.95 + surfaceTransition * 0.11)
            .blur(radius: max(0, CGFloat(1 - surfaceTransition) * 2.1))
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.08), .clear, .black.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }

    private func surfaceVerticalOffset(size: CGSize) -> CGFloat {
        CGFloat((1 - surfaceTransition) * size.height * 0.68)
    }

    private var touchdownBounce: CGFloat {
        guard !reduceMotion, isSurfaceLanding, progress > 0.965 else { return 0 }
        let local = min((progress - 0.965) / 0.035, 1)
        return CGFloat(sin(local * .pi * 3) * exp(-local * 4) * 7)
    }

    private var landingShake: CGFloat {
        guard !reduceMotion, progress > 0.93, progress < 1 else { return 0 }
        let local = (progress - 0.93) / 0.07
        return CGFloat(sin(local * .pi * 12) * (1 - local) * 1.8)
    }

    private func dockingGuides(size: CGSize) -> some View {
        ZStack {
            Circle().stroke(.cyan.opacity(0.22), style: StrokeStyle(lineWidth: 0.7, dash: [4, 10]))
                .frame(width: CGFloat(max(64, 188 - progress * 124)))
            Rectangle().fill(.cyan.opacity(0.28)).frame(width: 1, height: size.height * 0.22)
            Rectangle().fill(.cyan.opacity(0.28)).frame(width: size.width * 0.32, height: 1)
        }
        .position(x: size.width * 0.5, y: size.height * dockingTargetY)
    }

    private func dockedInterior(size: CGSize) -> some View {
        let lock = MissionVisualGeometry.eased(min(max((progress - 0.955) / 0.045, 0), 1))
        return Image("StationDockedInterior")
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .scaleEffect(1.08 - lock * 0.08)
            .offset(y: -size.height * 0.07)
            .opacity(lock)
            .overlay {
                Color.white.opacity(sin(lock * .pi) * 0.055)
                    .blendMode(.screen)
            }
            .allowsHitTesting(false)
    }
}

private struct SparseTransitionStars: View {
    let opacity: Double
    var fillsBackground = true

    var body: some View {
        Canvas(opaque: fillsBackground, colorMode: .linear, rendersAsynchronously: true) { context, size in
            if fillsBackground {
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            }
            for index in 0..<18 {
                let x = CGFloat((index * 431 + 59) % 997) / 997 * size.width
                let y = CGFloat((index * 677 + 31) % 991) / 991 * size.height * 0.74
                let radius: CGFloat = index % 6 == 0 ? 0.8 : 0.4
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)), with: .color(.white.opacity(opacity * (index % 5 == 0 ? 0.46 : 0.23))))
            }
        }
    }
}

private struct DockingCaptureView: View {
    let progress: Double

    var body: some View {
        let capture = min(max((progress - 0.38) / 0.62, 0), 1)
        ZStack {
            Circle()
                .stroke(.cyan.opacity(0.12 + capture * 0.32), lineWidth: 1)
                .frame(width: CGFloat(150 - capture * 78))
            Circle()
                .stroke(.white.opacity(capture * 0.55), lineWidth: 1.2)
                .frame(width: CGFloat(62 - capture * 22))
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(.cyan.opacity(0.2 + capture * 0.55))
                    .frame(width: 28, height: 2)
                    .offset(x: CGFloat(58 - capture * 34))
                    .rotationEffect(.degrees(Double(index) * 90))
            }
            if progress >= 0.995 {
                ZStack {
                    Circle().stroke(.green.opacity(0.9), lineWidth: 2).frame(width: 62, height: 62)
                        .shadow(color: .green, radius: 8)
                    Circle().stroke(.white.opacity(0.7), lineWidth: 1).frame(width: 48, height: 48)
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(.green.opacity(0.9))
                            .frame(width: 18, height: 4)
                            .offset(x: 34)
                            .rotationEffect(.degrees(Double(index) * 90))
                    }
                }
            }
        }
        .opacity(capture)
    }
}

private struct OrbitalInsertionView: View {
    let progress: Double
    let accent: Color

    var body: some View {
        let insertion = MissionVisualGeometry.eased(min(max((progress - 0.55) / 0.45, 0), 1))
        let angle = Angle.degrees(-205 + insertion * 305)
        return ZStack {
            Circle()
                .trim(from: 0.08, to: 0.08 + insertion * 0.72)
                .stroke(accent.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [7, 9]))
                .frame(width: 270, height: 116)
                .rotationEffect(.degrees(-12))
            Circle()
                .fill(insertion >= 0.99 ? Color.green : accent)
                .frame(width: insertion >= 0.99 ? 7 : 5, height: insertion >= 0.99 ? 7 : 5)
                .offset(
                    x: CGFloat(cos(angle.radians) * 132),
                    y: CGFloat(sin(angle.radians) * 54)
                )
                .shadow(color: accent, radius: 5)
            if insertion > 0.88 {
                Text(insertion >= 0.99 ? "周回軌道を確立" : "軌道投入中")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.46), in: Capsule())
                    .offset(y: 78)
            }
        }
        .opacity(insertion)
    }
}

private struct AscentCloudDeck: View {
    let progress: Double

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            guard progress > 0.12 && progress < 0.70 else { return }
            for index in 0..<8 {
                let local = (progress * 3.4 + Double(index) * 0.14).truncatingRemainder(dividingBy: 1)
                let width = size.width * CGFloat(1.2 + local * 0.55)
                let rect = CGRect(x: (size.width - width) / 2, y: size.height * CGFloat(local), width: width, height: 44 + CGFloat(local * 34))
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.025 + (1 - local) * 0.035)))
            }
        }
        .blur(radius: 12)
    }
}

private struct LandingDust: View {
    let progress: Double
    let color: Color

    var body: some View {
        let plume = MissionVisualGeometry.eased(min(max(progress, 0), 1))
        GeometryReader { proxy in
            ZStack {
                RadialGradient(
                    colors: [color.opacity(0.16 * plume), color.opacity(0.72 * plume), .clear],
                    center: UnitPoint(x: 0.5, y: 0.62),
                    startRadius: 12,
                    endRadius: CGFloat(120 + progress * 190)
                )
                Canvas(rendersAsynchronously: true) { context, size in
                    for index in 0..<22 {
                        let seed = Double((index * 47 + 13) % 97) / 97
                        let spread = CGFloat((seed - 0.5) * progress) * size.width * 1.15
                        let rise = CGFloat(progress * (0.08 + seed * 0.2)) * size.height
                        let diameter = CGFloat(2.5 + seed * 8) * CGFloat(plume)
                        let rect = CGRect(
                            x: size.width * 0.5 + spread - diameter / 2,
                            y: size.height * 0.66 - rise - diameter,
                            width: diameter,
                            height: diameter * 0.55
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.16 + plume * 0.28)))
                    }
                }
                .blur(radius: 2.5)
            }
        }
        .blur(radius: 4)
        .blendMode(.screen)
    }
}
