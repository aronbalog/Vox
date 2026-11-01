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
    
    /// A `POST` request with the resource. The document is `nil` when the server responds without
    /// content.
    public func create(_ resource: ResourceType) -> Request<ResourceType, Document<ResourceType>?> {
        let path = self.path { router in router.create(resource: resource) }
        
        return Request(client: client, method: "POST", target: .path(replacingPlaceholders(in: path, id: resource.id, type: resource.type)), resource: resource) { response, client in
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
    
    /// A `PATCH` request with the resource. The document is `nil` when the server responds without
    /// content.
    public func update(_ resource: ResourceType) -> Request<ResourceType, Document<ResourceType>?> {
        let path = self.path { router in router.update(resource: resource) }
        
        return Request(client: client, method: "PATCH", target: .path(replacingPlaceholders(in: path, id: resource.id, type: resource.type)), resource: resource) { response, client in
            try ResponseDecoding.optionalResource(response, client: client)
        }
    }
    
    /// A `DELETE` request for the resource with the id.
    public func delete(id: String) -> Request<ResourceType, Void> {
        let path = self.path { router in router.delete(id: id, type: ResourceType.self) }
        
        return Request(client: client, method: "DELETE", target: .path(replacingPlaceholders(in: path, id: id, type: ResourceType.resourceType))) { _, _ in }
    }
    
    private func path(fromRouter route: (Router) -> String) -> String {
        switch strategy {
        case .path(let path):
            return path
        case .router(let router):
            return route(router)
        }
    }
    
    private func replacingPlaceholders(in path: String, id: String?, type: String) -> String {
        var path = path
        
        if let id = id {
            path = path.replacingOccurrences(of: "<id>", with: id)
        }
        
        return path.replacingOccurrences(of: "<type>", with: type)
    }
}
