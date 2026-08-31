import SwiftUI

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var coreVisible = false
    @State private var corePulse = false
    @State private var primaryOrbitVisible = false
    @State private var primaryOrbitRotation = -28.0
    @State private var primaryTracerProgress = 0.02
    @State private var secondaryOrbitVisible = false
    @State private var secondaryOrbitRotation = 22.0
    @State private var secondaryTracerProgress = 0.02
    @State private var titleVisible = false
    @State private var animationToken = UUID()

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 380

            ZStack {
                backgroundLayer
                dustLayer
                centerBloom(compact: compact)
                orbitLayer(compact: compact)
                titleLayer(compact: compact)
                lowerFalloff
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            animationToken = UUID()
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.004, green: 0.008, blue: 0.022),
                    Color(red: 0.008, green: 0.014, blue: 0.038),
                    Color(red: 0.003, green: 0.005, blue: 0.016)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [AppTheme.blue.opacity(0.24), AppTheme.blue.opacity(0.05), .clear],
                center: .init(x: 0.5, y: 0.38),
                startRadius: 0,
                endRadius: 340
            )

            LinearGradient(
                colors: [.clear, .white.opacity(0.045), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 150)
            .rotationEffect(.degrees(-22))
            .blur(radius: 24)
            .offset(x: 66, y: -54)
        }
    }

    private var dustLayer: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 12 : 1 / 30)) { timeline in
            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.37)

                for index in 0..<18 {
                    let seed = Double((index * 59) % 149) / 149.0
                    let angle = seed * .pi * 2 + t * (0.05 + seed * 0.03)
                    let radius = 110.0 + Double(index * 11 % 100)
                    let x = center.x + cos(angle) * radius
                    let y = center.y + sin(angle) * radius * 0.68
                    let rect = CGRect(x: x, y: y, width: 1.2, height: 1.2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.10 + seed * 0.18)))
                }
            }
        }
    }

    private func centerBloom(compact: Bool) -> some View {
        let bloomSize = compact ? 214.0 : 268.0
        let ringSize = compact ? 78.0 : 92.0
        let coreSize = compact ? 12.0 : 14.0

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.blue.opacity(0.52), AppTheme.blue.opacity(0.14), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: bloomSize / 2
                    )
                )
                .frame(width: bloomSize, height: bloomSize)
                .blur(radius: 26)
                .scaleEffect(coreVisible ? (corePulse ? 1.08 : 0.84) : 0.12)
                .opacity(coreVisible ? 1 : 0)

            Circle()
                .stroke(.white.opacity(0.10), lineWidth: 1)
                .frame(width: ringSize, height: ringSize)
                .scaleEffect(coreVisible ? 1 : 0.4)
                .opacity(coreVisible ? 1 : 0)

            Circle()
                .fill(.white.opacity(0.98))
                .frame(width: coreSize, height: coreSize)
                .shadow(color: .white.opacity(0.72), radius: 12)
                .shadow(color: AppTheme.blue.opacity(0.95), radius: 32)
                .scaleEffect(coreVisible ? (corePulse ? 1.08 : 0.92) : 0.2)
                .opacity(coreVisible ? 1 : 0)
        }
        .offset(y: compact ? -14 : -20)
    }

    private func orbitLayer(compact: Bool) -> some View {
        let primaryWidth = compact ? 220.0 : 278.0
        let primaryHeight = compact ? 126.0 : 154.0
        let secondaryWidth = primaryWidth * 0.72
        let secondaryHeight = primaryHeight * 0.52

        return ZStack {
            Ellipse()
                .stroke(AppTheme.blue.opacity(0.14), lineWidth: 1)
                .frame(width: primaryWidth, height: primaryHeight)
                .rotationEffect(.degrees(primaryOrbitRotation))
                .opacity(primaryOrbitVisible ? 1 : 0)

            Ellipse()
                .trim(from: max(0, primaryTracerProgress - 0.18), to: primaryTracerProgress)
                .stroke(
                    LinearGradient(
                        colors: [.clear, AppTheme.blue.opacity(0.18), .white.opacity(0.34)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: compact ? 1.15 : 1.25, lineCap: .round)
                )
                .frame(width: primaryWidth, height: primaryHeight)
                .rotationEffect(.degrees(primaryOrbitRotation))
                .opacity(primaryOrbitVisible ? 1 : 0)

            orbitHead(
                width: primaryWidth,
                height: primaryHeight,
                progress: primaryTracerProgress,
                rotation: primaryOrbitRotation,
                size: compact ? 5.6 : 6.0
            )
            .opacity(primaryOrbitVisible ? 1 : 0)

            Ellipse()
                .stroke(.white.opacity(0.08), lineWidth: 0.9)
                .frame(width: secondaryWidth, height: secondaryHeight)
                .rotationEffect(.degrees(secondaryOrbitRotation))
                .opacity(secondaryOrbitVisible ? 0.9 : 0)

            Ellipse()
                .trim(from: max(0, secondaryTracerProgress - 0.15), to: secondaryTracerProgress)
                .stroke(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.22), .white.opacity(0.92)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )
                .frame(width: secondaryWidth, height: secondaryHeight)
                .rotationEffect(.degrees(secondaryOrbitRotation))
                .opacity(secondaryOrbitVisible ? 0.95 : 0)

            orbitHead(
                width: secondaryWidth,
                height: secondaryHeight,
                progress: secondaryTracerProgress,
                rotation: secondaryOrbitRotation,
                size: 3.2
            )
            .opacity(secondaryOrbitVisible ? 0.82 : 0)
        }
        .offset(y: compact ? -14 : -20)
    }

    private func titleLayer(compact: Bool) -> some View {
        VStack(spacing: compact ? 12 : 14) {
            Spacer()

            Text("FOCUS ORBIT")
                .font(.system(size: compact ? 13 : 14, weight: .semibold, design: .monospaced))
                .tracking(compact ? 5.4 : 5.9)
                .foregroundStyle(.white.opacity(0.95))
                .opacity(titleVisible ? 1 : 0)
                .blur(radius: titleVisible ? 0 : 8)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, AppTheme.blue.opacity(0.24), .white.opacity(0.95), AppTheme.blue.opacity(0.24), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: compact ? 78 : 94, height: 1.8)
                .opacity(titleVisible ? 1 : 0)
                .scaleEffect(x: titleVisible ? 1 : 0.28)

            Spacer().frame(height: compact ? 88 : 102)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lowerFalloff: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [.clear, AppTheme.blue.opacity(0.03), .black.opacity(0.58)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 240)
        }
        .allowsHitTesting(false)
    }

    private func orbitHead(width: CGFloat, height: CGFloat, progress: Double, rotation: Double, size: CGFloat) -> some View {
        let point = orbitPoint(width: width, height: height, progress: progress, rotation: rotation)

        return ZStack {
            Circle()
                .fill(AppTheme.blue.opacity(0.24))
                .frame(width: size * 5.8, height: size * 5.8)
                .blur(radius: size * 1.6)

            Circle()
                .fill(.white.opacity(0.98))
                .frame(width: size, height: size)
        }
        .offset(x: point.x, y: point.y)
    }

    private func orbitPoint(width: CGFloat, height: CGFloat, progress: Double, rotation: Double) -> CGPoint {
        let theta = progress * .pi * 2.0 - .pi / 2
        let x = cos(theta) * width / 2
        let y = sin(theta) * height / 2
        let radians = rotation * .pi / 180
        return CGPoint(
            x: x * cos(radians) - y * sin(radians),
            y: x * sin(radians) + y * cos(radians)
        )
    }

    private func startAnimation() {
        guard !reduceMotion else {
            coreVisible = true
            primaryOrbitVisible = true
            secondaryOrbitVisible = true
            titleVisible = true
            primaryTracerProgress = 0.78
            secondaryTracerProgress = 0.42
            return
        }

        let token = UUID()
        animationToken = token
        coreVisible = false
        corePulse = false
        primaryOrbitVisible = false
        secondaryOrbitVisible = false
        titleVisible = false
        primaryOrbitRotation = -28
        secondaryOrbitRotation = 22
        primaryTracerProgress = 0.02
        secondaryTracerProgress = 0.02

        withAnimation(.easeOut(duration: 0.38)) {
            coreVisible = true
        }
        withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
            corePulse = true
        }
        withAnimation(.easeOut(duration: 0.25).delay(0.16)) {
            primaryOrbitVisible = true
        }
        withAnimation(.linear(duration: 0.95).delay(0.16).repeatForever(autoreverses: false)) {
            primaryTracerProgress = 1.02
        }
        withAnimation(.linear(duration: 2.1).delay(0.16).repeatForever(autoreverses: false)) {
            primaryOrbitRotation = 332
        }
        withAnimation(.easeOut(duration: 0.22).delay(0.48)) {
            secondaryOrbitVisible = true
        }
        withAnimation(.linear(duration: 1.25).delay(0.48).repeatForever(autoreverses: false)) {
            secondaryTracerProgress = 1.02
        }
        withAnimation(.linear(duration: 2.4).delay(0.48).repeatForever(autoreverses: false)) {
            secondaryOrbitRotation = -338
        }
        withAnimation(.easeOut(duration: 0.45).delay(1.38)) {
            titleVisible = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.12))
            while animationToken == token {
                primaryTracerProgress = 0.02
                withAnimation(.linear(duration: 0.95)) {
                    primaryTracerProgress = 1.02
                }
                try? await Task.sleep(for: .seconds(0.95))
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.73))
            while animationToken == token {
                secondaryTracerProgress = 0.02
                withAnimation(.linear(duration: 1.25)) {
                    secondaryTracerProgress = 1.02
                }
                try? await Task.sleep(for: .seconds(1.25))
            }
        }
    }
}
