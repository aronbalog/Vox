import Foundation

public protocol PaginationStrategy: Sendable {
    func paginationURLQueryItems() -> [URLQueryItem]
}
