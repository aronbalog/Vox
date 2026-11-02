import Alamofire
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import Vox
import VoxAlamofire

/// Answers the requests of `StubURLProtocol.session` with `handler` and records them with their
/// bodies, which URL loading moves into a stream.
fileprivate final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response {
        var statusCode = 200
        var headers: [String: String] = [:]
        var body = ""
    }
    
    private struct State {
        var handler: (URLRequest) throws -> Response = { _ in Response() }
        var requests: [(request: URLRequest, body: Data?)] = []
    }
    
    private static let state = Locked(State())
    
    static var handler: (URLRequest) throws -> Response {
        get { state.withLock { $0.handler } }
        set { state.withLock { $0.handler = newValue } }
    }
    
    static var requests: [(request: URLRequest, body: Data?)] {
        get { state.withLock { $0.requests } }
        set { state.withLock { $0.requests = newValue } }
    }
    
    static var session: Session {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        
        return Session(configuration: configuration)
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        let body = StubURLProtocol.body(of: request)
        StubURLProtocol.state.withLock { $0.requests.append((request, body)) }
        
        do {
            let stub = try StubURLProtocol.handler(request)
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

/// Adds an `Authorization` header to every request.
fileprivate struct Authenticator: RequestInterceptor {
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest
        urlRequest.setValue("Bearer token", forHTTPHeaderField: "Authorization")
        
        completion(.success(urlRequest))
    }
}

fileprivate final class Widget: Resource, @unchecked Sendable {
    override class var resourceType: String {
        return "alamofire-widgets"
    }
}

@Suite("Alamofire client", .serialized)
struct AlamofireClientSpec {
    private let baseURL = URL(string: "https://example.com/api/")!
    
    init() {
        StubURLProtocol.requests = []
        StubURLProtocol.handler = { _ in StubURLProtocol.Response() }
    }
    
    @Test("sends the method, URL, headers and body of the request")
    func request() async throws {
        let body = Data(#"{"data":{"type":"alamofire-widgets"}}"#.utf8)
        let request = ClientRequest(method: "PATCH", target: .path("widgets/1"), queryItems: [URLQueryItem(name: "fields[alamofire-widgets]", value: "name")], headers: ["Content-Type": "application/vnd.api+json"], body: body)
        
        _ = try await AlamofireClient(baseURL: baseURL, session: StubURLProtocol.session).execute(request)
        
        let sent = try #require(StubURLProtocol.requests.first)
        #expect(sent.request.httpMethod == "PATCH")
        #expect(sent.request.url?.absoluteString == "https://example.com/api/widgets/1?fields%5Balamofire-widgets%5D=name")
        #expect(sent.request.value(forHTTPHeaderField: "Content-Type") == "application/vnd.api+json")
        #expect(sent.body == body)
    }
    
    @Test("returns responses with any status code")
    func response() async throws {
        StubURLProtocol.handler = { _ in
            StubURLProtocol.Response(statusCode: 404, headers: ["Content-Type": "application/vnd.api+json"], body: #"{"errors":[{"status":"404"}]}"#)
        }
        
        let response = try await AlamofireClient(baseURL: baseURL, session: StubURLProtocol.session).execute(ClientRequest(method: "GET", target: .path("widgets/1")))
        
        #expect(response.statusCode == 404)
        #expect(response.headers["Content-Type"] == "application/vnd.api+json")
        #expect(response.data == Data(#"{"errors":[{"status":"404"}]}"#.utf8))
    }
    
    @Test("responses without content are returned")
    func noContent() async throws {
        StubURLProtocol.handler = { _ in StubURLProtocol.Response(statusCode: 204) }
        
        let response = try await AlamofireClient(baseURL: baseURL, session: StubURLProtocol.session).execute(ClientRequest(method: "DELETE", target: .path("widgets/1")))
        
        #expect(response.statusCode == 204)
        #expect(response.data.isEmpty)
    }
    
    @Test("throws the errors of Alamofire")
    func transportError() async {
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        
        do {
            _ = try await AlamofireClient(baseURL: baseURL, session: StubURLProtocol.session).execute(ClientRequest(method: "GET", target: .path("widgets")))
            Issue.record("Expected AFError")
        } catch let error as AFError {
            #expect((error.underlyingError as? URLError)?.code == .timedOut)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
    
    @Test("requests go through the interceptor")
    func interceptor() async throws {
        let client = AlamofireClient(baseURL: baseURL, session: StubURLProtocol.session, interceptor: Authenticator())
        
        _ = try await client.execute(ClientRequest(method: "GET", target: .path("widgets")))
        
        #expect(StubURLProtocol.requests.first?.request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    }
    
    @Test("data sources fetch documents through it")
    func dataSource() async throws {
        StubURLProtocol.handler = { _ in
            StubURLProtocol.Response(body: #"{ "data": [{ "type": "alamofire-widgets", "id": "1" }] }"#)
        }
        
        let client = JSONAPIClient.Alamofire(baseURL: baseURL, session: StubURLProtocol.session)
        let document = try await DataSource<Widget>(strategy: .path("widgets"), client: client).fetch().result()
        
        #expect(document.data?.map(\.id) == ["1"])
        #expect(StubURLProtocol.requests.first?.request.value(forHTTPHeaderField: "Accept") == "application/vnd.api+json")
    }
}
