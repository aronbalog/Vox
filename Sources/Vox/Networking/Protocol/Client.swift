import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Sends the HTTP requests of data sources.
///
/// Vox builds the request, including its JSON:API headers and body, and interprets the response.
/// A client only has to transmit it. Responses with any status code are returned; clients throw
/// only when no response was received.
public protocol Client: Sendable {
    func execute(_ request: ClientRequest) async throws -> ClientResponse
}

/// An HTTP request built by a data source.
public struct ClientRequest: Sendable {
    /// Where a request goes.
    public enum Target: Sendable, Hashable {
        /// A path, which is appended to the client's base URL.
        case path(String)
        /// A link from a document, which is resolved against the client's base URL like a link
        /// in a web page. Absolute links are used as they are.
        case link(String)
    }
    
    public var method: String
    public var target: Target
    /// Query items, which are added after the query a link or path contains already.
    public var queryItems: [URLQueryItem]
    public var headers: [String: String]
    /// The JSON:API document to send.
    public var body: Data?
    /// The values set on the request with `userInfo(_:)`, for the client's own use.
    public var userInfo: [String: any Sendable]
    
    public init(method: String, target: Target, queryItems: [URLQueryItem] = [], headers: [String: String] = [:], body: Data? = nil, userInfo: [String: any Sendable] = [:]) {
        self.method = method
        self.target = target
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.userInfo = userInfo
    }
    
    /// The URL of the request, for an API at `baseURL`.
    ///
    /// Query item names and values are percent-encoded, including the brackets of parameters
    /// such as `page[number]` and plus signs, which some servers decode as spaces.
    public func url(relativeTo baseURL: URL) -> URL? {
        let url: URL?
        
        switch target {
        case .path(let path):
            url = ClientRequest.url(appending: path, to: baseURL)
        case .link(let link):
            url = Link.url(from: link, relativeTo: baseURL)
        }
        
        guard let resolvedURL = url, var components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: true) else {
            return nil
        }
        
        if !queryItems.isEmpty {
            let query = queryItems.map { item in
                ClientRequest.encodeQueryComponent(item.name) + (item.value.map { "=" + ClientRequest.encodeQueryComponent($0) } ?? "")
            }
            
            components.percentEncodedQuery = ([components.percentEncodedQuery].compactMap { $0 }.filter { !$0.isEmpty } + query).joined(separator: "&")
        }
        
        return components.url
    }
    
    private static func url(appending path: String, to baseURL: URL) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            return nil
        }
        
        let parts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let relativePath = parts[0].drop { $0 == "/" }
        var basePath = Substring(components.percentEncodedPath)
        
        while basePath.hasSuffix("/") {
            basePath = basePath.dropLast()
        }
        
        guard let encodedPath = relativePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        
        components.percentEncodedPath = String(basePath) + "/" + encodedPath
        components.percentEncodedQuery = parts.count > 1
            ? String(parts[1]).addingPercentEncoding(withAllowedCharacters: Link.allowedCharacters)
            : nil
        
        return components.url
    }
    
    private static let queryComponentAllowedCharacters: CharacterSet = {
        var characters = CharacterSet.urlQueryAllowed
        characters.remove(charactersIn: "&=+#")
        
        return characters
    }()
    
    private static func encodeQueryComponent(_ component: String) -> String {
        return component.addingPercentEncoding(withAllowedCharacters: queryComponentAllowedCharacters) ?? component
    }
}

/// The HTTP response to a `ClientRequest`.
public struct ClientResponse: Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var data: Data
    
    public init(statusCode: Int, headers: [String: String] = [:], data: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }
}
