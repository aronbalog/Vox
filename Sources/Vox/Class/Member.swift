import Foundation

/// A stored property of a resource that reads and writes a JSON member.
///
/// ```swift
/// final class Article: Resource {
///     @Member var title: String?
///     @Member var author: Person?
/// }
/// ```
///
/// This is the way to back a property with the resource's JSON without the Objective-C runtime,
/// so it works on Linux. On Apple platforms, `@objc dynamic` properties do the same thing.
/// `codingKeys` maps the names of members like the names of other properties.
@propertyWrapper
public struct Member<Value>: MemberStorage {
    static var valueType: Any.Type {
        Value.self
    }
    
    let token = MemberToken()
    private let fallback: Value
    
    /// A member whose missing value is `nil`.
    public init() where Value: ExpressibleByNilLiteral {
        self.fallback = Value(nilLiteral: ())
    }
    
    /// A member whose missing value is `wrappedValue`.
    public init(wrappedValue: Value) {
        self.fallback = wrappedValue
    }
    
    @available(*, unavailable, message: "A member is stored in the resource's JSON.")
    public var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }
    
    public static subscript<ResourceType: Resource>(
        _enclosingInstance resource: ResourceType,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<ResourceType, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<ResourceType, Member<Value>>
    ) -> Value {
        get {
            let stored = resource[keyPath: storageKeyPath]
            let name = ResourceRuntime.propertyName(of: storageKeyPath, token: stored.token, in: resource)
            
            return ResourceRuntime.memberValue(resource.value(forMember: name), fallback: stored.fallback)
        }
        set {
            let token = resource[keyPath: storageKeyPath].token
            
            resource.setValue(newValue, forMember: ResourceRuntime.propertyName(of: storageKeyPath, token: token, in: resource))
        }
    }
}

/// The storage of a `@Member` property, which declares a member of type `valueType`.
protocol MemberStorage {
    static var valueType: Any.Type { get }
    
    /// Identifies the storage among the stored properties of its resource.
    var token: MemberToken { get }
}

final class MemberToken: Sendable {}
