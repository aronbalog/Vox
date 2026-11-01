import Foundation

extension Pagination {
    public class OffsetBased: PaginationStrategy {
        public func paginationURLQueryItems() -> [URLQueryItem] {
            var items: [URLQueryItem] = []
            
            if let offset = offset {
                let name = "\(key)[offset]"
                let item = URLQueryItem(name: name, value: String(offset))
                items.append(item)
            }
            
            if let limit = limit {
                let name = "\(key)[limit]"
                let item = URLQueryItem(name: name, value: String(limit))
                items.append(item)
            }
            
            return items
        }
        
        public let key: String
        public let offset: Int?
        public let limit: Int?
        
        public init(offset: Int? = nil, limit: Int? = nil, key: String = "page") {
            self.key = key
            self.offset = offset
            self.limit = limit
        }
    }
}

