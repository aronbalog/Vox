import Foundation
import Testing

@testable import Vox

#if canImport(ObjectiveC)

fileprivate final class Article: Resource {
    override class var resourceType: String {
        "articles"
    }
    
    override class var codingKeys: [String: String] {
        return [
            "descriptionText": "description"
        ]
    }
    
    @objc dynamic var title: String?
    @objc dynamic var descriptionText: String?
    @objc dynamic var keywords: [String]?
    @objc dynamic var coauthors: [Person]?
    @objc dynamic var author: Person?
    @objc dynamic var hint: String?
    @objc dynamic var customObject: [String: Any]?
    @objc dynamic var rank: NSNumber?
    @objc dynamic var featured: NSNumber?
    @objc dynamic var dictionary: [String: Any]?
    @objc dynamic var anotherDictionary: [String: Any]?
    @objc dynamic var numericArray: [NSNumber]?
    @objc dynamic var arrayOfDictionaries: [[String: Any]]?
    @objc dynamic var anotherArrayOfDictionaries: [[String: Any]]?
    @objc dynamic var optionalValue: String?
    @objc dynamic var fans: [Person]?
}


fileprivate class Person: Resource {
    override class var resourceType: String {
        "persons"
    }
    
    @objc dynamic var name: String?
    @objc dynamic var age: NSNumber?
    @objc dynamic var gender: String?
    @objc dynamic var favoriteArticle: Article?
    
}

@Suite("Serializer when serializing single resource")
struct SerializerSingleSpec {
    private let expectedAttributes: [String: Any] = [
        "title": "title",
        "description": NSNull(),
        "keywords": NSNull(),
        "hint": "hint",
        "rank": 3,
        "featured": NSNull(),
        "dictionary": [
            "firstName": "fist",
            "lastName": "last"
        ],
        "anotherDictionary": NSNull(),
        "numericArray": NSNull(),
        "arrayOfDictionaries": NSNull(),
        "anotherArrayOfDictionaries": [
            ["key": "value"]
        ]
    ]
    
    private let expectedRelationships: [String: Any] = [
        "author": [
            "data": NSNull()
        ],
        "coauthors": [
            "data": []
        ],
        "fans": [
            "data": []
        ]
    ]
    
    private func makeArticle() -> Article {
        let article = Article()
        article.id = "id"
        article["title"] = "title"
        article.descriptionText = .null
        article.keywords = .null
        article.hint = "hint"
        article.rank = 3
        article.featured = .null
        article.dictionary = [
            "firstName": "fist",
            "lastName": "last"
        ]
        article.anotherDictionary = .null
        article.numericArray = .null
        article.arrayOfDictionaries = .null
        article.anotherArrayOfDictionaries = [
            [
                "key": "value"
            ]
        ]
        article.optionalValue = nil
        article.fans = .null
        article.author = .null()
        article.coauthors = .null
        
        return article
    }
    
    @Test("maps correctly")
    func mapsCorrectly() {
        let article = makeArticle()
        
        #expect((article.attributes as NSDictionary).isEqual(expectedAttributes))
        #expect((article.relationships as NSDictionary).isEqual(expectedRelationships))
    }
    
    @Test("returns document data")
    func returnsDocumentData() throws {
        let documentData = try makeArticle().documentData()
        
        #expect(!documentData.isEmpty)
    }
    
    @Test("returns document dictionary")
    func returnsDocumentDictionary() throws {
        let documentDictionary = try makeArticle().documentDictionary()
        
        let expectedDictionary: [String: Any] = [
            "data": [
                "id": "id",
                "type": Article.resourceType,
                "attributes": expectedAttributes,
                "relationships": expectedRelationships
            ]
        ]
        
        #expect((documentDictionary as NSDictionary).isEqual(expectedDictionary))
    }
}

#endif
