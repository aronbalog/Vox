import Foundation

/// Sparse fieldsets: the names of the fields to fetch, by resource type.
public typealias Fields = [String: [String]]

/// A request whose sparse fieldsets can be set.
public protocol FetchFieldable {
    associatedtype FetchConfigurableType
    
    var fields: Fields? { get }
    
    func fields(_ fields: Fields) -> FetchConfigurableType
}

