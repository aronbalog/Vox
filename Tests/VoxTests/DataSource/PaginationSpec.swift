import Foundation
import Testing

@testable import Vox

#if canImport(ObjectiveC)

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

fileprivate struct MockRouter: Router {
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

@Suite("Paginated DataSource when fetching first page")
struct PaginationSpec {
    private let router = MockRouter()
    /// Responds to the first request with `Pagination1.json` and to every following one with `Pagination2.json`.
    private let client = RecordingClient(jsonFileNames: ["Pagination1", "Pagination2"])
    
    private func fetchFirstPage() async throws -> Document<[Article3]> {
        let dataSource = DataSource<Article3>(strategy: .router(router), client: client)
        let document = try await dataSource.fetch().result()
        
        #expect(client.requests.first?.target == .path(router.fetch(type: Article3.self)))
        #expect(document.links != nil)
        
        return document
    }
    
    private func expectRequest(_ request: Document<[Article3]>.PageRequest?, following link: String) async throws {
        let document = try await #require(request).result()
        
        #expect(document.data?.first?.id == "id2")
        #expect(client.requests.count == 2)
        #expect(client.requests.last?.target == .link(link))
        #expect(client.requests.last?.queryItems == [])
    }
    
    @Test("when fetching next page returns next page document")
    func fetchingNextPage() async throws {
        let document = try await fetchFirstPage()
        
        try await expectRequest(document.next, following: "http://example.com/articles?page[number]=4&page[size]=1")
    }
    
    @Test("when fetching first page of document returns first page document")
    func fetchingFirstPageOfDocument() async throws {
        let document = try await fetchFirstPage()
        
        try await expectRequest(document.first, following: "http://example.com/articles?page[number]=1&page[size]=1")
    }
    
    @Test("when reloading current page receives page")
    func reloadingCurrentPage() async throws {
        let document = try await fetchFirstPage()
        
        try await expectRequest(document.reload, following: "http://example.com/articles?page[number]=3&page[size]=1")
    }
    
    @Test("when fetching previous page receives page")
    func fetchingPreviousPage() async throws {
        let document = try await fetchFirstPage()
        
        try await expectRequest(document.previous, following: "http://example.com/articles?page[number]=2&page[size]=1")
    }
    
    @Test("when fetching last page returns last page document")
    func fetchingLastPage() async throws {
        let document = try await fetchFirstPage()
        
        try await expectRequest(document.last, following: "http://example.com/articles?page[number]=13&page[size]=1")
    }
    
    @Test("when appending next page document and included are appended")
    func appendingNextPage() async throws {
        let document = try await fetchFirstPage()
        
        let page: PaginationData<Article3> = try await withCheckedThrowingContinuation { continuation in
            document.appendNext({ continuation.resume(returning: $0) }, { continuation.resume(throwing: $0) })
        }
        
        #expect(page.new.count == 1)
        #expect(page.old.count == 1)
        #expect(page.all.count == 2)
        #expect(document.data?.count == 2)
        #expect(document.included?.count == 6)
        #expect(client.requests.last?.target == .link("http://example.com/articles?page[number]=4&page[size]=1"))
    }
}

#endif
