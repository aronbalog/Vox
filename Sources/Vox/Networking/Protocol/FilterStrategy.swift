import Foundation

public protocol FilterStrategy: Sendable {
    func filterURLQueryItems() -> [URLQueryItem]
}
