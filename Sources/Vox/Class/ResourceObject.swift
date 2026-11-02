import Foundation

/// Identifies a resource object within a graph by its `type` and its `id` or local `lid`.
struct ResourceKey: Hashable {
    enum Identifier: Hashable {
        case id(String)
        case lid(String)
    }
    
    let type: String
    let identifier: Identifier
    
    /// The key of the resource object `json`, by `id` or else by `lid`.
    init?(json: [String: Any]) {
        guard let type = json["type"] as? String else {
            return nil
        }
        
        if let id = resourceIdentifier(json["id"]) {
            self.init(type: type, identifier: .id(id))
        } else if let lid = json["lid"] as? String {
            self.init(type: type, identifier: .lid(lid))
        } else {
            return nil
        }
    }
    
    init(type: String, identifier: Identifier) {
        self.type = type
        self.identifier = identifier
    }
}

/// The JSON of one resource object.
///
/// Resource objects are owned by a `ResourceGraph` and must only be accessed while holding
/// `ResourceGraph.lock`.
final class ResourceObject {
    let type: String
    var id: String?
    /// The local identifier of a resource that has no `id` yet.
    var lid: String?
    var attributes: [String: Any]
    var relationships: [String: RelationshipObject]
    var links: [String: Any]?
    var meta: [String: Any]?
    
    init(type: String) {
        self.type = type
        self.attributes = [:]
        self.relationships = [:]
    }
    
    /// Parses the resource object at `path` of a JSON:API document.
    init(json: [String: Any], at path: String) throws(JSONAPIError) {
        guard let type = json["type"] as? String, !type.isEmpty else {
            throw JSONAPIError.invalidDocument(reason: "The resource object at \(path) has no type.")
        }
        
        self.type = type
        self.id = resourceIdentifier(json["id"])
        self.lid = json["lid"] as? String
        self.attributes = json["attributes"] as? [String: Any] ?? [:]
        self.relationships = (json["relationships"] as? [String: Any] ?? [:]).compactMapValues { relationship in
            (relationship as? [String: Any]).map(RelationshipObject.init(json:))
        }
        self.links = json["links"] as? [String: Any]
        self.meta = json["meta"] as? [String: Any]
    }
    
    /// The keys resource identifiers can refer to the object by.
    var keys: [ResourceKey] {
        var keys: [ResourceKey] = []
        
        if let id {
            keys.append(ResourceKey(type: type, identifier: .id(id)))
        }
        
        if let lid {
            keys.append(ResourceKey(type: type, identifier: .lid(lid)))
        }
        
        return keys
    }
    
    /// Adds the members of `other` this object doesn't have, for documents that contain the same
    /// resource more than once.
    func merge(_ other: ResourceObject) {
        id = id ?? other.id
        lid = lid ?? other.lid
        attributes.merge(other.attributes) { current, _ in current }
        relationships.merge(other.relationships) { current, _ in current }
        links = links ?? other.links
        meta = meta ?? other.meta
    }
    
    /// Takes the members of `other`, a later version of the same resource, and keeps the ones
    /// `other` doesn't have.
    func update(with other: ResourceObject) {
        id = other.id ?? id
        lid = other.lid ?? lid
        attributes.merge(other.attributes) { _, newer in newer }
        relationships.merge(other.relationships) { current, newer in
            var relationship = newer
            relationship.data = newer.data ?? current.data
            relationship.links = newer.links ?? current.links
            relationship.meta = newer.meta ?? current.meta
            
            return relationship
        }
        links = other.links ?? links
        meta = other.meta ?? meta
    }
    
    /// Sets the resource linkage of a relationship. Removing the linkage keeps the relationship's
    /// links and meta.
    func setLinkage(_ linkage: ResourceLinkage?, forRelationship name: String) {
        var relationship = relationships[name] ?? RelationshipObject(data: nil)
        relationship.data = linkage
        
        if linkage == nil, relationship.links == nil, relationship.meta == nil {
            relationships[name] = nil
        } else {
            relationships[name] = relationship
        }
    }
}

/// A relationship of a resource object.
struct RelationshipObject {
    /// The resource linkage, `nil` when the relationship has no `data` member.
    var data: ResourceLinkage?
    var links: [String: Any]?
    var meta: [String: Any]?
    
    init(data: ResourceLinkage?) {
        self.data = data
    }
    
    init(json: [String: Any]) {
        switch json["data"] {
        case is NSNull:
            data = .toOne(nil)
        case let identifier as [String: Any]:
            data = .toOne(ResourceReference(json: identifier))
        case let identifiers as [Any]:
            data = .toMany(identifiers.compactMap { identifier in
                (identifier as? [String: Any]).flatMap(ResourceReference.init(json:))
            })
        default:
            data = nil
        }
        
        links = json["links"] as? [String: Any]
        meta = json["meta"] as? [String: Any]
    }
}

/// The resource linkage of a relationship.
enum ResourceLinkage {
    /// A to-one relationship, `nil` for an empty one.
    case toOne(ResourceReference?)
    case toMany([ResourceReference])
}

/// Points at a resource from a relationship.
enum ResourceReference {
    /// A resource identifier object received in a document.
    case identifier(ResourceKey, meta: [String: Any]?)
    /// A resource assigned in code. It's referenced by its object, so changes to its `id` made
    /// after the assignment are picked up.
    case object(ObjectIdentifier)
    
    init?(json: [String: Any]) {
        guard let type = json["type"] as? String else {
            return nil
        }
        
        let identifier: ResourceKey.Identifier
        
        if let id = resourceIdentifier(json["id"]) {
            identifier = .id(id)
        } else if let lid = json["lid"] as? String {
            identifier = .lid(lid)
        } else {
            return nil
        }
        
        self = .identifier(ResourceKey(type: type, identifier: identifier), meta: json["meta"] as? [String: Any])
    }
}

/// The `id` member of a resource object or resource identifier object. Integers are accepted for
/// servers that send them instead of strings.
private func resourceIdentifier(_ value: Any?) -> String? {
    switch value {
    case let id as String:
        return id
    case let id as Int:
        return String(id)
    default:
        return nil
    }
}
