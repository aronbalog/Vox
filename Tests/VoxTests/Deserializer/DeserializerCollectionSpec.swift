import Foundation
import Testing

@testable import Vox

#if canImport(ObjectiveC)

fileprivate class Article2: Resource {
    override class var resourceType: String {
        return "articles2"
    }
    
    override class var codingKeys: [String: String] {
        return [
            "descriptionText": "description"
        ]
    }
    
    @objc dynamic var title: String?
    @objc dynamic var descriptionText: String?
    @objc dynamic var keywords: [String]?
    @objc dynamic var coauthors: [Person2]?
    @objc dynamic var author: Person2?
    @objc dynamic var hint: String?
    @objc dynamic var customObject: [String: Any]?
}


fileprivate class Person2: Resource {
    override class var resourceType: String {
        return "persons2"
    }
    
    @objc dynamic var name: String?
    @objc dynamic var age: NSNumber?
    @objc dynamic var gender: String?
    @objc dynamic var favoriteArticle: Article2?
    
}

@Suite("Deserializer when deserializing resource collection")
struct DeserializerCollectionSpec {
    let data = Data(jsonFileName: "Articles")
    
    @Test("maps correctly")
    func mapsCorrectly() throws {
        let document = try Deserializer.Collection<Article2>().deserialize(data: data)
        let articles = try #require(document.data)
        
        #expect(articles.count == 1)
        
        let article = try #require(articles.first)
        #expect(article.title == "Title")
        #expect(article.descriptionText == "Desc")
        #expect(article.keywords != nil)
        #expect(article.customObject != nil)
        
        let author = try #require(article.author)
        #expect(author.name == "Aron")
        
        #expect(article.coauthors?.count == 2)
    }
}

#endif
