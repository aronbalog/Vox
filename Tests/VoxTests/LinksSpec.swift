import Foundation
import Testing

@testable import Vox

fileprivate final class Post: Resource {
    override class var resourceType: String {
        return "links-posts"
    }
    
    override class var codingKeys: [String: String] {
        return ["writer": "author"]
    }
    
    var title: String?
    var writer: Writer?
    var comments: [Comment]?
}

fileprivate final class Writer: Resource {
    override class var resourceType: String {
        return "links-writers"
    }
}

fileprivate final class Comment: Resource {
    override class var resourceType: String {
        return "links-comments"
    }
    
    var body: String?
    var post: Post?
}

fileprivate let postsDocument = Data("""
{
    "links": {
        "self": "https://example.com/posts?page[number]=2",
        "next": {
            "href": "/posts?page[number]=3",
            "title": "Next",
            "hreflang": "en",
            "meta": { "count": 10 },
            "describedby": "https://example.com/schema"
        },
        "prev": null
    },
    "data": [{
        "type": "links-posts",
        "id": "1",
        "links": { "self": "/posts/1" },
        "relationships": {
            "author": {
                "links": { "self": "/posts/1/relationships/author", "related": "/posts/1/author" },
                "data": { "type": "links-writers", "id": "9" },
                "meta": { "since": 2020 }
            },
            "comments": {
                "links": { "related": { "href": "/posts/1/comments", "meta": { "count": 2 } } }
            }
        }
    }]
}
""".utf8)

@Suite("Links and local identifiers")
struct LinksSpec {
    init() {
        ResourceRuntime.register(Post.self)
        ResourceRuntime.register(Writer.self)
        ResourceRuntime.register(Comment.self)
    }
    
    private func decodePosts() throws -> Document<[Post]> {
        return try Deserializer.Collection<Post>().deserialize(data: postsDocument)
    }
    
    @Test("document links are decoded from strings and link objects")
    func documentLinks() throws {
        let links = try #require(try decodePosts().links)
        
        #expect(links.all.count == 2)
        #expect(links.prev == nil)
        
        let selfLink = try #require(links.selfLink)
        #expect(selfLink.href == "https://example.com/posts?page[number]=2")
        
        let selfURL = try #require(selfLink.url)
        let queryItems = URLComponents(url: selfURL, resolvingAgainstBaseURL: false)?.queryItems
        #expect(queryItems == [URLQueryItem(name: "page[number]", value: "2")])
        
        let next = try #require(links.next)
        #expect(next.href == "/posts?page[number]=3")
        #expect(next.url?.path == "/posts")
        #expect(next.title == "Next")
        #expect(next.hreflang == ["en"])
        #expect(next.meta?["count"] as? Int == 10)
        #expect(next.describedby?.href == "https://example.com/schema")
    }
    
    @Test("resource links are decoded")
    func resourceLinks() throws {
        let post = try #require(try decodePosts().data?.first)
        
        #expect(post.links?.selfLink?.href == "/posts/1")
        #expect(Post().links == nil)
    }
    
    @Test("relationship links and meta are available by property and member name")
    func relationshipLinks() throws {
        let post = try #require(try decodePosts().data?.first)
        
        let author = try #require(post.relationship(named: "writer"))
        #expect(author.hasData)
        #expect(author.links?.selfLink?.href == "/posts/1/relationships/author")
        #expect(author.links?.related?.href == "/posts/1/author")
        #expect(author.meta?["since"] as? Int == 2020)
        #expect(post.relationship(named: "author")?.links?.related?.href == "/posts/1/author")
        
        let comments = try #require(post.relationship(named: "comments"))
        #expect(!comments.hasData)
        #expect(comments.links?.related?.meta?["count"] as? Int == 2)
        #expect(post["comments"] == nil)
        
        #expect(post.relationship(named: "tags") == nil)
    }
    
    @Test("removing the linkage of a relationship keeps its links")
    func removingLinkageKeepsLinks() throws {
        let post = try #require(try decodePosts().data?.first)
        post["writer"] = nil
        
        let author = try #require(post.relationship(named: "writer"))
        #expect(!author.hasData)
        #expect(author.links?.related?.href == "/posts/1/author")
        #expect(post.relationships["author"] == nil)
    }
    
    @Test("error links are decoded")
    func errorLinks() throws {
        let json = #"{ "errors": [{ "links": { "about": "https://example.com/errors/1", "type": "https://example.com/errors/validation" } }] }"#
        
        do {
            _ = try Deserializer.Single<Post>().deserialize(data: Data(json.utf8))
            Issue.record("Expected JSONAPIError.API")
        } catch JSONAPIError.API(let errors) {
            #expect(errors.first?.links?.about?.href == "https://example.com/errors/1")
            #expect(errors.first?.links?.type?.href == "https://example.com/errors/validation")
        }
    }
    
    @Test("resource identifiers with lid resolve to resources with that lid")
    func decodingLocalIdentifiers() throws {
        let json = """
        {
            "data": {
                "type": "links-posts",
                "lid": "post",
                "relationships": { "comments": { "data": [{ "type": "links-comments", "lid": "comment" }] } }
            },
            "included": [{
                "type": "links-comments",
                "lid": "comment",
                "attributes": { "body": "Hi" },
                "relationships": { "post": { "data": { "type": "links-posts", "lid": "post" } } }
            }]
        }
        """
        let post = try #require(try Deserializer.Single<Post>().deserialize(data: Data(json.utf8)).data)
        
        #expect(post.id == nil)
        #expect(post.lid == "post")
        
        let comment = try #require((post["comments"] as? [Comment])?.first)
        #expect(comment["body"] as? String == "Hi")
        #expect(comment["post"] as? Post === post)
    }
    
    @Test("resources without id are referenced by lid")
    func serializingLocalIdentifiers() throws {
        let post = Post()
        post.lid = "post"
        
        let comment = Comment()
        comment.lid = "comment"
        comment["post"] = post
        
        let data = try #require(try comment.documentDictionary()["data"] as? [String: Any])
        #expect(data["lid"] as? String == "comment")
        #expect(data["id"] == nil)
        
        let relationship = try #require((data["relationships"] as? [String: Any])?["post"] as? [String: Any])
        #expect(relationship["data"] as? [String: String] == ["type": "links-posts", "lid": "post"])
        
        post.id = "1"
        #expect((comment.relationships["post"] as? [String: Any])?["data"] as? [String: String] == ["type": "links-posts", "id": "1"])
        
        let collection = try [post, comment].documentDictionary()
        #expect((collection["data"] as? [[String: Any]])?.count == 2)
    }
}
