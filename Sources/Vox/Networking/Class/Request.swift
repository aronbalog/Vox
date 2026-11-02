import Foundation

/// The media type of JSON:API documents.
let jsonAPIMediaType = "application/vnd.api+json"

/// A request of a data source. Configure it with the modifiers, which return modified copies,
/// and send it with `result()`.
public struct Request<ResourceType: Resource, Output: Sendable>: DataSourceResultable, QueryItemsCustomizable, @unchecked Sendable {
    let client: any Client
    let method: String
    /// The target, or the error that prevents sending the request.
    let target: Result<ClientRequest.Target, Error>
    /// Creates the request document when the request is sent.
    let body: (() throws -> Data)?
    let decode: @Sendable (ClientResponse, any Client) throws -> Output
    
    private(set) var customQueryItems: [URLQueryItem] = []
    
    /// Headers sent in addition to the JSON:API ones.
    public var headers: [String: String] = [:]
    
    /// Values passed to the client with the request.
    public var userInfo: [String: any Sendable] = [:]
    
    init(client: any Client, method: String, target: Result<ClientRequest.Target, Error>, body: (() throws -> Data)? = nil, decode: @escaping @Sendable (ClientResponse, any Client) throws -> Output) {
        self.client = client
        self.method = method
        self.target = target
        self.body = body
        self.decode = decode
    }
    
    init(client: any Client, method: String, target: ClientRequest.Target, body: (() throws -> Data)? = nil, decode: @escaping @Sendable (ClientResponse, any Client) throws -> Output) {
        self.init(client: client, method: method, target: .success(target), body: body, decode: decode)
    }
    
    /// Adds query items, which are sent after the ones the request builds itself.
    public func queryItems(_ queryItems: [URLQueryItem]) -> Request {
        var request = self
        request.customQueryItems += queryItems
        
        return request
    }
    
    /// Adds headers, which replace the JSON:API headers with the same name, compared
    /// case-insensitively.
    public func headers(_ headers: [String: String]) -> Request {
        var request = self
        request.headers.merge(headers) { _, new in new }
        
        return request
    }
    
    /// Adds values passed to the client with the request.
    public func userInfo(_ userInfo: [String: any Sendable]) -> Request {
        var request = self
        request.userInfo.merge(userInfo) { _, new in new }
        
        return request
    }
    
    /// Sends the request.
    ///
    /// - Throws: `JSONAPIError.API` for responses with error objects,
    ///   `JSONAPIError.unacceptableStatusCode` for other responses with a status code outside
    ///   200–299, `JSONAPIError.invalidDocument` for responses that aren't the expected document,
    ///   `JSONAPIError.serialization` when the request document can't be created or the URL of
    ///   a relationship can't be determined, and the errors of the client.
    public func result() async throws -> Output {
        return try await perform(queryItems: customQueryItems)
    }
    
    func perform(queryItems: [URLQueryItem]) async throws -> Output {
        let target = try self.target.get()
        var headers = ["Accept": jsonAPIMediaType]
        let body = try self.body?()
        
        if body != nil {
            headers["Content-Type"] = jsonAPIMediaType
        }
        
        for (name, value) in self.headers {
            if let defaultName = headers.keys.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                headers[defaultName] = nil
            }
            
            headers[name] = value
        }
        
        let request = ClientRequest(method: method, target: target, queryItems: queryItems, headers: headers, body: body, userInfo: userInfo)
        let response = try await client.execute(request)
        
        guard (200..<300).contains(response.statusCode) else {
            throw JSONAPIDecoder.apiError(in: response.data) ?? JSONAPIError.unacceptableStatusCode(response.statusCode, body: response.data)
        }
        
        return try decode(response, client)
    }
}

/// A request for a resource or a collection, with the query parameters of JSON:API.
///
/// The parameters are sent in a fixed order: sparse fieldsets sorted by type, the filter,
/// `include`, `sort`, the pagination, and query items added with `queryItems(_:)`.
public struct FetchRequest<ResourceType: Resource, Output: Sendable>: DataSourceResultable, QueryItemsCustomizable, FetchConfigurable, @unchecked Sendable {
    private var request: Request<ResourceType, Output>
    
    public private(set) var pagination: PaginationStrategy?
    
    public private(set) var filter: FilterStrategy?
    
