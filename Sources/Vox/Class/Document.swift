import Foundation

public class Document<DataType> {
    public internal(set) var data: DataType?
    
    public let meta: [String: Any]?
    
    public let jsonapi: [String: Any]?
    
    public let links: Links?
    
    public internal(set) var included: [[String: Any]]?
    
    let context: Context
    weak var client: Client?
    
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
        let links: Links? = {
            guard
                let links = links,
                let data = try? JSONSerialization.data(withJSONObject: links, options: [])
                else { return nil }
            
            return try? JSONDecoder().decode(Links.self, from: data)
        }()
        self.links = links
        self.included = included
        self.context = context
    }
    
    deinit {
        context.reassign()
    }
}

