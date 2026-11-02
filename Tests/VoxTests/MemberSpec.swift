import Foundation
import Testing

@testable import Vox

fileprivate final class Article: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "member-articles"
    }
    
    @Member var title: String?
    @Member var published: Date?
    @Member var author: Person?
    @Member var count: Int = 0
}

fileprivate final class Person: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "member-people"
    }
    
    @Member var name: String?
}

fileprivate final class Review: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "member-reviews"
    }
    
    override class var codingKeys: [String: String] {
        ["headline": "title", "kind": "type", "writer": "author"]
    }
    
    @Member var headline: String?
    @Member var kind: String?
    @Member var author: String?
    @Member var writer: Person?
}

@Suite("JSON members")
struct MemberSpec {
    @Test("members read and write the resource JSON")
    func readAndWrite() throws {
        let article = Article()
        let author = Person()
        author.id = "1"
        author.name = "Ann"
        let published = Date(timeIntervalSince1970: 1_700_000_000)
        
        article.title = "Dune"
        article.published = published
        article.author = author
        article.count = 2
        
        #expect(article.title == "Dune")
        #expect(article["title"] as? String == "Dune")
        #expect(article.published == published)
        #expect(article.author === author)
        #expect(article.count == 2)
        #expect(try article.documentDictionary()["data"] != nil)
    }
    
    @Test("a missing member reads its fallback")
    func fallback() {
        let article = Article()
        
        #expect(article.title == nil)
        #expect(article.count == 0)
        
        article["title"] = 1
        #expect(article.title == nil)
    }
    
    @Test("members are cast like JSON values")
    func casting() {
        let date = ResourceRuntime.memberValue("2023-11-14T22:13:20Z", fallback: Date?.none)
        
        #expect(date == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(ResourceRuntime.memberValue(1, fallback: "fallback") == "fallback")
    }
    
    @Test("coding keys map member names")
    func codingKeys() throws {
        let review = Review()
        review.headline = "Great"
        
        let data = try #require(try review.documentDictionary()["data"] as? [String: Any])
        
        #expect(data["attributes"] as? [String: String] == ["title": "Great"])
        #expect(review.headline == "Great")
    }
    
    @Test("fields named type or id, or both attribute and relationship, aren't sent")
    func fieldNamespace() {
        let typed = Review()
        typed.kind = "opinion"
        
        #expect(throws: JSONAPIError.self) { try typed.documentData() }
        
        let author = Person()
        author.id = "1"
        let ambiguous = Review()
        ambiguous.author = "Ann"
        ambiguous.writer = author
        
        #expect(throws: JSONAPIError.self) { try ambiguous.documentData() }
    }
    
    @Test("lid is sent only without id")
    func localIdentifier() throws {
        let article = Article()
        article.lid = "draft"
        
        #expect(try article.documentDictionary()["data"].flatMap { $0 as? [String: Any] }?["lid"] as? String == "draft")
        
        article.id = "1"
        let data = try #require(try article.documentDictionary()["data"] as? [String: Any])
        
        #expect(data["id"] as? String == "1")
        #expect(data["lid"] == nil)
    }
}
