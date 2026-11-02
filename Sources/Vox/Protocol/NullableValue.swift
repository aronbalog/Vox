import Foundation

// A property can be set to one of the `null` placeholders in order to send JSON `null`. Setting a
// property to `nil` leaves the member out instead.
private let nullString = UUID().uuidString

/// Whether `value` is one of the `null` placeholders of attributes, which are stored as JSON
/// `null`.
func isNullValue(_ value: Any) -> Bool {
    switch value {
    case let value as String:
        value.isNull
    case let value as NSNumber:
        value.isNull
    case let value as [String]:
        value.isNull
    case let value as [NSNumber]:
        value.isNull
    case let value as [String: Any]:
        value.isNull
    case let value as [[String: Any]]:
        value.isNull
    default:
        false
    }
}

extension String {
    var isNull: Bool {
        self == nullString
    }
    
    /// A placeholder that's sent as `null`.
    public static var null: String {
        nullString
    }
}

extension [String] {
    var isNull: Bool {
        self.first == .null
    }
    
    /// A placeholder that's sent as `null`.
    public static var null: [String] {
        [.null]
    }
}

extension Dictionary where Key == String {
    /// A placeholder that's sent as `null`.
    public static var null: [String: Any] {
        [.null: NSNull()]
    }
    
    var isNull: Bool {
        self[.null] is NSNull
    }
}

extension [[String: Any]] {
    /// A placeholder that's sent as `null`.
    public static var null: [[String: Any]] {
        [.null]
    }
    
    var isNull: Bool {
        self.first?.isNull == true
    }
}

extension NSNumber {
    /// Every NaN counts as the placeholder, as NaN can't be represented in JSON.
    var isNull: Bool {
        doubleValue.isNaN
    }
    
    /// A placeholder that's sent as `null`.
    public static var null: NSNumber {
        NSNumber(value: Double.nan)
    }
}

extension [NSNumber] {
    /// A placeholder that's sent as `null`.
    public static var null: [NSNumber] {
        [.null]
    }
    
    var isNull: Bool {
        self.first?.isNull == true
    }
}

extension Resource {
    var isNull: Bool {
        self.id == .null
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
        self.first?.id == .null
    }
    
    /// A placeholder that empties a to-many relationship: it's sent as `"data": []`.
    public static var null: [Element] {
        [.null()]
    }
}
