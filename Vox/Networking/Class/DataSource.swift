import Foundation

public class DataSource<ResourceType: Resource>: NSObject, CRUD {
    
    public enum Strategy {
        case path(_: String)
        case router(_: Router)
    }
    
    private enum AnnotationStrategy {
        case resourceIdentifier(id: String?, type: String)
        case resource(ResourceType)
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
        var path: String = {
            switch strategy {
            case .path(let path):
                return path
            case .router(let router):
                return router.create(resource: resource)
            }
        }()
        
        path = replaceAnnotations(on: path, with: DataSource<ResourceType>.AnnotationStrategy.resource(resource))

        let request = Request<ResourceType, OptionalResourceSuccessBlock>(path: path, httpMethod: "POST", client: client)
        
        request.resource = resource
        
        return request
    }
    
    public func fetch() -> FetchRequest<ResourceType, ResourceCollectionSuccessBlock> {
        var path: String = {
            switch strategy {
            case .path(let path):
                return path
            case .router(let router):
                return router.fetch(type: ResourceType.self)
            }
        }()
        
        path = replaceAnnotations(on: path, with: DataSource<ResourceType>.AnnotationStrategy.resourceIdentifier(id: nil, type: ResourceType.resourceType))

        let request = FetchRequest<ResourceType, ResourceCollectionSuccessBlock>(path: path, httpMethod: "GET", client: client)
        
        return request
    }
    
    public func fetch(id: String) -> FetchRequest<ResourceType, ResourceSuccessBlock> {
        var path: String = {
            switch strategy {
            case .path(let path):
                return path
            case .router(let router):
                return router.fetch(id: id, type: ResourceType.self)
            }
        }()
        
        path = replaceAnnotations(on: path, with: DataSource<ResourceType>.AnnotationStrategy.resourceIdentifier(id: id, type: ResourceType.resourceType))
        
        let request = FetchRequest<ResourceType, ResourceSuccessBlock>(path: path, httpMethod: "GET", client: client)
        
        return request
    }
    
    public func update(_ resource: ResourceType) -> Request<ResourceType, OptionalResourceSuccessBlock> {
        var path: String = {
            switch strategy {
            case .path(let path):
                return path
            case .router(let router):
                return router.update(resource: resource)
            }
        }()
        
        path = replaceAnnotations(on: path, with: DataSource<ResourceType>.AnnotationStrategy.resource(resource))

        let request = Request<ResourceType, OptionalResourceSuccessBlock>(path: path, httpMethod: "PATCH", client: client)
        
        request.resource = resource
        
        return request
    }
    
    public func delete(id: String) -> Request<ResourceType, DeleteSuccessBlock> {
        var path: String = {
            switch strategy {
            case .path(let path):
                return path
            case .router(let router):
                return router.delete(id: id, type: ResourceType.self)
            }
        }()
        
        path = replaceAnnotations(on: path, with: DataSource<ResourceType>.AnnotationStrategy.resourceIdentifier(id: id, type: ResourceType.resourceType))
        
        let request = Request<ResourceType, DeleteSuccessBlock>(path: path, httpMethod: "DELETE", client: client)
        
        return request
    }
    
    private func replaceAnnotations(on path: String, with strategy: AnnotationStrategy) -> String {
        var newPath = path
        
        switch strategy {
        case .resource(let resource):
            if let id = resource.id {
                newPath = newPath.replacingOccurrences(of: "<id>", with: id)
            }
            newPath = newPath.replacingOccurrences(of: "<type>", with: resource.type)
        case .resourceIdentifier(let id, let type):
            if let id = id {
                newPath = newPath.replacingOccurrences(of: "<id>", with: id)
            }
            newPath = newPath.replacingOccurrences(of: "<type>", with: type)
        }
        
        return newPath
    }
}

