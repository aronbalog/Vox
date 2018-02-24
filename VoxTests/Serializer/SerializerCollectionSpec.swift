import UIKit
import Quick
import Nimble

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

class SerializerCollectionSpec: QuickSpec {
    override func spec() {
        describe("Serializer") {
            context("when serializing resource collection", {
                
                let article1 = Article()
                article1.id = "id1"
                article1.type = Article.resourceType
                article1.title = "title"
                article1.descriptionText = "desc"
                article1.keywords = ["key1", "key2"]
                article1.hint = "hint" // is meta object so it should not be mapped
                
                let article2 = Article()
                article2.id = "id2"
                article2.type = Article.resourceType
                article2.title = "title"
                article2.descriptionText = "desc"
                article2.keywords = ["key1", "key2"]
                article2.hint = "hint" // is meta object so it should not be mapped
                
                // create person
                
                let person = Person()
                person.id = "id"
                person.type = Person.resourceType
                person.name = "name"
                person.age = 10
                person.gender = "male"
                
                article1.author = person
                article1.coauthors = [person]
                
                article2.author = person
                article2.coauthors = [person]

                let expectedAttributes: [String: Any] = [
                    "title": "title",
                    "description": "desc",
                    "keywords": ["key1", "key2"],
                    "hint": "hint"
                ]
                
                let expectedRelationships: [String: Any] = [
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
                
                it("maps correctly", closure: {
                    let attributes1 = article1.attributes
                    let relationships = article1.relationships
                    
                    expect(attributes1?.isEqual(expectedAttributes as NSDictionary)).to(beTrue())
                    expect((relationships)?.isEqual(expectedRelationships as NSDictionary)).to(beTrue())
                    
                    expect((article2.attributes)?.isEqual(expectedAttributes as NSDictionary)).to(beTrue())
                    expect((article2.relationships)?.isEqual(expectedRelationships as NSDictionary)).to(beTrue())
                })
                
                let collection = [article1, article2]

                it("returns document data", closure: {
                    let documentData = collection.documentData

                    expect(documentData).notTo(beNil())
                })

                it("returns document dictionary", closure: {
                    let documentDictionary = try! collection.documentDictionary()

                    let expectedDictionary: [String: Any] = [
                        "data": [[
                                "id":"id1",
                                "type":Article.resourceType,
                                "attributes": expectedAttributes,
                                "relationships": expectedRelationships
                            ],
                             [
                                "id":"id2",
                                "type":Article.resourceType,
                                "attributes": expectedAttributes,
                                "relationships": expectedRelationships
                            ]
                        ]
                    ]

                    expect((documentDictionary as NSDictionary).isEqual(expectedDictionary)).to(beTrue())
                })
            })
        }
    }
}


