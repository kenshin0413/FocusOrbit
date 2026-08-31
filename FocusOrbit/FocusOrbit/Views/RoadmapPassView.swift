import AudioToolbox
import SwiftUI
import UIKit

private enum RoadmapScanPhase {
    case idle, scanning, verifying, authenticated
}

struct RoadmapPassView: View {
    let router: AppRouter
    let progress: RoadmapProgress
    let crewName: String
    let settings: AppSettings?
    let sessionManager: RoadmapSessionManager
    var onCancel: (() -> Void)? = nil
    var onAuthorized: (() -> Void)? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var phase: RoadmapScanPhase = .idle
    @State private var scanPulse = false
    @State private var illuminatedSteps = 0

    var body: some View {
        GeometryReader { proxy in
            let travel = max(proxy.size.width * 0.68, 220)
            let scanProgress = min(max(dragOffset / travel, 0), 1)
            let compact = proxy.size.width < 390
            let shortScreen = proxy.size.height < 720
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: shortScreen ? 12 : 16) {
                        ScreenHeader(title: LocalizedRuntime.text(ja: "航路認証", en: "Route Authorization"), subtitle: "ROADMAP BOARDING GATE") {
                            if let onCancel { onCancel() } else {
                                sessionManager.cancelPreflight()
                                router.show(.roadmap)
                            }
                        }
                        routeHeader(compact: compact, shortScreen: shortScreen)
                        scannerChamber(progress: scanProgress, travel: travel, compact: compact, shortScreen: shortScreen)
                        if !shortScreen {
                            scannerStatus(progress: scanProgress, compact: compact)
                        }
                    }
                    .padding(.bottom, shortScreen ? 146 : 24)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, shortScreen ? 16 : 20)
                .padding(.top, shortScreen ? 4 : 8)

