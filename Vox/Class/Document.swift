import Foundation

public class Document<DataType> {
    public let data: DataType?
    
    public let meta: [String: Any]?
    
    public let jsonapi: [String: Any]?
    
    public let links: [String: Any]?
    
    public let included: [[String: Any]]?
    
    let context: Context
    
    init(
        data: DataType?,
        meta: [String: Any]?,
        jsonapi: [String: Any]?,
        links: [String: Any]?,
        included: [[String: Any]]?,
        context: Context
    ) {
        self.data = data
        self.meta = meta
        self.jsonapi = jsonapi
        self.links = links
        self.included = included
        self.context = context
    }
    
    deinit {
        context.reassign()
    }
}

