import Foundation

public enum MacControlError: Error, LocalizedError, Sendable {
    case accessibilityDenied
    case appNotAllowed(String)
    case appNotRunning(String)
    case elementNotFound(String)
    case staleHandle(String)
    case secureContent
    case unsupportedVersion(app: String, version: String, supported: String)
    case invalidArgument(String)
    case accessibility(operation: String, code: Int32)
    case timeout(String)
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            "Accessibility permission is not granted. Enable mac-control-mcp in System Settings > Privacy & Security > Accessibility."
        case .appNotAllowed(let id): "Bundle id \(id) is not in the explicit allowlist."
        case .appNotRunning(let id): "App \(id) is not running."
        case .elementNotFound(let diagnostic): "Semantic selector failed: \(diagnostic). Run mac_scan_capabilities and update the adapter selector."
        case .staleHandle(let handle): "Element handle \(handle) is stale or no longer identifies the same element. Inspect the app again."
        case .secureContent: "Secure or secret-bearing content is blocked by policy."
        case .unsupportedVersion(let app, let version, let supported):
            "\(app) \(version) is not supported; supported range: \(supported). Refusing to guess. Run a capability rescan."
        case .invalidArgument(let message): message
        case .accessibility(let operation, let code): "Accessibility operation \(operation) failed with AXError \(code)."
        case .timeout(let message): "Timed out: \(message)"
        case .unavailable(let message): message
        }
    }
}

public struct AppInfo: Codable, Sendable, Equatable {
    public let bundleID: String
    public let name: String
    public let pid: Int32
    public let version: String?
    public let active: Bool
}

public struct ElementHandle: Codable, Hashable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct ElementSnapshot: Codable, Sendable, Equatable {
    public let handle: ElementHandle
    public let bundleID: String
    public let pid: Int32
    public let role: String?
    public let subrole: String?
    public let identifier: String?
    public let title: String?
    public let description: String?
    public let value: String?
    public let enabled: Bool?
    public let actions: [String]
    public let depth: Int
    public let childCount: Int
    /// Structural index path from the application element. Enables containment
    /// checks so adapters can scope a search to one widget instead of the app.
    public let path: [Int]

    public init(handle: ElementHandle, bundleID: String, pid: Int32, role: String?, subrole: String?, identifier: String?, title: String?, description: String?, value: String?, enabled: Bool?, actions: [String], depth: Int, childCount: Int, path: [Int] = []) {
        self.handle = handle; self.bundleID = bundleID; self.pid = pid; self.role = role; self.subrole = subrole
        self.identifier = identifier; self.title = title; self.description = description; self.value = value
        self.enabled = enabled; self.actions = actions; self.depth = depth; self.childCount = childCount
        self.path = path
    }

    private enum CodingKeys: String, CodingKey {
        case handle, bundleID, pid, role, subrole, identifier, title, description, value, enabled, actions, depth, childCount, path
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        handle = try container.decode(ElementHandle.self, forKey: .handle)
        bundleID = try container.decode(String.self, forKey: .bundleID)
        pid = try container.decode(Int32.self, forKey: .pid)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        subrole = try container.decodeIfPresent(String.self, forKey: .subrole)
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        actions = try container.decodeIfPresent([String].self, forKey: .actions) ?? []
        depth = try container.decode(Int.self, forKey: .depth)
        childCount = try container.decode(Int.self, forKey: .childCount)
        // Snapshots written before schema 2 have no path; containment checks then
        // degrade to "no container found" rather than failing the whole read.
        path = try container.decodeIfPresent([Int].self, forKey: .path) ?? []
    }
}

/// Pure containment helpers over a flat inspection result. Adapters use these to
/// scope an action to one widget instead of pressing the first app-wide match.
public enum ElementTree {
    public static func isDescendant(_ candidate: ElementSnapshot, of container: ElementSnapshot) -> Bool {
        guard candidate.path.count > container.path.count else { return false }
        return Array(candidate.path.prefix(container.path.count)) == container.path
    }

    /// Elements inside `container`, excluding the container itself.
    public static func descendants(of container: ElementSnapshot, in elements: [ElementSnapshot]) -> [ElementSnapshot] {
        elements.filter { isDescendant($0, of: container) }
    }

    /// The innermost element with one of `roles` that contains `target`.
    public static func innermostContainer(of target: ElementSnapshot, roles: Set<String>, in elements: [ElementSnapshot]) -> ElementSnapshot? {
        elements
            .filter { roles.contains($0.role ?? "") && isDescendant(target, of: $0) }
            .max { $0.path.count < $1.path.count }
    }
}

public struct ElementQuery: Codable, Sendable, Equatable {
    public var role: String?
    public var identifier: String?
    public var title: String?
    public var description: String?
    public var valueContains: String?

    public init(role: String? = nil, identifier: String? = nil, title: String? = nil, description: String? = nil, valueContains: String? = nil) {
        self.role = role
        self.identifier = identifier
        self.title = title
        self.description = description
        self.valueContains = valueContains
    }
}

public struct CapabilitySnapshot: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let bundleID: String
    public let appVersion: String
    public let capturedAt: Date
    public let roles: [String]
    public let attributes: [String]
    public let actions: [String]
    public let menuItems: [String]
    public let windowTitles: [String]
    public let hierarchy: [ElementSnapshot]
    public let electron: ElectronCapabilities?

    public init(schemaVersion: Int, bundleID: String, appVersion: String, capturedAt: Date, roles: [String], attributes: [String], actions: [String], menuItems: [String], windowTitles: [String], hierarchy: [ElementSnapshot], electron: ElectronCapabilities?) {
        self.schemaVersion = schemaVersion; self.bundleID = bundleID; self.appVersion = appVersion; self.capturedAt = capturedAt
        self.roles = roles; self.attributes = attributes; self.actions = actions; self.menuItems = menuItems
        self.windowTitles = windowTitles; self.hierarchy = hierarchy; self.electron = electron
    }
}

public struct ElectronCapabilities: Codable, Sendable, Equatable {
    public let preloadNamespaces: [String]
    public let urlSchemes: [String]
    public let rpcMethodNames: [String]
    public let asarManifestEntries: [String]
}

public struct CapabilityDiff: Codable, Sendable, Equatable {
    public struct ChangeSet: Codable, Sendable, Equatable {
        public let added: [String]
        public let removed: [String]
    }
    public let fromVersion: String
    public let toVersion: String
    public let roles: ChangeSet
    public let attributes: ChangeSet
    public let actions: ChangeSet
    public let menus: ChangeSet
    public let rpcMethods: ChangeSet
}

public enum JSONOutput {
    public static func encode<T: Encodable>(_ value: T, pretty: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if pretty { encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] }
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}

public enum HandleLeasePolicy {
    public static func isValid(expiresAt: Date, locatorGeneration: UInt64, currentGeneration: UInt64, now: Date = Date()) -> Bool {
        expiresAt > now && locatorGeneration <= currentGeneration
    }
}

public enum WaitTimeoutPolicy {
    public static func bounded(_ seconds: TimeInterval) -> TimeInterval {
        min(max(seconds, 0.1), 30)
    }
}
