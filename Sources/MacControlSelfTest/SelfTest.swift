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

        let old = CapabilitySnapshot(schemaVersion: 1, bundleID: "x", appVersion: "1", capturedAt: .distantPast, roles: ["AXButton"], attributes: [], actions: ["AXPress"], menuItems: [], windowTitles: [], hierarchy: [], electron: nil)
        let new = CapabilitySnapshot(schemaVersion: 1, bundleID: "x", appVersion: "2", capturedAt: .distantPast, roles: ["AXTextField"], attributes: [], actions: ["AXConfirm"], menuItems: [], windowTitles: [], hierarchy: [], electron: nil)
        let diff = CapabilityScanner.diff(old, new)
        check(diff.roles.added == ["AXTextField"] && diff.actions.removed == ["AXPress"], "capability diff")

        if failures.isEmpty {
            print("10 core self-tests passed.")
        } else {
            for failure in failures { FileHandle.standardError.write(Data("FAIL: \(failure)\n".utf8)) }
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
