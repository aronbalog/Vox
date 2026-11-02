import Foundation

/// Creates requests that fetch resources and collections.
public protocol Fetchable {
    associatedtype FetchableResourceTypeConfigurable: FetchConfigurable
    associatedtype FetchableResourceCollectionTypeConfigurable: FetchConfigurable
    
    func fetch() -> FetchableResourceCollectionTypeConfigurable
    
    func fetch(id: String) -> FetchableResourceTypeConfigurable
}
