@preconcurrency import AppKit
import Foundation
import MacControlCore

@main
struct Main {
    static func main() async {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            let configuration = try MacControlConfiguration.load()
            switch arguments.first {
            case "doctor":
                try await doctor(configuration: configuration, prompt: arguments.contains("--prompt"))
            case "scan":
                let bundleID = arguments.dropFirst().first ?? "com.anysphere.sand"
                try await scan(bundleID: bundleID, configuration: configuration)
            case "version", "--version", "-v":
                print(MacControlServer.version)
            case "help", "--help", "-h":
                print("Usage: mac-control-mcp [doctor [--prompt] | scan [bundle-id] | version]\nWith no command, runs the MCP server over STDIO.")
            case nil:
                try await MacControlServer.run(configuration: configuration)
            case .some(let command):
                throw MacControlError.invalidArgument("Unknown command: \(command)")
            }
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }

    @MainActor
    private static func doctor(configuration: MacControlConfiguration, prompt: Bool) async throws {
        let ax = AXController(configuration: configuration)
        let trusted = prompt ? ax.requestTrustPrompt() : ax.isTrusted
        let grok = ax.listApps().first { $0.bundleID == "com.anysphere.sand" }
        let compatible = grok?.version.map(GrokBotAdapter.isSupported(version:))
        struct Report: Codable {
            let version: String; let accessibilityTrusted: Bool; let transport: String
            let configSource: String; let allowedBundleIDs: [String]
            let grokBotInstalled: Bool; let grokBotRunning: Bool; let grokBotVersion: String?; let grokBotCompatible: Bool?
        }
        let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.anysphere.sand") != nil
        let configURL = MacControlConfiguration.supportDirectory.appendingPathComponent("config.json")
        let report = Report(
            version: MacControlServer.version, accessibilityTrusted: trusted, transport: "stdio (MCP Swift SDK 0.12.1)",
            configSource: FileManager.default.fileExists(atPath: configURL.path) ? configURL.path : "built-in defaults",
            allowedBundleIDs: configuration.allowedBundleIDs.sorted(), grokBotInstalled: installed,
            grokBotRunning: grok != nil, grokBotVersion: grok?.version, grokBotCompatible: compatible
        )
        print(try JSONOutput.encode(report, pretty: true))
        if !trusted { throw MacControlError.accessibilityDenied }
    }

    @MainActor
    private static func scan(bundleID: String, configuration: MacControlConfiguration) async throws {
        let ax = AXController(configuration: configuration)
        let scanner = CapabilityScanner(ax: ax)
        let snapshot = try scanner.scan(bundleID: bundleID)
        let url = try scanner.save(snapshot)
        print(try JSONOutput.encode(snapshot, pretty: true))
        FileHandle.standardError.write(Data("saved: \(url.path)\n".utf8))
    }
}
