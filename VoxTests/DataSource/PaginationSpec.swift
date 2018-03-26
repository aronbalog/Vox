import UIKit
import Quick
import Nimble

@testable import Vox

fileprivate class Article3: Resource {
    override class var resourceType: String {
        return "articles3"
    }
    
    override class var codingKeys: [String: String] {
        return [
            "descriptionText": "description"
        ]
    }
    
    @objc dynamic var title: String?
    @objc dynamic var descriptionText: String?
    @objc dynamic var keywords: [String]?
    @objc dynamic var coauthors: [Person3]?
    @objc dynamic var author: Person3?
    @objc dynamic var hint: String?
    @objc dynamic var customObject: [String: Any]?
}


fileprivate class Person3: Resource {
    override class var resourceType: String {
        return "persons3"
    }
    
    @objc dynamic var name: String?
    @objc dynamic var age: NSNumber?
    @objc dynamic var gender: String?
    @objc dynamic var favoriteArticle: Article3?
    
}


fileprivate class MockRouter: Router {
    func fetch(id: String, type: Resource.Type) -> String {
        fatalError()
    }
    
    func fetch(type: Resource.Type) -> String {
        return "mock"
    }
    
    func create(resource: Resource) -> String {
        fatalError()
    }
    
    func update(resource: Resource) -> String {
        fatalError()
    }
    
    func delete(id: String, type: Resource.Type) -> String {
        fatalError()
    }
}

fileprivate class MockClient: Client {
    lazy var data1 = Data(jsonFileName: "Pagination1")
    lazy var data2 = Data(jsonFileName: "Pagination2")
    
    var count: Int = 0
    var firstPath: String?
    var nextPath: String?
    var queryItems: [URLQueryItem]?
    
    func executeRequest(path: String, method: String, queryItems: [URLQueryItem], bodyParameters: [String : Any]?, success: @escaping ClientSuccessBlock, failure: @escaping ClientFailureBlock, userInfo: [String: Any]) {
        
        if count == 0 {
            count += 1
            firstPath = path
            success(nil, data1)
        } else {
            self.queryItems = queryItems
            nextPath = path
            success(nil, data2)
        }
    }
}

fileprivate class PageableResource: Resource {
    override class var resourceType: String {
        return "pageable-resource"
    }
}

