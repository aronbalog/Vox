import Foundation

public protocol FetchIncludable {
    associatedtype FetchConfigurableType
    
    var include: [String] { get }
    
    func include(_ include: [String]) -> FetchConfigurableType
}

