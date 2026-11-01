import Foundation

public protocol FetchFilterable {
    associatedtype FetchConfigurableType
    
    var filter: FilterStrategy? { get }
    
    func filter(_ filter: FilterStrategy) -> FetchConfigurableType
}
