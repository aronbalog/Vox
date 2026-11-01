import Foundation

/// Identifies a resource object within a graph by its `type` and `id`.
struct ResourceKey: Hashable {
    let type: String
    let id: String
}

/// The JSON of one resource object.
///
/// Resource objects are owned by a `ResourceGraph` and must only be accessed while holding
/// `ResourceGraph.lock`.
final class ResourceObject {
    let type: String
    var id: String?
    var attributes: [String: Any]
    var relationships: [String: RelationshipObject]
    var links: [String: Any]?
    var meta: [String: Any]?
    
    init(type: String, id: String? = nil) {
        self.type = type
        self.id = id
        self.attributes = [:]
        self.relationships = [:]
    }
    
    /// Parses a resource object of a JSON:API document.
    init(json: [String: Any]) throws {
        guard let type = json["type"] as? String, let id = json["id"] as? String else {
            throw JSONAPIError.serialization
        }
        
        self.type = type
        self.id = id
        self.attributes = json["attributes"] as? [String: Any] ?? [:]
        self.relationships = (json["relationships"] as? [String: Any] ?? [:]).compactMapValues { relationship in
            (relationship as? [String: Any]).map(RelationshipObject.init(json:))
        }
        self.links = json["links"] as? [String: Any]
        self.meta = json["meta"] as? [String: Any]
    }
    
    var key: ResourceKey? {
        return id.map { ResourceKey(type: type, id: $0) }
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
        guard let type = json["type"] as? String, let id = json["id"] as? String else {
            return nil
        }
        
        self = .identifier(ResourceKey(type: type, id: id), meta: json["meta"] as? [String: Any])
    }
}
