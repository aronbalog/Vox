import Foundation
import Testing

@testable import Vox

fileprivate final class Post: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "relationship-posts"
    }
    
    override class var codingKeys: [String: String] {
        ["coAuthors": "co-authors"]
    }
    
    var author: Person?
    var coAuthors: [Person]?
    var tags: [Tag]?
}

fileprivate final class Person: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "relationship-people"
    }
    
    var name: String?
}

fileprivate final class Tag: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "relationship-tags"
    }
}

fileprivate struct ResourceRouter: Router {
    func fetch(id: String, type: Resource.Type) -> String {
        "routed/\(type.resourceType)/\(id)"
    }
    
    func fetch(type: Resource.Type) -> String {
        fatalError()
    }
    
    func create(resource: Resource) -> String {
        fatalError()
    }
    
    func update(resource: Resource) -> String {
        fatalError()
    }
    
    func delete(id: String, type: Resource.Type) -> String {
        fatalError()
    }
}

fileprivate let linkedPostJSON = #"""
{
    "data": {
        "type": "relationship-posts",
        "id": "1",
        "relationships": {
            "author": {
                "links": {
                    "self": "https://example.com/posts/1/relationships/author",
                    "related": "https://example.com/posts/1/author"
                }
            },
            "tags": {
                "links": { "related": "https://example.com/posts/1/tags" }
            }
        }
    }
}
"""#

fileprivate let personJSON = #"{ "data": { "type": "relationship-people", "id": "9", "attributes": { "name": "Ann" } } }"#
fileprivate let tagsJSON = #"{ "data": [{ "type": "relationship-tags", "id": "t1" }, { "type": "relationship-tags", "id": "t2" }] }"#

@Suite("Relationship requests")
struct RelationshipRequestSpec {
    init() {
        ResourceRuntime.register(Post.self)
        ResourceRuntime.register(Person.self)
        ResourceRuntime.register(Tag.self)
    }
    
    private func linkedPost() throws -> Post {
        try #require(try Deserializer.Single<Post>().deserialize(data: Data(linkedPostJSON.utf8)).data)
    }
    
    private func post(id: String? = "1") -> Post {
        let post = Post()
        post.id = id
        
        return post
    }
    
    private func resource<T: Resource>(_ type: T.Type, id: String) -> T {
        let resource = T()
        resource.id = id
        
        return resource
    }
    
    /// The `data` member of the body of `request`.
    private func data(of request: ClientRequest?) throws -> Any? {
        let body = try #require(request?.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        
        return json["data"]
    }
    
    @Test("related resources are fetched at the related link")
    func relatedLink() async throws {
        let client = RecordingClient(json: personJSON)
        let dataSource = DataSource<Post>(strategy: .path("posts/<id>"), client: client)
        
        let document = try await dataSource.fetchRelated("author", of: try linkedPost(), as: Person.self).result()
        
        #expect(document.data?.id == "9")
        #expect(document.data?["name"] as? String == "Ann")
        #expect(client.requests.first?.method == "GET")
        #expect(client.requests.first?.target == .link("https://example.com/posts/1/author"))
    }
    
    @Test("related collections can be sorted and paginated")
    func relatedCollection() async throws {
        let client = RecordingClient(json: tagsJSON)
        let dataSource = DataSource<Post>(strategy: .path("posts/<id>"), client: client)
        
        let document = try await dataSource
            .fetchRelated("tags", of: try linkedPost(), as: [Tag].self)
            .sort([.ascending("name")])
            .paginate(Pagination.PageBased(number: 2, size: 10))
            .result()
        
        #expect(document.data?.map(\.id) == ["t1", "t2"])
        #expect(client.requests.first?.target == .link("https://example.com/posts/1/tags"))
        #expect(client.requests.first?.queryItems == [
            URLQueryItem(name: "sort", value: "name"),
            URLQueryItem(name: "page[number]", value: "2"),
            URLQueryItem(name: "page[size]", value: "10")
        ])
    }
    
    @Test("relationship linkage is fetched at the self link")
    func relationshipLink() async throws {
        let client = RecordingClient(json: #"{ "data": { "type": "relationship-people", "id": "9" }, "links": { "self": "https://example.com/posts/1/relationships/author" } }"#)
        let dataSource = DataSource<Post>(strategy: .path("posts/<id>"), client: client)
        
        let document = try await dataSource.fetchRelationship("author", of: try linkedPost(), as: Person.self).result()
        
        #expect(document.data?.id == "9")
        #expect(document.data?["name"] == nil)
        #expect(client.requests.first?.target == .link("https://example.com/posts/1/relationships/author"))
    }
    
    @Test("empty to-one relationships give no resource")
    func emptyToOne() async throws {
        let client = RecordingClient(json: #"{ "data": null }"#)
        let dataSource = DataSource<Post>(strategy: .path("posts/<id>"), client: client)
        
        let document = try await dataSource.fetchRelated("author", of: post(), as: Person.self).result()
        
        #expect(document.data == nil)
    }
    
    @Test("paths are built from the path of the resource without links", arguments: [
        ("posts/<id>", "posts/1"),
        ("posts/<id>/", "posts/1"),
        ("posts", "posts/1"),
        ("<type>/<id>", "relationship-posts/1")
    ])
    func builtPaths(path: String, resourcePath: String) async throws {
        let client = RecordingClient(json: tagsJSON)
        let dataSource = DataSource<Post>(strategy: .path(path), client: client)
        
        _ = try await dataSource.fetchRelated("tags", of: post(), as: [Tag].self).result()
        _ = try await dataSource.fetchRelationship("tags", of: post(), as: [Tag].self).result()
        try await dataSource.addToRelationship("tags", of: post(), [resource(Tag.self, id: "t1")]).result()
        
        #expect(client.requests.map(\.target) == [
            .path(resourcePath + "/tags"),
            .path(resourcePath + "/relationships/tags"),
            .path(resourcePath + "/relationships/tags")
        ])
    }
    
    @Test("routers build the paths, by default from the path of the resource")
    func routedPaths() async throws {
        let client = RecordingClient(json: tagsJSON)
        let dataSource = DataSource<Post>(strategy: .router(ResourceRouter()), client: client)
        
        _ = try await dataSource.fetchRelated("tags", of: post(), as: [Tag].self).result()
        _ = try await dataSource.fetchRelationship("tags", of: post(), as: [Tag].self).result()
        
        #expect(client.requests.map(\.target) == [
            .path("routed/relationship-posts/1/tags"),
            .path("routed/relationship-posts/1/relationships/tags")
        ])
    }
    
    @Test("property names are mapped to relationship names")
    func memberNames() async throws {
        let client = RecordingClient(json: #"{ "data": [] }"#)
        let dataSource = DataSource<Post>(strategy: .path("posts/<id>"), client: client)
        
        _ = try await dataSource.fetchRelated("coAuthors", of: post(), as: [Person].self).result()
        _ = try await dataSource.fetchRelated("co-authors", of: post(), as: [Person].self).result()
        
        #expect(client.requests.map(\.target) == [.path("posts/1/co-authors"), .path("posts/1/co-authors")])
    }
    
    @Test("relationships of resources without links and id fail before anything is sent")
    func withoutLinkAndID() async {
        let client = RecordingClient(json: personJSON)
        let dataSource = DataSource<Post>(strategy: .path("posts/<id>"), client: client)
        
        do {
            _ = try await dataSource.fetchRelated("author", of: post(id: nil), as: Person.self).result()
            Issue.record("Expected JSONAPIError.serialization")
        } catch JSONAPIError.serialization(let reason) {
            #expect(reason.contains("\"author\" has no related link"))
            #expect(client.requests.isEmpty)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
    
    @Test("to-one relationships are set and emptied")
    func updateToOne() async throws {
        let client = RecordingClient()
        let dataSource = DataSource<Post>(strategy: .path("posts/<id>"), client: client)
        
        try await dataSource.updateRelationship("author", of: try linkedPost(), to: resource(Person.self, id: "9")).result()
        try await dataSource.updateRelationship("author", of: try linkedPost(), to: nil).result()
        
        try #require(client.requests.count == 2)
        #expect(client.requests.map(\.method) == ["PATCH", "PATCH"])
        #expect(client.requests[0].target == .link("https://example.com/posts/1/relationships/author"))
        #expect(client.requests[0].headers["Content-Type"] == "application/vnd.api+json")
        
        let identifier = try #require(try data(of: client.requests[0]) as? [String: Any])
        #expect(identifier["type"] as? String == "relationship-people")
        #expect(identifier["id"] as? String == "9")
        #expect(try data(of: client.requests[1]) is NSNull)
    }
    
    @Test("to-many relationships are replaced, added to and removed from")
    func updateToMany() async throws {
        let client = RecordingClient()
        let dataSource = DataSource<Post>(strategy: .path("posts/<id>"), client: client)
        let tags = [resource(Tag.self, id: "t1"), resource(Tag.self, id: "t2")]
        let local = Tag()
        local.lid = "local-1"
        
        try await dataSource.updateRelationship("tags", of: post(), to: tags).result()
        try await dataSource.addToRelationship("tags", of: post(), [local]).result()
        try await dataSource.removeFromRelationship("tags", of: post(), [tags[0]]).result()
        try await dataSource.updateRelationship("tags", of: post(), to: []).result()
        
        #expect(client.requests.map(\.method) == ["PATCH", "POST", "DELETE", "PATCH"])
        #expect(Set(client.requests.map(\.target)).count == 1)
        
        let identifiers = try client.requests.map { request in
            try #require(try data(of: request) as? [[String: Any]]).map { identifier in
                (identifier["id"] ?? identifier["lid"]) as? String
            }
        }
        
        #expect(identifiers == [["t1", "t2"], ["local-1"], ["t1"], []])
    }
    
    @Test("related resources without id or lid can't be sent")
    func relatedWithoutIdentifier() async {
        let client = RecordingClient()
        let dataSource = DataSource<Post>(strategy: .path("posts/<id>"), client: client)
        
        do {
            try await dataSource.addToRelationship("tags", of: post(), [Tag()]).result()
            Issue.record("Expected JSONAPIError.serialization")
        } catch JSONAPIError.serialization(let reason) {
            #expect(reason.contains("relationship-tags"))
            #expect(client.requests.isEmpty)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
}
