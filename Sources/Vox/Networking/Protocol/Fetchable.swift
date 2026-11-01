import Foundation

public protocol Fetchable {
    associatedtype FetchableResourceTypeConfigurable: FetchConfigurable
    associatedtype FetchableResourceCollectionTypeConfigurable: FetchConfigurable
    
    func fetch() -> FetchableResourceCollectionTypeConfigurable
    
    func fetch(id: String) -> FetchableResourceTypeConfigurable
}
