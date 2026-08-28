import Foundation
import Testing
@testable import MacControlCore

private func element(role: String = "AXButton", identifier: String? = nil, title: String? = nil, description: String? = nil, value: String? = nil) -> ElementSnapshot {
    ElementSnapshot(handle: .init("fixture"), bundleID: "com.example.fixture", pid: 1,
                    role: role, subrole: nil, identifier: identifier, title: title,
                    description: description, value: value, enabled: true,
                    actions: ["AXPress"], depth: 1, childCount: 0)
}

@Test func selectorPriorityInputsAreExactAndLocalizedCaseInsensitive() {
    let candidate = element(identifier: "send-button", title: "SEND", description: "Afsend")
    #expect(SemanticMatcher.matches(candidate, query: .init(identifier: "send-button")))
    #expect(SemanticMatcher.matches(candidate, query: .init(title: "send")))
    #expect(!SemanticMatcher.matches(candidate, query: .init(identifier: "other")))
}

@Test func redactsSecureFieldsAndKnownSecretShapes() {
    #expect(SafetyPolicy.redact("hunter2", role: "AXSecureTextField") == "[REDACTED]")
    #expect(SafetyPolicy.redact("api_key=super-secret-value")?.contains("super-secret-value") == false)
    #expect(SafetyPolicy.isSensitive(role: "AXTextField", subrole: nil, identifier: "wallet-seed", title: nil, description: nil))
}

@Test func grokBotVersionGateStopsUnknownVersions() {
    #expect(GrokBotAdapter.isSupported(version: "0.29.0"))
    #expect(GrokBotAdapter.isSupported(version: "0.29.12"))
    #expect(!GrokBotAdapter.isSupported(version: "0.30.0"))
    #expect(!GrokBotAdapter.isSupported(version: "unknown"))
}

@Test func capabilityDiffReportsAddedAndRemovedValues() {
    func snapshot(version: String, roles: [String], actions: [String]) -> CapabilitySnapshot {
        .init(schemaVersion: 1, bundleID: "com.example", appVersion: version, capturedAt: .distantPast,
              roles: roles, attributes: [], actions: actions, menuItems: [], windowTitles: [], hierarchy: [], electron: nil)
    }
    let diff = CapabilityScanner.diff(
        snapshot(version: "1", roles: ["AXButton"], actions: ["AXPress"]),
        snapshot(version: "2", roles: ["AXButton", "AXTextField"], actions: ["AXConfirm"])
    )
    #expect(diff.roles.added == ["AXTextField"])
    #expect(diff.actions.removed == ["AXPress"])
}

@Test func defaultAllowlistContainsOnlyGrokBot() {
    #expect(MacControlConfiguration.default.allowedBundleIDs == ["com.anysphere.sand"])
}

@Test func handleLeaseInvalidationAndTimeoutBounds() {
    let now = Date()
    #expect(HandleLeasePolicy.isValid(expiresAt: now.addingTimeInterval(1), locatorGeneration: 2, currentGeneration: 2, now: now))
    #expect(!HandleLeasePolicy.isValid(expiresAt: now.addingTimeInterval(-1), locatorGeneration: 2, currentGeneration: 2, now: now))
    #expect(!HandleLeasePolicy.isValid(expiresAt: now.addingTimeInterval(1), locatorGeneration: 3, currentGeneration: 2, now: now))
    #expect(WaitTimeoutPolicy.bounded(0) == 0.1)
    #expect(WaitTimeoutPolicy.bounded(100) == 30)
}
