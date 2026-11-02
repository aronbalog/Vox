import Foundation
#if canImport(ObjectiveC)
import ObjectiveC
#endif

/// The JSON-backed properties of a resource class.
struct ResourceMetadata: @unchecked Sendable {
    static let empty = ResourceMetadata(properties: [:])
    
    /// The properties by name.
    let properties: [String: ResourceProperty]
}

/// A property of a resource class that's backed by the resource's JSON.
struct ResourceProperty {
    enum Kind {
        case attribute(Any.Type)
        case toOne(Resource.Type)
        case toMany(Resource.Type)
    }
    
    let name: String
    /// The name of the JSON member, which differs from `name` when the class maps it in
    /// `codingKeys`.
    let key: String
    let kind: Kind
}

/// Connects `Resource` subclasses to the runtime.
///
/// The first time a resource class is instantiated, its stored properties are inspected with
/// `Mirror` to tell attributes, to-one and to-many relationships apart. On Apple platforms, the
/// accessors of its `@objc dynamic` properties are then replaced with implementations that read
/// from and write to the resource's JSON, and the class is registered for its `resourceType`.
enum ResourceRuntime {
    private struct State {
        var metadataByClass: [ObjectIdentifier: ResourceMetadata] = [:]
        var classesByType: [String: Resource.Type] = [:]
        #if canImport(ObjectiveC)
        var preparedClasses = Set<ObjectIdentifier>()
        var scannedClassCount: Int32 = -1
        /// Types no class was found for in the latest scan.
        var unknownTypes = Set<String>()
        #endif
    }
    
    /// Guarded by `ResourceGraph.lock`, which is held while a class is prepared or the runtime is
    /// scanned, so other threads only see classes that are prepared completely.
    private static let state = Locked(State(), guardedBy: ResourceGraph.lock)
    
    /// The metadata of the class of `resource`, which is prepared first if needed.
    static func prepare(_ resource: Resource) -> ResourceMetadata {
        let classID = ObjectIdentifier(type(of: resource))
        
        return ResourceGraph.lock.withLock {
            if let metadata = state.withLock({ $0.metadataByClass[classID] }) {
                return metadata
            }
            
            let metadata = makeMetadata(for: resource)
            state.withLock { $0.metadataByClass[classID] = metadata }
            
            return metadata
        }
    }
    
    /// Registers `resourceClass` for its `resourceType`, unless another class is registered for
    /// that type already.
    static func register(_ resourceClass: Resource.Type) {
        guard let type = declaredResourceType(of: resourceClass) else {
            return
        }
        
        state.withLock { state in
            if let registeredClass = state.classesByType[type] {
                #if DEBUG
                if registeredClass != resourceClass {
                    print("[Vox] Both \(registeredClass) and \(resourceClass) declare resource type \"\(type)\"; \(registeredClass) is used.")
                }
                #endif
                return
            }
            
            state.classesByType[type] = resourceClass
        }
    }
    
    /// The class registered for a JSON:API `type`, if any.
    ///
    /// On Apple platforms, the runtime is scanned for `Resource` subclasses when no class is
    /// registered for `type`. The scan is repeated for types it didn't find only after new
    /// classes have been loaded and another type is missing.
    static func resourceClass(for type: String) -> Resource.Type? {
        return ResourceGraph.lock.withLock {
            if let resourceClass = state.withLock({ $0.classesByType[type] }) {
                return resourceClass
            }
            
            #if canImport(ObjectiveC)
            guard !state.withLock({ $0.unknownTypes.contains(type) }) else {
                return nil
            }
            
            scanLoadedClassesIfNeeded()
            
            return state.withLock { state -> Resource.Type? in
                if let resourceClass = state.classesByType[type] {
                    return resourceClass
                }
                
                state.unknownTypes.insert(type)
                
                return nil
            }
            #else
            return nil
            #endif
        }
    }
    
