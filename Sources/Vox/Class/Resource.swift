import Foundation

/// A JSON:API resource.
///
/// Subclasses declare their JSON:API type in `resourceType`, and their attributes and
/// relationships as stored `@objc dynamic` properties. Their values are read from and written to
/// the resource's JSON:
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
/// attributes. `Date` attributes are ISO 8601 strings in JSON, and `URL` attributes are strings.
///
/// Access to the JSON of resources is synchronized, so resources can be read and written from any
/// thread. A subclass without mutable state of its own can be declared `@unchecked Sendable` to
/// share its instances across isolation domains.
open class Resource: NSObject {
    #if canImport(ObjectiveC)
    /// The JSON:API `type` of the resource, which is the name of the class unless the class
    /// overrides it.
    @objc open class var resourceType: String {
        String(describing: self)
    }
    #else
    /// The JSON:API `type` of the resource, which is the name of the class unless the class
    /// overrides it.
    open class var resourceType: String {
        String(describing: self)
    }
    #endif
    
    /// Maps property names to JSON member names, for properties named differently than their
    /// attribute or relationship.
    open class var codingKeys: [String: String] {
        [:]
    }
    
    /// Registers the class for its `resourceType`, so documents decode resources of that type as
    /// instances of the class. A class whose `resourceType` is the same as its superclass's isn't
    /// registered, and neither is `Resource` itself.
    ///
    /// On Apple platforms, classes are found in the Objective-C runtime, and registering them is
    /// optional. On other platforms, the resource classes of data sources and deserializers are
    /// registered when they're used, and the classes of related and included resources must be
    /// registered before documents containing them are decoded.
    public static func register() {
        ResourceRuntime.register(self)
    }
    
    /// Guarded by `ResourceGraph.lock`.
    private var storage: (object: ResourceObject, graph: ResourceGraph)?
    
    /// Set once by the initializer.
    private(set) var classMetadata = ResourceMetadata.empty
    
    public required override init() {
        super.init()
        
        classMetadata = ResourceRuntime.prepare(self)
    }
    
    /// The id of the resource, which resources created on the client don't have until the server
    /// assigns one, unless the server accepts client-generated ids.
    public var id: String? {
        get {
            return ResourceGraph.lock.withLock {
                storageLocked().object.id
            }
        }
        set {
            ResourceGraph.lock.withLock {
                let (object, graph) = storageLocked()
                let oldKeys = object.keys
                object.id = newValue
                graph.updateKeys(of: object, replacing: oldKeys)
            }
        }
    }
    
    /// A local identifier for a resource that has no `id` yet, which other resources in the same
    /// request document can refer to it by.
    public var lid: String? {
        get {
            return ResourceGraph.lock.withLock {
                storageLocked().object.lid
            }
        }
        set {
            ResourceGraph.lock.withLock {
                let (object, graph) = storageLocked()
                let oldKeys = object.keys
                object.lid = newValue
                graph.updateKeys(of: object, replacing: oldKeys)
            }
        }
    }
    
    /// The JSON:API type of the resource: the `resourceType` of its class, or the type of the
    /// resource object for resources whose type has no class.
    public var type: String {
        return ResourceGraph.lock.withLock {
            storageLocked().object.type
        }
    }
    
    /// The meta of the resource, as JSON. It's sent with the resource.
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
    
    /// The links of the resource, as received.
    public var links: Links? {
        return ResourceGraph.lock.withLock {
            Links(json: storageLocked().object.links)
        }
    }
    
    /// The links and meta of a relationship, as received.
    ///
    /// - Parameter name: The name of the relationship property, or the name of the relationship
    ///   when no property is declared for it.
    public func relationship(named name: String) -> Relationship? {
        let key = memberName(forProperty: name)
        
        return ResourceGraph.lock.withLock {
            storageLocked().object.relationships[key].map { relationship in
                Relationship(
                    links: Links(json: relationship.links),
                    meta: relationship.meta,
                    hasData: relationship.data != nil
                )
            }
        }
    }
    
    /// A document with the resource as primary data.
    ///
    /// - Throws: `JSONAPIError.serialization` when an attribute or the meta can't be represented
    ///   in JSON, or when a related resource has neither `id` nor `lid`.
    public func documentDictionary() throws(JSONAPIError) -> [String: Any] {
        ["data": try resourceObjectJSON(requiringID: false)]
    }
    
    /// The JSON data of `documentDictionary()`.
    public func documentData() throws(JSONAPIError) -> Data {
        try JSONAPIEncoder.data(of: documentDictionary())
    }
    
    /// The request document of the resource, which must have an `id` or `lid` when
    /// `requiringID` is set.
    func documentData(requiringID: Bool) throws(JSONAPIError) -> Data {
        try JSONAPIEncoder.data(of: ["data": resourceObjectJSON(requiringID: requiringID)])
    }
    
    /// The resource identifier object of the resource, for relationship requests.
    func identifierJSON() throws(JSONAPIError) -> [String: Any] {
        return try ResourceGraph.lock.withLock { () throws(JSONAPIError) -> [String: Any] in
            let object = storageLocked().object
            
            if let id = object.id {
                return ["type": object.type, "id": id]
            } else if let lid = object.lid {
                return ["type": object.type, "lid": lid]
            } else {
                throw JSONAPIError.serialization(reason: "A resource of type \"\(object.type)\" has neither id nor lid, so a relationship can't refer to it.")
            }
        }
    }
    
    /// The JSON member name of the property `name`, which is `name` itself unless `codingKeys`
    /// maps it or there's no such property.
    func memberName(forProperty name: String) -> String {
        classMetadata.properties[name]?.key ?? name
    }
    
    // MARK: Storage
    
