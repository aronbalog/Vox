import Foundation

extension Deserializer {
    public class Collection<ResourceType: Resource> {
        public init() {}
        
        public func deserialize(data: Data) throws -> Document<[ResourceType]> {
            ResourceRuntime.register(ResourceType.self)
            
            let document = try JSONAPIDecoder.decode(data)
            
            return Document(data: try document.resources(of: ResourceType.self), document: document)
        }
    }
}
