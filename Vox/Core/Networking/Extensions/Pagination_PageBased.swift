import Foundation

extension Pagination {
    public class PageBased: PaginationStrategy {
        public func paginationURLQueryItems() -> [URLQueryItem] {
            var items: [URLQueryItem] = []
            
            if let number = number {
                let name = "\(key)[number]"
                let item = URLQueryItem(name: name, value: String(number))
                items.append(item)
            }
            
            if let size = size {
                let name = "\(key)[size]"
                let item = URLQueryItem(name: name, value: String(size))
                items.append(item)
            }
            
            return items
        }
        
        public let key: String
        public let number: Int?
        public let size: Int?
        
        public init(number: Int? = nil, size: Int? = nil, key: String = "page") {
            self.key = key
            self.number = number
            self.size = size
        }
    }
}