    /// The object and graph backing the resource. Resources created in code get a graph of their
    /// own on first use. Must be called while holding `ResourceGraph.lock`.
    func storageLocked() -> (object: ResourceObject, graph: ResourceGraph) {
        if let storage {
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
        case "lid":
            return lid
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
        case "lid":
            lid = value as? String
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
        guard let value else {
            return nil
        }
        
        if isNullValue(value) {
            return NSNull()
        }
        
        if let url = value as? URL {
            return url.absoluteString
        }
        
        if let date = value as? Date {
            return ISO8601DateCoding.string(from: date)
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
    
    /// The resource object of the resource for a request document.
    ///
    /// - Throws: `JSONAPIError.serialization` when an attribute or the meta can't be represented
    ///   in JSON, when a related resource has neither `id` nor `lid`, or when `requiringID` is
    ///   set and the resource itself has neither.
    func resourceObjectJSON(requiringID: Bool) throws(JSONAPIError) -> [String: Any] {
        return try ResourceGraph.lock.withLock { () throws(JSONAPIError) -> [String: Any] in
            let (object, graph) = storageLocked()
            
            var json: [String: Any] = ["type": object.type]
            json["id"] = object.id
            json["lid"] = object.lid
            
            if requiringID, object.id == nil, object.lid == nil {
                throw JSONAPIError.serialization(reason: "A resource of type \"\(object.type)\" has neither id nor lid.")
            }
            
            for (name, value) in object.attributes where !JSONSerialization.isValidJSONObject([value]) {
                throw JSONAPIError.serialization(reason: "The attribute \"\(name)\" of a resource of type \"\(object.type)\" has a value of type \(Swift.type(of: value)), which can't be represented in JSON.")
            }
            
            if !object.attributes.isEmpty {
                json["attributes"] = object.attributes
            }
            
            let relationships = try relationshipsJSON(of: object, in: graph, skippingInvalid: false)
            
            if !relationships.isEmpty {
                json["relationships"] = relationships
            }
            
            if let meta = object.meta {
                guard JSONSerialization.isValidJSONObject(meta) else {
                    throw JSONAPIError.serialization(reason: "The meta of a resource of type \"\(object.type)\" can't be represented in JSON.")
                }
                
                json["meta"] = meta
            }
            
            return json
        }
    }
    
    /// The relationships with resource linkage as JSON. Relationships with only links or meta are
    /// left out.
    private func relationshipsJSON(of object: ResourceObject, in graph: ResourceGraph, skippingInvalid: Bool) throws(JSONAPIError) -> [String: Any] {
        var json: [String: Any] = [:]
        
        for (name, relationship) in object.relationships {
            guard let linkage = relationship.data else {
                continue
            }
            
            do throws(JSONAPIError) {
                json[name] = ["data": try linkageJSON(linkage, ofRelationship: name, in: graph)]
            } catch {
                if !skippingInvalid {
                    throw error
                }
            }
        }
        
        return json
    }
    
    private func linkageJSON(_ linkage: ResourceLinkage, ofRelationship name: String, in graph: ResourceGraph) throws(JSONAPIError) -> Any {
        switch linkage {
        case .toOne(nil):
            return NSNull()
        case .toOne(let reference?):
            return try identifierJSON(reference, ofRelationship: name, in: graph)
        case .toMany(let references):
            return try references.map { reference throws(JSONAPIError) in
                try identifierJSON(reference, ofRelationship: name, in: graph)
            }
        }
    }
    
    private func identifierJSON(_ reference: ResourceReference, ofRelationship name: String, in graph: ResourceGraph) throws(JSONAPIError) -> [String: Any] {
        switch reference {
        case .identifier(let key, let meta):
            var json: [String: Any] = ["type": key.type]
            
            switch key.identifier {
            case .id(let id):
                json["id"] = id
            case .lid(let lid):
                json["lid"] = lid
            }
            
            json["meta"] = meta
            
            return json
        case .object:
            guard let object = graph.object(for: reference) else {
                preconditionFailure("A relationship refers to a resource object outside of its graph.")
            }
            
            if let id = object.id {
                return ["type": object.type, "id": id]
            } else if let lid = object.lid {
                return ["type": object.type, "lid": lid]
            } else {
                throw JSONAPIError.serialization(reason: "The relationship \"\(name)\" refers to a resource of type \"\(object.type)\" that has neither id nor lid.")
            }
        }
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
    /// The value of the property `key`, or of the JSON member `key` when no property has that
    /// name: an attribute value, a related resource or an array of related resources.
    ///
    /// Setting a value works like setting the property: `nil` leaves the member out, and the
    /// `null` placeholders send JSON `null`. `id` and `lid` can be set, and `type` is read-only.
    ///
    /// On platforms without the Objective-C runtime, the stored properties of resource classes
    /// aren't backed by the JSON. They declare the attributes and relationships, which are read
    /// and written with the subscript.
    public subscript(key: String) -> Any? {
        get {
            value(forMember: key)
        }
        set {
            setValue(newValue, forMember: key)
        }
    }
}

extension Array where Element: Resource {
    /// A document with the resources as primary data.
    ///
    /// - Throws: `JSONAPIError.serialization` when a resource has neither `id` nor `lid`, and for
    ///   the reasons of `Resource.documentDictionary()`.
    public func documentDictionary() throws(JSONAPIError) -> [String: Any] {
        return ["data": try map { resource throws(JSONAPIError) in
            try resource.resourceObjectJSON(requiringID: true)
        }]
    }
    
    /// The JSON data of `documentDictionary()`.
    public func documentData() throws(JSONAPIError) -> Data {
        try JSONAPIEncoder.data(of: documentDictionary())
    }
}