    /// `value` if it's an instance of `type`, with JSON strings converted for `URL` and `Date`
    /// properties.
    static func cast(_ value: Any, to type: Any.Type) -> Any? {
        if type == Any.self || type == AnyObject.self {
            return value
        }
        
        if type == URL.self {
            return (value as? String).flatMap(URL.init(string:))
        }
        
        if type == Date.self {
            return (value as? String).flatMap(ISO8601DateCoding.date(from:))
        }
        
        return isInstance(value, of: type) ? value : nil
    }
    
    static func isInstance(_ value: Any, of type: Any.Type) -> Bool {
        func check<T>(_: T.Type) -> Bool {
            return value is T
        }
        
        return _openExistential(type, do: check)
    }
    
    private static func makeMetadata(for resource: Resource) -> ResourceMetadata {
        let codingKeys = type(of: resource).codingKeys
        var properties: [String: ResourceProperty] = [:]
        var mirror: Mirror? = Mirror(reflecting: resource)
        
        while let classMirror = mirror,
              let resourceClass = classMirror.subjectType as? Resource.Type,
              resourceClass != Resource.self {
            #if canImport(ObjectiveC)
            let objectiveCProperties = ObjectiveCProperty.properties(of: resourceClass)
            #endif
            
            for child in classMirror.children {
                guard let name = child.label, !name.hasPrefix("$") else {
                    continue
                }
                
                #if canImport(ObjectiveC)
                // Objective-C properties of primitive and block types keep their own storage.
                if let property = objectiveCProperties[name], !property.isObject {
                    continue
                }
                #endif
                
                properties[name] = ResourceProperty(
                    name: name,
                    key: codingKeys[name] ?? name,
                    kind: ResourceProperty.Kind(Swift.type(of: child.value))
                )
            }
            
            #if canImport(ObjectiveC)
            if state.withLock({ $0.preparedClasses.insert(ObjectIdentifier(resourceClass)).inserted }) {
                for property in objectiveCProperties.values where property.isObject {
                    if properties[property.name] != nil {
                        installAccessors(for: property, on: resourceClass)
                    }
                }
                
                register(resourceClass)
            }
            #endif
            
            mirror = classMirror.superclassMirror
        }
        
        return ResourceMetadata(properties: properties)
    }
    
    /// The class's `resourceType`, or `nil` when the class doesn't override it itself.
    ///
    /// Abstract intermediate subclasses and subclasses inheriting the type of a concrete
    /// superclass are not registered, and their `resourceType` is never called.
    private static func declaredResourceType(of resourceClass: Resource.Type) -> String? {
        guard resourceClass != Resource.self else {
            return nil
        }
        
        #if canImport(ObjectiveC)
        guard let metaclass = object_getClass(resourceClass) else {
            return nil
        }
        
        var methodCount: UInt32 = 0
        
        guard let methods = class_copyMethodList(metaclass, &methodCount) else {
            return nil
        }
        defer { free(methods) }
        
        let selector = NSSelectorFromString("resourceType")
        let declaresResourceType = (0..<Int(methodCount)).contains { index in
            method_getName(methods[index]) == selector
        }
        
        guard declaresResourceType else {
            return nil
        }
        #endif
        
        return resourceClass.resourceType
    }
    
    #if canImport(ObjectiveC)
    private static func scanLoadedClassesIfNeeded() {
        let classCount = objc_getClassList(nil, 0)
        
        guard classCount != state.withLock({ $0.scannedClassCount }) else {
            return
        }
        
        let classes = UnsafeMutablePointer<AnyClass>.allocate(capacity: Int(classCount))
        defer { classes.deallocate() }
        
        let copiedCount = objc_getClassList(AutoreleasingUnsafeMutablePointer<AnyClass>(classes), classCount)
        
        state.withLock { state in
            state.scannedClassCount = classCount
            state.unknownTypes.removeAll()
        }
        
        for index in 0..<Int(min(classCount, copiedCount)) {
            let loadedClass: AnyClass = classes[index]
            
            if isStrictSubclassOfResource(loadedClass), let resourceClass = loadedClass as? Resource.Type {
                register(resourceClass)
            }
        }
    }
    
