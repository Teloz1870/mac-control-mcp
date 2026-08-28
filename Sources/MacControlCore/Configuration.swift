import Foundation

public struct MacControlConfiguration: Codable, Sendable, Equatable {
    public var allowedBundleIDs: Set<String>
    public var handleLifetimeSeconds: TimeInterval
    public var maximumScanDepth: Int
    public var maximumScanNodes: Int

    public static let `default` = MacControlConfiguration(
        allowedBundleIDs: ["com.anysphere.sand"],
        handleLifetimeSeconds: 30,
        maximumScanDepth: 12,
        maximumScanNodes: 2_000
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
