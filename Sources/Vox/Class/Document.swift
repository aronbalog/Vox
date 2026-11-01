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
    
    public let meta: [String: Any]?
    
    public let jsonapi: [String: Any]?
    
    public let links: Links?
    
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
    
    private var _data: DataType?
    private var _included: [[String: Any]]?
    private var _client: (any Client)?
    
    init(data: DataType?, document: DecodedDocument) {
        self._data = data
        self.meta = document.meta
        self.jsonapi = document.jsonapi
        self.links = Links(json: document.links)
        self._included = document.included
        self.graph = document.graph
    }
}