class PaginationSpec: QuickSpec {
    override func spec() {

        describe("Paginated DataSource") {
            let router = MockRouter()
            let client = MockClient()
            let dataSource: DataSource = DataSource<Article3>(strategy: .router(router), client: client)

            var document: Document<[Article3]>?
            var nextDocument: Document<[Article3]>?
            var error: Error?
            
            context("when fetching first page", {
                try! dataSource.fetch().result({ (_document) in
                    document = _document
                }, { (_error) in
                    error = _error
                })
                
                it("returns first page document", closure: {
                    expect(error).toEventually(beNil())
                    expect(document).toEventuallyNot(beNil())
                    expect(error).toEventually(beNil())
                    expect(client.firstPath).toEventually(equal(router.fetch(type: Article3.self)))
                })
                
                context("when fetching next page", {
                    try! document?.next?.result({ (_nextDocument) in
                        nextDocument = _nextDocument
                    }, { (_error) in
                        error = _error
                    })
                    
                    it("returns next page document", closure: {
                        expect(error).toEventually(beNil())
                        expect(nextDocument).toEventuallyNot(beNil())
                    })
                })
            })
        }
        
        describe("Paginated DataSource") {
            let router = MockRouter()
            let client = MockClient()
            let dataSource: DataSource = DataSource<Article3>(strategy: .router(router), client: client)
            
            var document: Document<[Article3]>?
            var firstDocument: Document<[Article3]>?
            var error: Error?
            
            context("when fetching first page", {
                try! dataSource.fetch().result({ (_document) in
                    document = _document
                }, { (_error) in
                    error = _error
                })
                
                it("returns first page document", closure: {
                    expect(error).toEventually(beNil())
                    expect(document).toEventuallyNot(beNil())
                    expect(error).toEventually(beNil())
                    expect(client.firstPath).toEventually(equal(router.fetch(type: Article3.self)))
                })
                
                context("when fetching first page of document", {
                    try! document?.first?.result({ (_firstDocument) in
                        firstDocument = _firstDocument
                    }, { (_error) in
                        error = _error
                    })
                    
                    it("returns first page document", closure: {
                        expect(error).toEventually(beNil())
                        expect(firstDocument).toEventuallyNot(beNil())
                    })
                })
            })
        }
        
        describe("Paginated DataSource") {
            let router = MockRouter()
            let client = MockClient()
            let dataSource: DataSource = DataSource<Article3>(strategy: .router(router), client: client)

            var document: Document<[Article3]>?
            var pagination: PaginationData<Article3>?
            var error: Error?

            context("when fetching first page", {
                try! dataSource.fetch().result({ (_document) in
                    document = _document
                }, { (_error) in
                    error = _error
                })
                
                it("returns first page document", closure: {
                    expect(document).toEventuallyNot(beNil())
                    expect(document?.links).toEventuallyNot(beNil())
                    expect(error).toEventually(beNil())
                    expect(client.firstPath).toEventually(equal(router.fetch(type: Article3.self)))
                })
                
                                
                context("when appending next page", {
                    document?.appendNext({ (_pagination) in
                        pagination = _pagination
                    }, { (_error) in
                        error = _error
                    })
                
                    it("receives pagination", closure: {
                        expect(error).toEventually(beNil())
                        expect(pagination).toEventuallyNot(beNil())
                        expect(pagination?.new).toEventually(haveCount(1))
                        expect(pagination?.old).toEventually(haveCount(1))
                        expect(pagination?.all).toEventually(haveCount(2))
                        expect(document?.data).toEventually(haveCount(2))
                        expect(client.nextPath).toEventually(equal("/articles"))
                        expect(client.queryItems).toEventually(equal([
                            URLQueryItem.init(name: "page[number]", value: "4"),
                            URLQueryItem.init(name: "page[size]", value: "1")
                            ]))
                    })
                    
                    it("document is appended", closure: {
                        expect(document?.data).toEventually(haveCount(2))
                    })
                    
                    it("included is appended", closure: {
                        expect(document?.included).toEventually(haveCount(6))
                    })
                })
            })
        }
        
        describe("Paginated DataSource") {
            let router = MockRouter()
            let client = MockClient()
            let dataSource: DataSource = DataSource<Article3>(strategy: .router(router), client: client)
            
            var document: Document<[Article3]>?
            var reloadedDocument: Document<[Article3]>?
            var error: Error?
            
            context("when fetching first page", {
                try! dataSource.fetch().result({ (_document) in
                    document = _document
                }, { (_error) in
                    error = _error
                })
                
                it("returns first page document", closure: {
                    expect(document).toEventuallyNot(beNil())
                    expect(document?.links).toEventuallyNot(beNil())
                    expect(error).toEventually(beNil())
                    expect(client.firstPath).toEventually(equal(router.fetch(type: Article3.self)))
                })
                
                
                context("when reloading current page", {
                    try! document?.reload?.result({ (document) in
                        reloadedDocument = document
                    }, { (_error) in
                        error = _error
                    })
                    
                    it("receives page", closure: {
                        expect(error).toEventually(beNil())
                        expect(reloadedDocument).toEventuallyNot(beNil())
                    })
                })
            })
        }
        
        describe("Paginated DataSource") {
            let router = MockRouter()
            let client = MockClient()
            let dataSource: DataSource = DataSource<Article3>(strategy: .router(router), client: client)
            
            var document: Document<[Article3]>?
            var previousDocument: Document<[Article3]>?
            var error: Error?
            
            context("when fetching first page", {
                try! dataSource.fetch().result({ (_document) in
                    document = _document
                }, { (_error) in
                    error = _error
                })
                
                it("returns first page document", closure: {
                    expect(document).toEventuallyNot(beNil())
                    expect(document?.links).toEventuallyNot(beNil())
                    expect(error).toEventually(beNil())
                    expect(client.firstPath).toEventually(equal(router.fetch(type: Article3.self)))
                })
                
                
                context("when fetching previous page", {
                    try! document?.previous?.result({ (document) in
                        previousDocument = document
                    }, { (_error) in
                        error = _error
                    })
                    
                    it("receives page", closure: {
                        expect(error).toEventually(beNil())
                        expect(previousDocument).toEventuallyNot(beNil())
                    })
                })
            })
        }
        
        describe("Paginated DataSource") {
            let router = MockRouter()
            let client = MockClient()
            let dataSource: DataSource = DataSource<Article3>(strategy: .router(router), client: client)
            
            var document: Document<[Article3]>?
            var lastDocument: Document<[Article3]>?
            var error: Error?
            
            context("when fetching first page", {
                try! dataSource.fetch().result({ (_document) in
                    document = _document
                }, { (_error) in
                    error = _error
                })
                
                it("returns first page document", closure: {
                    expect(error).toEventually(beNil())
                    expect(document).toEventuallyNot(beNil())
                    expect(error).toEventually(beNil())
                    expect(client.firstPath).toEventually(equal(router.fetch(type: Article3.self)))
                })
                
                context("when fetching last page", {
                    try! document?.last?.result({ (_lastDocument) in
                        lastDocument = _lastDocument
                    }, { (_error) in
                        error = _error
                    })
                    
                    it("returns last page document", closure: {
                        expect(error).toEventually(beNil())
                        expect(lastDocument).toEventuallyNot(beNil())
                    })
                })
            })
        }
    }
}

