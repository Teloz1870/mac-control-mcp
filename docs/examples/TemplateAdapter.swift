import MacControlCore

@MainActor
final class ExampleAdapter: AppAdapter {
    static let identifier = "example"
    let bundleID = "com.example.app"
    let supportedVersionDescription = "1.x"
    let ax: AXController

    init(ax: AXController) { self.ax = ax }

    var selectors: [SemanticSelector] {
        [.init(name: "primary-action", candidates: [
            .init(role: "AXButton", identifier: "primary-action"),
            .init(role: "AXButton", description: "Primary action"),
        ])]
    }
    var capabilities: [String] { ["primary-action"] }
    var tools: [AdapterToolDefinition] {
        [.init(name: "example_get_status", description: "Read status.", readOnly: true)]
    }

    func detectedVersion() throws -> String { try ax.appInfo(bundleID: bundleID).version ?? "unknown" }
    func validateCompatibility() throws {
        guard try detectedVersion().hasPrefix("1.") else {
            throw MacControlError.unsupportedVersion(app: "Example", version: try detectedVersion(), supported: supportedVersionDescription)
        }
    }
    func call(tool: String, arguments: [String: String]) async throws -> String {
        try validateCompatibility()
        return try JSONOutput.encode(try ax.appInfo(bundleID: bundleID), pretty: true)
    }
}
