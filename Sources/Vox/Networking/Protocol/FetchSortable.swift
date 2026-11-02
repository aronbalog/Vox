import Foundation

/// A sort field of a collection request.
public struct Sort: Equatable, Sendable {
    /// The field, which can be a dot-separated path through relationships.
    public let field: String
    public let isDescending: Bool
    
    /// Sorts by the field in ascending order.
    public static func ascending(_ field: String) -> Sort {
        Sort(field: field, isDescending: false)
    }
    
    /// Sorts by the field in descending order, which is sent as `-field`.
    public static func descending(_ field: String) -> Sort {
        Sort(field: field, isDescending: true)
    }
    
    /// The field as it appears in the `sort` query parameter.
    var value: String {
        isDescending ? "-" + field : field
    }
}

/// A request whose collection can be sorted.
public protocol FetchSortable {
    associatedtype FetchConfigurableType
    
    var sort: [Sort] { get }
    
    func sort(_ sort: [Sort]) -> FetchConfigurableType
}