    public private(set) var sort: [Sort] = []
    
    public private(set) var fields: Fields?
    
    public private(set) var include: [String] = []
    
    /// Headers sent in addition to the JSON:API ones.
    public var headers: [String: String] {
        get { return request.headers }
        set { request.headers = newValue }
    }
    
    /// Values passed to the client with the request.
    public var userInfo: [String: any Sendable] {
        get { return request.userInfo }
        set { request.userInfo = newValue }
    }
    
    init(_ request: Request<ResourceType, Output>) {
        self.request = request
    }
    
    /// Replaces the sort fields.
    public func sort(_ sort: [Sort]) -> FetchRequest {
        var request = self
        request.sort = sort
        
        return request
    }
    
    /// Sets the sparse fieldsets of the given types. An empty field list requests no fields of
    /// that type.
    public func fields(_ fields: Fields) -> FetchRequest {
        var request = self
        request.fields = (self.fields ?? [:]).merging(fields) { _, new in new }
        
        return request
    }
    
    /// Adds relationship paths to include, leaving out the ones included already.
    public func include(_ include: [String]) -> FetchRequest {
        var request = self
        
        for path in include where !request.include.contains(path) {
            request.include.append(path)
        }
        
        return request
    }
    
    /// Replaces the filter.
    public func filter(_ filter: FilterStrategy) -> FetchRequest {
        var request = self
        request.filter = filter
        
        return request
    }
    
    /// Replaces the pagination.
    public func paginate(_ pagination: PaginationStrategy) -> FetchRequest {
        var request = self
        request.pagination = pagination
        
        return request
    }
    
    /// Adds query items, which are sent after the ones the request builds itself.
    public func queryItems(_ queryItems: [URLQueryItem]) -> FetchRequest {
        var request = self
        request.request = self.request.queryItems(queryItems)
        
        return request
    }
    
    /// Adds headers, which replace the JSON:API headers with the same name, compared
    /// case-insensitively.
    public func headers(_ headers: [String: String]) -> FetchRequest {
        var request = self
        request.request = self.request.headers(headers)
        
        return request
    }
    
    /// Adds values passed to the client with the request.
    public func userInfo(_ userInfo: [String: any Sendable]) -> FetchRequest {
        var request = self
        request.request = self.request.userInfo(userInfo)
        
        return request
    }
    
    /// Sends the request.
    ///
    /// - Throws: The errors of `Request.result()`.
    public func result() async throws -> Output {
        return try await request.perform(queryItems: makeQueryItems())
    }
    
    func makeQueryItems() -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = []
        
        for (type, fieldNames) in (fields ?? [:]).sorted(by: { $0.key < $1.key }) {
            queryItems.append(URLQueryItem(name: "fields[\(type)]", value: fieldNames.joined(separator: ",")))
        }
        
        queryItems += filter?.filterURLQueryItems() ?? []
        
        if !include.isEmpty {
            queryItems.append(URLQueryItem(name: "include", value: include.joined(separator: ",")))
        }
        
        if !sort.isEmpty {
            queryItems.append(URLQueryItem(name: "sort", value: sort.map(\.value).joined(separator: ",")))
        }
        
        queryItems += pagination?.paginationURLQueryItems() ?? []
        
        return queryItems + request.customQueryItems
    }
}

/// Decodes the responses of data source requests.
enum ResponseDecoding {
    static func resource<T: Resource>(_ response: ClientResponse, client: any Client) throws -> Document<T> {
        guard !response.data.isEmpty else {
            throw JSONAPIError.invalidDocument(reason: "The response has no content.")
        }
        
        let document = try Deserializer.Single<T>().deserialize(data: response.data)
        document.client = client
        
        return document
    }
    
    /// `nil` for responses without content, such as 204 No Content.
    static func optionalResource<T: Resource>(_ response: ClientResponse, client: any Client) throws -> Document<T>? {
        return response.data.isEmpty ? nil : try resource(response, client: client)
    }
    
    static func collection<T: Resource>(_ response: ClientResponse, client: any Client) throws -> Document<[T]> {
        guard !response.data.isEmpty else {
            throw JSONAPIError.invalidDocument(reason: "The response has no content.")
        }
        
        let document = try Deserializer.Collection<T>().deserialize(data: response.data)
        document.client = client
        
        return document
    }
}
