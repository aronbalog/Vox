import Foundation

extension Deserializer {
    /// Decodes documents whose primary data is an array of resources. With `Resource` as
    /// `ResourceType`, the array can mix resources of any type.
    public class Collection<ResourceType: Resource> {
        public init() {}
        
        /// Decodes the document in `data`.
        ///
        /// - Throws: `JSONAPIError.API` with the error objects of an error document, and
        ///   `JSONAPIError.invalidDocument` when `data` isn't a JSON:API document, its primary data
        ///   isn't an array, or one of its resources isn't a `ResourceType`.
        public func deserialize(data: Data) throws(JSONAPIError) -> Document<[ResourceType]> {
            ResourceRuntime.register(ResourceType.self)
            
            let document = try JSONAPIDecoder.decode(data)
            
            return Document(data: try document.resources(of: ResourceType.self), document: document)
        }
    }
}
