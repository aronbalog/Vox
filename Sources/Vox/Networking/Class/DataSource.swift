import Foundation

/// Creates the requests for the resources of one type.
///
/// ```swift
/// let dataSource = DataSource<Article>(strategy: .path("articles/<id>"), client: client)
///
/// let document = try await dataSource.fetch(id: "1").include(["author"]).result()
/// ```
public final class DataSource<ResourceType: Resource>: CRUD, Sendable {
    /// How the paths of requests are determined.
    public enum Strategy: Sendable {
        /// A path for all requests, in which the `<type>` and `<id>` placeholders are replaced.
        case path(_: String)
        case router(_: Router)
    }
    
    public typealias ResourceSuccessBlock = @MainActor (_ document: Document<ResourceType>) -> Void
    public typealias OptionalResourceSuccessBlock = @MainActor (_ document: Document<ResourceType>?) -> Void
    public typealias ResourceCollectionSuccessBlock = @MainActor (_ document: Document<[ResourceType]>) -> Void
    public typealias DeleteSuccessBlock = @MainActor () -> Void
    
    public typealias CreatableResourceTypeCompletable = Request<ResourceType, Document<ResourceType>?>
    public typealias FetchableResourceTypeConfigurable = FetchRequest<ResourceType, Document<ResourceType>>
    public typealias FetchableResourceCollectionTypeConfigurable = FetchRequest<ResourceType, Document<[ResourceType]>>
    public typealias UpdatableResourceTypeCompletable = Request<ResourceType, Document<ResourceType>?>
    public typealias DeletableResourceTypeCompletable = Request<ResourceType, Void>
    
    public let strategy: Strategy
    public let client: any Client
    
    public init(strategy: Strategy, client: any Client) {
        self.strategy = strategy
        self.client = client
    }
    
    /// A `POST` request with the resource, to the path of the collection even when the resource
    /// has a client-generated id. The document is `nil` when the server responds without content.
    public func create(_ resource: ResourceType) -> Request<ResourceType, Document<ResourceType>?> {
        let path = self.path { router in router.create(resource: resource) }
        
        return Request(client: client, method: "POST", target: .path(replacingPlaceholders(in: path, id: nil, type: resource.type)), body: { try resource.documentData(requiringID: false) }) { response, client in
            try ResponseDecoding.optionalResource(response, client: client)
        }
    }
    
    /// A `GET` request for the collection.
    public func fetch() -> FetchRequest<ResourceType, Document<[ResourceType]>> {
        let path = self.path { router in router.fetch(type: ResourceType.self) }
        
        return FetchRequest(Request(client: client, method: "GET", target: .path(replacingPlaceholders(in: path, id: nil, type: ResourceType.resourceType))) { response, client in
            try ResponseDecoding.collection(response, client: client)
        })
    }
    
    /// A `GET` request for the resource with the id.
    public func fetch(id: String) -> FetchRequest<ResourceType, Document<ResourceType>> {
        let path = self.path { router in router.fetch(id: id, type: ResourceType.self) }
        
        return FetchRequest(Request(client: client, method: "GET", target: .path(replacingPlaceholders(in: path, id: id, type: ResourceType.resourceType))) { response, client in
            try ResponseDecoding.resource(response, client: client)
        })
    }
    
    /// A `PATCH` request with the resource, which must have an `id`. The document is `nil` when
    /// the server responds without content.
    public func update(_ resource: ResourceType) -> Request<ResourceType, Document<ResourceType>?> {
        let path = self.path { router in router.update(resource: resource) }
        
        return Request(client: client, method: "PATCH", target: .path(replacingPlaceholders(in: path, id: resource.id, type: resource.type)), body: { try resource.documentData(requiringID: true) }) { response, client in
            try ResponseDecoding.optionalResource(response, client: client)
        }
    }
    
