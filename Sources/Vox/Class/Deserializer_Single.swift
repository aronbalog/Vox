import Foundation

extension Deserializer {
    /// Decodes documents whose primary data is a single resource or `null`.
    public class Single<ResourceType: Resource> {
        public init() {}
        
        /// Decodes the document in `data`.
        ///
        /// - Throws: `JSONAPIError.API` with the error objects of an error document, and
        ///   `JSONAPIError.invalidDocument` when `data` isn't a JSON:API document, its primary data
        ///   is an array, or its resource isn't a `ResourceType`.
        public func deserialize(data: Data) throws(JSONAPIError) -> Document<ResourceType> {
            ResourceRuntime.register(ResourceType.self)
            
            let document = try JSONAPIDecoder.decode(data)
            
            return Document(data: try document.resource(of: ResourceType.self), document: document)
        }
    }
}
