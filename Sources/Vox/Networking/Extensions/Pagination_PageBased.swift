import Foundation

extension Pagination {
    /// Sends `page[number]` and `page[size]`.
    public struct PageBased: PaginationStrategy {
        /// The name of the parameter family, `page` by default.
        public let key: String
        public let number: Int?
        public let size: Int?
        
        public init(number: Int? = nil, size: Int? = nil, key: String = "page") {
            self.key = key
            self.number = number
            self.size = size
        }
        
        public func paginationURLQueryItems() -> [URLQueryItem] {
            var items: [URLQueryItem] = []
            
            if let number {
                items.append(URLQueryItem(name: "\(key)[number]", value: String(number)))
            }
            
            if let size {
                items.append(URLQueryItem(name: "\(key)[size]", value: String(size)))
            }
            
            return items
        }
    }
}
