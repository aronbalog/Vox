import Foundation

/// A request whose collection can be filtered.
public protocol FetchFilterable {
    associatedtype FetchConfigurableType
    
    var filter: FilterStrategy? { get }
    
    func filter(_ filter: FilterStrategy) -> FetchConfigurableType
}
