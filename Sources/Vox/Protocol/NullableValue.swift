import Foundation

let nullString: String = UUID().uuidString
let nullNumber: NSNumber = NSNumber(value: INT_MAX)
let nullDictionary: [String: Any] = [.null: NSNull()]
let nullStringArray: [String] = [.null]
let nullNumberArray: [NSNumber] = [.null]
let nullDictionaryArray: [[String: Any]] = [.null]

protocol NullableAware {
    var isNull: Bool { get }
}

extension String: NullableAware {
    var isNull: Bool {
        return self == nullString
    }
    
    public static var null: String {
        return nullString
    }
}

public extension Array where Element == String {
    var isNull: Bool {
        return self.first == .null
    }
    
    public static var null: Array<Element> {
        return nullStringArray
    }
}

public extension Dictionary where Key == String, Value: Any {
    public static var null: Dictionary<String, Any> {
        return nullDictionary
    }
    
    var isNull: Bool {
        return self[.null] is NSNull
    }
}

public extension Array where Element == Dictionary<String, Any> {
    public static var null: Array<Element> {
        return nullDictionaryArray
    }
    
    var isNull: Bool {
        return self.first?.isNull ?? false
    }
}

extension NSNumber: NullableAware {
    var isNull: Bool {
        return self.isEqual(to: nullNumber)
    }
    
    public static var null: NSNumber {
        return nullNumber
    }
}

public extension Array where Element == NSNumber {
    public static var null: Array<Element> {
        return nullNumberArray
    }
    
    var isNull: Bool {
        return self.first?.isNull ?? false
    }
}

extension Resource: NullableAware {
    var isNull: Bool {
        return self.id == .null
    }
    
    public static func null() -> Self {
        let _null = self.init()
        _null.id = .null
        
        return _null
    }
}

public extension Array where Element: Resource {
    var isNull: Bool {
        return self.first?.id == .null
    }
    
    public static var null: Array<Element> {
        return [.null()]
    }
}
