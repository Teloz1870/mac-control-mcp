import Foundation

public enum SafetyPolicy {
    private static let secretTerms = [
        "password", "passwd", "secret", "token", "cookie", "session", "authorization",
        "private key", "seed phrase", "mnemonic", "wallet", "credit card", "cvv", "sand-secrets.json",
        ".env", "credentials", "settings.local", "keychain"
    ]

    public static func isSensitive(role: String?, subrole: String?, identifier: String?, title: String?, description: String?) -> Bool {
        if role == "AXSecureTextField" || subrole == "AXSecureTextField" { return true }
        let metadata = [identifier, title, description].compactMap { $0 }.joined(separator: " ").lowercased()
        return secretTerms.contains { metadata.contains($0) }
    }

    public static func redact(_ value: String?, role: String? = nil, subrole: String? = nil, identifier: String? = nil, title: String? = nil, description: String? = nil) -> String? {
        guard let value else { return nil }
        if isSensitive(role: role, subrole: subrole, identifier: identifier, title: title, description: description) {
            return "[REDACTED]"
        }
        var output = value
        let patterns = [
            #"(?i)(bearer\s+)[A-Za-z0-9._~+\-/=]+"#,
            #"(?i)(api[_-]?key\s*[:=]\s*)[^\s,;]+"#,
            #"(?i)(token\s*[:=]\s*)[^\s,;]+"#,
            #"\b[1-9A-HJ-NP-Za-km-z]{43,44}\b"#
        ]
        for pattern in patterns {
            output = output.replacingOccurrences(of: pattern, with: "$1[REDACTED]", options: .regularExpression)
        }
        return output
    }

    /// Roles a value may be written to. Settability alone is not a permission: plenty of
    /// controls accept a value and mean something by it. Writing is for text the user
    /// could have typed, so the role is checked as well as the content.
    public static let writableRoles: Set<String> = [
        "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField",
    ]

    public static func permitsWriting(role: String?) -> Bool {
        writableRoles.contains(role ?? "")
    }

    public static func validateWritable(role: String?, subrole: String?, identifier: String?, title: String?, description: String?) throws {
        if isSensitive(role: role, subrole: subrole, identifier: identifier, title: title, description: description) {
            throw MacControlError.secureContent
        }
        guard permitsWriting(role: role) else {
            throw MacControlError.invalidArgument("Values may only be written to a text-bearing element (\(writableRoles.sorted().joined(separator: ", "))). This element is \(role ?? "of unknown role"); a settable value on another role usually means something other than text.")
        }
    }
}
