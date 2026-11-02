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
    
    /// The URL that paths are appended to and links are resolved against.
    public let baseURL: URL
    public let session: URLSession
    /// Changes requests before they're sent.
    public let adapter: RequestAdapter?
    
    public init(baseURL: URL, session: URLSession = .shared, adapter: RequestAdapter? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.adapter = adapter
    }
    
    public func execute(_ request: ClientRequest) async throws -> ClientResponse {
        var urlRequest = try makeURLRequest(for: request)
        
        if let adapter {
            urlRequest = try await adapter(urlRequest)
        }
        
        return try await send(urlRequest)
    }
    
    /// The URL request for `request`, before the adapter changes it.
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
    
    private func send(_ request: URLRequest) async throws -> ClientResponse {
        let task = CancellableDataTask()
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                task.start(session.dataTask(with: request) { data, response, error in
                    continuation.resume(with: Result {
                        try URLSessionClient.clientResponse(data: data, response: response, error: error)
                    })
                })
            }
        } onCancel: {
            task.cancel()
        }
    }
    
    /// The response for the arguments of a data task's completion handler.
    static func clientResponse(data: Data?, response: URLResponse?, error: (any Error)?) throws -> ClientResponse {
        if let error {
            throw error
        }
        
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        var headers: [String: String] = [:]
        
        for case let (name as String, value as String) in response.allHeaderFields {
            headers[name] = value
        }
        
        return ClientResponse(statusCode: response.statusCode, headers: headers, data: data ?? Data())
    }
}

/// A data task that can be cancelled before it exists.
private final class CancellableDataTask: Sendable {
    private struct State {
        var task: URLSessionDataTask?
        var isCancelled = false
    }
    
    private let state = Locked(State())
    
    func start(_ task: URLSessionDataTask) {
        let isCancelled = state.withLock { state -> Bool in
            state.task = task
            
            return state.isCancelled
        }
        
        task.resume()
        
        if isCancelled {
            task.cancel()
        }
    }
    
    func cancel() {
        let task = state.withLock { state -> URLSessionDataTask? in
            state.isCancelled = true
            
            return state.task
        }
        
        task?.cancel()
    }
}
