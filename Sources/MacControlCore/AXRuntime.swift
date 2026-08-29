@preconcurrency import AppKit
@preconcurrency import ApplicationServices
import Foundation

private struct ElementLocator: Sendable {
    let bundleID: String
    let pid: pid_t
    let path: [Int]
    let fingerprint: String
    let generation: UInt64
    let expiresAt: Date
}

private final class AXEventMonitor: @unchecked Sendable {
    private var observer: AXObserver?
    private var storedEventCount = 0
    private let lock = NSLock()

    var eventCount: Int {
        lock.lock(); defer { lock.unlock() }
        return storedEventCount
    }

    init(pid: pid_t, element: AXUIElement) {
        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, pointer in
            guard let pointer else { return }
            let monitor = Unmanaged<AXEventMonitor>.fromOpaque(pointer).takeUnretainedValue()
            monitor.lock.lock()
            monitor.storedEventCount += 1
            monitor.lock.unlock()
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return }
        observer = created
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        for notification in [
            kAXWindowCreatedNotification,
            kAXFocusedUIElementChangedNotification,
            kAXValueChangedNotification,
            kAXTitleChangedNotification,
            kAXUIElementDestroyedNotification,
        ] {
            AXObserverAddNotification(created, element, notification as CFString, pointer)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
    }

    deinit {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
    }
}

@MainActor
public final class AXController {
    public private(set) var configuration: MacControlConfiguration
    private var handles: [String: ElementLocator] = [:]
    private var generation: UInt64 = 0

    public init(configuration: MacControlConfiguration = .default) {
        self.configuration = configuration
    }

    public var isTrusted: Bool { AXIsProcessTrusted() }