                if shortScreen {
                    scannerStatus(progress: scanProgress, compact: true)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        .background(
                            LinearGradient(
                                colors: [.clear, AppTheme.background.opacity(0.88), AppTheme.background],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .bottom)
                        )
                }
            }
        }
    }

    private func routeHeader(compact: Bool, shortScreen: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            passChip("ROADMAP", tint: progress.target.accent)
            HStack(spacing: compact ? 10 : 12) {
                routeLabel("FROM", progress.origin?.englishName ?? "EARTH")
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    Circle().fill(.cyan).frame(width: 6, height: 6)
                    Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
                        .overlay(Image(systemName: "arrow.right").font(.caption2).foregroundStyle(AppTheme.secondary))
                    Circle().fill(progress.target.accent).frame(width: 7, height: 7)
                }
                .frame(maxWidth: compact ? 90 : 160)
                routeLabel(String(localized: "roadmap_pass.next", defaultValue: "NEXT"), progress.target.englishName, alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(shortScreen ? 14 : 16)
        .background(panelBackground)
        .overlay(panelStroke)
        .clipShape(RoundedRectangle(cornerRadius: OrbitDesign.Radius.largeCard, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 10)
    }

    private func routeLabel(_ label: String, _ value: String, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(AppTheme.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }

    private func scannerChamber(progress scanProgress: CGFloat, travel: CGFloat, compact: Bool, shortScreen: Bool) -> some View {
        let cardScale: CGFloat = shortScreen ? 0.68 : 0.78
        let cardHeight: CGFloat = shortScreen ? 330 : (compact ? 400 : 430)
        let chamberHeight: CGFloat = shortScreen ? 380 : (compact ? 456 : 486)
        return ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 26).fill(Color.black.opacity(0.46))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(AppTheme.line))
            VStack(spacing: 5) {
                HStack {
                    Circle().fill(phase == .authenticated ? .green : AppTheme.blue).frame(width: 6, height: 6)
                    Text("ROADMAP READER 01").font(.system(size: 9, design: .monospaced)).tracking(1.2).foregroundStyle(AppTheme.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                ZStack(alignment: .trailing) {
                    roadmapPassCard
                        .scaleEffect(cardScale)
                        .frame(height: cardHeight)
                        .offset(x: dragOffset)
                        .opacity(phase == .authenticated ? 0.18 : 1)
                        .gesture(phase == .idle || phase == .scanning ? scanGesture(travel: travel) : nil)
                    readerGate(progress: scanProgress)
                }
                .clipped()
            }
            .padding(.vertical, shortScreen ? 8 : 12)
        }
        .frame(height: chamberHeight)
    }

    private var roadmapPassCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROADMAP PASS").font(.system(size: 28, weight: .black, design: .rounded)).tracking(1)
                    Text("FOCUS ORBIT TRANSIT AUTHORITY").font(.caption2).tracking(1.5).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "point.3.connected.trianglepath.dotted").font(.title2)
            }
            Divider()
            passRow("CREW", crewName)
            passRow("FROM", progress.origin?.englishName ?? "EARTH")
            passRow("NEXT", progress.target.englishName)
            passRow("ROUTE", "PLANETARY ROADMAP")
            passRow("TIMER", "OPEN ENDED")
            passRow("LEG", String(format: "%02d / %02d", progress.legIndex + 1, RoadmapRoute.legs.count))
            HStack {
                Text("STATUS").frame(width: 92, alignment: .leading)
                Text("READY").foregroundStyle(.blue)
            }
            .font(.system(.subheadline, design: .monospaced, weight: .semibold))
        }
        .foregroundStyle(Color(red: 0.06, green: 0.10, blue: 0.17))
        .padding(24)
        .background(Color(red: 0.92, green: 0.93, blue: 0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .trailing) { Rectangle().fill(progress.target.accent).frame(width: 7).padding(.vertical, 24) }
        .shadow(color: progress.target.accent.opacity(0.18), radius: 24)
    }

    private func passRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).frame(width: 92, alignment: .leading).foregroundStyle(.secondary)
            Text(value).lineLimit(2)
        }
        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
    }

    private func readerGate(progress scanProgress: CGFloat) -> some View {
        ZStack {
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18)
                .fill(LinearGradient(colors: [Color(red: 0.12, green: 0.15, blue: 0.20), .black], startPoint: .leading, endPoint: .trailing))
                .frame(width: 72)
            VStack(spacing: 12) {
                Text("SCAN").font(.system(size: 8, design: .monospaced)).tracking(1.4).rotationEffect(.degrees(90))
                ForEach(0..<5, id: \.self) { index in
                    Capsule().fill(index < illuminatedSteps ? AppTheme.blue : .white.opacity(0.12)).frame(width: 18, height: 3)
                }
                Image(systemName: phase == .authenticated ? "checkmark.shield.fill" : "wave.3.right")
                    .foregroundStyle(phase == .authenticated ? .green : AppTheme.blue)
            }
            if scanProgress > 0.38 && phase != .authenticated {
                Rectangle().fill(LinearGradient(colors: [.clear, .cyan, .white, .cyan, .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: 390).blur(radius: 1).offset(x: -35).opacity(scanPulse ? 0.95 : 0.35)
                    .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: scanPulse)
            }
        }
        .onChange(of: scanProgress) { _, value in
            scanPulse = value > 0.38
            let step = min(5, max(0, Int(value / 0.16)))
            if step > illuminatedSteps { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7) }
            illuminatedSteps = step
        }
    }

    private func scannerStatus(progress scanProgress: CGFloat, compact: Bool) -> some View {
        VStack(spacing: 10) {
            HStack {
                Label(statusTitle, systemImage: statusSymbol).foregroundStyle(phase == .authenticated ? .green : AppTheme.blue)
                Spacer()
                Text(phase == .verifying ? LocalizedRuntime.text(ja: "照合中", en: "Verifying") : String(format: "%03d%%", Int(scanProgress * 100)))
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(AppTheme.secondary)
            }
            ProgressView(value: phase == .authenticated ? 1 : scanProgress).tint(phase == .authenticated ? .green : AppTheme.blue)
            Text(statusDetail).font(.caption).foregroundStyle(AppTheme.secondary).frame(maxWidth: .infinity, alignment: .leading)
            if compact {
                VStack(spacing: 8) {
                    statusPill(LocalizedRuntime.text(ja: "区間 \(progress.legIndex + 1)", en: "Leg \(progress.legIndex + 1)"), symbol: "point.3.connected.trianglepath.dotted")
                    statusPill(progress.target.name, symbol: progress.target.isSurfaceDestination ? "airplane.departure" : "arrow.trianglehead.clockwise")
                }
            } else {
                HStack(spacing: 10) {
                    statusPill(LocalizedRuntime.text(ja: "区間 \(progress.legIndex + 1)", en: "Leg \(progress.legIndex + 1)"), symbol: "point.3.connected.trianglepath.dotted")
                    statusPill(progress.target.name, symbol: progress.target.isSurfaceDestination ? "airplane.departure" : "arrow.trianglehead.clockwise")
                }
            }
        }
        .spacePanel()
    }

    private func scanGesture(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in phase = .scanning; dragOffset = min(max(value.translation.width, 0), travel) }
            .onEnded { _ in
                if dragOffset / travel > 0.86 { completeScan(travel: travel) }
                else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { dragOffset = 0; phase = .idle }
                    illuminatedSteps = 0
                }
            }
    }

    private func completeScan(travel: CGFloat) {
        phase = .verifying
        withAnimation(.easeOut(duration: 0.22)) { dragOffset = travel }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        Task {
            let voiceEnabled = settings?.voiceAnnouncementsEnabled ?? true
            AnnouncementService.shared.speak(
                LocalizedRuntime.text(ja: "ロードマップ航路とクルー情報を照合しております。", en: "Verifying roadmap route and crew credentials."),
                clipName: "roadmap_verifying",
                chime: false,
                enabled: voiceEnabled
            )
            try? await Task.sleep(for: .milliseconds(voiceEnabled ? 4_200 : 1_800))
            AudioServicesPlaySystemSound(1104)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring) { phase = .authenticated }
            AnnouncementService.shared.speak(
                LocalizedRuntime.text(ja: "航路認証が完了しました。発射シーケンスへ移行します。", en: "Route authorization complete. Moving to launch sequence."),
                clipName: "roadmap_authorized",
                enabled: voiceEnabled
            )
            try? await Task.sleep(for: .seconds(voiceEnabled ? 5.8 : 1.3))
            if let onAuthorized {
                onAuthorized()
                return
            }
            if settings?.skipLaunchSequence == true {
                sessionManager.startSession()
                sessionManager.acknowledgeInitialLaunch()
                router.show(.roadmapFocus)
            } else {
                sessionManager.markPreflightAuthorized()
                router.show(.roadmapLaunch)
            }
        }
    }

    private var statusTitle: String {
        switch phase {
        case .idle: LocalizedRuntime.text(ja: "認証待機", en: "Awaiting Authorization")
        case .scanning: LocalizedRuntime.text(ja: "航路パスを読み取り中", en: "Reading Route Pass")
        case .verifying: LocalizedRuntime.text(ja: "ロードマップ航路を照合中", en: "Verifying Roadmap Route")
        case .authenticated: LocalizedRuntime.text(ja: "認証完了", en: "Authorized")
        }
    }
    private var statusDetail: String {
        switch phase {
        case .idle: LocalizedRuntime.text(ja: "カードを右方向へ、読取ゲートの奥まで通してください", en: "Slide the card to the right through the gate")
        case .scanning: LocalizedRuntime.text(ja: "クルーIDと航路署名を走査しています", en: "Scanning crew ID and route signature")
        case .verifying: "CREW ID / ROADMAP ROUTE / LEG HASH"
        case .authenticated: LocalizedRuntime.text(ja: "発射シーケンスを開始します", en: "Starting launch sequence")
        }
    }
    private var statusSymbol: String {
        switch phase { case .idle: "sensor"; case .scanning: "barcode.viewfinder"; case .verifying: "ellipsis.circle"; case .authenticated: "checkmark.shield.fill" }
    }

    private func passChip(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }

    private func statusPill(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.04), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.08)))
        .foregroundStyle(AppTheme.secondary)
    }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OrbitDesign.Radius.largeCard, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.panelElevated.opacity(0.96), AppTheme.panel.opacity(0.86)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: OrbitDesign.Radius.largeCard, style: .continuous)
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
    }

    private var panelStroke: some View {
        RoundedRectangle(cornerRadius: OrbitDesign.Radius.largeCard, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [.white.opacity(0.16), AppTheme.line, .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}
