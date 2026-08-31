import AVKit
import SwiftUI

struct SpaceBackground: View {
    var accent: Color = AppTheme.blue

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [AppTheme.background, Color(red: 0.035, green: 0.025, blue: 0.10), .black]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
                ))
                let t = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<38 {
                    let seed = Double(index * 7919 % 1000) / 1000
                    let x = CGFloat(Double(index * 3571 % 997) / 997) * size.width
                    let y = CGFloat((seed * Double(size.height) + t * (0.35 + seed * 0.55)).truncatingRemainder(dividingBy: Double(size.height)))
                    let radius = 0.4 + seed * 0.75
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)), with: .color(.white.opacity(0.14 + seed * 0.28)))
                }
                let glow = CGRect(x: size.width * 0.1, y: -size.width * 0.55, width: size.width * 1.4, height: size.width * 1.4)
                context.fill(Path(ellipseIn: glow), with: .radialGradient(Gradient(colors: [accent.opacity(0.14), .clear]), center: CGPoint(x: glow.midX, y: glow.midY), startRadius: 0, endRadius: glow.width / 2))
            }
        }
        .ignoresSafeArea()
    }
}

struct DestinationOrb: View {
    let destination: Destination
    var size: CGFloat = 70
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [.white.opacity(0.9), destination.accent, destination.accent.opacity(0.18)], center: .topLeading, startRadius: 2, endRadius: size * 0.65))
            Circle().stroke(.white.opacity(0.24), lineWidth: 1)
            Image(systemName: destination.symbol).font(.system(size: size * 0.33, weight: .thin)).foregroundStyle(.white.opacity(0.55))
        }
        .frame(width: size, height: size)
        .shadow(color: destination.accent.opacity(0.4), radius: size * 0.25)
    }
}

struct LoopingVideoView: View {
    let resourceName: String
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        Group {
            if let player { VideoPlayer(player: player).disabled(true) } else { Color.clear }
        }
        .task {
            guard player == nil, let url = Bundle.main.url(forResource: resourceName, withExtension: "mp4") else { return }
            let item = AVPlayerItem(url: url); let queue = AVQueuePlayer(); looper = AVPlayerLooper(player: queue, templateItem: item)
            player = queue; queue.isMuted = true; queue.play()
        }
    }
}
