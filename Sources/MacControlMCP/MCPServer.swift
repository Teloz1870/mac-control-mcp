import Foundation
import MacControlCore
import MCP

@MainActor
final class ToolService {
    let ax: AXController
    let scanner: CapabilityScanner
    let adapters: [any AppAdapter]

    init(configuration: MacControlConfiguration) {
        let ax = AXController(configuration: configuration)
        self.ax = ax
        self.scanner = CapabilityScanner(ax: ax)
        self.adapters = [GrokBotAdapter(ax: ax)]
    }

    var tools: [Tool] {
        genericTools + adapters.flatMap { adapter in adapter.tools.map(tool(from:)) }
    }

    func call(name: String, arguments: [String: Value]) async throws -> String {
        let started = ContinuousClock.now
        let bundleID = arguments["bundle_id"]?.stringValue ?? (name.hasPrefix("grokbot_") ? "com.anysphere.sand" : "-")
        do {
            let result: String
            switch name {
            case "mac_list_apps":
                result = try JSONOutput.encode(ax.listApps(), pretty: true)
            case "mac_inspect_app":
                let bundle = try requiredString("bundle_id", arguments)
                let depth = arguments["max_depth"]?.intValue ?? 6
                let nodes = arguments["max_nodes"]?.intValue ?? 500
                result = try JSONOutput.encode(try ax.inspect(bundleID: bundle, maxDepth: depth, maxNodes: nodes), pretty: true)
            case "mac_find_elements":
                let bundle = try requiredString("bundle_id", arguments)
                let query = ElementQuery(
                    role: arguments["role"]?.stringValue,
                    identifier: arguments["identifier"]?.stringValue,
                    title: arguments["title"]?.stringValue,
                    description: arguments["description"]?.stringValue,
                    valueContains: arguments["value_contains"]?.stringValue
                )
                result = try JSONOutput.encode(try ax.find(bundleID: bundle, query: query, limit: arguments["limit"]?.intValue ?? 25), pretty: true)
            case "mac_read_element":
                result = try JSONOutput.encode(try ax.read(handle: .init(try requiredString("handle", arguments))), pretty: true)
            case "mac_perform_action":
                try ax.perform(handle: .init(try requiredString("handle", arguments)), action: try requiredString("action", arguments))
                result = #"{"performed":true}"#
            case "mac_set_value":
                try ax.setValue(handle: .init(try requiredString("handle", arguments)), value: try requiredString("value", arguments))
                result = #"{"set":true}"#
            case "mac_press_menu_item":
                let bundle = try requiredString("bundle_id", arguments)
                let path = arguments["path"]?.arrayValue?.compactMap(\.stringValue) ?? []
                try await ax.pressMenuItem(bundleID: bundle, path: path)
                result = #"{"pressed":true}"#
            case "mac_wait_for":
                let bundle = try requiredString("bundle_id", arguments)
                let query = ElementQuery(
                    role: arguments["role"]?.stringValue,
                    identifier: arguments["identifier"]?.stringValue,
                    title: arguments["title"]?.stringValue,
                    description: arguments["description"]?.stringValue,
                    valueContains: arguments["value_contains"]?.stringValue
                )
                let found = try await ax.waitFor(bundleID: bundle, query: query, timeout: arguments["timeout_seconds"]?.doubleValue ?? Double(arguments["timeout_seconds"]?.intValue ?? 10))
                result = try JSONOutput.encode(found, pretty: true)
            case "mac_scan_capabilities":
                let bundle = try requiredString("bundle_id", arguments)
                let snapshot = try scanner.scan(bundleID: bundle, includeElectron: arguments["include_electron"]?.boolValue ?? true)
                let url = try scanner.save(snapshot)
                result = try JSONOutput.encode(ScanResult(snapshot: snapshot, savedTo: url.path), pretty: true)
            case "mac_diff_capabilities":
                let old = try scanner.loadSnapshot(at: snapshotURL(try requiredString("from_snapshot", arguments)))
                let new = try scanner.loadSnapshot(at: snapshotURL(try requiredString("to_snapshot", arguments)))
                result = try JSONOutput.encode(CapabilityScanner.diff(old, new), pretty: true)
            default:
                guard let adapter = adapters.first(where: { candidate in candidate.tools.contains { $0.name == name } }) else {
                    throw MacControlError.invalidArgument("Unknown tool: \(name)")
                }
                result = try await adapter.call(tool: name, arguments: arguments.mapValues(stringify))
            }
            audit(tool: name, bundleID: bundleID, started: started, errorType: nil)
            return result
        } catch {
            audit(tool: name, bundleID: bundleID, started: started, errorType: String(describing: type(of: error)))
            throw error
        }
    }

    private struct ScanResult: Codable { let snapshot: CapabilitySnapshot; let savedTo: String }

