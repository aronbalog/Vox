import Foundation
import Testing

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

/// Responds to the first request with `Pagination1.json` and to every following one with `Pagination2.json`.
fileprivate class MockClient: Client {
    let firstPage = Data(jsonFileName: "Pagination1")
    let nextPage = Data(jsonFileName: "Pagination2")
    
    var count: Int = 0
    var firstPath: String?
    var nextPath: String?
    var queryItems: [URLQueryItem]?
    
    func executeRequest(path: String, method: String, queryItems: [URLQueryItem], bodyParameters: [String : Any]?, success: @escaping ClientSuccessBlock, failure: @escaping ClientFailureBlock, userInfo: [String: Any]) {
        if count == 0 {
            count += 1
            firstPath = path
            success(nil, firstPage)
        } else {
            self.queryItems = queryItems
            nextPath = path
            success(nil, nextPage)
        }
    }
}

@Suite("Paginated DataSource when fetching first page")
struct PaginationSpec {
    private let router = MockRouter()
    private let client = MockClient()
    
    private func fetchFirstPage() throws -> Document<[Article3]> {
        let dataSource = DataSource<Article3>(strategy: .router(router), client: client)
        var document: Document<[Article3]>?
        
        try dataSource.fetch().result({ document = $0 }, { error in
            Issue.record("Unexpected error: \(String(describing: error))")
        })
        
        #expect(client.firstPath == router.fetch(type: Article3.self))
        
        let firstPage = try #require(document)
        #expect(firstPage.links != nil)
        
        return firstPage
    }
    
    private func fetch(_ request: FetchRequest<Article3, DataSource<Article3>.ResourceCollectionSuccessBlock>?) throws -> Document<[Article3]>? {
        var document: Document<[Article3]>?
        
        try request?.result({ document = $0 }, { error in
            Issue.record("Unexpected error: \(String(describing: error))")
        })
        
        return document
    }
    
    @Test("when fetching next page returns next page document")
    func fetchingNextPage() throws {
        let document = try fetchFirstPage()
        
        #expect(try fetch(document.next) != nil)
    }
    
    @Test("when fetching first page of document returns first page document")
    func fetchingFirstPageOfDocument() throws {
        let document = try fetchFirstPage()
        
        #expect(try fetch(document.first) != nil)
    }
    
    @Test("when reloading current page receives page")
    func reloadingCurrentPage() throws {
        let document = try fetchFirstPage()
        
        #expect(try fetch(document.reload) != nil)
    }
    
    @Test("when fetching previous page receives page")
    func fetchingPreviousPage() throws {
        let document = try fetchFirstPage()
        
        #expect(try fetch(document.previous) != nil)
    }
    
    @Test("when fetching last page returns last page document")
    func fetchingLastPage() throws {
        let document = try fetchFirstPage()
        
        #expect(try fetch(document.last) != nil)
    }
    
    @Test("when appending next page document and included are appended")
    func appendingNextPage() throws {
        let document = try fetchFirstPage()
        var pagination: PaginationData<Article3>?
        
        document.appendNext({ pagination = $0 }, { error in
            Issue.record("Unexpected error: \(String(describing: error))")
        })
        
        let page = try #require(pagination)
        #expect(page.new.count == 1)
        #expect(page.old.count == 1)
        #expect(page.all.count == 2)
        #expect(document.data?.count == 2)
        #expect(document.included?.count == 6)
        #expect(client.nextPath == "/articles")
        #expect(client.queryItems == [
            URLQueryItem(name: "page[number]", value: "4"),
            URLQueryItem(name: "page[size]", value: "1")
        ])
    }
}
