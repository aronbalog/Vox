import Foundation

public class Request<ResourceType: Resource, SuccessCallbackType>: DataSourceResultable {
    public typealias DataSourceResourceSuccessfulBlock = SuccessCallbackType
    
    private var path: String
    private var httpMethod: String
    private var client: Client
    
    fileprivate var queryItems: [URLQueryItem] = []
    
    var resource: ResourceType?
    
    var successBlock: SuccessCallbackType?
    var failureBlock: ((Error) -> Void)?
    
    init(path: String, httpMethod: String, client: Client) {
        self.path = path
        self.httpMethod = httpMethod
        self.client = client
    }
    
    public func result(_ success: SuccessCallbackType, _ failure: ((Error) -> Void)?) throws {
        successBlock = success
        failureBlock = failure
        
        try execute()
    }
    
    func execute() throws {
        let parameters: [String: Any]? = try resource?.documentDictionary()
        
        client.executeRequest(path, method: httpMethod, queryItems: queryItems, parameters: parameters, success: { (response, data) in
            if let success = self.successBlock as? DataSource<ResourceType>.ResourceSuccessBlock {
                guard let data = data else {
                    fatalError("Unhandled exception")
                }
                
                do {
                    let document: Document<ResourceType> = try Deserializer.Single().deserialize(data: data)
                    success(document)
                } catch let __error as JSONAPIError {
                    self.failureBlock?(__error)
                } catch {
                    fatalError("Unhandled exception")
                }
            } else if let success = self.successBlock as? DataSource<ResourceType>.OptionalResourceSuccessBlock {
                guard let data = data else {
                    success(nil)
                    return
                }
                
                do {
                    let document: Document<ResourceType> = try Deserializer.Single().deserialize(data: data)
                    success(document)
                } catch let __error as JSONAPIError {
                    self.failureBlock?(__error)
                } catch {
                    fatalError("Unhandled exception")
                }
            } else if let success = self.successBlock as? DataSource<ResourceType>.ResourceCollectionSuccessBlock {
                guard let data = data else {
                    fatalError("Unhandled exception")
                }
                
                do {
                    let document: Document<[ResourceType]> = try Deserializer.Collection().deserialize(data: data)
                    success(document)
                } catch let __error as JSONAPIError {
                    self.failureBlock?(__error)
                } catch {
                    fatalError("Unhandled exception")
                }
            } else if let success = self.successBlock as? DataSource<ResourceType>.DeleteSuccessBlock {
                success()
            }
        }) { (error, data) in
            guard let data = data else {
                self.failureBlock?(error)
                return
            }
            
            do {
                let _: Document<DataType> = try JSONAPIDecoder.decode(data: data)
            } catch let error as JSONAPIError {
                self.failureBlock?(error)
            } catch {
                fatalError("Unhandled exception")
            }
        }
    }
}

public class FetchRequest<ResourceType: Resource, SuccessCallbackType>: Request<ResourceType, SuccessCallbackType>, FetchConfigurable {
    public var filter: FilterStrategy? {
        didSet {
            self.filter?.filterURLQueryItems().forEach({ (queryItem) in
                queryItems.append(queryItem)
            })
        }
    }
    
    public var sort: [Sort] = [] {
        didSet {
            let value = self.sort.map { element in
                return element.value
            }.joined(separator: ",")
            let queryItem = URLQueryItem(name: "sort", value: value)
            queryItems.append(queryItem)
        }
    }
    
    public var fields: Fields? {
        didSet {
            var dictionary: [String: String] = [:]
            fields?.forEach({ (field) in
                dictionary[field.key] = field.value.joined(separator: ",")
            })
            let _queryItems = dictionary.map { (field) -> URLQueryItem in
                let name = "fields[\(field.key)]"
                return URLQueryItem(name: name, value: field.value)
            }
            queryItems.append(contentsOf: _queryItems)
        }
    }
    public var include: [String] = [] {
        didSet {
            let value = include.joined(separator: ",")
            let queryItem = URLQueryItem(name: "include", value: value)
            queryItems.append(queryItem)
        }
    }
    
    public func sort(_ sort: [Sort]) -> FetchRequest<ResourceType, SuccessCallbackType> {
        self.sort = sort
        
        return self
    }
    
    public func fields(_ fields: Fields) -> FetchRequest<ResourceType, SuccessCallbackType> {
        self.fields = fields
        
        return self
    }
    
    public func include(_ include: [String]) -> FetchRequest<ResourceType, SuccessCallbackType> {
        self.include.append(contentsOf: include)
        
        return self
    }
    
    public func filter(_ filter: FilterStrategy) -> FetchRequest<ResourceType, SuccessCallbackType> {
        self.filter = filter
        
        return self
        
    }
}
