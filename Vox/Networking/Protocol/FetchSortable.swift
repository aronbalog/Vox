import Foundation

public enum Sort {
    public static func ascending(_ value: String) -> Sort {
        return Sort._ascending(value: value)
    }
    
    public static func descending(_ value: String) -> Sort {
        return Sort._descending(value: value)
    }
    
    case _ascending(value: String)
    case _descending(value: String)
    
    var value: String {
        switch self {
        case ._ascending(let value):
            return value
        case ._descending(let value):
            return "-" + value
        }
    }
}

public protocol FetchSortable {
    associatedtype FetchConfigurableType
    
    var sort: [Sort] { get }
    
    func sort(_ sort: [Sort]) -> FetchConfigurableType
}

