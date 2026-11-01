import Foundation

/// A JSON:API document whose resource objects have been added to a graph.
struct DecodedDocument {
    enum PrimaryData {
        case resource(ResourceObject)
        case collection([ResourceObject])
    }
    
    let graph: ResourceGraph
    let primaryData: PrimaryData
    let meta: [String: Any]?
    let jsonapi: [String: Any]?
    let links: [String: Any]?
    let included: [[String: Any]]?
    
    /// The instance of the primary resource, if the primary data is a single resource of type `T`.
    func resource<T: Resource>(of _: T.Type) -> T? {
        guard case .resource(let object) = primaryData else {
            return nil
        }
        
        return ResourceGraph.lock.withLock {
            graph.instance(for: object) as? T
        }
    }
    
    /// The instances of the primary resources of type `T`, if the primary data is a collection.
    func resources<T: Resource>(of _: T.Type) -> [T]? {
        guard case .collection(let objects) = primaryData else {
            return nil
        }
        
        return ResourceGraph.lock.withLock {
            objects.compactMap { graph.instance(for: $0) as? T }
        }
    }
}

enum JSONAPIDecoder {
    static func decode(_ data: Data) throws -> DecodedDocument {
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw JSONAPIError.serialization
        }
        
        if let errors = json["errors"] as? [[String: Any]] {
            throw JSONAPIError.API(errors.map(ErrorObject.init(dictionary:)))
        }
        
        let graph = ResourceGraph()
        let primaryData: DecodedDocument.PrimaryData
        
        switch json["data"] {
        case let resource as [String: Any]:
            primaryData = .resource(graph.insert(try ResourceObject(json: resource)))
        case let resources as [[String: Any]]:
            primaryData = .collection(try resources.map { graph.insert(try ResourceObject(json: $0)) })
        default:
            throw JSONAPIError.serialization
        }
        
        let included = json["included"] as? [[String: Any]]
        
        for resource in included ?? [] {
            graph.insert(try ResourceObject(json: resource))
        }
        
        return DecodedDocument(
            graph: graph,
            primaryData: primaryData,
            meta: json["meta"] as? [String: Any],
            jsonapi: json["jsonApi"] as? [String: Any],
            links: json["links"] as? [String: Any],
            included: included
        )
    }
}
