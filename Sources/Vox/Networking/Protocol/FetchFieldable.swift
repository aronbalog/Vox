import Foundation

public typealias Fields = [String: [String]]

public protocol FetchFieldable {
    associatedtype FetchConfigurableType
    
    var fields: Fields? { get }
    
    func fields(_ fields: Fields) -> FetchConfigurableType
}

