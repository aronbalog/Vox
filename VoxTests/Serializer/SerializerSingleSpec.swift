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
        return "persons"
    }
    
    @objc dynamic var name: String?
    @objc dynamic var age: NSNumber?
    @objc dynamic var gender: String?
    @objc dynamic var favoriteArticle: Article?
    
}

class SerializerSingleSpec: QuickSpec {
    override func spec() {
        describe("Serializer") {
            context("when serializing single resource", {
                
                let article = Article()
                article.id = "id"
                article.type = Article.resourceType
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
                        "key":"value"
                    ]
                ]
                article.optionalValue = nil
                article.fans = .null

                let person = Person()
                person.id = "id"
                person.type = Person.resourceType
                person.name = "name"
                person.age = 30
                person.gender = "male"
                
                article.author = .null()
                article.coauthors = .null
                
                let expectedAttributes: [String: Any] = [
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
                        ["key":"value"]
                    ]
                ]
                
                let expectedRelationships: [String: Any] = [
                    "author": [
                        "data": NSNull()
                    ],
                    "coauthors": [
                        "data": NSNull()
                    ],
                    "fans": [
                        "data": NSNull()
                    ]
                ]
                
                it("maps correctly", closure: {
                    let attributes = article.attributes!
                    let relationships = article.relationships!
                    
                    print(String(data: try! JSONSerialization.data(withJSONObject: relationships, options: .prettyPrinted), encoding: .utf8)!)
                    
                    print("------------")
                    
                    print(String(data: try! JSONSerialization.data(withJSONObject: expectedRelationships, options: .prettyPrinted), encoding: .utf8)!)
                    
                    expect((attributes as NSDictionary).isEqual(expectedAttributes as NSDictionary)).to(beTrue())
                    expect((relationships as NSDictionary).isEqual(expectedRelationships as NSDictionary)).to(beTrue())
                })
                
                it("returns document data", closure: {
                    let documentData = try! article.documentData()
                    
                    expect(documentData).notTo(beNil())
                })
                
                it("returns document dictionary", closure: {
                    let documentDictionary = try! article.documentDictionary()

                    let expectedDictionary: [String: Any] = [
                        "data": [
                            "id":"id",
                            "type":Article.resourceType,
                            "attributes": expectedAttributes,
                            "relationships": expectedRelationships
                        ]
                    ]
                    
                    expect((documentDictionary as NSDictionary).isEqual(expectedDictionary)).to(beTrue())
                })
            })
        }
    }
}

