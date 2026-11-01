import Foundation
import Testing

@testable import Vox

fileprivate final class Article: Resource {
    override class var resourceType: String {
        return "articles"
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
}


fileprivate class Person: Resource {
    override class var resourceType: String {
        return "persons"
    }
    
    @objc dynamic var name: String?
    @objc dynamic var age: NSNumber?
    @objc dynamic var gender: String?
    @objc dynamic var favoriteArticle: Article?
    
}

@Suite("Serializer when serializing resource collection")
struct SerializerCollectionSpec {
    private let expectedAttributes: [String: Any] = [
        "title": "title",
        "description": "desc",
        "keywords": ["key1", "key2"],
        "hint": "hint"
    ]
    
    private let expectedRelationships: [String: Any] = [
        "author": [
            "data": [
                "id": "id",
                "type": Person.resourceType
            ]
        ],
        "coauthors": [
            "data": [
                [
                    "id": "id",
                    "type": Person.resourceType
                ]
            ]
        ]
    ]
    
    private func makeArticles() -> [Article] {
        let person = Person()
        person.id = "id"
        person.type = Person.resourceType
        person.name = "name"
        person.age = 10
        person.gender = "male"
        
        return ["id1", "id2"].map { id in
            let article = Article()
            article.id = id
            article.type = Article.resourceType
            article.title = "title"
            article.descriptionText = "desc"
            article.keywords = ["key1", "key2"]
            article.hint = "hint"
            article.author = person
            article.coauthors = [person]
            
            return article
        }
    }
    
    @Test("maps correctly")
    func mapsCorrectly() {
        for article in makeArticles() {
            #expect(article.attributes?.isEqual(expectedAttributes as NSDictionary) == true)
            #expect(article.relationships?.isEqual(expectedRelationships as NSDictionary) == true)
        }
    }
    
    @Test("returns document data")
    func returnsDocumentData() throws {
        let documentData = try makeArticles().documentData()
        
        #expect(!documentData.isEmpty)
    }
    
    @Test("returns document dictionary")
    func returnsDocumentDictionary() throws {
        let documentDictionary = try makeArticles().documentDictionary()
        
        let expectedDictionary: [String: Any] = [
            "data": [
                [
                    "id": "id1",
                    "type": Article.resourceType,
                    "attributes": expectedAttributes,
                    "relationships": expectedRelationships
                ],
                [
                    "id": "id2",
                    "type": Article.resourceType,
                    "attributes": expectedAttributes,
                    "relationships": expectedRelationships
                ]
            ]
        ]
        
        #expect((documentDictionary as NSDictionary).isEqual(expectedDictionary))
    }
}
