import Foundation
import Testing

@testable import Vox

fileprivate final class Story: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "paging-stories"
    }
    
    var title: String?
    var writer: Writer?
}

fileprivate final class Writer: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "paging-writers"
    }
    
    var name: String?
}

fileprivate let firstPage = #"""
{
    "data": [
        { "type": "paging-stories", "id": "s1", "attributes": { "title": "One" }, "relationships": { "writer": { "data": { "type": "paging-writers", "id": "w1" } } } },
        { "type": "paging-stories", "id": "s2", "attributes": { "title": "Two" } }
    ],
    "included": [{ "type": "paging-writers", "id": "w1", "attributes": { "name": "Ann" } }],
    "links": { "next": "https://example.com/stories?page[number]=2" },
    "meta": { "total": 3 }
}
"""#

/// Repeats `s2`, which moved from the first page when a story was added.
fileprivate let secondPage = #"""
{
    "data": [
        { "type": "paging-stories", "id": "s2", "attributes": { "title": "Two, updated" } },
        { "type": "paging-stories", "id": "s3", "attributes": { "title": "Three" }, "relationships": { "writer": { "data": { "type": "paging-writers", "id": "w1" } } } }
    ],
    "included": [{ "type": "paging-writers", "id": "w1", "attributes": { "name": "Ann B." } }],
    "links": {
        "prev": "https://example.com/stories?page[number]=1",
        "next": "https://example.com/stories?page[number]=3"
    },
    "meta": { "total": 4 }
}
"""#

fileprivate let lastPage = #"{ "data": [{ "type": "paging-stories", "id": "s4" }] }"#

fileprivate func response(_ json: String, statusCode: Int = 200) -> Result<ClientResponse, any Error> {
    .success(ClientResponse(statusCode: statusCode, data: Data(json.utf8)))
}

@Suite("Appending pages")
struct PageAppendingSpec {
    init() {
        ResourceRuntime.register(Story.self)
        ResourceRuntime.register(Writer.self)
    }
    
    private func fetchFirstPage(from client: RecordingClient) async throws -> Document<[Story]> {
        try await DataSource<Story>(strategy: .path("stories"), client: client).fetch().result()
    }
    
    @Test("resources the document contains aren't appended again but take the newer values")
    func duplicates() async throws {
        let client = RecordingClient(responses: [response(firstPage), response(secondPage)])
        let document = try await fetchFirstPage(from: client)
        let stories = try #require(document.data)
        let writer = try #require(stories[0]["writer"] as? Writer)
        
        let page = try #require(try await document.appendNext())
        
        #expect(page.old.map(\.id) == ["s1", "s2"])
        #expect(page.new.map(\.id) == ["s3"])
        #expect(page.all.map(\.id) == ["s1", "s2", "s3"])
        #expect(document.data?.map(\.id) == ["s1", "s2", "s3"])
        #expect(document.data?[1] === stories[1])
        #expect(stories[1]["title"] as? String == "Two, updated")
        #expect(document.data?[2]["writer"] as? Writer === writer)
        #expect(writer["name"] as? String == "Ann B.")
    }
    
    @Test("included resources are merged by type and id")
    func included() async throws {
        let client = RecordingClient(responses: [response(firstPage), response(secondPage)])
        let document = try await fetchFirstPage(from: client)
        
        try await document.appendNext()
        
        let included = try #require(document.included)
        #expect(included.count == 1)
        #expect((included.first?["attributes"] as? [String: Any])?["name"] as? String == "Ann B.")
    }
    
    @Test("links and meta are those of the appended page, so the next page follows it")
    func advancing() async throws {
        let client = RecordingClient(responses: [response(firstPage), response(secondPage), response(lastPage)])
        let document = try await fetchFirstPage(from: client)
        
        try await document.appendNext()
        
        #expect(document.links?.next?.href == "https://example.com/stories?page[number]=3")
        #expect(document.meta?["total"] as? Int == 4)
        
        try await document.appendNext()
        
        #expect(document.data?.map(\.id) == ["s1", "s2", "s3", "s4"])
        #expect(document.links == nil)
        #expect(try await document.appendNext() == nil)
        #expect(client.requests.map(\.target) == [
            .path("stories"),
            .link("https://example.com/stories?page[number]=2"),
            .link("https://example.com/stories?page[number]=3")
        ])
    }
    
    @Test("a failed page leaves the document unchanged")
    func failure() async throws {
        let client = RecordingClient(responses: [response(firstPage), response("", statusCode: 503)])
        let document = try await fetchFirstPage(from: client)
        
        do {
            try await document.appendNext()
            Issue.record("Expected JSONAPIError.unacceptableStatusCode")
        } catch JSONAPIError.unacceptableStatusCode(503, _) {
        }
        
        #expect(document.data?.map(\.id) == ["s1", "s2"])
        #expect(document.links?.next?.href == "https://example.com/stories?page[number]=2")
    }
    
    @Test("documents without a next page or a client append nothing")
    func nothingToAppend() async throws {
        let withoutClient = try Deserializer.Collection<Story>().deserialize(data: Data(firstPage.utf8))
        let withoutNext = try await fetchFirstPage(from: RecordingClient(json: lastPage))
        
        #expect(try await withoutClient.appendNext() == nil)
        #expect(try await withoutNext.appendNext() == nil)
        #expect(withoutClient.data?.count == 2)
    }
    
    @Test("the callback variant passes nil on the main actor when there's no next page")
    func callbackWithoutNextPage() async throws {
        let document = try await fetchFirstPage(from: RecordingClient(json: lastPage))
        
        let receivedNil: Bool = await withCheckedContinuation { continuation in
            document.appendNext({ page in
                #expect(isOnMainQueue())
                continuation.resume(returning: page == nil)
            }, { _ in
                continuation.resume(returning: false)
            })
        }
        
        #expect(receivedNil)
    }
}
