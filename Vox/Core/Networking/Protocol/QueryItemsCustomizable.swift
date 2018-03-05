import Foundation

public protocol QueryItemsCustomizable {
    func queryItems(_ queryItems: [URLQueryItem]) -> Self
}
