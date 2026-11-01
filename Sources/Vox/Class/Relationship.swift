import Foundation

/// The links and meta of a relationship of a resource.
public struct Relationship: @unchecked Sendable {
    public let links: Links?
    public let meta: [String: Any]?
    /// Whether the relationship has resource linkage. Relationships without it provide only links
    /// or meta, and their properties read as `nil` until the related resources are fetched.
    public let hasData: Bool
}
