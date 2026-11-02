import Foundation

/// A JSON:API document received from a server.
///
/// Documents can be shared across isolation domains. Their resources synchronize access to their
/// JSON as well.
public final class Document<DataType>: @unchecked Sendable {
    /// The primary data: a resource or an array of resources.
    public internal(set) var data: DataType? {
        get { return ResourceGraph.lock.withLock { _data } }
        set { ResourceGraph.lock.withLock { _data = newValue } }
    }
    
    /// The meta of the document, as JSON. After `appendNext()`, the meta of the appended page.
    public internal(set) var meta: [String: Any]? {
        get { return ResourceGraph.lock.withLock { _meta } }
        set { ResourceGraph.lock.withLock { _meta = newValue } }
    }
    
    /// The `jsonapi` member, which describes the server's implementation, as JSON.
    public let jsonapi: [String: Any]?
    
    /// The links of the document. After `appendNext()`, the links of the appended page.
    public internal(set) var links: Links? {
        get { return ResourceGraph.lock.withLock { _links } }
        set { ResourceGraph.lock.withLock { _links = newValue } }
    }
    
    /// The included resource objects as JSON.
    public internal(set) var included: [[String: Any]]? {
        get { return ResourceGraph.lock.withLock { _included } }
        set { ResourceGraph.lock.withLock { _included = newValue } }
    }
    
    /// The graph of the document's resources. Resources keep it alive on their own, so they work
    /// after the document is gone.
    let graph: ResourceGraph
    
    /// The client that fetched the document, for fetching other pages.
    var client: (any Client)? {
        get { return ResourceGraph.lock.withLock { _client } }
        set { ResourceGraph.lock.withLock { _client = newValue } }
    }
    
    /// Guarded by `ResourceGraph.lock`, like the members below.
    var _data: DataType?
    var _meta: [String: Any]?
    var _links: Links?
    var _included: [[String: Any]]?
    private var _client: (any Client)?
    
    init(data: DataType?, document: DecodedDocument) {
        self._data = data
        self._meta = document.meta
        self.jsonapi = document.jsonapi
        self._links = Links(json: document.links)
        self._included = document.included
        self.graph = document.graph
    }
}
