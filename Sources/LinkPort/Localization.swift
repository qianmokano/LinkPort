import Foundation
import LinkPortCore

enum L10n {
    static func text(_ key: String) -> String {
        let bundle = Bundle.main.bundleIdentifier == "com.linkport.app" ? Bundle.main : Bundle.module
        return NSLocalizedString(key, bundle: bundle, value: key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
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