    public func requestTrustPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public func listApps() -> [AppInfo] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard let bundleID = app.bundleIdentifier,
                  configuration.allowedBundleIDs.contains(bundleID) else { return nil }
            return AppInfo(
                bundleID: bundleID,
                name: app.localizedName ?? bundleID,
                pid: app.processIdentifier,
                version: app.bundleURL.flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String },
                active: app.isActive
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func appInfo(bundleID: String) throws -> AppInfo {
        try configuration.validate(bundleID: bundleID)
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
            throw MacControlError.appNotRunning(bundleID)
        }
        return AppInfo(
            bundleID: bundleID,
            name: app.localizedName ?? bundleID,
            pid: app.processIdentifier,
            version: app.bundleURL.flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String },
            active: app.isActive
        )
    }

    public func appBundleURL(bundleID: String) throws -> URL {
        try configuration.validate(bundleID: bundleID)
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }), let url = running.bundleURL {
            return url
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) { return url }
        throw MacControlError.unavailable("App \(bundleID) is not installed.")
    }

    public func inspect(bundleID: String, maxDepth: Int = 6, maxNodes: Int = 500) throws -> [ElementSnapshot] {
        guard isTrusted else { throw MacControlError.accessibilityDenied }
        let app = try appInfo(bundleID: bundleID)
        generation &+= 1
        purgeExpiredHandles()
        let root = AXUIElementCreateApplication(app.pid)
        AXUIElementSetMessagingTimeout(root, 1.0)
        var output: [ElementSnapshot] = []
        traverse(
            root,
            bundleID: bundleID,
            pid: app.pid,
            path: [],
            depth: 0,
            maxDepth: min(max(maxDepth, 0), configuration.maximumScanDepth),
            maxNodes: min(max(maxNodes, 1), configuration.maximumScanNodes),
            output: &output
        )
        return output
    }

    public func find(bundleID: String, query: ElementQuery, limit: Int = 25) throws -> [ElementSnapshot] {
        let all = try inspect(bundleID: bundleID, maxDepth: configuration.maximumScanDepth, maxNodes: configuration.maximumScanNodes)
        return all.filter { SemanticMatcher.matches($0, query: query) }.prefix(max(1, min(limit, 100))).map { $0 }
    }

    public func read(handle: ElementHandle) throws -> ElementSnapshot {
        let (element, locator) = try resolve(handle)
        return snapshot(element, handle: handle.rawValue, locator: locator, depth: locator.path.count)
    }

    public func perform(handle: ElementHandle, action: String) throws {
        let (element, _) = try resolve(handle)
        let actions = actionNames(element)
        guard actions.contains(action) else { throw MacControlError.invalidArgument("Element does not expose action \(action). Available: \(actions.joined(separator: ", "))") }
        let error = AXUIElementPerformAction(element, action as CFString)
        guard error == .success else { throw MacControlError.accessibility(operation: action, code: error.rawValue) }
    }

    public func setValue(handle: ElementHandle, value: String) throws {
        let (element, locator) = try resolve(handle)
        let current = snapshot(element, handle: handle.rawValue, locator: locator, depth: locator.path.count)
        try SafetyPolicy.validateWritable(role: current.role, subrole: current.subrole, identifier: current.identifier, title: current.title, description: current.description)
        var settable = DarwinBoolean(false)
        let check = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        guard check == .success, settable.boolValue else { throw MacControlError.invalidArgument("Element value is not settable.") }
        let error = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFTypeRef)
        guard error == .success else { throw MacControlError.accessibility(operation: "set value", code: error.rawValue) }
    }

    public func submitText(handle: ElementHandle, value: String) throws {
        let (element, locator) = try resolve(handle)
        let current = snapshot(element, handle: handle.rawValue, locator: locator, depth: locator.path.count)
        try SafetyPolicy.validateWritable(role: current.role, subrole: current.subrole, identifier: current.identifier, title: current.title, description: current.description)
        try setValue(handle: handle, value: value)
        let focusResult = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        if actionNames(element).contains(kAXConfirmAction) {
            let result = AXUIElementPerformAction(element, kAXConfirmAction as CFString)
            if result == .success { return }
        }
        // Fallback only. A synthetic Return is the one operation that can escape the
        // target app, so it is refused unless that app owns the keyboard focus, and
        // it is delivered to the app's process rather than the global event tap.
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == locator.pid else {
            throw MacControlError.unavailable("Element exposes no AXConfirm action, and \(locator.bundleID) is not frontmost. Refusing to send a Return key event that another app could receive. Bring the app to the front and retry.")
        }
        // Frontmost only settles which app receives the key. Within that app the Return
        // still lands wherever focus actually is, so the element must confirm it holds
        // focus — the setter's own result is not taken on trust.
        guard focusResult == .success, boolAttribute(element, kAXFocusedAttribute) == true else {
            throw MacControlError.unavailable("Element did not take keyboard focus, so a Return key event could reach a different field in the same app. Refusing to send it.")
        }
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: false) else {
            throw MacControlError.unavailable("Could not create a Return key event.")
        }
        down.postToPid(locator.pid)
        up.postToPid(locator.pid)
    }

    /// Presses a menu item by walking the menu bar level by level. Every component
    /// of `path` must match exactly one item at its own level, so "File > Close"
    /// can never resolve to "Window > Close".
    public func pressMenuItem(bundleID: String, path: [String]) async throws {
        guard !path.isEmpty else { throw MacControlError.invalidArgument("Menu path must not be empty.") }
        guard isTrusted else { throw MacControlError.accessibilityDenied }
        let app = try appInfo(bundleID: bundleID)
        let root = AXUIElementCreateApplication(app.pid)
        AXUIElementSetMessagingTimeout(root, 1.0)
        var current = try menuBar(of: root, bundleID: bundleID)
        // Menus opened to reveal their contents, closed again if the walk fails so a
        // failed lookup does not leave the app's menus hanging open in the user's face.
        var opened: [AXUIElement] = []
        do {
            for (index, component) in path.enumerated() {
                var candidates = menuChildren(current)
                // Many apps populate a submenu only once it is opened, so an empty level
                // is not proof the item is absent. Open the parent and look again before
                // concluding anything.
                if candidates.isEmpty, index > 0, actionNames(current).contains(kAXPressAction) {
                    let result = AXUIElementPerformAction(current, kAXPressAction as CFString)
                    if result == .success {
                        opened.append(current)
                        try await Task.sleep(for: .milliseconds(150))
                        candidates = menuChildren(current)
                    }
                }
                let matches = candidates.filter {
                    stringAttribute($0, kAXTitleAttribute)?.localizedCaseInsensitiveCompare(component) == .orderedSame
                }
                let walked = path.prefix(index + 1).joined(separator: " > ")
                guard matches.count == 1, let next = matches.first else {
                    throw MacControlError.elementNotFound("menu item \(walked); \(matches.count) items match at that level")
                }
                current = next
            }
            guard actionNames(current).contains(kAXPressAction) else {
                throw MacControlError.invalidArgument("Menu item \(path.joined(separator: " > ")) exposes no AXPress action.")
            }
            let error = AXUIElementPerformAction(current, kAXPressAction as CFString)
            guard error == .success else { throw MacControlError.accessibility(operation: kAXPressAction, code: error.rawValue) }
        } catch {
            closeMenus(opened)
            throw error
        }
    }

    private func closeMenus(_ opened: [AXUIElement]) {
        for element in opened.reversed() where actionNames(element).contains(kAXCancelAction) {
            _ = AXUIElementPerformAction(element, kAXCancelAction as CFString)
        }
    }

    private func menuBar(of root: AXUIElement, bundleID: String) throws -> AXUIElement {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXMenuBarAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            throw MacControlError.elementNotFound("menu bar for \(bundleID)")
        }
        return value as! AXUIElement
    }

    /// Children of a menu node, transparently descending through the AXMenu
    /// wrapper macOS inserts between a menu item and its submenu items.
    private func menuChildren(_ element: AXUIElement) -> [AXUIElement] {
        children(element).flatMap { child in
            stringAttribute(child, kAXRoleAttribute) == kAXMenuRole ? children(child) : [child]
        }
    }

    public func waitFor(bundleID: String, query: ElementQuery, timeout: TimeInterval) async throws -> ElementSnapshot {
        let app = try appInfo(bundleID: bundleID)
        let root = AXUIElementCreateApplication(app.pid)
        let monitor = AXEventMonitor(pid: app.pid, element: root)
        let deadline = Date().addingTimeInterval(WaitTimeoutPolicy.bounded(timeout))
        var observed = monitor.eventCount
        while Date() < deadline {
            if let result = try find(bundleID: bundleID, query: query, limit: 1).first { return result }
            // AXObserver drives immediate rechecks; the short timer also covers apps that omit notifications.
            if monitor.eventCount != observed { observed = monitor.eventCount; continue }
            try await Task.sleep(for: .milliseconds(80))
        }
        throw MacControlError.timeout("element matching the semantic selector")
    }

    public func attributeNames(handle: ElementHandle) throws -> [String] {
        let (element, _) = try resolve(handle)
        var names: CFArray?
        let error = AXUIElementCopyAttributeNames(element, &names)
        guard error == .success else { return [] }
        return (names as? [String])?.sorted() ?? []
    }

    private func traverse(_ element: AXUIElement, bundleID: String, pid: pid_t, path: [Int], depth: Int, maxDepth: Int, maxNodes: Int, output: inout [ElementSnapshot]) {
        guard output.count < maxNodes else { return }
        let (handle, locator) = makeLocator(element: element, bundleID: bundleID, pid: pid, path: path)
        output.append(snapshot(element, handle: handle, locator: locator, depth: depth))
        guard depth < maxDepth else { return }
        for (index, child) in children(element).enumerated() {
            guard output.count < maxNodes else { return }
            traverse(child, bundleID: bundleID, pid: pid, path: path + [index], depth: depth + 1, maxDepth: maxDepth, maxNodes: maxNodes, output: &output)
        }
    }

    private func makeLocator(element: AXUIElement, bundleID: String, pid: pid_t, path: [Int]) -> (String, ElementLocator) {
        let fingerprint = fingerprint(element, path: path)
        let raw = "axh_\(pid)_\(generation)_\(stableHash("\(fingerprint)|\(UUID().uuidString)"))"
        let locator = ElementLocator(bundleID: bundleID, pid: pid, path: path, fingerprint: fingerprint, generation: generation, expiresAt: Date().addingTimeInterval(configuration.handleLifetimeSeconds))
        handles[raw] = locator
        return (raw, locator)
    }

    private func snapshot(_ element: AXUIElement, handle: String, locator: ElementLocator, depth: Int) -> ElementSnapshot {
        let role = stringAttribute(element, kAXRoleAttribute)
        let subrole = stringAttribute(element, kAXSubroleAttribute)
        let identifier = stringAttribute(element, kAXIdentifierAttribute)
        let title = stringAttribute(element, kAXTitleAttribute)
        let description = stringAttribute(element, kAXDescriptionAttribute)
        let rawValue = stringAttribute(element, kAXValueAttribute)
        return ElementSnapshot(
            handle: ElementHandle(handle), bundleID: locator.bundleID, pid: locator.pid,
            role: role, subrole: subrole, identifier: identifier,
            title: SafetyPolicy.redact(title, role: role, subrole: subrole, identifier: identifier, title: title, description: description),
            description: SafetyPolicy.redact(description, role: role, subrole: subrole, identifier: identifier, title: title, description: description),
            value: SafetyPolicy.redact(rawValue, role: role, subrole: subrole, identifier: identifier, title: title, description: description),
            enabled: boolAttribute(element, kAXEnabledAttribute), actions: actionNames(element), depth: depth, childCount: children(element).count,
            path: locator.path
        )
    }

    private func resolve(_ handle: ElementHandle) throws -> (AXUIElement, ElementLocator) {
        purgeExpiredHandles()
        guard let locator = handles[handle.rawValue],
              HandleLeasePolicy.isValid(expiresAt: locator.expiresAt, locatorGeneration: locator.generation, currentGeneration: generation) else {
            throw MacControlError.staleHandle(handle.rawValue)
        }
        guard let running = NSRunningApplication(processIdentifier: locator.pid), running.bundleIdentifier == locator.bundleID else {
            throw MacControlError.staleHandle(handle.rawValue)
        }
        let root = AXUIElementCreateApplication(locator.pid)
        if let candidate = element(at: locator.path, root: root), fingerprint(candidate, path: locator.path) == locator.fingerprint {
            return (candidate, locator)
        }
        var matches: [(AXUIElement, [Int])] = []
        searchFingerprint(root, expected: locator.fingerprint, path: [], depth: 0, matches: &matches)
        guard matches.count == 1 else { throw MacControlError.staleHandle(handle.rawValue) }
        return (matches[0].0, locator)
    }

    private func element(at path: [Int], root: AXUIElement) -> AXUIElement? {
        var current = root
        for index in path {
            let list = children(current)
            guard list.indices.contains(index) else { return nil }
            current = list[index]
        }
        return current
    }

    private func searchFingerprint(_ element: AXUIElement, expected: String, path: [Int], depth: Int, matches: inout [(AXUIElement, [Int])]) {
        guard matches.count < 2, depth <= configuration.maximumScanDepth else { return }
        if fingerprint(element, path: path) == expected { matches.append((element, path)) }
        for (index, child) in children(element).enumerated() {
            searchFingerprint(child, expected: expected, path: path + [index], depth: depth + 1, matches: &matches)
        }
    }

    private func fingerprint(_ element: AXUIElement, path: [Int]) -> String {
        [stringAttribute(element, kAXRoleAttribute), stringAttribute(element, kAXSubroleAttribute), stringAttribute(element, kAXIdentifierAttribute), stringAttribute(element, kAXTitleAttribute), path.map(String.init).joined(separator: ".")]
            .map { $0 ?? "" }.joined(separator: "|")
    }

    private func children(_ element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success, let value else { return nil }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private func boolAttribute(_ element: AXUIElement, _ name: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return (value as? NSNumber)?.boolValue
    }

    private func actionNames(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return ((names as? [String]) ?? []).sorted()
    }

    private func purgeExpiredHandles() {
        handles = handles.filter { $0.value.expiresAt > Date() }
    }

    private func stableHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
        return String(hash, radix: 16)
    }

}
