import Foundation

@MainActor
public final class CapabilityScanner {
    private let ax: AXController

    public init(ax: AXController) { self.ax = ax }

    public func scan(bundleID: String, includeElectron: Bool = true) throws -> CapabilitySnapshot {
        let appURL = try ax.appBundleURL(bundleID: bundleID)
        // Read from disk rather than through Bundle, which caches: a snapshot stamped with
        // a stale version would silently diff against itself after an in-place update.
        let version = ax.bundleVersion(at: appURL) ?? "unknown"
        let hierarchy: [ElementSnapshot]
        if ax.listApps().contains(where: { $0.bundleID == bundleID }) {
            hierarchy = try ax.inspect(bundleID: bundleID, maxDepth: ax.configuration.maximumScanDepth, maxNodes: ax.configuration.maximumScanNodes)
        } else {
            hierarchy = []
        }
        var attributes = Set<String>()
        for element in hierarchy {
            for name in (try? ax.attributeNames(handle: element.handle)) ?? [] { attributes.insert(name) }
        }
        let electron = includeElectron ? ElectronScanner.scan(appURL: appURL) : nil
        return CapabilitySnapshot(
            schemaVersion: 2,
            bundleID: bundleID,
            appVersion: version,
            capturedAt: Date(),
            roles: Array(Set(hierarchy.compactMap(\.role))).sorted(),
            attributes: attributes.sorted(),
            actions: Array(Set(hierarchy.flatMap(\.actions))).sorted(),
            menuItems: Array(Set(hierarchy.filter { $0.role == "AXMenuItem" }.compactMap(\.title))).sorted(),
            windowTitles: Array(Set(hierarchy.filter { $0.role == "AXWindow" }.compactMap(\.title))).sorted(),
            hierarchy: hierarchy,
            electron: electron
        )
    }

    @discardableResult
    public func save(_ snapshot: CapabilitySnapshot) throws -> URL {
        try FileManager.default.createDirectory(at: MacControlConfiguration.snapshotsDirectory, withIntermediateDirectories: true)
        let safeVersion = snapshot.appVersion.replacingOccurrences(of: "/", with: "-")
        let url = MacControlConfiguration.snapshotsDirectory.appendingPathComponent("\(snapshot.bundleID)-\(safeVersion)-\(Int(snapshot.capturedAt.timeIntervalSince1970)).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(snapshot).write(to: url, options: .atomic)
        return url
    }

    public func loadSnapshot(at url: URL) throws -> CapabilitySnapshot {
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        let root = MacControlConfiguration.snapshotsDirectory.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        guard resolved.path.hasPrefix(root) else { throw MacControlError.invalidArgument("Snapshots may only be read from the mac-control-mcp Application Support directory.") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CapabilitySnapshot.self, from: Data(contentsOf: resolved))
    }

    public nonisolated static func diff(_ old: CapabilitySnapshot, _ new: CapabilitySnapshot) -> CapabilityDiff {
        func changes(_ a: [String], _ b: [String]) -> CapabilityDiff.ChangeSet {
            let left = Set(a), right = Set(b)
            return .init(added: Array(right.subtracting(left)).sorted(), removed: Array(left.subtracting(right)).sorted())
        }
        // The descriptions adapters select on. Comparing roles and actions says whether the
        // app changed shape; comparing these says whether the selectors still land.
        func landmarks(_ snapshot: CapabilitySnapshot) -> [String] {
            Array(Set(snapshot.hierarchy.compactMap { element in
                guard let description = element.description?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !description.isEmpty else { return nil }
                return description
            })).sorted()
        }
        return CapabilityDiff(
            fromVersion: old.appVersion, toVersion: new.appVersion,
            roles: changes(old.roles, new.roles),
            attributes: changes(old.attributes, new.attributes),
            actions: changes(old.actions, new.actions),
            menus: changes(old.menuItems, new.menuItems),
            rpcMethods: changes(old.electron?.rpcMethodNames ?? [], new.electron?.rpcMethodNames ?? []),
            landmarks: changes(landmarks(old), landmarks(new))
        )
    }
}

public enum ElectronScanner {
    private struct ASAREntry { let offset: Int; let size: Int; let path: String }

    public static func scan(appURL: URL) -> ElectronCapabilities? {
        let resources = appURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let asarURL = resources.appendingPathComponent("app.asar")
        guard let data = try? Data(contentsOf: asarURL, options: .mappedIfSafe), data.count >= 16,
              let manifest = parseManifest(data) else { return nil }
        let entries = flatten(manifest.files)
        let paths = entries.map(\.path).sorted()
        let candidates = entries.filter {
            let lower = $0.path.lowercased()
            let script = lower.hasSuffix(".js") || lower.hasSuffix(".cjs") || lower.hasSuffix(".mjs")
            return script && (lower.contains("preload") || lower.contains("main")) && $0.size <= 8_000_000
        }.prefix(40)
        var namespaces = Set<String>()
        var rpc = Set<String>()
        for entry in candidates {
            guard entry.offset >= 0, entry.size >= 0, manifest.dataOffset + entry.offset + entry.size <= data.count else { continue }
            let bytes = data.subdata(in: (manifest.dataOffset + entry.offset)..<(manifest.dataOffset + entry.offset + entry.size))
            guard let text = String(data: bytes, encoding: .utf8) else { continue }
            namespaces.formUnion(matches(in: text, pattern: #"exposeInMainWorld\(\s*[\"']([A-Za-z_$][A-Za-z0-9_$.-]*)[\"']"#))
            rpc.formUnion(matches(in: text, pattern: #"\b([A-Za-z][A-Za-z0-9]{2,80})\s*:\s*\{\s*args\s*:"#))
            rpc.formUnion(matches(in: text, pattern: #"method\s*:\s*[\"']([A-Za-z][A-Za-z0-9]{2,80})[\"']"#))
        }
        let bundle = Bundle(url: appURL)
        let urlTypes = bundle?.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        return ElectronCapabilities(
            preloadNamespaces: namespaces.sorted(), urlSchemes: Array(Set(schemes)).sorted(),
            rpcMethodNames: rpc.sorted(), asarManifestEntries: paths
        )
    }

    private struct ParsedManifest { let files: [String: Any]; let dataOffset: Int }

    private static func parseManifest(_ data: Data) -> ParsedManifest? {
        func u32(_ offset: Int) -> Int {
            Int(data[offset..<offset + 4].enumerated().reduce(UInt32(0)) { $0 | (UInt32($1.element) << UInt32(8 * $1.offset)) })
        }
        let headerSize = u32(4)
        let jsonSize = u32(12)
        guard headerSize > 0, jsonSize > 0, jsonSize < 64_000_000, 16 + jsonSize <= data.count else { return nil }
        let jsonData = data.subdata(in: 16..<(16 + jsonSize))
        guard let object = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let files = object["files"] as? [String: Any] else { return nil }
        return ParsedManifest(files: files, dataOffset: 8 + headerSize)
    }

    private static func flatten(_ files: [String: Any], prefix: String = "") -> [ASAREntry] {
        var output: [ASAREntry] = []
        for (name, raw) in files {
            guard let info = raw as? [String: Any] else { continue }
            let path = prefix.isEmpty ? name : "\(prefix)/\(name)"
            if let children = info["files"] as? [String: Any] {
                output += flatten(children, prefix: path)
            } else if let size = info["size"] as? Int {
                let offset = Int(info["offset"] as? String ?? "") ?? 0
                output.append(ASAREntry(offset: offset, size: size, path: path))
            }
        }
        return output
    }

    private static func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }
}
