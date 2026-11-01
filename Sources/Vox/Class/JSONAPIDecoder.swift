import Foundation

/// A JSON:API document whose resource objects have been added to a graph.
struct DecodedDocument {
    enum PrimaryData {
        /// The document has no `data` member.
        case absent
        /// A single resource, `nil` when `data` is `null`.
        case resource(ResourceObject?)
        case collection([ResourceObject])
    }
    
    let graph: ResourceGraph
    let primaryData: PrimaryData
    let meta: [String: Any]?
    let jsonapi: [String: Any]?
    let links: [String: Any]?
    let included: [[String: Any]]?
    
    /// The instance of the primary resource.
    ///
    /// - Throws: `JSONAPIError.invalidDocument` when the primary data is an array or a resource
    ///   that isn't a `T`.
    func resource<T: Resource>(of _: T.Type) throws -> T? {
        switch primaryData {
        case .absent, .resource(nil):
            return nil
        case .resource(let object?):
            return try ResourceGraph.lock.withLock {
                try instance(of: object, as: T.self)
            }
        case .collection:
            throw JSONAPIError.invalidDocument(reason: "Expected a single resource, but the primary data is an array.")
        }
    }
    
    /// The instances of the primary resources.
    ///
    /// - Throws: `JSONAPIError.invalidDocument` when the primary data is a single resource or
    ///   contains a resource that isn't a `T`.
    func resources<T: Resource>(of _: T.Type) throws -> [T]? {
        switch primaryData {
        case .absent, .resource(nil):
            return nil
        case .resource:
            throw JSONAPIError.invalidDocument(reason: "Expected an array of resources, but the primary data is a single resource.")
        case .collection(let objects):
            return try ResourceGraph.lock.withLock {
                try objects.map { try instance(of: $0, as: T.self) }
            }
        }
    }
    
    private func instance<T: Resource>(of object: ResourceObject, as _: T.Type) throws -> T {
        guard let resource = graph.instance(for: object) as? T else {
            throw JSONAPIError.invalidDocument(reason: "Expected resources of class \(T.self), but the primary data contains a resource of type \"\(object.type)\".")
        }
        
        return resource
    }
}

enum JSONAPIDecoder {
    /// Parses a JSON:API document.
    ///
    /// - Throws: `JSONAPIError.API` for documents with errors, `JSONAPIError.invalidDocument` for
    ///   data that isn't a JSON:API document.
    static func decode(_ data: Data) throws -> DecodedDocument {
        let json = try topLevelObject(of: data)
        
        if let error = apiError(in: json) {
            throw error
        }
        
        guard json["data"] != nil || json["meta"] != nil else {
            throw JSONAPIError.invalidDocument(reason: "A document must contain at least one of data, errors and meta.")
        }
        
        let graph = ResourceGraph()
        let primaryData: DecodedDocument.PrimaryData
        
        switch json["data"] {
        case nil:
            primaryData = .absent
        case is NSNull:
            primaryData = .resource(nil)
        case let resource as [String: Any]:
            primaryData = .resource(graph.insert(try ResourceObject(json: resource, at: "data")))
        case let resources as [Any]:
            primaryData = .collection(try resourceObjects(resources, at: "data").map(graph.insert))
        default:
            throw JSONAPIError.invalidDocument(reason: "The primary data must be null, a resource object or an array of resource objects.")
        }
        
        var included: [[String: Any]]?
        
        switch json["included"] {
        case nil:
            break
        case let resources as [Any]:
            for object in try resourceObjects(resources, at: "included") {
                graph.insert(object)
            }
            
            included = resources.compactMap { $0 as? [String: Any] }
        default:
            throw JSONAPIError.invalidDocument(reason: "The included member must be an array of resource objects.")
        }
        
        return DecodedDocument(
            graph: graph,
            primaryData: primaryData,
            meta: json["meta"] as? [String: Any],
            jsonapi: json["jsonapi"] as? [String: Any],
            links: json["links"] as? [String: Any],
            included: included
        )
    }
    
    /// The error objects of a document, or `nil` when `data` isn't a JSON:API document with
    /// errors.
    static func apiError(in data: Data) -> JSONAPIError? {
        return (try? topLevelObject(of: data)).flatMap(apiError(in:))
    }
    
    private static func apiError(in json: [String: Any]) -> JSONAPIError? {
        guard let errors = json["errors"] as? [Any] else {
            return nil
        }
        
        return .API(errors.compactMap { $0 as? [String: Any] }.map(ErrorObject.init(dictionary:)))
    }
    
    private static func topLevelObject(of data: Data) throws -> [String: Any] {
        let json: Any
        
        do {
            json = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw JSONAPIError.invalidDocument(reason: "The data isn't valid JSON.")
        }
        
        guard let object = json as? [String: Any] else {
            throw JSONAPIError.invalidDocument(reason: "The top level of a document must be an object.")
        }
        
        return object
    }
    
    private static func resourceObjects(_ array: [Any], at path: String) throws -> [ResourceObject] {
        return try array.enumerated().map { index, element in
            guard let json = element as? [String: Any] else {
                throw JSONAPIError.invalidDocument(reason: "The element at \(path)[\(index)] isn't a resource object.")
            }
            
            return try ResourceObject(json: json, at: "\(path)[\(index)]")
        }
    }
}
