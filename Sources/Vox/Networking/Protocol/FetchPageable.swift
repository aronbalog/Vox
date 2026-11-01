import Foundation

public protocol FetchPageable {
    associatedtype FetchConfigurableType

    var pagination: PaginationStrategy? { get }
    
    func paginate(_ pagination: PaginationStrategy) -> FetchConfigurableType
}

public struct PaginationData<T>: @unchecked Sendable {
    public let old: [T]
    public let new: [T]
    public let all: [T]
}

extension Document where DataType: Collection, DataType.Element: Resource {
    public typealias PageRequest = FetchRequest<DataType.Element, Document<[DataType.Element]>>
    
    /// A request for the first page, or `nil` when the document has no `first` link.
    public var first: PageRequest? {
        return request(following: links?.first)
    }
    
    /// A request for the next page, or `nil` when the document has no `next` link.
    public var next: PageRequest? {
        return request(following: links?.next)
    }
    
    /// A request for the previous page, or `nil` when the document has no `prev` link.
    public var previous: PageRequest? {
        return request(following: links?.prev)
    }
    
    /// A request for the last page, or `nil` when the document has no `last` link.
    public var last: PageRequest? {
        return request(following: links?.last)
    }
    
    /// A request for the current page, or `nil` when the document has no `self` link.
    public var reload: PageRequest? {
        return request(following: links?.selfLink)
    }
    
    /// Fetches the next page and appends its resources and included resources to the document.
    /// Does nothing when the document has no `next` link.
    public func appendNext(_ completion: (@MainActor (PaginationData<DataType.Element>) -> Void)? = nil, _ failure: (@MainActor (Error) -> Void)? = nil) {
        guard let next = next else {
            return
        }
        
        next.result({ document in
            let oldElements = self.data as? [DataType.Element] ?? []
            let newElements = document.data ?? []
            
            self.mergeDocument(document)
            
            let allElements = self.data as? [DataType.Element] ?? []
            
            completion?(PaginationData(old: oldElements, new: newElements, all: allElements))
        }, failure)
    }
    
    /// A request following `link` with the client that fetched the document.
    private func request(following link: Link?) -> PageRequest? {
        guard let link = link, let client = client else {
            return nil
        }
        
        return FetchRequest(Request(client: client, method: "GET", target: .link(link.href)) { response, client in
            try ResponseDecoding.collection(response, client: client)
        })
    }
    
    private func mergeDocument(_ document: Document<[DataType.Element]>) {
        ResourceGraph.lock.withLock {
            _ = ResourceGraph.merge(graph, document.graph)
        }
        
        var collection = data as? [DataType.Element] ?? []
        collection.append(contentsOf: document.data ?? [])
        self.data = collection as? DataType
        
        if let newIncluded = document.included {
            included = (included ?? []) + newIncluded
        }
    }
}
