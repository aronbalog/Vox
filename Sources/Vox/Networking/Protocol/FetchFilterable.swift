import Foundation

/// A request whose collection can be filtered.
public protocol FetchFilterable {
    associatedtype FetchConfigurableType
    
    var filter: (any FilterStrategy)? { get }
    
    func filter(_ filter: any FilterStrategy) -> FetchConfigurableType
}
