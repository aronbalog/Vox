import Foundation
import Testing

@testable import Vox

fileprivate final class Gadget: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "networking-gadgets"
    }
}

fileprivate struct TransportError: Error {}

fileprivate let mediaType = "application/vnd.api+json"
fileprivate let gadgetJSON = #"{ "data": { "type": "networking-gadgets", "id": "1", "attributes": { "name": "Widget" } } }"#

@Suite("Networking")
struct NetworkingSpec {
    init() {
        ResourceRuntime.register(Gadget.self)
    }
    
    private func gadget(id: String? = "1", name: String = "Widget") -> Gadget {
        let gadget = Gadget()
        gadget.id = id
        gadget["name"] = name
        
        return gadget
    }
    
    private func dataSource(_ client: RecordingClient, path: String = "gadgets/<id>") -> DataSource<Gadget> {
        DataSource(strategy: .path(path), client: client)
    }
    
    @Test("requests accept JSON:API documents and declare the media type of their body")
    func headers() async throws {
        let client = RecordingClient()
        
        _ = try await dataSource(client).create(gadget()).result()
        try await dataSource(client).delete(id: "1").result()
        
        try #require(client.requests.count == 2)
        #expect(client.requests[0].headers == ["Accept": mediaType, "Content-Type": mediaType])
        #expect(client.requests[1].headers == ["Accept": mediaType])
        #expect(client.requests[1].body == nil)
    }
    
    @Test("custom headers are added and replace the JSON:API ones")
    func customHeaders() async throws {
        let client = RecordingClient(json: gadgetJSON)
        let atomic = mediaType + #"; ext="https://jsonapi.org/ext/atomic""#
        
        _ = try await dataSource(client)
            .fetch(id: "1")
            .headers(["Authorization": "Bearer token"])
            .headers(["accept": atomic])
            .result()
        _ = try await dataSource(client)
            .update(gadget())
            .headers(["Content-Type": atomic])
            .result()
        
        try #require(client.requests.count == 2)
        #expect(client.requests[0].headers == ["accept": atomic, "Authorization": "Bearer token"])
        #expect(client.requests[1].headers == ["Accept": mediaType, "Content-Type": atomic])
    }
    
    @Test("the resource is sent as the request document")
    func body() async throws {
        let client = RecordingClient()
        
        _ = try await dataSource(client).update(gadget(name: "Gizmo")).result()
        
        let body = try #require(client.requests.first?.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let data = try #require(json["data"] as? [String: Any])
        
        #expect(data["type"] as? String == "networking-gadgets")
        #expect(data["id"] as? String == "1")
        #expect((data["attributes"] as? [String: Any])?["name"] as? String == "Gizmo")
    }
    
