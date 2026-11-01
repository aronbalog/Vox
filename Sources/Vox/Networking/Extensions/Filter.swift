import Foundation

/// Filters a collection with `filter[field]=value` query parameters, the strategy the JSON:API
/// recommendations suggest. Servers can use any strategy; implement `FilterStrategy` for others.
///
/// ```swift
/// dataSource.fetch().filter(Filter(["author": "9", "tag": "swift,ios"]))
/// // filter[author]=9&filter[tag]=swift,ios
/// ```
public struct Filter: FilterStrategy {
    public let values: [String: String]
    public let key: String
    
    public init(_ values: [String: String], key: String = "filter") {
        self.values = values
        self.key = key
    }
    
    /// The query items, sorted by field.
    public func filterURLQueryItems() -> [URLQueryItem] {
        return values
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: "\(key)[\($0.key)]", value: $0.value) }
    }
}
