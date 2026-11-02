import Foundation

/// The links and meta of a relationship of a resource.
public struct Relationship: @unchecked Sendable {
    /// The links of the relationship, such as its `self` and `related` links.
    public let links: Links?
    /// The meta of the relationship, as JSON.
    public let meta: [String: Any]?
    /// Whether the relationship has resource linkage. Relationships without it provide only links
    /// or meta, and their properties read as `nil` until the related resources are fetched.
    public let hasData: Bool
}
