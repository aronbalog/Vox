import Foundation

extension Pagination {
    /// Sends `page[offset]` and `page[limit]`.
    public struct OffsetBased: PaginationStrategy {
        public let key: String
        public let offset: Int?
        public let limit: Int?
        
        public init(offset: Int? = nil, limit: Int? = nil, key: String = "page") {
            self.key = key
            self.offset = offset
            self.limit = limit
        }
        
        public func paginationURLQueryItems() -> [URLQueryItem] {
            var items: [URLQueryItem] = []
            
            if let offset = offset {
                items.append(URLQueryItem(name: "\(key)[offset]", value: String(offset)))
            }
            
            if let limit = limit {
                items.append(URLQueryItem(name: "\(key)[limit]", value: String(limit)))
            }
            
            return items
        }
    }
}
