import Foundation
import Testing

@Test func browserBundleDeclaresWebSchemesAndPageTypes() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("Configuration/Info.plist"))
    let info = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    let urlTypes = info["CFBundleURLTypes"] as? [[String: Any]] ?? []
    let schemes = Set(urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] })
    #expect(schemes.isSuperset(of: ["http", "https"]))

    let documentTypes = info["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
    let viewableTypes = documentTypes.filter { ["Viewer", "Editor"].contains($0["CFBundleTypeRole"] as? String ?? "") }
    let contentTypes = Set(viewableTypes.flatMap { $0["LSItemContentTypes"] as? [String] ?? [] })
    #expect(contentTypes.isSuperset(of: ["public.html", "public.xhtml"]))
}
