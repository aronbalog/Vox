import Foundation

/// Builds the filter parameters of a collection request. JSON:API leaves the strategy to the
/// server; `Filter` implements the one the recommendations suggest.
public protocol FilterStrategy: Sendable {
    func filterURLQueryItems() -> [URLQueryItem]
}
