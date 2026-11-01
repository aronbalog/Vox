import Foundation

extension Deserializer {
    public class Single<ResourceType: Resource> {
        public init() {}
        
        public func deserialize(data: Data) throws -> Document<ResourceType> {
            ResourceRuntime.register(ResourceType.self)
            
            let document = try JSONAPIDecoder.decode(data)
            
            return Document(data: try document.resource(of: ResourceType.self), document: document)
        }
    }
}
