import Foundation

public class DataSource<ResourceType: Resource>: NSObject, CRUD {
    
    public enum Strategy {
        case path(_: String)
        case router(_: Router)
    }
    
    public typealias DocumentType<Type> = Document<Type>
    public typealias ResourceSuccessBlock = (_ document: DocumentType<ResourceType>) -> Void
    public typealias OptionalResourceSuccessBlock = (_ document: DocumentType<ResourceType>?) -> Void
    public typealias ResourceCollectionSuccessBlock = (_ document: DocumentType<[ResourceType]>) -> Void
    public typealias DeleteSuccessBlock = () -> Void
    
    public typealias CreatableResourceTypeCompletable = Request<ResourceType, OptionalResourceSuccessBlock>
    public typealias FetchableResourceTypeConfigurable = FetchRequest<ResourceType, ResourceSuccessBlock>
    public typealias FetchableResourceCollectionTypeConfigurable = FetchRequest<ResourceType, ResourceCollectionSuccessBlock>
    public typealias UpdatableResourceTypeCompletable = Request<ResourceType, OptionalResourceSuccessBlock>
    public typealias DeletableResourceTypeCompletable = Request<ResourceType, DeleteSuccessBlock>
    
    let strategy: Strategy
    let client: Client
    
    public init(strategy: Strategy, client: Client) {
        self.strategy = strategy
        self.client = client
    }
    
    public func create(_ resource: ResourceType) -> Request<ResourceType, OptionalResourceSuccessBlock> {
        let path: String = {
            switch strategy {
            case .path(let path):
                return path
            case .router(let router):
                return router.create(resource: resource)
            }
        }()
        
        let request = Request<ResourceType, OptionalResourceSuccessBlock>(path: path, httpMethod: "POST", client: client)
        
        request.resource = resource
        
        return request
    }
    
    public func fetch() -> FetchRequest<ResourceType, ResourceCollectionSuccessBlock> {
        let path: String = {
            switch strategy {
            case .path(let path):
                return path
            case .router(let router):
                return router.fetch(type: ResourceType.self)
            }
        }()
        
        let request = FetchRequest<ResourceType, ResourceCollectionSuccessBlock>(path: path, httpMethod: "GET", client: client)
        
        return request
    }
    
    public func fetch(id: String) -> FetchRequest<ResourceType, ResourceSuccessBlock> {
        let path: String = {
            switch strategy {
            case .path(let path):
                return path
            case .router(let router):
                return router.fetch(id: id, type: ResourceType.self)
            }
        }()
        
        let request = FetchRequest<ResourceType, ResourceSuccessBlock>(path: path, httpMethod: "GET", client: client)
        
        return request
    }
    
    public func update(_ resource: ResourceType) -> Request<ResourceType, OptionalResourceSuccessBlock> {
        let path: String = {
            switch strategy {
            case .path(let path):
                return path
            case .router(let router):
                return router.update(resource: resource)
            }
        }()
        
        let request = Request<ResourceType, OptionalResourceSuccessBlock>(path: path, httpMethod: "PATCH", client: client)
        
        request.resource = resource
        
        return request
    }
    
    public func delete(id: String) -> Request<ResourceType, DeleteSuccessBlock> {
        let path: String = {
            switch strategy {
            case .path(let path):
                return path
            case .router(let router):
                return router.delete(id: id, type: ResourceType.self)
            }
        }()
        
        let request = Request<ResourceType, DeleteSuccessBlock>(path: path, httpMethod: "DELETE", client: client)
        
        return request
    }
}
