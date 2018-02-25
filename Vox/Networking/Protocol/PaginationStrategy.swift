import Foundation

public protocol PaginationStrategy {
    func paginationURLQueryItems() -> [URLQueryItem]
}
