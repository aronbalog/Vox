import Foundation

public protocol FetchPageable {
    associatedtype FetchConfigurableType

    var pagination: PaginationStrategy? { get }
    
    func paginate(_ pagination: PaginationStrategy) -> FetchConfigurableType
}

/// The resources of a document before and after a page was appended to it.
public struct PaginationData<T>: @unchecked Sendable {
    /// The resources before the page was appended.
    public let old: [T]
    /// The resources of the page that were appended. Resources the document contained already
    /// aren't appended again and aren't part of `new`.
    public let new: [T]
    /// The resources after the page was appended.
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
    ///
    /// Resources the document contains already, which pages of a changing collection can
    /// repeat, aren't appended again but take the values of the page. Afterwards `links` and
    /// `meta` are those of the page, so `next` continues after it.
    ///
    /// - Returns: The resources before and after the page was appended, or `nil` when the
    ///   document has no `next` link or wasn't fetched by a client.
    @discardableResult
    public func appendNext() async throws -> PaginationData<DataType.Element>? {
        guard let next = next else {
            return nil
        }
        
        return append(try await next.result())
    }
    
    /// Fetches the next page, appends it like `appendNext()` and calls `completion` or `failure`
    /// on the main actor. `completion` receives `nil` when there's no next page.
    public func appendNext(_ completion: @escaping @MainActor (PaginationData<DataType.Element>?) -> Void, _ failure: (@MainActor (Error) -> Void)? = nil) {
        Task { @MainActor in
            do {
                completion(try await self.appendNext())
            } catch {
                failure?(error)
            }
        }
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
    
    func append(_ page: Document<[DataType.Element]>) -> PaginationData<DataType.Element> {
        return ResourceGraph.lock.withLock {
            let graph = self.graph.current
            graph.update(with: page.graph)
            
            let old = _data.map { Array($0) } ?? []
            var all = old
            var new: [DataType.Element] = []
            var known = Set(old.map { ObjectIdentifier($0) })
            
            for resource in page._data ?? [] {
                let pageObject = resource.storageLocked().object
                let object = graph.object(matching: pageObject) ?? pageObject
                
                guard let instance = graph.instance(for: object) as? DataType.Element, known.insert(ObjectIdentifier(instance)).inserted else {
                    continue
                }
                
                new.append(instance)
                all.append(instance)
            }
            
            _data = all as? DataType
            _included = Document.merging(page._included, into: _included)
            _links = page._links
            _meta = page._meta
            
            return PaginationData(old: old, new: new, all: all)
        }
    }
    
    /// `included` with the resource objects of `newer` appended, replacing the objects with the
    /// same type and `id` or `lid`.
    private static func merging(_ newer: [[String: Any]]?, into included: [[String: Any]]?) -> [[String: Any]]? {
        guard let newer = newer else {
            return included
        }
        
        var merged = included ?? []
        var indices: [ResourceKey: Int] = [:]
        
        for (index, json) in merged.enumerated() {
            if let key = ResourceKey(json: json) {
                indices[key] = index
            }
        }
        
        for json in newer {
            let key = ResourceKey(json: json)
            
            if let key = key, let index = indices[key] {
                merged[index] = json
            } else {
                if let key = key {
                    indices[key] = merged.count
                }
                
                merged.append(json)
            }
        }
        
        return merged
    }
}
