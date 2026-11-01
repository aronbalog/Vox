import Foundation

/// A JSON:API resource.
///
/// Subclasses override `resourceType` and declare attributes and relationships as stored
/// `@objc dynamic` properties. Their values are read from and written to the resource's JSON:
///
/// ```swift
/// final class Article: Resource {
///     override class var resourceType: String { "articles" }
///
///     @objc dynamic var title: String?
///     @objc dynamic var author: Person?
///     @objc dynamic var comments: [Comment]?
/// }
/// ```
///
/// Properties typed as a `Resource` subclass are to-one relationships, properties typed as an
/// array of a `Resource` subclass are to-many relationships, and all other properties are
/// attributes.
///
/// Access to the JSON of resources is synchronized, so resources can be read and written from any
/// thread. A subclass without mutable state of its own can be declared `@unchecked Sendable` to
/// share its instances across isolation domains.
open class Resource: NSObject {
    #if canImport(ObjectiveC)
    /// The JSON:API `type` of the resource. Subclasses must override it.
    @objc open class var resourceType: String {
        Resource.missingResourceType(self)
    }
    #else
    /// The JSON:API `type` of the resource. Subclasses must override it.
    open class var resourceType: String {
        Resource.missingResourceType(self)
    }
    #endif
    
    /// Maps property names to JSON member names, for properties named differently than their
    /// attribute or relationship.
    open class var codingKeys: [String: String] {
        return [:]
    }
    
    /// Guarded by `ResourceGraph.lock`.
    private var storage: (object: ResourceObject, graph: ResourceGraph)?
    
    /// Set once by the initializer.
    private(set) var classMetadata = ResourceMetadata.empty
    
    public required override init() {
        super.init()
        
        classMetadata = ResourceRuntime.prepare(self)
    }
    
    public var id: String? {
        get {
            return ResourceGraph.lock.withLock {
                storageLocked().object.id
            }
        }
        set {
            ResourceGraph.lock.withLock {
                let (object, graph) = storageLocked()
                let oldKey = object.key
                object.id = newValue
                graph.updateKey(of: object, replacing: oldKey)
            }
        }
    }
    
    public var type: String {
        return ResourceGraph.lock.withLock {
            storageLocked().object.type
        }
    }
    
    public var meta: [String: Any]? {
        get {
            return ResourceGraph.lock.withLock {
                storageLocked().object.meta
            }
        }
        set {
            ResourceGraph.lock.withLock {
                storageLocked().object.meta = newValue
            }
        }
    }
    
    /// The attributes of the resource as JSON.
    public var attributes: [String: Any] {
        return ResourceGraph.lock.withLock {
            storageLocked().object.attributes
        }
    }
    
    /// The resource linkage of the resource's relationships as JSON.
    public var relationships: [String: Any] {
        return ResourceGraph.lock.withLock {
            let (object, graph) = storageLocked()
            
            return (try? relationshipsJSON(of: object, in: graph, skippingInvalid: true)) ?? [:]
        }
    }
    
    public func documentDictionary() throws -> [String: Any] {
        return ["data": try resourceObjectJSON(requiringID: false)]
    }
    
    public func documentData() throws -> Data {
        return try JSONSerialization.data(withJSONObject: documentDictionary(), options: [])
    }
    
    // MARK: Storage
    
    /// The object and graph backing the resource. Resources created in code get a graph of their
    /// own on first use. Must be called while holding `ResourceGraph.lock`.
    func storageLocked() -> (object: ResourceObject, graph: ResourceGraph) {
        if let storage = storage {
            let graph = storage.graph.current
            
            if graph !== storage.graph {
                self.storage = (storage.object, graph)
            }
            
            return (storage.object, graph)
        }
        
        let object = ResourceObject(type: Swift.type(of: self).resourceType)
        let graph = ResourceGraph()
        graph.insert(object)
        bind(to: object, in: graph)
        
        return (object, graph)
    }
    
    /// Makes `object` the storage of the resource. Must be called while holding
    /// `ResourceGraph.lock`.
    func bind(to object: ResourceObject, in graph: ResourceGraph) {
        storage = (object, graph)
        graph.register(self, for: object)
    }
    