    /// A `DELETE` request for the resource with the id.
    public func delete(id: String) -> Request<ResourceType, Void> {
        let path = self.path { router in router.delete(id: id, type: ResourceType.self) }
        
        return Request(client: client, method: "DELETE", target: .path(replacingPlaceholders(in: path, id: id, type: ResourceType.resourceType))) { _, _ in }
    }
    
    // MARK: Relationships
    
    /// A `GET` request for the resource of the to-one relationship `relationship` of `resource`,
    /// which is `nil` when the relationship is empty.
    ///
    /// The request follows the `related` link of the relationship. Without one, the path is built
    /// as JSON:API recommends, `<path of the resource>/<relationship>`, or by the router.
    /// `relationship` is the name of a property or of a relationship member.
    public func fetchRelated<Related: Resource>(_ relationship: String, of resource: ResourceType, as type: Related.Type) -> FetchRequest<Related, Document<Related>> {
        return FetchRequest(Request(client: client, method: "GET", target: target(of: .related, relationship, of: resource)) { response, client in
            try ResponseDecoding.resource(response, client: client)
        })
    }
    
    /// A `GET` request for the resources of the to-many relationship `relationship` of
    /// `resource`, which can be sorted, filtered and paginated like a collection.
    ///
    /// The request follows the `related` link of the relationship. Without one, the path is built
    /// as JSON:API recommends, `<path of the resource>/<relationship>`, or by the router.
    /// `relationship` is the name of a property or of a relationship member.
    public func fetchRelated<Related: Resource>(_ relationship: String, of resource: ResourceType, as type: [Related].Type) -> FetchRequest<Related, Document<[Related]>> {
        return FetchRequest(Request(client: client, method: "GET", target: target(of: .related, relationship, of: resource)) { response, client in
            try ResponseDecoding.collection(response, client: client)
        })
    }
    
    /// A `GET` request for the linkage of the to-one relationship `relationship` of `resource`.
    /// The resource of the document only has a type and id, unless the server includes it.
    ///
    /// The request follows the `self` link of the relationship. Without one, the path is built
    /// as JSON:API recommends, `<path of the resource>/relationships/<relationship>`, or by the
    /// router. `relationship` is the name of a property or of a relationship member.
    public func fetchRelationship<Related: Resource>(_ relationship: String, of resource: ResourceType, as type: Related.Type) -> FetchRequest<Related, Document<Related>> {
        return FetchRequest(Request(client: client, method: "GET", target: target(of: .relationship, relationship, of: resource)) { response, client in
            try ResponseDecoding.resource(response, client: client)
        })
    }
    
    /// A `GET` request for the linkage of the to-many relationship `relationship` of `resource`.
    /// The resources of the document only have a type and id, unless the server includes them.
    ///
    /// The request follows the `self` link of the relationship. Without one, the path is built
    /// as JSON:API recommends, `<path of the resource>/relationships/<relationship>`, or by the
    /// router. `relationship` is the name of a property or of a relationship member.
    public func fetchRelationship<Related: Resource>(_ relationship: String, of resource: ResourceType, as type: [Related].Type) -> FetchRequest<Related, Document<[Related]>> {
        return FetchRequest(Request(client: client, method: "GET", target: target(of: .relationship, relationship, of: resource)) { response, client in
            try ResponseDecoding.collection(response, client: client)
        })
    }
    
    /// A `PATCH` request that sets the to-one relationship `relationship` of `resource` to
    /// `related`, or empties it when `related` is `nil`.
    ///
    /// The request goes to the relationship's URL, as in `fetchRelationship`. It doesn't change
    /// `resource`.
    public func updateRelationship(_ relationship: String, of resource: ResourceType, to related: Resource?) -> Request<ResourceType, Void> {
        return relationshipRequest("PATCH", relationship, of: resource) {
            guard let related = related else {
                return NSNull()
            }
            
            return try related.identifierJSON()
        }
    }
    
