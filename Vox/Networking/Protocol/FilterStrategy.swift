import Foundation

public protocol FilterStrategy {
    func filterURLQueryItems() -> [URLQueryItem]
}
