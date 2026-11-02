import Foundation

/// A request that can send query items of its own.
public protocol QueryItemsCustomizable {
    /// Adds query items, which are sent after the ones the request builds itself.
    func queryItems(_ queryItems: [URLQueryItem]) -> Self
}