    private static func isStrictSubclassOfResource(_ candidate: AnyClass) -> Bool {
        var superclass = class_getSuperclass(candidate)
        
        while let current = superclass {
            if current == Resource.self {
                return true
            }
            superclass = class_getSuperclass(current)
        }
        
        return false
    }
    
    private static func installAccessors(for property: ObjectiveCProperty, on resourceClass: AnyClass) {
        let name = property.name
        
        let getter: @convention(block) (Resource) -> AnyObject? = { resource in
            return resource.value(forProperty: name).map { $0 as AnyObject }
        }
        
        class_replaceMethod(resourceClass, property.getter, imp_implementationWithBlock(getter), "@@:")
        
        guard !property.isReadOnly else {
            return
        }
        
        let setter: @convention(block) (Resource, AnyObject?) -> Void = { resource, value in
            resource.setValue(value, forProperty: name)
        }
        
        class_replaceMethod(resourceClass, property.setter, imp_implementationWithBlock(setter), "v@:@")
    }
    #endif
}

extension ResourceProperty.Kind {
    /// The kind of a property declared with `type`.
    init(_ type: Any.Type) {
        let valueType = (type as? OptionalType.Type)?.wrappedType ?? type
        
        if let resourceType = valueType as? Resource.Type {
            self = .toOne(resourceType)
        } else if let elementType = (valueType as? ArrayType.Type)?.elementType as? Resource.Type {
            self = .toMany(elementType)
        } else {
            self = .attribute(valueType)
        }
    }
}

fileprivate protocol OptionalType {
    static var wrappedType: Any.Type { get }
}

extension Optional: OptionalType {
    fileprivate static var wrappedType: Any.Type {
        return Wrapped.self
    }
}

fileprivate protocol ArrayType {
    static var elementType: Any.Type { get }
}

extension Array: ArrayType {
    fileprivate static var elementType: Any.Type {
        return Element.self
    }
}

#if canImport(ObjectiveC)
/// The parts of an Objective-C property declaration needed to replace its accessors.
private struct ObjectiveCProperty {
    let name: String
    let getter: Selector
    let setter: Selector
    let isReadOnly: Bool
    /// Whether the property holds an object, as opposed to a primitive value or a block.
    let isObject: Bool
    
    /// The Objective-C properties declared by `resourceClass` itself, by name.
    static func properties(of resourceClass: AnyClass) -> [String: ObjectiveCProperty] {
        var propertyCount: UInt32 = 0
        
        guard let properties = class_copyPropertyList(resourceClass, &propertyCount) else {
            return [:]
        }
        defer { free(properties) }
        
        var propertiesByName: [String: ObjectiveCProperty] = [:]
        
        for index in 0..<Int(propertyCount) {
            let property = ObjectiveCProperty(properties[index])
            propertiesByName[property.name] = property
        }
        
        return propertiesByName
    }
    
    init(_ property: objc_property_t) {
        let name = String(cString: property_getName(property))
        
        var typeEncoding = ""
        var customGetter: String?
        var customSetter: String?
        var isReadOnly = false
        
        var attributeCount: UInt32 = 0
        
        if let attributes = property_copyAttributeList(property, &attributeCount) {
            defer { free(attributes) }
            
            for index in 0..<Int(attributeCount) {
                let attribute = attributes[index]
                let value = String(cString: attribute.value)
                
                switch String(cString: attribute.name) {
                case "T": typeEncoding = value
                case "G": customGetter = value
                case "S": customSetter = value
                case "R": isReadOnly = true
                default: break
                }
            }
        }
        
        self.name = name
        self.getter = NSSelectorFromString(customGetter ?? name)
        self.setter = NSSelectorFromString(customSetter ?? "set\(name.prefix(1).uppercased())\(name.dropFirst()):")
        self.isReadOnly = isReadOnly
        self.isObject = typeEncoding.hasPrefix("@") && typeEncoding != "@?"
    }
}
#endif
