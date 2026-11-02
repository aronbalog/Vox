import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Alamofire
#if SWIFT_PACKAGE
import Vox
#endif

/// A client that sends requests with an Alamofire `Session`.
///
/// ```swift
/// let client = AlamofireClient(baseURL: URL(string: "https://example.com/api/")!)
/// let articles = DataSource<Article>(strategy: .path("articles/<id>"), client: client)
/// ```
///
/// The paths of data sources are appended to `baseURL`, and the links of documents are resolved
/// against it. Requests go through `session` and `interceptor`, so interceptors can add
/// authentication or retry requests, and event monitors see every request. Cancelling the task
/// that awaits a request cancels the request.
///
/// Responses with any status code are returned to the data source, which maps them to results
/// and errors. Errors of Alamofire are thrown as they are.
public struct AlamofireClient: Client {
    /// The URL that paths are appended to and links are resolved against.
    public let baseURL: URL
    public let session: Session
    /// Adapts and retries the requests, in addition to the interceptor of `session`.
    public let interceptor: (any RequestInterceptor)?
    
    public init(baseURL: URL, session: Session = .default, interceptor: (any RequestInterceptor)? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.interceptor = interceptor
    }
    
    public func execute(_ request: ClientRequest) async throws -> ClientResponse {
        let dataRequest = session.request(try makeURLRequest(for: request), interceptor: interceptor)
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                dataRequest.response(queue: .global()) { response in
                    if let error = response.error {
                        continuation.resume(throwing: error)
                    } else if let httpResponse = response.response {
                        continuation.resume(returning: ClientResponse(statusCode: httpResponse.statusCode, headers: httpResponse.headers.dictionary, data: response.data ?? Data()))
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
            }
        } onCancel: {
            dataRequest.cancel()
        }
    }
    
    /// The URL request for `request`, before interceptors change it.
    ///
    /// - Throws: `URLError.badURL` when the target of the request isn't a valid URL.
    public func makeURLRequest(for request: ClientRequest) throws(URLError) -> URLRequest {
        guard let url = request.url(relativeTo: baseURL) else {
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        
        return urlRequest
    }
}

extension JSONAPIClient {
    /// A client that sends requests with Alamofire.
    public typealias Alamofire = AlamofireClient
}
