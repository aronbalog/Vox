import Foundation

public class Links: Decodable {
    public let _self: URL?
    public let first: URL?
    public let prev: URL?
    public let next: URL?
    public let last: URL?
    
    enum CodingKeys: String, CodingKey {
        case _self = "self"
        case first = "first"
        case prev = "prev"
        case next = "next"
        case last = "last"
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        _self = try container.decodeIfPresent(URL.self, forKey: Links.CodingKeys._self)
        first = try container.decodeIfPresent(URL.self, forKey: Links.CodingKeys.first)
        prev = try container.decodeIfPresent(URL.self, forKey: Links.CodingKeys.prev)
        next = try container.decodeIfPresent(URL.self, forKey: Links.CodingKeys.next)
        last = try container.decodeIfPresent(URL.self, forKey: Links.CodingKeys.last)
    }
}
