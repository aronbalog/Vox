import Foundation

extension Deserializer {
    public class Single<ResourceType: Resource> {
        public init() {}
        
        public func deserialize(data: Data) throws -> Document<ResourceType> {
            return try JSONAPIDecoder.decode(data: data)
        }
    }
}