    /// The value of the JSON-backed property `name`.
    func value(forProperty name: String) -> Any? {
        guard let property = classMetadata.properties[name] else {
            return nil
        }
        
        return ResourceGraph.lock.withLock {
            valueLocked(for: property)
        }
    }
    
    /// Sets the value of the JSON-backed property `name`.
    func setValue(_ value: Any?, forProperty name: String) {
        guard let property = classMetadata.properties[name] else {
            return
        }
        
        ResourceGraph.lock.withLock {
            setValueLocked(value, for: property)
        }
    }
    
    /// The value of the property `name`, or of the JSON member `name` when no property has that
    /// name.
    func value(forMember name: String) -> Any? {
        switch name {
        case "id":
            return id
        case "type":
            return type
        default:
            break
        }
        
        return ResourceGraph.lock.withLock {
            if let property = classMetadata.properties[name] {
                return valueLocked(for: property)
            }
            
            return valueLocked(forMember: name)
        }
    }
    
    /// Sets the value of the property `name`, or of the JSON member `name` when no property has
    /// that name. `type` is read-only.
    func setValue(_ value: Any?, forMember name: String) {
        switch name {
        case "id":
            id = value as? String
            return
        case "type":
            return
        default:
            break
        }
        
        ResourceGraph.lock.withLock {
            if let property = classMetadata.properties[name] {
                setValueLocked(value, for: property)
            } else {
                setValueLocked(value, forMember: name)
            }
        }
    }
    
    private func valueLocked(for property: ResourceProperty) -> Any? {
        let (object, graph) = storageLocked()
        
        switch property.kind {
        case .attribute(let valueType):
            guard let value = object.attributes[property.key], !(value is NSNull) else {
                return nil
            }
            
            return ResourceRuntime.cast(value, to: valueType)
        case .toOne(let resourceType):
            guard case .toOne(let reference?)? = object.relationships[property.key]?.data,
                  let resource = graph.instance(for: reference),
                  ResourceRuntime.isInstance(resource, of: resourceType) else {
                return nil
            }
            
            return resource
        case .toMany(let resourceType):
            guard case .toMany(let references)? = object.relationships[property.key]?.data else {
                return nil
            }
            
            return references
                .compactMap(graph.instance(for:))
                .filter { ResourceRuntime.isInstance($0, of: resourceType) }
        }
    }
    
    private func valueLocked(forMember name: String) -> Any? {
        let (object, graph) = storageLocked()
        
        if let value = object.attributes[name] {
            return value is NSNull ? nil : value
        }
        
        switch object.relationships[name]?.data {
        case .toOne(let reference?)?:
            return graph.instance(for: reference)
        case .toMany(let references)?:
            return references.compactMap(graph.instance(for:))
        default:
            return nil
        }
    }
    
    private func setValueLocked(_ value: Any?, for property: ResourceProperty) {
        let (object, _) = storageLocked()
        
        switch property.kind {
        case .attribute:
            object.attributes[property.key] = attributeValue(value)
        case .toOne:
            guard let resource = value as? Resource else {
                object.setLinkage(nil, forRelationship: property.key)
                return
            }
            
            object.setLinkage(.toOne(resource.isNull ? nil : referenceLocked(to: resource)), forRelationship: property.key)
        case .toMany:
            guard let resources = value as? [Resource] else {
                object.setLinkage(nil, forRelationship: property.key)
                return
            }
            
            object.setLinkage(.toMany(resources.isNull ? [] : resources.map(referenceLocked(to:))), forRelationship: property.key)
        }
    }
    
    private func setValueLocked(_ value: Any?, forMember name: String) {
        let (object, _) = storageLocked()
        
        switch value {
        case let resource as Resource:
            object.attributes[name] = nil
            object.setLinkage(.toOne(resource.isNull ? nil : referenceLocked(to: resource)), forRelationship: name)
        case let resources as [Resource] where !resources.isEmpty || object.relationships[name] != nil:
            object.attributes[name] = nil
            object.setLinkage(.toMany(resources.isNull ? [] : resources.map(referenceLocked(to:))), forRelationship: name)
        default:
            object.setLinkage(nil, forRelationship: name)
            object.attributes[name] = attributeValue(value)
        }
    }
    
