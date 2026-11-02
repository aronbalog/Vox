import Foundation

// A property can be set to one of the `null` placeholders in order to send JSON `null`. Setting a
// property to `nil` leaves the member out instead.
private let nullString = UUID().uuidString

protocol NullableAware {
    var isNull: Bool { get }
}

/// Whether `value` is one of the `null` placeholders, which are stored as JSON `null`.
func isNullValue(_ value: Any) -> Bool {
    if let value = value as? NullableAware {
        return value.isNull
    } else if let value = value as? String {
        return value.isNull
    } else if let value = value as? [String] {
        return value.isNull
    } else if let value = value as? [String: Any] {
        return value.isNull
    } else if let value = value as? [[String: Any]] {
        return value.isNull
    } else if let value = value as? [NSNumber] {
        return value.isNull
    }
    
    return false
}

extension String: NullableAware {
    var isNull: Bool {
        return self == nullString
    }
    
    /// A placeholder that's sent as `null`.
    public static var null: String {
        return nullString
    }
}

extension Array where Element == String {
    var isNull: Bool {
        return self.first == .null
    }
    
    /// A placeholder that's sent as `null`.
    public static var null: Array<Element> {
        return [.null]
    }
}

extension Dictionary where Key == String {
    /// A placeholder that's sent as `null`.
    public static var null: Dictionary<String, Any> {
        return [.null: NSNull()]
    }
    
    var isNull: Bool {
        return self[.null] is NSNull
    }
}

extension Array where Element == Dictionary<String, Any> {
    /// A placeholder that's sent as `null`.
    public static var null: Array<Element> {
        return [.null]
    }
    
    var isNull: Bool {
        return self.first?.isNull ?? false
    }
}

extension NSNumber: NullableAware {
    /// Every NaN counts as the placeholder, as NaN can't be represented in JSON.
    var isNull: Bool {
        return doubleValue.isNaN
    }
    
    /// A placeholder that's sent as `null`.
    public static var null: NSNumber {
        return NSNumber(value: Double.nan)
    }
}

extension Array where Element == NSNumber {
    /// A placeholder that's sent as `null`.
    public static var null: Array<Element> {
        return [.null]
    }
    
    var isNull: Bool {
        return self.first?.isNull ?? false
    }
}

extension Resource: NullableAware {
    var isNull: Bool {
        return self.id == .null
    }
    
    /// A placeholder that empties a to-one relationship: it's sent as `"data": null`.
    public static func null() -> Self {
        let _null = self.init()
        _null.id = .null
        
        return _null
    }
}

extension Array where Element: Resource {
    var isNull: Bool {
        return self.first?.id == .null
    }
    
    /// A placeholder that empties a to-many relationship: it's sent as `"data": []`.
    public static var null: Array<Element> {
        return [.null()]
    }
}
