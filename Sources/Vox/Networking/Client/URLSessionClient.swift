import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A client that sends requests with a `URLSession`.
///
/// ```swift
/// let client = URLSessionClient(baseURL: URL(string: "https://example.com/api/")!)
/// let articles = DataSource<Article>(strategy: .path("articles/<id>"), client: client)
/// ```
///
/// The paths of data sources are appended to `baseURL`, and the links of documents are resolved
/// against it. Cancelling the task that awaits a request cancels the request.
public struct URLSessionClient: Client {
    /// Changes a request before it's sent, for example to add authentication.
    public typealias RequestAdapter = @Sendable (URLRequest) async throws -> URLRequest
    
    public let baseURL: URL
    public let session: URLSession
    public let adapter: RequestAdapter?
    
    public init(baseURL: URL, session: URLSession = .shared, adapter: RequestAdapter? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.adapter = adapter
    }
    
    public func execute(_ request: ClientRequest) async throws -> ClientResponse {
        var urlRequest = try makeURLRequest(for: request)
        
        if let adapter = adapter {
            urlRequest = try await adapter(urlRequest)
        }
        
        return try await send(urlRequest)
    }
    
    /// The URL request for `request`, before the adapter changes it.
    ///
    /// - Throws: `URLError.badURL` when the target of the request isn't a valid URL.
    public func makeURLRequest(for request: ClientRequest) throws -> URLRequest {
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
    
    private func send(_ request: URLRequest) async throws -> ClientResponse {
        let task = CancellableDataTask()
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                task.start(session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let response = response as? HTTPURLResponse {
                        continuation.resume(returning: ClientResponse(statusCode: response.statusCode, headers: URLSessionClient.headers(of: response), data: data ?? Data()))
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                })
            }
        } onCancel: {
            task.cancel()
        }
    }
    
    private static func headers(of response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        
        for case let (name as String, value) in response.allHeaderFields {
            headers[name] = value as? String ?? String(describing: value)
        }
        
        return headers
    }
}

/// A data task that can be cancelled before it exists.
private final class CancellableDataTask: @unchecked Sendable {
    private let lock = Lock()
    private var task: URLSessionDataTask?
    private var isCancelled = false
    
    func start(_ task: URLSessionDataTask) {
        let isCancelled = lock.withLock { () -> Bool in
            self.task = task
            
            return self.isCancelled
        }
        
        task.resume()
        
        if isCancelled {
            task.cancel()
        }
    }
    
    func cancel() {
        let task = lock.withLock { () -> URLSessionDataTask? in
            isCancelled = true
            
            return self.task
        }
        
        task?.cancel()
    }
}