    /// A `PATCH` request that replaces the members of the to-many relationship `relationship`
    /// of `resource` with `related`.
    ///
    /// The request goes to the relationship's URL, as in `fetchRelationship`. It doesn't change
    /// `resource`.
    public func updateRelationship(_ relationship: String, of resource: ResourceType, to related: [Resource]) -> Request<ResourceType, Void> {
        return relationshipRequest("PATCH", relationship, of: resource) {
            try related.map { try $0.identifierJSON() }
        }
    }
    
    /// A `POST` request that adds `related` to the members of the to-many relationship
    /// `relationship` of `resource`.
    ///
    /// The request goes to the relationship's URL, as in `fetchRelationship`. It doesn't change
    /// `resource`.
    public func addToRelationship(_ relationship: String, of resource: ResourceType, _ related: [Resource]) -> Request<ResourceType, Void> {
        return relationshipRequest("POST", relationship, of: resource) {
            try related.map { try $0.identifierJSON() }
        }
    }
    
    /// A `DELETE` request that removes `related` from the members of the to-many relationship
    /// `relationship` of `resource`.
    ///
    /// The request goes to the relationship's URL, as in `fetchRelationship`. It doesn't change
    /// `resource`.
    public func removeFromRelationship(_ relationship: String, of resource: ResourceType, _ related: [Resource]) -> Request<ResourceType, Void> {
        return relationshipRequest("DELETE", relationship, of: resource) {
            try related.map { try $0.identifierJSON() }
        }
    }
    
    private enum RelationshipEndpoint {
        /// The relationship itself, at its `self` link.
        case relationship
        /// The related resources, at the `related` link.
        case related
    }
    
    private func relationshipRequest(_ method: String, _ relationship: String, of resource: ResourceType, linkage: @escaping () throws -> Any) -> Request<ResourceType, Void> {
        return Request(client: client, method: method, target: target(of: .relationship, relationship, of: resource), body: {
            try JSONSerialization.data(withJSONObject: ["data": try linkage()], options: [])
        }) { _, _ in }
    }
    
    private func target(of endpoint: RelationshipEndpoint, _ relationship: String, of resource: ResourceType) -> Result<ClientRequest.Target, Error> {
        let links = resource.relationship(named: relationship)?.links
        let link = endpoint == .relationship ? links?.selfLink : links?.related
        
        if let link = link {
            return .success(.link(link.href))
        }
        
        let member = resource.memberName(forProperty: relationship)
        
        guard let id = resource.id else {
            let linkName = endpoint == .relationship ? "self" : "related"
            
            return .failure(JSONAPIError.serialization(reason: "The relationship \"\(member)\" has no \(linkName) link, and the resource has no id to build its URL with."))
        }
        
        switch strategy {
        case .path(let path):
            var resourcePath = replacingPlaceholders(in: path, id: id, type: resource.type)
            
            while resourcePath.hasSuffix("/") {
                resourcePath.removeLast()
            }
            
            if !path.contains("<id>") {
                resourcePath += "/" + id
            }
            
            return .success(.path(resourcePath + (endpoint == .relationship ? "/relationships/" : "/") + member))
        case .router(let router):
            return .success(.path(endpoint == .relationship ? router.relationship(member, of: resource) : router.related(member, of: resource)))
        }
    }
    
    private func path(fromRouter route: (Router) -> String) -> String {
        switch strategy {
        case .path(let path):
            return path
        case .router(let router):
            return route(router)
        }
    }
    
    /// `path` with the placeholders replaced. Without an id, as for the collection, `<id>` is left
    /// out together with the slash before it.
    private func replacingPlaceholders(in path: String, id: String?, type: String) -> String {
        let path = path.replacingOccurrences(of: "<type>", with: type)
        
        if let id = id {
            return path.replacingOccurrences(of: "<id>", with: id)
        }
        
        return path.replacingOccurrences(of: "/<id>", with: "").replacingOccurrences(of: "<id>", with: "")
    }
}
