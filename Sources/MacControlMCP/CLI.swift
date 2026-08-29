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
            let selectors: [String: String]
        }
        let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.anysphere.sand") != nil
        let configURL = MacControlConfiguration.supportDirectory.appendingPathComponent("config.json")
        let report = Report(
            version: MacControlServer.version, accessibilityTrusted: trusted, transport: "stdio (MCP Swift SDK 0.12.1)",
            configSource: FileManager.default.fileExists(atPath: configURL.path) ? configURL.path : "built-in defaults",
            allowedBundleIDs: configuration.allowedBundleIDs.sorted(), grokBotInstalled: installed,
            grokBotRunning: grok != nil, grokBotVersion: grok?.version, grokBotCompatible: compatible,
            selectors: resolveSelectors(ax: ax, running: grok != nil)
        )
        print(try JSONOutput.encode(report, pretty: true))
        if !trusted { throw MacControlError.accessibilityDenied }
    }

    /// Resolves every selector the adapter declares, against the app as it is right now.
    ///
    /// A capability diff says what moved in the app. It does not say whether the adapter's
    /// own selectors still land, and checking that by hand after each update is a step
    /// someone eventually forgets. This answers the question directly, per selector.
    @MainActor
    private static func resolveSelectors(ax: AXController, running: Bool) -> [String: String] {
        let adapter = GrokBotAdapter(ax: ax)
        guard running else {
            return Dictionary(uniqueKeysWithValues: adapter.selectors.map { ($0.name, "not checked: app not running") })
        }
        var results: [String: String] = [:]
        for selector in adapter.selectors {
            do {
                let matches = try adapter.resolve(selector, using: ax, limit: 5)
                results[selector.name] = matches.count == 1
                    ? "ok"
                    : "ambiguous: \(matches.count) matches"
            } catch {
                results[selector.name] = "FAILED: \(error.localizedDescription)"
            }
        }
        return results
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
