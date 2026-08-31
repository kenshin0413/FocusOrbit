import CoreHaptics
import UIKit

@MainActor
enum MissionHaptics {
    private static var launchEngine: CHHapticEngine?

    static func launchSequence(enabled: Bool, reduceMotion: Bool) {
        guard enabled else { return }
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                let engine = try CHHapticEngine()
                try engine.start()
                let duration = reduceMotion ? 1.8 : 2.65
                var events = [CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: reduceMotion ? 0.55 : 1),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: reduceMotion ? 0.35 : 0.68)
                    ],
                    relativeTime: 0,
                    duration: duration
                )]
                if !reduceMotion {
                    for time in stride(from: 0.0, through: 2.4, by: 0.4) {
                        events.append(CHHapticEvent(
                            eventType: .hapticTransient,
                            parameters: [
                                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.82)
                            ],
                            relativeTime: time
                        ))
                    }
                }
                let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
                try player.start(atTime: 0)
                launchEngine = engine
                return
            } catch {
                launchEngine = nil
            }
        }
        Task { @MainActor in
            let generator = UIImpactFeedbackGenerator(style: reduceMotion ? .medium : .heavy)
            generator.prepare()
            let intensity: CGFloat = reduceMotion ? 0.48 : 1
            let pulseCount = reduceMotion ? 6 : 12
            for index in 0..<pulseCount {
                generator.impactOccurred(intensity: intensity)
                if index < pulseCount - 1 {
                    try? await Task.sleep(for: .milliseconds(reduceMotion ? 400 : 220))
                    generator.prepare()
                }
            }
        }
    }

    static func ascentBurst(enabled: Bool, reduceMotion: Bool) {
        guard enabled else { return }
        Task { @MainActor in
            let generator = UIImpactFeedbackGenerator(style: reduceMotion ? .light : .rigid)
            for index in 0..<3 {
                generator.prepare()
                generator.impactOccurred(intensity: reduceMotion ? 0.32 : 0.72)
                if index < 2 { try? await Task.sleep(for: .milliseconds(320)) }
            }
        }
    }

    static func orbitInsertion(enabled: Bool, reduceMotion: Bool) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light)
            .impactOccurred(intensity: reduceMotion ? 0.28 : 0.44)
    }

    static func landing(enabled: Bool, reduceMotion: Bool) {
        guard enabled else { return }
        let first = UIImpactFeedbackGenerator(style: reduceMotion ? .light : .medium)
        first.impactOccurred(intensity: reduceMotion ? 0.25 : 0.46)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(170))
            UIImpactFeedbackGenerator(style: .soft)
                .impactOccurred(intensity: reduceMotion ? 0.2 : 0.32)
        }
    }

    static func completed(enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
