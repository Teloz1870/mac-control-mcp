import Foundation

public struct MacControlConfiguration: Codable, Sendable, Equatable {
    public var allowedBundleIDs: Set<String>
    public var handleLifetimeSeconds: TimeInterval
    public var maximumScanDepth: Int
    public var maximumScanNodes: Int

    // Electron apps derive their Accessibility tree from the DOM, so real controls sit
    // far deeper than a native window's would. Grok Bot 0.29 puts its bot list past
    // depth 12, where a shallower limit silently returns an empty result rather than
    // an error — the traversal simply stops before reaching anything that matters.
    public static let `default` = MacControlConfiguration(
        allowedBundleIDs: ["com.anysphere.sand"],
        handleLifetimeSeconds: 30,
        maximumScanDepth: 30,
        maximumScanNodes: 8_000
    )

    public static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("mac-control-mcp", isDirectory: true)
    }

    public static var snapshotsDirectory: URL {
        supportDirectory.appendingPathComponent("snapshots", isDirectory: true)
    }

    public static func load() throws -> MacControlConfiguration {
        let url = supportDirectory.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return .default }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    public func validate(bundleID: String) throws {
        guard allowedBundleIDs.contains(bundleID) else { throw MacControlError.appNotAllowed(bundleID) }
    }
}
