import Foundation

enum LocalizedRuntime {
    static var isEnglish: Bool {
        Locale.autoupdatingCurrent.language.languageCode?.identifier == "en"
    }

    static func text(ja: String, en: String) -> String {
        isEnglish ? en : ja
    }

    static func format(ja: String, en: String, _ arguments: CVarArg...) -> String {
        let template = isEnglish ? en : ja
        return String(format: template, locale: Locale.autoupdatingCurrent, arguments: arguments)
    }
}
