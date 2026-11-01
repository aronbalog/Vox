import Foundation

/// A sort field of a collection request.
public struct Sort: Equatable {
    public let field: String
    public let isDescending: Bool
    
    public static func ascending(_ field: String) -> Sort {
        return Sort(field: field, isDescending: false)
    }
    
    public static func descending(_ field: String) -> Sort {
        return Sort(field: field, isDescending: true)
    }
    
    /// The field as it appears in the `sort` query parameter.
    var value: String {
        return isDescending ? "-" + field : field
    }
}

public protocol FetchSortable {
    associatedtype FetchConfigurableType
    
    var sort: [Sort] { get }
    
    func sort(_ sort: [Sort]) -> FetchConfigurableType
}
