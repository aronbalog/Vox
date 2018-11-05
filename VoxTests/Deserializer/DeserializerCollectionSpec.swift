import UIKit

import Quick
import Nimble

@testable import Vox

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
    @objc dynamic var here: URL?
    @objc dynamic var there: URL?
    @objc dynamic var related: [String: Any]?
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


class DeserializerCollectionSpec: QuickSpec {
    lazy var data = Data(jsonFileName: "Articles")
    
    override func spec() {
        describe("Deserializer") {
            let sut = Deserializer.Collection<Article2>()

            context("when deserializing resource collection", {
                let document = try! sut.deserialize(data: self.data)
                
                it("maps correctly", closure: {
                    expect(document).notTo(beNil())
                    let articles = document.data
                    
                    expect(articles).notTo(beNil())
                    expect(articles?.count).to(equal(1))
                    
                    let article = articles?.first
                    expect(article?.title).to(equal("Title"))
                    expect(article?.descriptionText).to(equal("Desc"))
                    expect(article?.keywords).notTo(beNil())
                    expect(article?.customObject).notTo(beNil())
                    expect(article?.here).to(equal(URL(string: "www.example.com")!))
                    expect(article?.related).notTo(beNil())

                    let coauthors = article?.coauthors
                    let author = article?.author

                    expect(author).notTo(beNil())
                    expect(author?.name).to(equal("Aron"))

                    expect(coauthors!.count).to(equal(2))
                })
            })
        }
    }
}