    private var genericTools: [Tool] {
        [
            tool("mac_list_apps", "List only running apps in the explicit allowlist.", readOnly: true),
            tool("mac_inspect_app", "Read a bounded, redacted Accessibility tree and issue short-lived handles.", readOnly: true, required: ["bundle_id"], optional: ["max_depth", "max_nodes"]),
            tool("mac_find_elements", "Find Accessibility elements using semantic attributes, never screen coordinates.", readOnly: true, required: ["bundle_id"], optional: ["role", "identifier", "title", "description", "value_contains", "limit"]),
            tool("mac_read_element", "Re-find and read one element through a short-lived handle.", readOnly: true, required: ["handle"]),
            tool("mac_perform_action", "Perform an action already exposed by an Accessibility element.", readOnly: false, destructive: true, required: ["handle", "action"]),
            tool("mac_set_value", "Set a non-secure Accessibility value. Secure and secret-like fields are blocked.", readOnly: false, destructive: true, required: ["handle", "value"]),
            tool("mac_press_menu_item", "Press an exact visible menu item in an allowed app.", readOnly: false, destructive: true, required: ["bundle_id", "path"], arrays: ["path"]),
            tool("mac_wait_for", "Wait with AXObserver-backed checks for a semantic element condition.", readOnly: true, required: ["bundle_id"], optional: ["role", "identifier", "title", "description", "value_contains", "timeout_seconds"]),
            tool("mac_scan_capabilities", "Scan live AX metadata and read-only Electron metadata, then save a redacted local snapshot.", readOnly: false, required: ["bundle_id"], optional: ["include_electron"]),
            tool("mac_diff_capabilities", "Compare two snapshots stored by mac-control-mcp in Application Support.", readOnly: true, required: ["from_snapshot", "to_snapshot"]),
        ]
    }

    private func tool(from definition: AdapterToolDefinition) -> Tool {
        tool(definition.name, definition.description, readOnly: definition.readOnly, destructive: definition.destructive, required: definition.requiredArguments, optional: definition.optionalArguments)
    }

    private func tool(_ name: String, _ description: String, readOnly: Bool, destructive: Bool = false, required: [String] = [], optional: [String] = [], arrays: Set<String> = []) -> Tool {
        var properties: [String: Value] = [:]
        for key in required + optional {
            let type: Value
            if arrays.contains(key) {
                type = .object(["type": .string("array"), "items": .object(["type": .string("string")])])
            } else if ["max_depth", "max_nodes", "limit"].contains(key) {
                type = .object(["type": .string("integer")])
            } else if key == "timeout_seconds" {
                type = .object(["type": .string("number")])
            } else if ["include_electron", "enabled"].contains(key) {
                type = .object(["type": .string("boolean")])
            } else {
                type = .object(["type": .string("string")])
            }
            properties[key] = type
        }
        return Tool(
            name: name,
            description: description,
            inputSchema: .object(["type": .string("object"), "properties": .object(properties), "required": .array(required.map(Value.string)), "additionalProperties": .bool(false)]),
            annotations: .init(readOnlyHint: readOnly, destructiveHint: destructive, idempotentHint: readOnly, openWorldHint: false)
        )
    }

    private func requiredString(_ name: String, _ arguments: [String: Value]) throws -> String {
        guard let value = arguments[name]?.stringValue, !value.isEmpty else { throw MacControlError.invalidArgument("Missing required string argument: \(name)") }
        return value
    }

    private func stringify(_ value: Value) -> String {
        switch value {
        case .string(let value): value
        case .bool(let value): String(value)
        case .int(let value): String(value)
        case .double(let value): String(value)
        default: ""
        }
    }

    private func snapshotURL(_ value: String) -> URL {
        if value.contains("/") { return URL(fileURLWithPath: value) }
        return MacControlConfiguration.snapshotsDirectory.appendingPathComponent(value)
    }

    private func audit(tool: String, bundleID: String, started: ContinuousClock.Instant, errorType: String?) {
        let duration = started.duration(to: .now)
        let ms = Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
        let line = "tool=\(tool) duration_ms=\(String(format: "%.1f", ms)) bundle_id=\(bundleID) error_type=\(errorType ?? "none")\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}

enum MacControlServer {
    static let version = "0.1.1-preview"
    static let instructions = "mac-control-mcp controls explicitly allowed local macOS apps through Accessibility. Reading is redacted. Sending prompts, changing values, pressing controls, and running routines modify external state and must follow the host client's approval rules. Never request secrets, secure fields, wallet data, cookies, or tokens. Handles expire quickly; inspect again when stale. Selectors never fall back to screen coordinates. Unknown Grok Bot versions must stop and be rescanned."

    @MainActor
    static func run(configuration: MacControlConfiguration) async throws {
        let service = ToolService(configuration: configuration)
        let server = Server(
            name: "mac-control-mcp",
            version: version,
            title: "mac-control-mcp",
            instructions: instructions,
            capabilities: .init(tools: .init(listChanged: false)),
            configuration: .strict
        )
        await server.withMethodHandler(ListTools.self) { _ in
            await MainActor.run { ListTools.Result(tools: service.tools) }
        }
        await server.withMethodHandler(CallTool.self) { params in
            do {
                let text = try await service.call(name: params.name, arguments: params.arguments ?? [:])
                return CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)], isError: false)
            } catch {
                return CallTool.Result(content: [.text(text: error.localizedDescription, annotations: nil, _meta: nil)], isError: true)
            }
        }
        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}
