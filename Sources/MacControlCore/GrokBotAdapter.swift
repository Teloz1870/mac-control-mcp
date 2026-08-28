@preconcurrency import ApplicationServices
import Foundation

@MainActor
public final class GrokBotAdapter: AppAdapter {
    public static let identifier = "grokbot"
    public let bundleID = "com.anysphere.sand"
    public let supportedVersionDescription = "0.29.x"
    private let ax: AXController

    public init(ax: AXController) { self.ax = ax }

    public var capabilities: [String] {
        ["status", "bots", "conversation", "prompt", "question-widget", "routines"]
    }

    public var selectors: [SemanticSelector] {
        [
            .init(name: "prompt", candidates: [
                .init(role: "AXTextArea", identifier: "prompt-input"),
                .init(role: "AXTextArea", description: "Prompt"),
                .init(role: "AXTextField", description: "Prompt"),
            ]),
            .init(name: "conversation-details", candidates: [
                .init(role: "AXButton", identifier: "conversation-details"),
                .init(role: "AXButton", description: "View conversation details"),
            ]),
        ]
    }

    public var tools: [AdapterToolDefinition] {
        [
            .init(name: "grokbot_get_status", description: "Read Grok Bot process, version, compatibility, and current window status.", readOnly: true),
            .init(name: "grokbot_list_bots", description: "List bots exposed in the Grok Bot sidebar without screenshots.", readOnly: true),
            .init(name: "grokbot_open_bot", description: "Open a bot by its exact visible name.", readOnly: false, requiredArguments: ["name"]),
            .init(name: "grokbot_read_conversation", description: "Read redacted visible messages from the current conversation.", readOnly: true, optionalArguments: ["limit"]),
            .init(name: "grokbot_send_prompt", description: "Send one prompt to the current bot. This changes external state and requires host approval.", readOnly: false, requiredArguments: ["prompt"]),
            .init(name: "grokbot_answer_question", description: "Press an exact answer in the visible question widget. This changes external state.", readOnly: false, requiredArguments: ["answer"]),
            .init(name: "grokbot_list_routines", description: "Read visible Grok Bot routines without enabling or running them.", readOnly: true),
            .init(name: "grokbot_run_routine", description: "Run an exact visible routine. This changes external state and requires host approval.", readOnly: false, requiredArguments: ["name"]),
            .init(name: "grokbot_set_routine_enabled", description: "Enable or disable an exact visible routine. This changes external state.", readOnly: false, requiredArguments: ["name", "enabled"]),
        ]
    }

    public func detectedVersion() throws -> String {
        try ax.appInfo(bundleID: bundleID).version ?? "unknown"
    }

    public func validateCompatibility() throws {
        let version = try detectedVersion()
        guard Self.isSupported(version: version) else {
            throw MacControlError.unsupportedVersion(app: "Grok Bot", version: version, supported: supportedVersionDescription)
        }
    }

    public nonisolated static func isSupported(version: String) -> Bool {
        let parts = version.split(separator: ".")
        return parts.count >= 2 && parts[0] == "0" && parts[1] == "29"
    }

    public func call(tool: String, arguments: [String: String]) async throws -> String {
        try validateCompatibility()
        switch tool {
        case "grokbot_get_status":
            return try JSONOutput.encode(status(), pretty: true)
        case "grokbot_list_bots":
            return try JSONOutput.encode(try listBots(), pretty: true)
        case "grokbot_open_bot":
            let name = try required("name", arguments)
            try openBot(name: name)
            return try JSONOutput.encode(["opened": name])
        case "grokbot_read_conversation":
            let limit = min(max(Int(arguments["limit"] ?? "50") ?? 50, 1), 200)
            return try JSONOutput.encode(try readConversation(limit: limit), pretty: true)
        case "grokbot_send_prompt":
            try await sendPrompt(try required("prompt", arguments))
            return try JSONOutput.encode(["sent": true])
        case "grokbot_answer_question":
            let answer = try required("answer", arguments)
            try pressExactButton(title: answer, purpose: "question answer")
            return try JSONOutput.encode(["answered": answer])
        case "grokbot_list_routines":
            return try JSONOutput.encode(try listRoutines(), pretty: true)
        case "grokbot_run_routine":
            let name = try required("name", arguments)
            try routineAction(name: name, actionLabels: ["Run now", "Run"])
            return try JSONOutput.encode(["ran": name])
        case "grokbot_set_routine_enabled":
            let name = try required("name", arguments)
            guard let enabled = Bool(try required("enabled", arguments)) else { throw MacControlError.invalidArgument("enabled must be true or false") }
            try setRoutine(name: name, enabled: enabled)
            return try JSONOutput.encode(RoutineState(routine: name, enabled: enabled))
        default:
            throw MacControlError.invalidArgument("Unknown Grok Bot tool: \(tool)")
        }
    }

    private struct Status: Codable { let running: Bool; let version: String; let compatible: Bool; let active: Bool; let windows: [String] }
    private struct RoutineState: Codable { let routine: String; let enabled: Bool }
    private func status() throws -> Status {
        let app = try ax.appInfo(bundleID: bundleID)
        let windows = try ax.find(bundleID: bundleID, query: .init(role: "AXWindow"), limit: 20).compactMap(\.title)
        return Status(running: true, version: app.version ?? "unknown", compatible: Self.isSupported(version: app.version ?? "unknown"), active: app.active, windows: windows)
    }

