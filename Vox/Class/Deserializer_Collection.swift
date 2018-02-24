import Foundation

extension Deserializer {
    public class Collection<ResourceType: Resource> {
        public func deserialize(data: Data) throws -> Document<[ResourceType]> {
            return try JSONAPIDecoder.decode(data: data)
        }
    }
}
