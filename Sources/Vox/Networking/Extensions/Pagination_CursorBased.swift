import Foundation

extension Pagination {
    /// Sends `page[cursor]`.
    public struct CursorBased: PaginationStrategy {
        /// The name of the parameter family, `page` by default.
        public let key: String
        public let cursor: String
        
        public init(cursor: String, key: String = "page") {
            self.key = key
            self.cursor = cursor
        }
        
        public func paginationURLQueryItems() -> [URLQueryItem] {
            return [URLQueryItem(name: "\(key)[cursor]", value: cursor)]
        }
    }
}
