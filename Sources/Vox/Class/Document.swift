import Foundation

public class Document<DataType> {
    public internal(set) var data: DataType?
    
    public let meta: [String: Any]?
    
    public let jsonapi: [String: Any]?
    
    public let links: Links?
    
    public internal(set) var included: [[String: Any]]?
    
    /// The graph of the document's resources. Resources keep it alive on their own, so they work
    /// after the document is gone.
    let graph: ResourceGraph
    weak var client: Client?
    
    init(data: DataType?, document: DecodedDocument) {
        self.data = data
        self.meta = document.meta
        self.jsonapi = document.jsonapi
        self.links = {
            guard
                let links = document.links,
                let data = try? JSONSerialization.data(withJSONObject: links, options: [])
                else { return nil }
            
            return try? JSONDecoder().decode(Links.self, from: data)
        }()
        self.included = document.included
        self.graph = document.graph
    }
}
