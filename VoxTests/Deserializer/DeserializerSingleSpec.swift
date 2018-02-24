import UIKit
import Quick
import Nimble

@testable import Vox

fileprivate final class Article1: Resource {
    override class var resourceType: String {
        return "articles1"
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
        return "persons1"
    }
    
    @objc dynamic var name: String?
    @objc dynamic var age: NSNumber?
    @objc dynamic var gender: String?
    @objc dynamic var favoriteArticle: Article1?
    
}

class DeserializerSingleSpec: QuickSpec {
    lazy var data = Data(jsonFileName: "Article")
    
    override func spec() {
        describe("Deserializer") {
            let sut = Deserializer.Single<Article1>()
            context("when deserializing single resource", {
                let document = try! sut.deserialize(data: self.data)
                
                it("maps correctly", closure: {
                    expect(document).notTo(beNil())
                    let article = document.data!
                    
                    expect(article).notTo(beNil())
                    expect(article.title).to(equal("Title"))
                    expect(article["title"] as? String).to(equal("Title"))
                    expect(article.descriptionText).to(equal("Desc"))
                    expect(article.keywords).notTo(beNil())
                    expect(article.customObject).notTo(beNil())


                    let coauthors = article.coauthors
                    let author = article.author
                    
                    expect(author).notTo(beNil())
                    expect(author?.name).to(equal("Aron"))
                    
                    expect(coauthors?.count).to(equal(2))                    
                })
            })
        }
    }
}
