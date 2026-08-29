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
        ["status", "bots", "conversation", "prompt", "question-widget", "routines", "handover-pointer"]
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
            .init(name: "bot-list", candidates: [
                .init(role: "AXGroup", description: "Bot list"),
                .init(role: "AXGroup", description: "Bots"),
            ]),
            .init(name: "transcript", candidates: [
                .init(role: "AXGroup", description: "Conversation transcript"),
            ]),
            .init(name: "question-widget", candidates: [
                .init(role: "AXGroup", identifier: "question-widget"),
                .init(role: "AXGroup", identifier: "question"),
                .init(role: "AXGroup", description: "Question"),
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
            .init(name: "grokbot_notify_handover", description: "Ring the peer agent's doorbell: send a fixed pointer to one repo-relative handover file. Carries no content, no claims and no approval, because those travel through the repository. This changes external state and requires host approval.", readOnly: false, requiredArguments: ["path"]),
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
            try answerQuestion(answer)
            return try JSONOutput.encode(["answered": answer])
        case "grokbot_list_routines":
            return try JSONOutput.encode(try listRoutines(), pretty: true)
        case "grokbot_run_routine":
            let name = try required("name", arguments)
            try routineAction(name: name, actionLabels: ["Run now", "Run"])
            return try JSONOutput.encode(["ran": name])
        case "grokbot_notify_handover":
            let path = try required("path", arguments)
            try await notifyHandover(path: path)
            return try JSONOutput.encode(["notified": path])
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

    /// Resolves a named selector against an inspection already in hand, so a call that
    /// needs several landmarks does not re-traverse the app once per landmark.
    private func locate(_ name: String, in elements: [ElementSnapshot]) throws -> ElementSnapshot {
        guard let selector = selectors.first(where: { $0.name == name }) else {
            throw MacControlError.invalidArgument("No selector named \(name)")
        }
        for candidate in selector.candidates {
            if let match = elements.first(where: { SemanticMatcher.matches($0, query: candidate) }) { return match }
        }
        throw MacControlError.elementNotFound("\(Self.identifier).\(name); tested \(selector.candidates.count) selectors. Run mac_scan_capabilities and update the adapter.")
    }

    /// Rows of the sidebar's bot list. Anchored on the app's own "Bot list" landmark;
    /// structure is used only inside that landmark, never to find it.
    private func botRows(in elements: [ElementSnapshot]) throws -> [(row: ElementSnapshot, name: String)] {
        let list = try locate("bot-list", in: elements)
        let inList = ElementTree.descendants(of: list, in: elements)
        guard let content = inList.first(where: { $0.role == "AXList" }) else {
            throw MacControlError.elementNotFound("\(Self.identifier).bot-list contains no AXList")
        }
        return inList
            .filter { $0.path.count == content.path.count + 1 && ElementTree.isDescendant($0, of: content) }
            .compactMap { row in
                guard let name = ElementTree.descendants(of: row, in: elements)
                    .first(where: { $0.role == "AXStaticText" })?
                    .value?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
                return (row, name)
            }
    }

    private func listBots() throws -> [String] {
        try botRows(in: try fullTree()).map(\.name)
    }

    private func openBot(name: String) throws {
        let elements = try fullTree()
        let matches = try botRows(in: elements).filter { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
        guard matches.count == 1, let row = matches.first?.row else {
            throw MacControlError.elementNotFound("exactly one bot named \(name) in the sidebar; found \(matches.count)")
        }
        // The row itself is a plain group; the clickable element sits inside it. Take the
        // first descendant that actually exposes a press rather than assuming a role.
        guard let target = ElementTree.descendants(of: row, in: elements).first(where: { $0.actions.contains(kAXPressAction) })
            ?? (row.actions.contains(kAXPressAction) ? row : nil) else {
            throw MacControlError.elementNotFound("a pressable element inside the row for bot \(name)")
        }
        try ax.perform(handle: target.handle, action: kAXPressAction)
    }

    /// Reads the transcript only. Scoping matters: an app-wide sweep of static text also
    /// collects the settings panel and the sidebar, which then read as conversation.
    private func readConversation(limit: Int) throws -> [String] {
        let elements = try fullTree()
        let transcript = try locate("transcript", in: elements)
        let inTranscript = ElementTree.descendants(of: transcript, in: elements)
        let messages: [String] = inTranscript
            .filter { $0.subrole == "AXDocumentArticle" }
            .compactMap { article in
                let body = ElementTree.descendants(of: article, in: elements)
                    .filter { $0.role == "AXStaticText" }
                    .compactMap { $0.value?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                guard !body.isEmpty else { return nil }
                // The article title carries sender and timestamp; keeping it makes a
                // transcript readable without a second lookup.
                return [article.title, body].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
            }
        return Array(messages.suffix(limit))
    }

    private func sendPrompt(_ prompt: String) async throws {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MacControlError.invalidArgument("prompt must not be empty") }
        let selector = selectors.first { $0.name == "prompt" }!
        guard let field = try resolve(selector, using: ax, limit: 1).first else { throw MacControlError.elementNotFound("GrokBot.prompt") }
        let before = try readConversation(limit: 200).filter { $0.contains(prompt) }.count
        try ax.submitText(handle: field.handle, value: prompt)
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let count = try readConversation(limit: 200).filter { $0.contains(prompt) }.count - before
            if count == 1 { return }
            if count > 1 { throw MacControlError.unavailable("Prompt appeared more than once; refusing to retry.") }
            // Each poll is a full bounded AX traversal, so it is deliberately unhurried.
            try await Task.sleep(for: .milliseconds(300))
        }
        throw MacControlError.timeout("sent prompt did not appear exactly once; it was not retried")
    }

    /// Presses an answer strictly inside the visible question widget. Scoping matters:
    /// an app-wide title match could press an unrelated control that happens to carry
    /// the same label (an answer "Send" would otherwise hit the composer's Send button).
    private func answerQuestion(_ answer: String) throws {
        guard let widget = try resolve(selectors.first { $0.name == "question-widget" }!, using: ax, limit: 2).first else {
            throw MacControlError.elementNotFound("GrokBot.question-widget; refusing an app-wide press for answer \(answer)")
        }
        let elements = try fullTree()
        let candidates = ElementTree.descendants(of: widget, in: elements).filter {
            $0.role == "AXButton"
                && $0.title?.localizedCaseInsensitiveCompare(answer) == .orderedSame
                && $0.actions.contains(kAXPressAction)
        }
        guard candidates.count == 1, let button = candidates.first else {
            throw MacControlError.elementNotFound("exactly one answer button named \(answer) inside the question widget; found \(candidates.count)")
        }
        try ax.perform(handle: button.handle, action: kAXPressAction)
    }

    /// A UI bridge is an unreliable, unversioned channel, so it is allowed to carry
    /// one thing only: a pointer to a handover that already exists in the repository.
    /// The handover's content, its claims and any approval stay in git, where they are
    /// versioned and diffable and where the receiver can verify them independently.
    public nonisolated static func validHandoverPointer(_ path: String) -> Bool {
        guard path.count <= 200,
              path.range(of: #"\A[A-Za-z0-9._/-]+\.md\z"#, options: .regularExpression) != nil,
              !path.hasPrefix("/"), !path.contains(".."), !path.contains("//") else { return false }
        return true
    }

    private func notifyHandover(path: String) async throws {
        guard Self.validHandoverPointer(path) else {
            throw MacControlError.invalidArgument("A handover pointer must be a repo-relative .md path. This bridge carries a pointer only; the handover itself, and any approval, must travel through the repository.")
        }
        try await sendPrompt("HANDOVER: read \(path) and follow PROTOCOL.md")
    }

    private func listRoutines() throws -> [String] {
        try openDetailsIfNeeded()
        let elements = try fullTree()
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

    /// Runs one routine by pressing the control inside that routine's own row, so a
    /// "Run now" button belonging to a different routine can never be pressed instead.
    private func routineAction(name: String, actionLabels: [String]) throws {
        try openDetailsIfNeeded()
        let elements = try fullTree()
        let labels = elements.filter {
            ($0.value ?? $0.title)?.localizedCaseInsensitiveContains(name) == true
        }
        guard let label = labels.min(by: { ($0.value ?? $0.title ?? "").count < ($1.value ?? $1.title ?? "").count }) else {
            throw MacControlError.elementNotFound("routine named \(name)")
        }
        guard let row = ElementTree.innermostContainer(of: label, roles: ["AXRow", "AXGroup", "AXCell"], in: elements) else {
            throw MacControlError.elementNotFound("row container for routine \(name)")
        }
        let buttons = ElementTree.descendants(of: row, in: elements).filter { $0.role == "AXButton" && $0.actions.contains(kAXPressAction) }
        for actionLabel in actionLabels {
            let matches = buttons.filter { $0.title?.localizedCaseInsensitiveCompare(actionLabel) == .orderedSame }
            guard matches.count <= 1 else {
                throw MacControlError.elementNotFound("exactly one \(actionLabel) control inside the row for routine \(name); found \(matches.count)")
            }
            if let button = matches.first {
                try ax.perform(handle: button.handle, action: kAXPressAction); return
            }
        }
        throw MacControlError.elementNotFound("run control inside the row for routine \(name)")
    }

    /// Toggles the switch belonging to one routine. The switch is located inside the
    /// routine's own row, so a second routine on screen no longer makes this ambiguous
    /// and can never be toggled by mistake.
    private func setRoutine(name: String, enabled: Bool) throws {
        try openDetailsIfNeeded()
        let elements = try fullTree()
        let labels = elements.filter {
            ($0.value ?? $0.title)?.localizedCaseInsensitiveContains(name) == true
        }
        guard let label = labels.min(by: { ($0.value ?? $0.title ?? "").count < ($1.value ?? $1.title ?? "").count }) else {
            throw MacControlError.elementNotFound("routine named \(name)")
        }
        guard let row = ElementTree.innermostContainer(of: label, roles: ["AXRow", "AXGroup", "AXCell"], in: elements) else {
            throw MacControlError.elementNotFound("row container for routine \(name)")
        }
        let switches = ElementTree.descendants(of: row, in: elements).filter {
            ["AXCheckBox", "AXSwitch", "AXToggle"].contains($0.role ?? "") && $0.actions.contains(kAXPressAction)
        }
        guard switches.count == 1, let toggle = switches.first else {
            throw MacControlError.elementNotFound("exactly one enable switch inside the row for routine \(name); found \(switches.count)")
        }
        let current = ["1", "true", "on"].contains(toggle.value?.lowercased() ?? "")
        if current != enabled { try ax.perform(handle: toggle.handle, action: kAXPressAction) }
    }

    /// Scans as deep as the configuration allows rather than a hardcoded depth. A limit
    /// that stops short of the controls does not fail — it returns an empty list, which
    /// reads as "no bots" instead of "I did not look far enough".
    private func fullTree() throws -> [ElementSnapshot] {
        try ax.inspect(
            bundleID: bundleID,
            maxDepth: ax.configuration.maximumScanDepth,
            maxNodes: ax.configuration.maximumScanNodes
        )
    }

    private func required(_ name: String, _ arguments: [String: String]) throws -> String {
        guard let value = arguments[name], !value.isEmpty else { throw MacControlError.invalidArgument("Missing required argument: \(name)") }
        return value
    }
}
