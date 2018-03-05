import Foundation

public protocol FetchPageable {
    associatedtype FetchConfigurableType

    var pagination: PaginationStrategy? { get }
    
    func paginate(_ pagination: PaginationStrategy) -> FetchConfigurableType
}



public struct PaginationData<T> {
    let old: [T]
    let new: [T]
    let all: [T]
}

public extension Document where DataType: Collection, DataType.Element: Resource {
    typealias ResourceCollectionSuccessBlock = DataSource<DataType.Element>.ResourceCollectionSuccessBlock
    
    public var first: FetchRequest<DataType.Element, ResourceCollectionSuccessBlock>? {
        guard let client = client else { fatalError("Client not available") }
        guard let first = self.links?.first else { return nil }
        
        let dataSource = DataSource<DataType.Element>(strategy: .path(first.path), client: client)
        
        return dataSource.fetch()
    }
    
    public var next: FetchRequest<DataType.Element, ResourceCollectionSuccessBlock>? {
        guard let client = client else { fatalError("Client not available") }
        guard let next = self.links?.next else { return nil }
        
        let dataSource = DataSource<DataType.Element>(strategy: .path(next.path), client: client)
        
        return dataSource.fetch()
    }
    
    public var previous: FetchRequest<DataType.Element, ResourceCollectionSuccessBlock>? {
        guard let client = client else { fatalError("Client not available") }
        guard let prev = self.links?.prev else { return nil }
        
        let dataSource = DataSource<DataType.Element>(strategy: .path(prev.path), client: client)
        
        return dataSource.fetch()
    }
    
    public var last: FetchRequest<DataType.Element, ResourceCollectionSuccessBlock>? {
        guard let client = client else { fatalError("Client not available") }
        guard let last = self.links?.last else { return nil }
        
        let dataSource = DataSource<DataType.Element>(strategy: .path(last.path), client: client)
        
        return dataSource.fetch()
    }
    
    public var reload: FetchRequest<DataType.Element, ResourceCollectionSuccessBlock>? {
        guard let client = client else { fatalError("Client not available") }
        guard let _self = self.links?._self else { return nil }
        
        let dataSource = DataSource<DataType.Element>(strategy: .path(_self.path), client: client)
        
        return dataSource.fetch()
    }
    
    public func appendNext(_ completion: ((PaginationData<DataType.Element>) -> Void)? = nil, _ failure: ((Error?) -> Void)? = nil) {
        guard let next = self.links?.next else {
            return
        }
        
        guard let client = client else {
            fatalError("Client not available")
        }
        
        let path = URLComponents(url: next, resolvingAgainstBaseURL: false)
        
        let queryItems = path?.queryItems ?? []
        
        let dataSource = DataSource<DataType.Element>(strategy: .path(next.path), client: client)
        
        do {
            try dataSource
                .fetch()
                .queryItems(queryItems)
                .result({ (document) in
                    let oldElements = self.data as? [DataType.Element] ?? []
                    let newElements = document.data ?? []
                    
                    self.mergeDocument(document)

                    let allElements = self.data as? [DataType.Element] ?? []
                    
                    let page = PaginationData<DataType.Element>.init(old: oldElements, new: newElements, all: allElements)
                    completion?(page)
                }) { (error) in
                    failure?(error)
                }
        } catch let error {
            failure?(error)
        }
        
    }
    
    private func mergeDocument(_ document: Document<[DataType.Element]>) {
        if let array = document.context.dictionary["data"] as? [Any] {
            let selfData = self.context.dictionary["data"] as? NSMutableArray
            
            let resources = array.flatMap({ (resourceJson) -> Resource? in
                guard let resourceJson = resourceJson as? NSMutableDictionary else { return nil }
                let copy = resourceJson.mutableCopy() as! NSMutableDictionary
                
                selfData?.add(copy)
                
                guard let resource = self.context.mapResource(for: copy) else { return nil }
                
                return resource
            })
            
            
            var collection = data as? [Resource]
            collection?.append(contentsOf: resources)
            self.data = collection as? DataType
            
            print(collection!.count)
        }
        
        if let array = document.context.dictionary["included"] as? NSMutableArray {
            let selfData = self.context.dictionary["included"] as? NSMutableArray
            
            array.forEach({ (resourceJson) in
                guard let resourceJson = resourceJson as? NSMutableDictionary else { return }
                let copy = resourceJson.mutableCopy() as! NSMutableDictionary
                
                if let selfData = selfData {
                    selfData.add(copy)
                    included?.append(copy as! [String : Any])
                }
                
                guard let _ = self.context.mapResource(for: copy) else { return }

            })
            
        }
    }
}
