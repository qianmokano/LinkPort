import Foundation
import LinkPortCore
import Observation

@MainActor @Observable
final class L10n {
    private static let shared = L10n()
    private var language = AppLanguage.system

    private init() {}

    static func setLanguage(_ language: AppLanguage) { shared.language = language }

    static var locale: Locale { Locale(identifier: shared.language.localizationIdentifier()) }

    static func languageName(_ language: AppLanguage) -> String {
        switch language {
        case .system: text("language.system")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }

    static func text(_ key: String) -> String {
        let bundle = Bundle.main.bundleIdentifier == "com.linkport.app" ? Bundle.main : Bundle.module
        let identifier = shared.language.localizationIdentifier()
        let localized = bundle.url(forResource: identifier, withExtension: "lproj").flatMap(Bundle.init(url:)) ?? bundle
        return NSLocalizedString(key, bundle: localized, value: key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    static func issue(_ issue: LinkPortIssue) -> String {
        switch issue {
        case .invalidURL: text("error.invalidURL")
        case .browserUnavailable: text("error.browserUnavailable")
        case .openFailed: text("error.openFailed")
        case .copyFailed: text("error.copyFailed")
        case .defaultChangeFailed: text("error.defaultChangeFailed")
        }
    }
}
