import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing

@testable import Vox

/// Answers the requests of `StubURLProtocol.session` with `handler` and records them with their
/// bodies, which URL loading moves into a stream. Requests the handler returns `nil` for are
/// never answered.
fileprivate final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response {
        var statusCode = 200
        var headers: [String: String] = [:]
        var body = ""
    }
    
    private struct State {
        var handler: (URLRequest) throws -> Response? = { _ in Response() }
        var requests: [(request: URLRequest, body: Data?)] = []
    }
    
    private static let state = Locked(State())
    
    static var handler: (URLRequest) throws -> Response? {
        get { state.withLock { $0.handler } }
        set { state.withLock { $0.handler = newValue } }
    }
    
    static var requests: [(request: URLRequest, body: Data?)] {
        get { state.withLock { $0.requests } }
        set { state.withLock { $0.requests = newValue } }
    }
    
    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        
        return URLSession(configuration: configuration)
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override func startLoading() {
        let body = StubURLProtocol.body(of: request)
        StubURLProtocol.state.withLock { $0.requests.append((request, body)) }
        
        do {
            guard let stub = try StubURLProtocol.handler(request) else {
                return
            }
            
            let response = HTTPURLResponse(url: request.url!, statusCode: stub.statusCode, httpVersion: "HTTP/1.1", headerFields: stub.headers)!
            
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
    
    private static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        
        guard let stream = request.httpBodyStream else {
            return nil
        }
        
        stream.open()
        defer { stream.close() }
        
        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            
            guard count > 0 else {
                break
            }
            
            body.append(buffer, count: count)
        }
        
        return body
    }
}

fileprivate final class Gizmo: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "session-gizmos"
    }
}

@Suite("URLSession client", .serialized)
struct URLSessionClientSpec {
    private let baseURL = URL(string: "https://example.com/api/")!
    
    init() {
        ResourceRuntime.register(Gizmo.self)
        StubURLProtocol.requests = []
        StubURLProtocol.handler = { _ in StubURLProtocol.Response() }
    }
    
    private func client(adapter: URLSessionClient.RequestAdapter? = nil) -> URLSessionClient {
        URLSessionClient(baseURL: baseURL, session: StubURLProtocol.session, adapter: adapter)
    }
    
    @Test("sends the method, URL, headers and body of the request")
    func request() async throws {
        let body = Data(#"{"data":{"type":"session-gizmos"}}"#.utf8)
        let request = ClientRequest(method: "POST", target: .path("gizmos"), queryItems: [URLQueryItem(name: "include", value: "parts")], headers: ["Content-Type": "application/vnd.api+json"], body: body)
        
        _ = try await client().execute(request)
        
        let sent = try #require(StubURLProtocol.requests.first)
        #expect(sent.request.httpMethod == "POST")
        #expect(sent.request.url?.absoluteString == "https://example.com/api/gizmos?include=parts")
        #expect(sent.request.value(forHTTPHeaderField: "Content-Type") == "application/vnd.api+json")
        #expect(sent.body == body)
    }
    
    @Test("returns responses with any status code")
    func response() async throws {
        StubURLProtocol.handler = { _ in
            StubURLProtocol.Response(statusCode: 422, headers: ["Content-Type": "application/vnd.api+json"], body: #"{"errors":[]}"#)
        }
        
        let response = try await client().execute(ClientRequest(method: "GET", target: .path("gizmos")))
        
        #expect(response.statusCode == 422)
        #expect(response.headers["Content-Type"] == "application/vnd.api+json")
        #expect(response.data == Data(#"{"errors":[]}"#.utf8))
    }
    
    @Test("throws the errors of the session")
    func transportError() async {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        
        do {
            _ = try await client().execute(ClientRequest(method: "GET", target: .path("gizmos")))
            Issue.record("Expected URLError")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
    
    @Test("links that aren't URLs throw URLError.badURL")
    func badURL() async {
        do {
            _ = try await client().execute(ClientRequest(method: "GET", target: .link("https://example.com:port/gizmos")))
            Issue.record("Expected URLError")
        } catch let error as URLError {
            #expect(error.code == .badURL)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
        
        #expect(StubURLProtocol.requests.isEmpty)
    }
    
    @Test("cancelling the task that awaits a request cancels the request")
    func cancellation() async {
        StubURLProtocol.handler = { _ in nil }
        let client = client()
        
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            
            return try await client.execute(ClientRequest(method: "GET", target: .path("gizmos")))
        }
        
        do {
            _ = try await task.value
            Issue.record("Expected URLError")
        } catch let error as URLError {
            #expect(error.code == .cancelled)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
    
    @Test("responses without a body have empty data")
    func missingBody() throws {
        let response = HTTPURLResponse(url: baseURL, statusCode: 204, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/vnd.api+json"])
        
        let clientResponse = try URLSessionClient.clientResponse(data: nil, response: response, error: nil)
        
        #expect(clientResponse.statusCode == 204)
        #expect(clientResponse.headers == ["Content-Type": "application/vnd.api+json"])
        #expect(clientResponse.data.isEmpty)
    }
    
    @Test("responses that aren't HTTP responses throw URLError.badServerResponse")
    func nonHTTPResponse() {
        let response = URLResponse(url: baseURL, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        
        do {
            _ = try URLSessionClient.clientResponse(data: Data(), response: response, error: nil)
            Issue.record("Expected URLError")
        } catch let error as URLError {
            #expect(error.code == .badServerResponse)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
    
    @Test("the adapter changes requests before they're sent")
    func adapter() async throws {
        let client = client { request in
            var request = request
            request.setValue("Bearer token", forHTTPHeaderField: "Authorization")
            
            return request
        }
        
        _ = try await client.execute(ClientRequest(method: "GET", target: .path("gizmos")))
        
        #expect(StubURLProtocol.requests.first?.request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    }
    
    @Test("links are resolved against the base URL")
    func links() async throws {
        _ = try await client().execute(ClientRequest(method: "GET", target: .link("/gizmos?page[number]=2")))
        
        #expect(StubURLProtocol.requests.first?.request.url?.absoluteString == "https://example.com/gizmos?page%5Bnumber%5D=2")
    }
    
    @Test("data sources fetch documents through it")
    func dataSource() async throws {
        StubURLProtocol.handler = { _ in
            StubURLProtocol.Response(body: #"{ "data": { "type": "session-gizmos", "id": "7" } }"#)
        }
        
        let document = try await DataSource<Gizmo>(strategy: .path("gizmos/<id>"), client: client()).fetch(id: "7").result()
        
        let sent = try #require(StubURLProtocol.requests.first)
        #expect(document.data?.id == "7")
        #expect(sent.request.url?.absoluteString == "https://example.com/api/gizmos/7")
        #expect(sent.request.value(forHTTPHeaderField: "Accept") == "application/vnd.api+json")
    }
}
