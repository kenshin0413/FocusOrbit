import SwiftUI
import UIKit

struct SmoothCelestialMotionView: UIViewRepresentable {
    let destination: Destination
    var origin: Destination? = nil
    let fallbackProgress: Double
    let scheduledEndAt: Date?
    let totalSeconds: TimeInterval
    let isPaused: Bool
    let isActive: Bool
    let cinematicScale: CGFloat
    let darkRoomMode: Bool
    let reduceMotion: Bool

    func makeUIView(context: Context) -> CelestialMotionUIView {
        let view = CelestialMotionUIView()
        view.configure(destination: destination, origin: origin)
        context.coordinator.attach(view)
        return view
    }

    func updateUIView(_ view: CelestialMotionUIView, context: Context) {
        context.coordinator.update(
            destination: destination,
            origin: origin,
            fallbackProgress: fallbackProgress,
            scheduledEndAt: scheduledEndAt,
            totalSeconds: totalSeconds,
            isPaused: isPaused,
            isActive: isActive,
            cinematicScale: cinematicScale,
            darkRoomMode: darkRoomMode,
            reduceMotion: reduceMotion
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIView(_ uiView: CelestialMotionUIView, coordinator: Coordinator) {
        coordinator.invalidate()
    }

    @MainActor
    final class Coordinator: NSObject {
        private weak var view: CelestialMotionUIView?
        private var displayLink: CADisplayLink?
        private var destination: Destination = .mars
        private var origin: Destination?
        private var fallbackProgress = 0.0
        private var scheduledEndAt: Date?
        private var totalSeconds: TimeInterval = 1
        private var isPaused = false
        private var isActive = true
        private var cinematicScale: CGFloat = 1
        private var darkRoomMode = false
        private var reduceMotion = false

        func attach(_ view: CelestialMotionUIView) {
            self.view = view
            let link = CADisplayLink(target: self, selector: #selector(frameDidRefresh))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func update(
            destination: Destination,
            origin: Destination?,
            fallbackProgress: Double,
            scheduledEndAt: Date?,
            totalSeconds: TimeInterval,
            isPaused: Bool,
            isActive: Bool,
            cinematicScale: CGFloat,
            darkRoomMode: Bool,
            reduceMotion: Bool
        ) {
            if self.destination != destination || self.origin != origin {
                self.destination = destination
                self.origin = origin
                view?.configure(destination: destination, origin: origin)
            }
            self.fallbackProgress = fallbackProgress
            self.scheduledEndAt = scheduledEndAt
            self.totalSeconds = max(totalSeconds, 1)
            self.isPaused = isPaused
            self.isActive = isActive
            self.cinematicScale = cinematicScale
            self.darkRoomMode = darkRoomMode
            self.reduceMotion = reduceMotion
            displayLink?.isPaused = !isActive || isPaused
            render(at: .now)
        }

        @objc private func frameDidRefresh() {
            render(at: .now)
        }

        private func render(at date: Date) {
            let progress: Double
            if isActive, !isPaused, let scheduledEndAt {
                progress = min(max(1 - scheduledEndAt.timeIntervalSince(date) / totalSeconds, 0), 1)
            } else {
                progress = min(max(fallbackProgress, 0), 1)
            }
            view?.render(
                progress: progress,
                destination: destination,
                cinematicScale: cinematicScale,
                darkRoomMode: darkRoomMode,
                reduceMotion: reduceMotion,
                time: date.timeIntervalSinceReferenceDate
            )
        }

        func invalidate() {
            displayLink?.invalidate()
            displayLink = nil
        }
    }
}

@MainActor
final class CelestialMotionUIView: UIView {
    private let earthView = UIImageView()
    private let destinationView = UIImageView()
    private var configuredDestination: Destination?
    private var configuredOrigin: Destination?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        [earthView, destinationView].forEach {
            $0.contentMode = .scaleAspectFit
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }
        earthView.image = CelestialImageCache.image(named: "EarthNASA")
        earthView.layer.masksToBounds = true
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        earthView.layer.cornerRadius = earthView.bounds.width / 2
    }

    func configure(destination: Destination, origin: Destination? = nil) {
        configuredDestination = destination
        configuredOrigin = origin
        if let origin {
            earthView.image = CelestialImageCache.image(for: origin)
        } else {
            earthView.image = CelestialImageCache.image(named: "EarthNASA")
        }
        earthView.layer.masksToBounds = origin == nil
        destinationView.image = CelestialImageCache.image(for: destination)
        destinationView.layer.masksToBounds = false
        destinationView.layer.compositingFilter = nil
    }

    func render(
        progress: Double,
        destination: Destination,
        cinematicScale: CGFloat,
        darkRoomMode: Bool,
        reduceMotion: Bool,
        time: TimeInterval
    ) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        if configuredDestination != destination { configure(destination: destination, origin: configuredOrigin) }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let referenceWidth = min(bounds.width, bounds.height * 0.82)
        let earthRenderWidth = referenceWidth * 0.87
        setSquareBounds(earthView, side: earthRenderWidth)
        earthView.layer.cornerRadius = configuredOrigin == nil ? earthRenderWidth / 2 : 0
        earthView.center = CGPoint(x: bounds.midX, y: bounds.height * MissionVisualGeometry.earthY(progress: progress))
        let earthWidth = MissionVisualGeometry.earthWidth(screenWidth: referenceWidth, progress: progress)
        earthView.transform = CGAffineTransform(scaleX: earthWidth / earthRenderWidth, y: earthWidth / earthRenderWidth)
        earthView.alpha = MissionVisualGeometry.earthOpacity(progress: progress, destination: destination)

        let widthScale = min(max(min(bounds.width, bounds.height * 0.9) / 390, 0.82), 1.75)
        let lateScale = 1 + CGFloat(MissionVisualGeometry.eased(min(max((progress - 0.88) / 0.12, 0), 1))) * 0.42
        let renderWidth = MissionVisualGeometry.destinationWidth(destination, progress: 1) * widthScale * cinematicScale * 1.42
        let currentWidth = MissionVisualGeometry.destinationWidth(destination, progress: progress) * widthScale * cinematicScale * lateScale
        setSquareBounds(destinationView, side: renderWidth)
        let driftX = reduceMotion ? 0 : sin(time * 0.075) * 2.2
        let driftY = reduceMotion ? 0 : cos(time * 0.061) * 1.6
        destinationView.center = CGPoint(
            x: bounds.midX + driftX,
            y: bounds.height * MissionVisualGeometry.destinationY(destination, progress: progress) + driftY
        )
        let rotation = reduceMotion || destination == .station
            ? 0
            : CGFloat(time.truncatingRemainder(dividingBy: 36_000) * 0.0015 * .pi / 180)
        destinationView.transform = CGAffineTransform(scaleX: currentWidth / renderWidth, y: currentWidth / renderWidth)
            .rotated(by: rotation)
        destinationView.layer.shadowColor = UIColor(destination.accent).cgColor
        destinationView.layer.shadowOpacity = darkRoomMode ? 0.10 : 0.24
        destinationView.layer.shadowRadius = 24
        destinationView.layer.shadowOffset = .zero

        CATransaction.commit()
    }

    private func setSquareBounds(_ imageView: UIImageView, side: CGFloat) {
        guard abs(imageView.bounds.width - side) > 0.25 else { return }
        imageView.bounds = CGRect(x: 0, y: 0, width: side, height: side)
    }
}

private enum CelestialImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(named name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let source = UIImage(named: name) else { return nil }
        let image = source.preparingThumbnail(of: CGSize(width: 2_048, height: 2_048)) ?? source
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    static func image(for destination: Destination) -> UIImage? {
        let key = "planet-\(destination.rawValue)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = UIImage(named: destination.assetName) else { return nil }

        let prepared = source.preparingThumbnail(of: CGSize(width: 2_048, height: 2_048)) ?? source
        let image = if destination.prefersTransparentCutout, !prepared.hasAlphaChannel {
            prepared.circularCutout()
        } else {
            prepared
        }

        cache.setObject(image, forKey: key)
        return image
    }
}

private extension Destination {
    var assetName: String {
        switch self {
        case .moon: "MoonPhotoNASA"
        case .mercury: "MercuryNASA"
        case .venus: "VenusNASA"
        case .mars: "MarsNASA"
        case .jupiter: "JupiterNASA"
        case .saturn: "SaturnNASA"
        case .station: "StationNASA"
        case .uranus: "UranusNASA"
        case .neptune: "NeptuneNASA"
        case .pluto: "PlutoNASA"
        }
    }

    var prefersTransparentCutout: Bool {
        self != .station && !hasWideRings
    }
}

private extension UIImage {
    var hasAlphaChannel: Bool {
        guard let alphaInfo = cgImage?.alphaInfo else { return false }
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly:
            return true
        default:
            return false
        }
    }

    func circularCutout() -> UIImage {
        let edge = min(size.width, size.height)
        let cropOrigin = CGPoint(x: (size.width - edge) / 2, y: (size.height - edge) / 2)
        let cropRect = CGRect(origin: cropOrigin, size: CGSize(width: edge, height: edge))

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = scale

        return UIGraphicsImageRenderer(size: cropRect.size, format: format).image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: cropRect.size)).addClip()
            draw(at: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y))
        }
    }
}
