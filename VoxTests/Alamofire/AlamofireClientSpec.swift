import UIKit
import Quick
import Nimble

@testable import Vox

fileprivate class Article4: Resource {
    override class var resourceType: String {
        return "articles4"
    }
    
    override class var codingKeys: [String: String] {
        return [
            "descriptionText": "description"
        ]
    }
    
    @objc dynamic var title: String?
    @objc dynamic var descriptionText: String?
    @objc dynamic var keywords: [String]?
    @objc dynamic var coauthors: [Person4]?
    @objc dynamic var author: Person4?
    @objc dynamic var hint: String?
    @objc dynamic var customObject: [String: Any]?
}

fileprivate class Person4: Resource {
    override class var resourceType: String {
        return "persons4"
    }
    
    @objc dynamic var name: String?
    @objc dynamic var age: NSNumber?
    @objc dynamic var gender: String?
    @objc dynamic var favoriteArticle: Article4?
    
}

class AlamofireClientSpec: QuickSpec {
    override func spec() {
        describe("DataSource with Alamofire client") {
            let client = JSONAPIClient.Alamofire(baseURL: URL(string: "http://demo7377577.mockable.io")!)
                
            context("when executing request with valid URL", {
                let dataSource = DataSource<Article4>(strategy: .path("vox/articles"), client: client)
                
                var document: Document<[Article4]>?
                
                try! dataSource.fetch().result({ (_document) in
                    document = _document
                }, nil)
                
                it("receives response", closure: {
                    expect(document).toEventuallyNot(beNil())
                })
            })
            
            context("when executing request with invalid URL", {
                let dataSource = DataSource<Article4>(strategy: .path("invalid-url"), client: client)
                
                var error: Error?
                
                try! dataSource
                    .fetch()
                    .fields([
                        "articles": ["title"]
                    ])
                    .result({ (_) in
                    
                    }, { (_error) in
                        error = _error
                    })
                
                it("receives error", closure: {
                    expect(error).toEventuallyNot(beNil())
                })
            })
        }
    }
}