    @Test("a resource that can't be serialized isn't sent")
    func serializationFailure() async {
        let client = RecordingClient()
        let gadget = gadget()
        gadget["blob"] = NSObject()
        
        do {
            _ = try await dataSource(client).update(gadget).result()
            Issue.record("Expected JSONAPIError.serialization")
        } catch JSONAPIError.serialization {
            #expect(client.requests.isEmpty)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
    
    @Test("updated resources must have an id", arguments: [nil, "local"])
    func updateWithoutID(lid: String?) async {
        let client = RecordingClient()
        let gadget = gadget(id: nil)
        gadget.lid = lid
        
        do {
            _ = try await dataSource(client).update(gadget).result()
            Issue.record("Expected JSONAPIError.serialization")
        } catch JSONAPIError.serialization {
            #expect(client.requests.isEmpty)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
    
    @Test("user info is passed to the client")
    func userInfo() async throws {
        let client = RecordingClient()
        
        try await dataSource(client).delete(id: "1").userInfo(["retry": 2]).userInfo(["tag": "delete"]).result()
        
        let userInfo = try #require(client.requests.first?.userInfo)
        #expect(userInfo["retry"] as? Int == 2)
        #expect(userInfo["tag"] as? String == "delete")
    }
    
    @Test("headers and user info added again replace the earlier values")
    func replacedHeadersAndUserInfo() async throws {
        let client = RecordingClient()
        
        try await dataSource(client).delete(id: "1")
            .headers(["Authorization": "Bearer old"])
            .headers(["Authorization": "Bearer new"])
            .userInfo(["retry": 1])
            .userInfo(["retry": 2])
            .result()
        
        let request = try #require(client.requests.first)
        #expect(request.headers["Authorization"] == "Bearer new")
        #expect(request.userInfo["retry"] as? Int == 2)
    }
    
    @Test("the headers and user info of fetch requests can be read and changed")
    func fetchRequestHeadersAndUserInfo() async throws {
        let client = RecordingClient(json: gadgetJSON)
        var request = dataSource(client).fetch(id: "1").userInfo(["tag": "fetch"])
        request.headers["Authorization"] = "Bearer token"
        request.userInfo["retry"] = 2
        
        #expect(request.headers == ["Authorization": "Bearer token"])
        #expect(request.userInfo["tag"] as? String == "fetch")
        
        _ = try await request.result()
        
        let sent = try #require(client.requests.first)
        #expect(sent.headers["Authorization"] == "Bearer token")
        #expect(sent.userInfo["retry"] as? Int == 2)
        #expect(sent.userInfo["tag"] as? String == "fetch")
    }
    
    @Test("created and updated resources are nil when the response has no content")
    func noContent() async throws {
        let client = RecordingClient(response: ClientResponse(statusCode: 204, data: Data()))
        
        let created = try await dataSource(client).create(gadget()).result()
        let updated = try await dataSource(client).update(gadget()).result()
        
        #expect(created == nil)
        #expect(updated == nil)
    }
    
    @Test("created resources are decoded from the response document")
    func createdDocument() async throws {
        let client = RecordingClient(statusCode: 201, json: gadgetJSON)
        
        let document = try await dataSource(client, path: "gadgets").create(gadget(id: nil)).result()
        
        let gadget = try #require(document?.data)
        #expect(gadget.id == "1")
        #expect(gadget["name"] as? String == "Widget")
    }
    
    @Test("fetches without a response document fail")
    func fetchWithoutContent() async {
        let client = RecordingClient(response: ClientResponse(statusCode: 200, data: Data()))
        
        do {
            _ = try await dataSource(client).fetch(id: "1").result()
            Issue.record("Expected JSONAPIError.invalidDocument")
        } catch JSONAPIError.invalidDocument(let reason) {
            #expect(reason == "The response has no content.")
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
    
    @Test("error responses with error objects throw them")
    func errorObjects() async {
        let client = RecordingClient(statusCode: 404, json: #"{ "errors": [{ "status": "404", "title": "Not Found" }] }"#)
        
        do {
            _ = try await dataSource(client).fetch(id: "1").result()
            Issue.record("Expected JSONAPIError.API")
        } catch JSONAPIError.API(let errors) {
            #expect(errors.map(\.title) == ["Not Found"])
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
    
    @Test("error responses without error objects throw the status code and body", arguments: [
        (404, ""),
        (500, "Internal Server Error"),
        (503, #"{ "data": null }"#),
        (302, "")
    ])
    func unacceptableStatusCodes(statusCode: Int, body: String) async {
        let client = RecordingClient(statusCode: statusCode, json: body)
        
        do {
            try await dataSource(client).delete(id: "1").result()
            Issue.record("Expected JSONAPIError.unacceptableStatusCode")
        } catch JSONAPIError.unacceptableStatusCode(let receivedStatusCode, let receivedBody) {
            #expect(receivedStatusCode == statusCode)
            #expect(receivedBody == Data(body.utf8))
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
    
    @Test("errors of the client are thrown as they are")
    func transportErrors() async {
        let client = RecordingClient(error: TransportError())
        
        do {
            _ = try await dataSource(client).fetch().result()
            Issue.record("Expected TransportError")
        } catch is TransportError {
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
    
    @Test("callbacks are called on the main actor")
    func callbacks() async throws {
        let client = RecordingClient(json: gadgetJSON)
        let request = dataSource(client).fetch(id: "1")
        
        let name: String? = try await withCheckedThrowingContinuation { continuation in
            request.result({ document in
                #expect(isOnMainQueue())
                continuation.resume(returning: document.data?["name"] as? String)
            }, { error in
                continuation.resume(throwing: error)
            })
        }
        
        #expect(name == "Widget")
    }
    
    @Test("failures are passed to the failure callback on the main actor")
    func failureCallback() async {
        let client = RecordingClient(error: TransportError())
        let request = dataSource(client).delete(id: "1")
        
        let error: (any Error)? = await withCheckedContinuation { continuation in
            request.result({
                continuation.resume(returning: nil)
            }, { error in
                #expect(isOnMainQueue())
                continuation.resume(returning: error)
            })
        }
        
        #expect(error is TransportError)
    }
    
    @Test("failures of requests with an output are passed to the failure callback on the main actor")
    func outputFailureCallback() async {
        let client = RecordingClient(error: TransportError())
        let request = dataSource(client).fetch(id: "1")
        
        let error: (any Error)? = await withCheckedContinuation { continuation in
            request.result({ _ in
                continuation.resume(returning: nil)
            }, { error in
                #expect(isOnMainQueue())
                continuation.resume(returning: error)
            })
        }
        
        #expect(error is TransportError)
    }
    
    @Test("requests without an output call the success callback on the main actor")
    func successCallbackWithoutOutput() async {
        let client = RecordingClient()
        let request = dataSource(client).delete(id: "1")
        
        let succeeded: Bool = await withCheckedContinuation { continuation in
            request.result({
                #expect(isOnMainQueue())
                continuation.resume(returning: true)
            }, { _ in
                continuation.resume(returning: false)
            })
        }
        
        #expect(succeeded)
    }
}

@Suite("Client request URLs")
struct ClientRequestURLSpec {
    private let baseURL = URL(string: "https://example.com/api/")!
    
    private func url(_ target: ClientRequest.Target, queryItems: [URLQueryItem] = [], relativeTo baseURL: URL? = nil) -> String? {
        ClientRequest(method: "GET", target: target, queryItems: queryItems).url(relativeTo: baseURL ?? self.baseURL)?.absoluteString
    }
    
    @Test("paths are appended to the base URL", arguments: [
        ("articles", "https://example.com/api/articles"),
        ("/articles/1", "https://example.com/api/articles/1"),
        ("articles/1/relationships/author", "https://example.com/api/articles/1/relationships/author"),
        ("articles/hello world", "https://example.com/api/articles/hello%20world"),
        ("articles?page[size]=1", "https://example.com/api/articles?page%5Bsize%5D=1")
    ])
    func paths(path: String, expected: String) {
        #expect(url(.path(path)) == expected)
    }
    
    @Test("paths are appended to base URLs without a trailing slash")
    func baseURLWithoutTrailingSlash() {
        #expect(url(.path("articles"), relativeTo: URL(string: "https://example.com/api")!) == "https://example.com/api/articles")
        #expect(url(.path("articles"), relativeTo: URL(string: "https://example.com")!) == "https://example.com/articles")
    }
    
    @Test("links are resolved against the base URL", arguments: [
        ("https://other.example.com/articles?page[number]=2", "https://other.example.com/articles?page%5Bnumber%5D=2"),
        ("/articles?page%5Bnumber%5D=2", "https://example.com/articles?page%5Bnumber%5D=2"),
        ("articles?page[cursor]=abc", "https://example.com/api/articles?page%5Bcursor%5D=abc")
    ])
    func links(link: String, expected: String) {
        #expect(url(.link(link)) == expected)
    }
    
    @Test("query items are encoded and appended to the query of the target")
    func queryItems() {
        let queryItems = [
            URLQueryItem(name: "filter[name]", value: "a&b=c+d"),
            URLQueryItem(name: "include", value: "author,comments.author"),
            URLQueryItem(name: "flag", value: nil)
        ]
        
        #expect(url(.path("articles"), queryItems: queryItems) == "https://example.com/api/articles?filter%5Bname%5D=a%26b%3Dc%2Bd&include=author,comments.author&flag")
        #expect(url(.link("https://example.com/articles?page[number]=2"), queryItems: [queryItems[2]]) == "https://example.com/articles?page%5Bnumber%5D=2&flag")
    }
    
    @Test("links that aren't URLs, even when percent-encoded, have no URL")
    func invalidLinks() {
        #expect(url(.link("https://example.com:port/articles")) == nil)
        #expect(url(.link("https://example.com:port/articles"), queryItems: [URLQueryItem(name: "flag", value: nil)]) == nil)
    }
}

@Suite("Page links")
struct PageLinkSpec {
    init() {
        ResourceRuntime.register(Gadget.self)
    }
    
    private let json = #"""
    {
        "data": [{ "type": "networking-gadgets", "id": "1" }],
        "links": { "next": "https://example.com/gadgets?page[cursor]=abc", "prev": null }
    }
    """#
    
    @Test("page requests follow the links of the document")
    func following() async throws {
        let client = RecordingClient(json: json)
        let document = try await DataSource<Gadget>(strategy: .path("gadgets"), client: client).fetch().result()
        
        _ = try await #require(document.next).result()
        
        #expect(client.requests.last?.target == .link("https://example.com/gadgets?page[cursor]=abc"))
        #expect(client.requests.last?.method == "GET")
        #expect(document.previous == nil)
        #expect(document.first == nil)
    }
    
    @Test("the last and the current page are requested at their links")
    func lastAndReload() async throws {
        let client = RecordingClient(json: #"""
        {
            "data": [{ "type": "networking-gadgets", "id": "1" }],
            "links": { "self": "https://example.com/gadgets?page[number]=2", "last": "https://example.com/gadgets?page[number]=9" }
        }
        """#)
        let document = try await DataSource<Gadget>(strategy: .path("gadgets"), client: client).fetch().result()
        
        _ = try await #require(document.last).result()
        _ = try await #require(document.reload).result()
        
        #expect(client.requests.map(\.target) == [
            .path("gadgets"),
            .link("https://example.com/gadgets?page[number]=9"),
            .link("https://example.com/gadgets?page[number]=2")
        ])
    }
    
    @Test("documents decoded without a client have no page requests")
    func withoutClient() throws {
        let document = try Deserializer.Collection<Gadget>().deserialize(data: Data(json.utf8))
        
        #expect(document.links?.next != nil)
        #expect(document.next == nil)
    }
}
