import AudioToolbox
import SwiftData
import SwiftUI
import UIKit

private enum ScanPhase {
    case idle, scanning, verifying, authenticated
}

struct MissionPassView: View {
    @Environment(\.modelContext) private var context
    let router: AppRouter
    let mission: Mission
    let crewName: String
    let settings: AppSettings?
    @State private var dragOffset: CGFloat = 0
    @State private var phase: ScanPhase = .idle
    @State private var scanPulse = false
    @State private var illuminatedScannerSteps = 0

    var body: some View {
        GeometryReader { proxy in
            let travel = max(proxy.size.width * 0.68, 220)
            let progress = min(max(dragOffset / travel, 0), 1)
            let compact = proxy.size.width < 390
            let shortScreen = proxy.size.height < 720
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: shortScreen ? 12 : 16) {
                        ScreenHeader(title: LocalizedRuntime.text(ja: "航路認証", en: "Route Authorization"), subtitle: "CUSTOM BOARDING GATE") { router.show(.setup) }
                        routeHeader(compact: compact, shortScreen: shortScreen)
                        scannerChamber(progress: progress, travel: travel, compact: compact, shortScreen: shortScreen)
                        if !shortScreen {
                            scannerStatus(progress: progress, compact: compact)
                        }
                    }
                    .padding(.bottom, shortScreen ? 146 : 24)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, shortScreen ? 16 : 20)
                .padding(.top, shortScreen ? 4 : 8)

                if shortScreen {
                    scannerStatus(progress: progress, compact: true)
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
            passChip("CUSTOM", tint: AppTheme.blue)
            HStack(spacing: compact ? 10 : 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FROM").font(.caption2).foregroundStyle(AppTheme.secondary)
                    Text("EARTH ORBIT")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    Circle().fill(.cyan).frame(width: 6, height: 6)
                    Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
                        .overlay(Image(systemName: "arrow.right").font(.caption2).foregroundStyle(AppTheme.secondary))
                    Circle().fill(mission.destination.accent).frame(width: 7, height: 7)
                }
                .frame(maxWidth: compact ? 90 : 160)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("DESTINATION").font(.caption2).foregroundStyle(AppTheme.secondary)
                    Text(mission.destination.englishName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(shortScreen ? 14 : 16)
        .background(panelBackground)
        .overlay(panelStroke)
        .clipShape(RoundedRectangle(cornerRadius: OrbitDesign.Radius.largeCard, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 10)
    }

    private func scannerChamber(progress: CGFloat, travel: CGFloat, compact: Bool, shortScreen: Bool) -> some View {
        let cardScale: CGFloat = shortScreen ? 0.68 : 0.78
        let cardHeight: CGFloat = shortScreen ? 330 : (compact ? 400 : 430)
        let chamberHeight: CGFloat = shortScreen ? 380 : (compact ? 456 : 486)
        return ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 26).fill(Color.black.opacity(0.46)).overlay(RoundedRectangle(cornerRadius: 26).stroke(AppTheme.line))
            VStack(spacing: 5) {
                HStack { Circle().fill(phase == .authenticated ? .green : AppTheme.blue).frame(width: 6, height: 6); Text("OPTICAL READER 07").font(.system(size: 9, design: .monospaced)).tracking(1.2).foregroundStyle(AppTheme.secondary); Spacer() }.padding(.horizontal, 14)
                ZStack(alignment: .trailing) {
                    MissionPassCard(mission: mission, crewName: crewName)
                        .scaleEffect(cardScale)
                        .frame(height: cardHeight)
                        .offset(x: dragOffset)
                        .opacity(phase == .authenticated ? 0.18 : 1)
                        .gesture(phase == .idle || phase == .scanning ? scanGesture(travel: travel) : nil)

                    readerGate(progress: progress)
                }
                .clipped()
            }.padding(.vertical, shortScreen ? 8 : 12)
        }
        .frame(height: chamberHeight)
    }