    private func attributeValue(_ value: Any?) -> Any? {
        guard let value = value else {
            return nil
        }
        
        if isNullValue(value) {
            return NSNull()
        }
        
        if let url = value as? URL {
            return url.absoluteString
        }
        
        return value
    }
    
    /// A reference to `resource` from this resource's graph. When `resource` belongs to another
    /// graph, the two graphs are merged.
    private func referenceLocked(to resource: Resource) -> ResourceReference {
        let (_, graph) = storageLocked()
        let (target, targetGraph) = resource.storageLocked()
        
        ResourceGraph.merge(graph, targetGraph).prefer(target)
        
        return .object(ObjectIdentifier(target))
    }
    
    // MARK: Serialization
    
    func resourceObjectJSON(requiringID: Bool) throws -> [String: Any] {
        return try ResourceGraph.lock.withLock {
            let (object, graph) = storageLocked()
            
            var json: [String: Any] = ["type": object.type]
            
            if let id = object.id {
                json["id"] = id
            } else if requiringID {
                throw JSONAPIError.serialization
            }
            
            if !object.attributes.isEmpty {
                json["attributes"] = object.attributes
            }
            
            let relationships = try relationshipsJSON(of: object, in: graph, skippingInvalid: false)
            
            if !relationships.isEmpty {
                json["relationships"] = relationships
            }
            
            return json
        }
    }
    
    private func relationshipsJSON(of object: ResourceObject, in graph: ResourceGraph, skippingInvalid: Bool) throws -> [String: Any] {
        var json: [String: Any] = [:]
        
        for (name, relationship) in object.relationships {
            guard let linkage = relationship.data else {
                continue
            }
            
            do {
                json[name] = ["data": try linkageJSON(linkage, in: graph)]
            } catch {
                if !skippingInvalid {
                    throw error
                }
            }
        }
        
        return json
    }
    
    private func linkageJSON(_ linkage: ResourceLinkage, in graph: ResourceGraph) throws -> Any {
        switch linkage {
        case .toOne(nil):
            return NSNull()
        case .toOne(let reference?):
            return try identifierJSON(reference, in: graph)
        case .toMany(let references):
            return try references.map { try identifierJSON($0, in: graph) }
        }
    }
    
    private func identifierJSON(_ reference: ResourceReference, in graph: ResourceGraph) throws -> [String: Any] {
        switch reference {
        case .identifier(let key, let meta):
            var json: [String: Any] = ["type": key.type, "id": key.id]
            json["meta"] = meta
            
            return json
        case .object:
            guard let object = graph.object(for: reference), let id = object.id else {
                throw JSONAPIError.serialization
            }
            
            return ["type": object.type, "id": id]
        }
    }
    
    private static func missingResourceType(_ resourceClass: AnyClass) -> Never {
        fatalError("\(resourceClass) must override `class var resourceType: String`")
    }
}

#if canImport(ObjectiveC)
extension Resource {
    open override func value(forKey key: String) -> Any? {
        if classMetadata.properties[key] == nil, responds(to: NSSelectorFromString(key)) {
            return super.value(forKey: key)
        }
        
        return value(forMember: key)
    }
    
    open override func setValue(_ value: Any?, forKey key: String) {
        let setter = "set\(key.prefix(1).uppercased())\(key.dropFirst()):"
        
        if classMetadata.properties[key] == nil, responds(to: NSSelectorFromString(setter)) {
            super.setValue(value, forKey: key)
        } else {
            setValue(value, forMember: key)
        }
    }
}
#endif

extension Resource {
    subscript(key: String) -> Any? {
        get {
            return value(forMember: key)
        }
        set {
            setValue(newValue, forMember: key)
        }
    }
}

extension Array where Element: Resource {
    public func documentDictionary() throws -> [String: Any] {
        return ["data": try map { try $0.resourceObjectJSON(requiringID: true) }]
    }
    
    public func documentData() throws -> Data {
        return try JSONSerialization.data(withJSONObject: documentDictionary(), options: [])
    }
}
