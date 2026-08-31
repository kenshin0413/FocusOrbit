import Foundation

enum Formatters {
    static func clock(_ seconds: TimeInterval) -> String {
        let value = max(Int(seconds.rounded(.down)), 0)
        let hours = value / 3600, minutes = value % 3600 / 60, secs = value % 60
        return hours > 0 ? String(format: "%02d:%02d:%02d", hours, minutes, secs) : String(format: "%02d:%02d", minutes, secs)
    }
    static func countdown(_ seconds: TimeInterval) -> String {
        let value = max(Int(seconds.rounded(.up)), 0)
        let hours = value / 3600, minutes = value % 3600 / 60, secs = value % 60
        return hours > 0 ? String(format: "%02d:%02d:%02d", hours, minutes, secs) : String(format: "%02d:%02d", minutes, secs)
    }
    static func hoursMinutes(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 60 {
            return LocalizedRuntime.text(
                ja: "\(minutes / 60)時間 \(minutes % 60)分",
                en: "\(minutes / 60) hr \(minutes % 60) min"
            )
        }
        return LocalizedRuntime.text(ja: "\(minutes)分", en: "\(minutes) min")
    }
    static func distance(_ kilometers: Double) -> String {
        if kilometers < 1 { return "\(max(0, Int((kilometers * 1_000).rounded()))) m" }
        return kilometers.formatted(.number.precision(.fractionLength(0))) + " km"
    }
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("HHmm")
        return f
    }()
    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("yyyyMMddHHmm")
        return f
    }()
}
