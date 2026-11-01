import Foundation

extension Pagination {
    public class CursorBased: PaginationStrategy {
        public func paginationURLQueryItems() -> [URLQueryItem] {
            let name = "\(key)[cursor]"
            let item = URLQueryItem(name: name, value: cursor)
            
            return [item]
        }
        
        public let key: String
        public let cursor: String
        
        public init(cursor: String, key: String = "page") {
            self.key = key
            self.cursor = cursor
        }
    }
}


