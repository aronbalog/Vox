import Foundation
import Testing

@testable import Vox

#if canImport(ObjectiveC)

fileprivate final class Article1: Resource {
    override class var resourceType: String {
        "articles1"
    }

    override class var codingKeys: [String: String] {
        return [
            "descriptionText": "description"
        ]
    }
    
    @objc dynamic var title: String?
    @objc dynamic var descriptionText: String?
    @objc dynamic var keywords: [String]?
    @objc dynamic var coauthors: [Person1]?
    @objc dynamic var author: Person1?
    @objc dynamic var hint: String?
    @objc dynamic var customObject: [String: Any]?
}


fileprivate class Person1: Resource {
    override class var resourceType: String {
        "persons1"
    }
    
    @objc dynamic var name: String?
    @objc dynamic var age: NSNumber?
    @objc dynamic var gender: String?
    @objc dynamic var favoriteArticle: Article1?
    
}

@Suite("Deserializer when deserializing single resource")
struct DeserializerSingleSpec {
    let data = Data(jsonFileName: "Article")
    
    @Test("maps correctly")
    func mapsCorrectly() throws {
        let document = try Deserializer.Single<Article1>().deserialize(data: data)
        let article = try #require(document.data)
        
        #expect(article.title == "Title")
        #expect(article["title"] as? String == "Title")
        #expect(article.descriptionText == "Desc")
        #expect(article.keywords != nil)
        #expect(article.customObject != nil)
        
        let author = try #require(article.author)
        #expect(author.name == "Aron")
        
        #expect(article.coauthors?.count == 2)
    }
}

#endif