    private func listBots() throws -> [String] {
        let elements = try ax.inspect(bundleID: bundleID, maxDepth: 12, maxNodes: 2_000)
        let excluded = Set(["new bot", "search", "plugins", "settings", "update", "view conversation details", "close", "minimize", "zoom"])
        return Array(Set(elements.filter { $0.role == "AXButton" && $0.actions.contains(kAXPressAction) }.compactMap { item in
            guard let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
                  !excluded.contains(where: { title.lowercased().hasPrefix($0) }), title.count <= 120 else { return nil }
            return title
        })).sorted()
    }

    private func openBot(name: String) throws {
        try pressExactButton(title: name, purpose: "bot")
    }

    private func readConversation(limit: Int) throws -> [String] {
        let elements = try ax.inspect(bundleID: bundleID, maxDepth: 12, maxNodes: 2_000)
        let controls = Set(["Bots", "New Bot", "Search", "View conversation details", "Send"])
        var messages: [String] = []
        for item in elements where ["AXStaticText", "AXTextArea"].contains(item.role ?? "") {
            let text = (item.value ?? item.title)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let text, !text.isEmpty, !controls.contains(text), text != messages.last else { continue }
            messages.append(text)
        }
        return Array(messages.suffix(limit))
    }

    private func sendPrompt(_ prompt: String) async throws {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MacControlError.invalidArgument("prompt must not be empty") }
        let selector = selectors.first { $0.name == "prompt" }!
        guard let field = try resolve(selector, using: ax, limit: 1).first else { throw MacControlError.elementNotFound("GrokBot.prompt") }
        let before = try readConversation(limit: 200).filter { $0 == prompt }.count
        try ax.submitText(handle: field.handle, value: prompt)
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let count = try readConversation(limit: 200).filter { $0 == prompt }.count - before
            if count == 1 { return }
            if count > 1 { throw MacControlError.unavailable("Prompt appeared more than once; refusing to retry.") }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw MacControlError.timeout("sent prompt did not appear exactly once; it was not retried")
    }

    private func pressExactButton(title: String, purpose: String) throws {
        let candidates = try ax.find(bundleID: bundleID, query: .init(role: "AXButton", title: title), limit: 5)
        guard candidates.count == 1, let button = candidates.first else {
            throw MacControlError.elementNotFound("exact \(purpose) button named \(title); found \(candidates.count)")
        }
        try ax.perform(handle: button.handle, action: kAXPressAction)
    }

    private func listRoutines() throws -> [String] {
        try openDetailsIfNeeded()
        let elements = try ax.inspect(bundleID: bundleID, maxDepth: 12, maxNodes: 2_000)
        return Array(Set(elements.compactMap { item in
            guard ["AXRow", "AXGroup", "AXStaticText"].contains(item.role ?? ""),
                  let text = item.title ?? item.value,
                  text.localizedCaseInsensitiveContains("routine") else { return nil }
            return text
        })).sorted()
    }

    private func openDetailsIfNeeded() throws {
        if !(try ax.find(bundleID: bundleID, query: .init(valueContains: "routine"), limit: 1)).isEmpty { return }
        let selector = selectors.first { $0.name == "conversation-details" }!
        guard let button = try resolve(selector, using: ax, limit: 1).first else {
            throw MacControlError.elementNotFound("GrokBot.conversation-details")
        }
        try ax.perform(handle: button.handle, action: kAXPressAction)
    }

    private func routineAction(name: String, actionLabels: [String]) throws {
        try openDetailsIfNeeded()
        guard !(try ax.find(bundleID: bundleID, query: .init(valueContains: name), limit: 5)).isEmpty else {
            throw MacControlError.elementNotFound("routine named \(name)")
        }
        for label in actionLabels {
            if let button = try ax.find(bundleID: bundleID, query: .init(role: "AXButton", title: label), limit: 2).first {
                try ax.perform(handle: button.handle, action: kAXPressAction); return
            }
        }
        throw MacControlError.elementNotFound("run control for routine \(name)")
    }

    private func setRoutine(name: String, enabled: Bool) throws {
        try openDetailsIfNeeded()
        guard !(try ax.find(bundleID: bundleID, query: .init(valueContains: name), limit: 5)).isEmpty else {
            throw MacControlError.elementNotFound("routine named \(name)")
        }
        let switches = try ax.find(bundleID: bundleID, query: .init(role: "AXCheckBox"), limit: 20)
        guard switches.count == 1, let toggle = switches.first else {
            throw MacControlError.elementNotFound("unambiguous enable switch for routine \(name)")
        }
        let current = ["1", "true", "on"].contains(toggle.value?.lowercased() ?? "")
        if current != enabled { try ax.perform(handle: toggle.handle, action: kAXPressAction) }
    }

    private func required(_ name: String, _ arguments: [String: String]) throws -> String {
        guard let value = arguments[name], !value.isEmpty else { throw MacControlError.invalidArgument("Missing required argument: \(name)") }
        return value
    }
}
