import Foundation

/// Builds the pagination parameters of a collection request. JSON:API leaves the strategy to the
/// server; `Pagination` has the ones the recommendations suggest.
public protocol PaginationStrategy: Sendable {
    func paginationURLQueryItems() -> [URLQueryItem]
}
