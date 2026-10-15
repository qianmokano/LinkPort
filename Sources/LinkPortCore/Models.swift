import CoreGraphics
import Foundation

public struct Browser: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let applicationURL: URL

    public init(id: String, name: String, applicationURL: URL) {
        self.id = id
        self.name = name
        self.applicationURL = applicationURL
    }
}

public enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public func localizationIdentifier(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        guard self == .system else { return rawValue }
        return Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: preferredLanguages).first ?? "en"
    }
}

public struct BrowserPreferences: Equatable, Sendable {
    public var orderedIDs: [String]
    public var hiddenIDs: Set<String>
    public var hasSeenWelcome: Bool
    public var language: AppLanguage

    public init(orderedIDs: [String] = [], hiddenIDs: Set<String> = [], hasSeenWelcome: Bool = false, language: AppLanguage = .system) {
        self.orderedIDs = orderedIDs
        self.hiddenIDs = hiddenIDs
        self.hasSeenWelcome = hasSeenWelcome
        self.language = language
    }
}

public enum BrowserCatalog {
    public static func arrange(_ discovered: [Browser], preferences: BrowserPreferences, excluding ownID: String) -> [Browser] {
        var seen = Set<String>()
        let unique = discovered.filter { $0.id != ownID && seen.insert($0.id).inserted }
        let positions = Dictionary(preferences.orderedIDs.enumerated().map { ($1, $0) }, uniquingKeysWith: min)
        return unique.sorted { lhs, rhs in
            let left = positions[lhs.id] ?? Int.max
            let right = positions[rhs.id] ?? Int.max
            if left != right { return left < right }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

public struct LinkQueue: Equatable, Sendable {
    public private(set) var urls: [URL] = []
    public var current: URL? { urls.first }
    public var count: Int { urls.count }

    public init() {}

    @discardableResult
    public mutating func enqueue(_ incoming: [URL]) -> Int {
        var invalidCount = 0
        var existing = Set(urls.map(\.absoluteString))
        for url in incoming {
            guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
                  let host = url.host, !host.isEmpty else {
                invalidCount += 1
                continue
            }
            if existing.insert(url.absoluteString).inserted { urls.append(url) }
        }
        return invalidCount
    }

    public mutating func completeCurrent() {
        if !urls.isEmpty { urls.removeFirst() }
    }

    public mutating func cancel() { urls.removeAll() }
}

public struct DefaultHandlers: Equatable, Sendable {
    public var http: String?
    public var https: String?

    public init(http: String? = nil, https: String? = nil) {
        self.http = http
        self.https = https
    }

    public func isDefault(_ bundleID: String) -> Bool { http == bundleID && https == bundleID }
}

public enum LinkPortIssue: Error, Equatable, Sendable {
    case invalidURL, browserUnavailable, openFailed, copyFailed, defaultChangeFailed
}

public enum PickerGeometry {
    public static func frame(size: CGSize, pointer: CGPoint, visibleFrame: CGRect) -> CGRect {
        let inset = visibleFrame.insetBy(dx: 12, dy: 12)
        let width = min(size.width, inset.width)
        let height = min(size.height, inset.height)
        let x = min(max(pointer.x + 12, inset.minX), inset.maxX - width)
        let y = min(max(pointer.y - height - 12, inset.minY), inset.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
