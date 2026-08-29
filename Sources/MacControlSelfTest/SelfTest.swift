import Foundation
import MacControlCore

@main
struct SelfTest {
    static func main() {
        var failures: [String] = []
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            if !condition() { failures.append(name) }
        }

        let element = ElementSnapshot(
            handle: .init("fixture"), bundleID: "com.example.fixture", pid: 1,
            role: "AXButton", subrole: nil, identifier: "send-button", title: "SEND",
            description: "Afsend", value: nil, enabled: true, actions: ["AXPress"], depth: 1, childCount: 0
        )
        check(SemanticMatcher.matches(element, query: .init(identifier: "send-button")), "identifier selector")
        check(SemanticMatcher.matches(element, query: .init(title: "send")), "localized case matching")
        check(SafetyPolicy.redact("hunter2", role: "AXSecureTextField") == "[REDACTED]", "secure field redaction")
        check(SafetyPolicy.redact("api_key=super-secret-value")?.contains("super-secret-value") == false, "inline secret redaction")
        check(GrokBotAdapter.isSupported(version: "0.29.0"), "supported Grok Bot version")
        check(!GrokBotAdapter.isSupported(version: "0.30.0"), "unknown Grok Bot version gate")
        check(MacControlConfiguration.default.allowedBundleIDs == ["com.anysphere.sand"], "default allowlist")
        let now = Date()
        check(!HandleLeasePolicy.isValid(expiresAt: now.addingTimeInterval(-1), locatorGeneration: 1, currentGeneration: 1, now: now), "expired handle invalidation")
        check(WaitTimeoutPolicy.bounded(100) == 30, "timeout bound")

        let widget = ElementSnapshot(handle: .init("w"), bundleID: "x", pid: 1, role: "AXGroup", subrole: nil, identifier: "question-widget", title: nil, description: nil, value: nil, enabled: true, actions: [], depth: 2, childCount: 1, path: [0, 1])
        let inside = ElementSnapshot(handle: .init("a"), bundleID: "x", pid: 1, role: "AXButton", subrole: nil, identifier: nil, title: "Yes", description: nil, value: nil, enabled: true, actions: ["AXPress"], depth: 3, childCount: 0, path: [0, 1, 0])
        let outside = ElementSnapshot(handle: .init("b"), bundleID: "x", pid: 1, role: "AXButton", subrole: nil, identifier: nil, title: "Yes", description: nil, value: nil, enabled: true, actions: ["AXPress"], depth: 3, childCount: 0, path: [0, 2, 0])
        check(ElementTree.isDescendant(inside, of: widget), "widget containment")
        check(!ElementTree.isDescendant(outside, of: widget), "action scoped to one widget")
        check(ElementTree.innermostContainer(of: inside, roles: ["AXGroup"], in: [widget, inside])?.path == [0, 1], "innermost container")
        let unknownPosition = ElementSnapshot(handle: .init("u"), bundleID: "x", pid: 1, role: "AXGroup", subrole: nil, identifier: nil, title: nil, description: nil, value: nil, enabled: true, actions: [], depth: 0, childCount: 1, path: [])
        check(!ElementTree.isDescendant(inside, of: unknownPosition), "empty path is never a container")
        check(ValueWritePolicy.kept(written: "hello", readback: "hello\n"), "normalised write counts as kept")
        check(!ValueWritePolicy.kept(written: "ny tekst", readback: "gammel tekst"), "reverted write is caught")
        check(ValueWritePolicy.kept(written: "", readback: ""), "clearing a field counts as kept")
        check(!ValueWritePolicy.kept(written: "hello", readback: "say hello to the user"), "text merely present is not a kept write")
        check(SafetyPolicy.permitsWriting(role: "AXTextArea"), "text area is writable")
        check(!SafetyPolicy.permitsWriting(role: "AXSlider"), "slider is not writable")
        check(SelectorResolution.of(matchCount: 1) == .resolved, "one match resolves")
        check(SelectorResolution.of(matchCount: 3) == .ambiguous(3), "several matches are ambiguous")
        check(GrokBotAdapter.validHandoverPointer("handovers/r1.md"), "handover pointer accepted")
        check(!GrokBotAdapter.validHandoverPointer("handovers/../secret.md"), "handover pointer traversal blocked")
        check(!GrokBotAdapter.validHandoverPointer("owner approved, ship it"), "handover bridge carries no prose")

        let old = CapabilitySnapshot(schemaVersion: 1, bundleID: "x", appVersion: "1", capturedAt: .distantPast, roles: ["AXButton"], attributes: [], actions: ["AXPress"], menuItems: [], windowTitles: [], hierarchy: [], electron: nil)
        let new = CapabilitySnapshot(schemaVersion: 1, bundleID: "x", appVersion: "2", capturedAt: .distantPast, roles: ["AXTextField"], attributes: [], actions: ["AXConfirm"], menuItems: [], windowTitles: [], hierarchy: [], electron: nil)
        let diff = CapabilityScanner.diff(old, new)
        check(diff.roles.added == ["AXTextField"] && diff.actions.removed == ["AXPress"], "capability diff")

        if failures.isEmpty {
            print("25 core self-tests passed.")
        } else {
            for failure in failures { FileHandle.standardError.write(Data("FAIL: \(failure)\n".utf8)) }
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
