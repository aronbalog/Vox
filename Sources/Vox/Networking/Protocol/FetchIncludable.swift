import Foundation

/// A request that can include related resources in the response document.
public protocol FetchIncludable {
    associatedtype FetchConfigurableType
    
    var include: [String] { get }
    
    func include(_ include: [String]) -> FetchConfigurableType
}

