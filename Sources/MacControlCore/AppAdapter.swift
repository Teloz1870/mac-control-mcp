import Foundation

public struct SemanticSelector: Codable, Sendable, Equatable {
    public let name: String
    public let candidates: [ElementQuery]
    public init(name: String, candidates: [ElementQuery]) {
        self.name = name
        self.candidates = candidates
    }
}

public enum SemanticMatcher {
    public static func matches(_ element: ElementSnapshot, query: ElementQuery) -> Bool {
        if let expected = query.role, element.role != expected { return false }
        if let expected = query.identifier, element.identifier != expected { return false }
        if let expected = query.title, element.title?.localizedCaseInsensitiveCompare(expected) != .orderedSame { return false }
        if let expected = query.description, element.description?.localizedCaseInsensitiveCompare(expected) != .orderedSame { return false }
        if let expected = query.valueContains, element.value?.localizedCaseInsensitiveContains(expected) != true { return false }
        return true
    }
}

public struct AdapterToolDefinition: Sendable, Equatable {
    public let name: String
    public let description: String
    public let readOnly: Bool
    public let requiredArguments: [String]
    public let optionalArguments: [String]

    public init(name: String, description: String, readOnly: Bool, requiredArguments: [String] = [], optionalArguments: [String] = []) {
        self.name = name
        self.description = description
        self.readOnly = readOnly
        self.requiredArguments = requiredArguments
        self.optionalArguments = optionalArguments
    }
}

@MainActor
public protocol AppAdapter: AnyObject {
    static var identifier: String { get }
    var bundleID: String { get }
    var supportedVersionDescription: String { get }
    var selectors: [SemanticSelector] { get }
    var capabilities: [String] { get }
    var tools: [AdapterToolDefinition] { get }
    func detectedVersion() throws -> String
    func validateCompatibility() throws
    func call(tool: String, arguments: [String: String]) async throws -> String
}

public extension AppAdapter {
    func resolve(_ selector: SemanticSelector, using ax: AXController, limit: Int = 25) throws -> [ElementSnapshot] {
        for candidate in selector.candidates {
            let matches = try ax.find(bundleID: bundleID, query: candidate, limit: limit)
            if !matches.isEmpty { return matches }
        }
        throw MacControlError.elementNotFound("\(Self.identifier).\(selector.name); tested \(selector.candidates.count) identifier/role/description selectors")
    }
}
