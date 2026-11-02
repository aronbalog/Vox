import Foundation

/// A JSON:API document received from a server.
///
/// Documents can be shared across isolation domains. Their resources synchronize access to their
/// JSON as well.
public final class Document<DataType>: @unchecked Sendable {
    /// The primary data: a resource or an array of resources.
    public var data: DataType? {
        ResourceGraph.lock.withLock { _data }
    }
    
    /// The meta of the document, as JSON. After `appendNext()`, the meta of the appended page.
    public var meta: [String: Any]? {
        ResourceGraph.lock.withLock { _meta }
    }
    
    /// The `jsonapi` member, which describes the server's implementation, as JSON.
    public let jsonapi: [String: Any]?
    
    /// The links of the document. After `appendNext()`, the links of the appended page.
    public var links: Links? {
        ResourceGraph.lock.withLock { _links }
    }
    
    /// The included resource objects as JSON.
    public var included: [[String: Any]]? {
        ResourceGraph.lock.withLock { _included }
    }
    
    /// The graph of the document's resources. Resources keep it alive on their own, so they work
    /// after the document is gone.
    let graph: ResourceGraph
    
    /// The client that fetched the document, for fetching other pages.
    var client: (any Client)? {
        get { ResourceGraph.lock.withLock { _client } }
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
