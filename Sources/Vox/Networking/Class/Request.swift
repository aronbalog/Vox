import Foundation

public class Request<ResourceType: Resource, SuccessCallbackType>: DataSourceResultable, QueryItemsCustomizable {
    public typealias DataSourceResourceSuccessfulBlock = SuccessCallbackType
    
    private var path: String
    private var httpMethod: String
    private var client: Client
    public var userInfo: [String: Any] = [:]
    
    private var customQueryItems: [URLQueryItem] = []
    
    var resource: ResourceType?
    
    var successBlock: SuccessCallbackType?
    var failureBlock: ((Error?) -> Void)?
    
    init(path: String, httpMethod: String, client: Client) {
        self.path = path
        self.httpMethod = httpMethod
        self.client = client
    }
    
    public func result(_ success: SuccessCallbackType, _ failure: ((Error?) -> Void)?) throws {
        successBlock = success
        failureBlock = failure
        
        try execute()
    }
    
    /// Adds query items, which are sent after the ones the request builds itself.
    public func queryItems(_ queryItems: [URLQueryItem]) -> Self {
        customQueryItems.append(contentsOf: queryItems)
        
        return self
    }
    
    /// The query items of the request.
    func makeQueryItems() -> [URLQueryItem] {
        return customQueryItems
    }
    
    func execute() throws {
        let parameters: [String: Any]? = try resource?.documentDictionary()
        
        client.executeRequest(path: path, method: httpMethod, queryItems: makeQueryItems(), bodyParameters: parameters, success: { (response, data) in
            if let success = self.successBlock as? DataSource<ResourceType>.ResourceSuccessBlock {
                guard let data = data else {
                    fatalError("Unhandled exception")
                }
                
                do {
                    let document: Document<ResourceType> = try Deserializer.Single().deserialize(data: data)
                    success(document)
                } catch let __error {
                    self.failureBlock?(__error)
                }
            } else if let success = self.successBlock as? DataSource<ResourceType>.OptionalResourceSuccessBlock {
                guard
                    let data = data,
                    !data.isEmpty
                else {
                    success(nil)
                    return
                }
                
                do {
                    let document: Document<ResourceType> = try Deserializer.Single().deserialize(data: data)
                    success(document)
                } catch let __error {
                    self.failureBlock?(__error)
                }
            } else if let success = self.successBlock as? DataSource<ResourceType>.ResourceCollectionSuccessBlock {
                guard let data = data else {
                    fatalError("Unhandled exception")
                }
                
                do {
                    let document: Document<[ResourceType]> = try Deserializer.Collection().deserialize(data: data)
                    document.client = self.client
                    success(document)
                } catch let __error {
                    self.failureBlock?(__error)
                }
            } else if let success = self.successBlock as? DataSource<ResourceType>.DeleteSuccessBlock {
                success()
            }
        }, failure: { (error, data) in
            if let data = data, let apiError = JSONAPIDecoder.apiError(in: data) {
                self.failureBlock?(apiError)
            } else {
                self.failureBlock?(error)
            }
        }, userInfo: userInfo)
    }
}

/// A request for a resource or a collection, with the query parameters of JSON:API.
///
/// The parameters are sent in a fixed order: sparse fieldsets sorted by type, the filter,
/// `include`, `sort`, the pagination, and query items added with `queryItems(_:)`.
public class FetchRequest<ResourceType: Resource, SuccessCallbackType>: Request<ResourceType, SuccessCallbackType>, FetchConfigurable {
    public internal(set) var pagination: PaginationStrategy?
    
    public internal(set) var filter: FilterStrategy?
    
    public internal(set) var sort: [Sort] = []
    
    public internal(set) var fields: Fields?
    
    public internal(set) var include: [String] = []
    
    /// Replaces the sort fields.
    public func sort(_ sort: [Sort]) -> FetchRequest<ResourceType, SuccessCallbackType> {
        self.sort = sort
        
        return self
    }
    
    /// Sets the sparse fieldsets of the given types. An empty field list requests no fields of
    /// that type.
    public func fields(_ fields: Fields) -> FetchRequest<ResourceType, SuccessCallbackType> {
        self.fields = (self.fields ?? [:]).merging(fields) { _, new in new }
        
        return self
    }
    
    /// Adds relationship paths to include, leaving out the ones included already.
    public func include(_ include: [String]) -> FetchRequest<ResourceType, SuccessCallbackType> {
        for path in include where !self.include.contains(path) {
            self.include.append(path)
        }
        
        return self
    }
    
    /// Replaces the filter.
    public func filter(_ filter: FilterStrategy) -> FetchRequest<ResourceType, SuccessCallbackType> {
        self.filter = filter
        
        return self
    }
    
    /// Replaces the pagination.
    public func paginate(_ pagination: PaginationStrategy) -> FetchRequest<ResourceType, SuccessCallbackType> {
        self.pagination = pagination
        
        return self
    }
    
    override func makeQueryItems() -> [URLQueryItem] {
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
        
        return queryItems + super.makeQueryItems()
    }
}