    private func readerGate(progress: CGFloat) -> some View {
        ZStack {
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18)
                .fill(LinearGradient(colors: [Color(red: 0.12, green: 0.15, blue: 0.20), .black], startPoint: .leading, endPoint: .trailing))
                .frame(width: 72)
                .overlay(alignment: .leading) { Rectangle().fill(.black).frame(width: 13).shadow(color: .black, radius: 6) }
            VStack(spacing: 12) {
                Text("SCAN").font(.system(size: 8, design: .monospaced)).tracking(1.4).rotationEffect(.degrees(90))
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index < illuminatedScannerSteps ? AppTheme.blue : .white.opacity(0.12))
                        .frame(width: 18, height: 3)
                        .shadow(color: index < illuminatedScannerSteps ? AppTheme.blue : .clear, radius: 5)
                }
                Image(systemName: phase == .authenticated ? "checkmark.shield.fill" : "wave.3.right").foregroundStyle(phase == .authenticated ? .green : AppTheme.blue)
            }
            if progress > 0.38 && phase != .authenticated {
                Rectangle().fill(LinearGradient(colors: [.clear, .cyan, .white, .cyan, .clear], startPoint: .top, endPoint: .bottom)).frame(width: 3, height: 390).blur(radius: 1).offset(x: -35).opacity(scanPulse ? 0.95 : 0.35).animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: scanPulse)
            }
        }.onChange(of: progress) { _, value in
            scanPulse = value > 0.38
            let step = min(5, max(0, Int(value / 0.16)))
            if step > illuminatedScannerSteps {
                let firstNewStep = illuminatedScannerSteps + 1
                Task { @MainActor in
                    for crossedStep in firstNewStep...step {
                        let generator = UIImpactFeedbackGenerator(style: .rigid)
                        generator.prepare()
                        generator.impactOccurred(intensity: 0.48 + CGFloat(crossedStep) * 0.08)
                        if crossedStep < step { try? await Task.sleep(for: .milliseconds(45)) }
                    }
                }
            }
            illuminatedScannerSteps = step
        }
    }

    private func scannerStatus(progress: CGFloat, compact: Bool) -> some View {
        VStack(spacing: 10) {
            HStack {
                Label(statusTitle, systemImage: statusSymbol).foregroundStyle(statusColor)
                Spacer()
                Text(phase == .verifying ? LocalizedRuntime.text(ja: "照合中", en: "Verifying") : String(format: "%03d%%", Int(progress * 100))).font(.system(.caption, design: .monospaced)).foregroundStyle(AppTheme.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule().fill(LinearGradient(colors: [AppTheme.blue, statusColor], startPoint: .leading, endPoint: .trailing)).frame(width: proxy.size.width * (phase == .authenticated ? 1 : progress))
                }
            }.frame(height: 3)
            Text(statusDetail).font(.caption).foregroundStyle(AppTheme.secondary).frame(maxWidth: .infinity, alignment: .leading)
            if compact {
                VStack(spacing: 8) {
                    statusPill(LocalizedRuntime.text(ja: "集中 \(mission.durationMinutes)分", en: "Focus \(mission.durationMinutes) min"), symbol: "timer")
                    statusPill(mission.destination.name, symbol: "sparkles")
                }
            } else {
                HStack(spacing: 10) {
                    statusPill(LocalizedRuntime.text(ja: "集中 \(mission.durationMinutes)分", en: "Focus \(mission.durationMinutes) min"), symbol: "timer")
                    statusPill(mission.destination.name, symbol: "sparkles")
                }
            }
        }.spacePanel()
    }

    private func scanGesture(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                phase = .scanning
                dragOffset = min(max(value.translation.width, 0), travel)
            }
            .onEnded { _ in
                if dragOffset / travel > 0.86 { completeScan(travel: travel) }
                else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { dragOffset = 0; phase = .idle }
                    illuminatedScannerSteps = 0
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
                LocalizedRuntime.text(ja: "クルー情報を照合しております。そのままお待ちください。", en: "Verifying crew credentials. Please remain still."),
                clipName: "cabin_verifying",
                chime: false,
                enabled: voiceEnabled
            )
            try? await Task.sleep(for: .milliseconds(voiceEnabled ? 4_500 : 2_200))
            AudioServicesPlaySystemSound(1104)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring) { phase = .authenticated }
            AnnouncementService.shared.speak(LocalizedRuntime.text(ja: "認証が完了いたしました。まもなく、発射シーケンスを開始いたします。", en: "Authorization complete. Launch sequence will begin shortly."), clipName: "cabin_authorized", enabled: settings?.voiceAnnouncementsEnabled ?? true)
            mission.status = .launching
            try? context.save()
            try? await Task.sleep(for: .seconds(voiceEnabled ? 6.7 : 1.45))
            router.show(settings?.skipLaunchSequence == true ? .flight : .launch)
        }
    }

    private var statusTitle: String {
        switch phase {
        case .idle: LocalizedRuntime.text(ja: "認証待機", en: "Awaiting Authorization")
        case .scanning: LocalizedRuntime.text(ja: "パス情報を読み取り中", en: "Reading Pass")
        case .verifying: LocalizedRuntime.text(ja: "船員情報を照合中", en: "Verifying Crew")
        case .authenticated: LocalizedRuntime.text(ja: "認証完了", en: "Authorized")
        }
    }
    private var statusDetail: String {
        switch phase {
        case .idle: LocalizedRuntime.text(ja: "カードを右方向へ、読取ゲートの奥まで通してください", en: "Slide the card to the right through the gate")
        case .scanning: LocalizedRuntime.text(ja: "光学コードとミッション署名を走査しています", en: "Scanning optical code and mission signature")
        case .verifying: "CREW ID / ROUTE / MISSION HASH"
        case .authenticated: LocalizedRuntime.text(ja: "発射シーケンスを開始します", en: "Starting launch sequence")
        }
    }
    private var statusSymbol: String {
        switch phase { case .idle: "sensor"; case .scanning: "barcode.viewfinder"; case .verifying: "ellipsis.circle"; case .authenticated: "checkmark.shield.fill" }
    }
    private var statusColor: Color { phase == .authenticated ? .green : AppTheme.blue }

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
