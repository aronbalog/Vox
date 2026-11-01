import Foundation
import Testing

@testable import Vox

fileprivate let fetchCollectionPath = "fetch-collection"
fileprivate let fetchSinglePath = "fetch/single"
fileprivate let createPath = "create"
fileprivate let updatePath = "update"
fileprivate let deletePath = "delete"
fileprivate let filterQueryItem = URLQueryItem(name: "name", value: "value")
fileprivate let paginationQueryItem = URLQueryItem(name: "page", value: "value")

fileprivate let immutablePath = "path/<type>"

fileprivate final class MockRouter: Router, @unchecked Sendable {
    final class Invocation {
        var fetchCollection: Int = 0
        var fetchSingle: Int = 0
        var create: Int = 0
        var update: Int = 0
        var delete: Int = 0
    }
    
    final class Inspector {
        var singleFetchId: String?
        var singleFetchType: Resource.Type?
        var collectionFetchType: Resource.Type?
        var createResource: Resource?
        var updateResource: Resource?
        var deleteId: String?
        var deleteType: Resource.Type?
    }
    
    let invocation = Invocation()
    let inspector = Inspector()
    
    func fetch(id: String, type: Resource.Type) -> String {
        invocation.fetchSingle.invoke()

        inspector.singleFetchId = id
        inspector.singleFetchType = type
        
        return fetchSinglePath
    }
    
    func fetch(type: Resource.Type) -> String {
        invocation.fetchCollection.invoke()
        
        inspector.collectionFetchType = type
        
        return fetchCollectionPath
    }
    
    func create(resource: Resource) -> String {
        invocation.create.invoke()
        
        inspector.createResource = resource

        return createPath
    }
    
    func update(resource: Resource) -> String {
        invocation.update.invoke()
        
        inspector.updateResource = resource
        
        return updatePath
    }
    
    func delete(id: String, type: Resource.Type) -> String {
        invocation.delete.invoke()
        
        inspector.deleteId = id
        inspector.deleteType = type
        
        return deletePath
    }
}

fileprivate struct MockFilterStrategy: FilterStrategy {
    func filterURLQueryItems() -> [URLQueryItem] {
        return [filterQueryItem]
    }
}

fileprivate struct MockPaginationStrategy: PaginationStrategy {
    func paginationURLQueryItems() -> [URLQueryItem] {
        return [paginationQueryItem]
    }
}

fileprivate final class MockResource: Resource {
    override class var resourceType: String {
        return "mock-resource"
    }
}

fileprivate let singleResourceJSON = #"{ "data": { "type": "mock-resource", "id": "mock" } }"#
fileprivate let collectionJSON = #"{ "data": [] }"#

/// Checks the query items produced by `fetch(id:)` configured with fields, a filter, includes and sorting.
fileprivate func expectConfiguredFetchQueryItems(_ queryItems: [URLQueryItem]) throws {
    try #require(queryItems.count == 4)
    
    // http://jsonapi.org/format/#fetching-sparse-fieldsets
    #expect(queryItems[0].name == "fields[key]")
    #expect(queryItems[0].value == "value1,value2")
    
    // http://jsonapi.org/format/#fetching-filtering
    #expect(queryItems[1].name == filterQueryItem.name)
    #expect(queryItems[1].value == filterQueryItem.value)
    
    // http://jsonapi.org/format/#fetching-includes
    #expect(queryItems[2].name == "include")
    #expect(queryItems[2].value == "include1,include2")
    
    // http://jsonapi.org/format/#fetching-sorting
    #expect(queryItems[3].name == "sort")
    #expect(queryItems[3].value == "value1,-value2")
}

fileprivate func fetchConfigured(id: String, from dataSource: DataSource<MockResource>) async throws {
    _ = try await dataSource
        .fetch(id: id)
        .fields([
            "key": ["value1", "value2"]
        ])
        .filter(MockFilterStrategy())
        .include(["include1", "include2"])
        .sort([
            .ascending("value1"),
            .descending("value2")
        ])
        .result()
}

@Suite("DataSource with router and client")
struct DataSourceWithRouterSpec {
    @Test("when creating resource")
    func creatingResource() async throws {
        let client = RecordingClient()
        let router = MockRouter()
        let sut = DataSource<MockResource>(strategy: .router(router), client: client)
        let resource = MockResource()
        
        _ = try await sut
            .create(resource)
            .userInfo(["key": "value"])
            .result()
        
        let request = try #require(client.requests.first)
        #expect(client.requests.count == 1)
        #expect(router.invocation.create.isInvokedOnce)
        #expect(router.inspector.createResource === resource)
        #expect(request.method == "POST")
        #expect(request.target == .path(createPath))
        #expect(request.userInfo["key"] as? String == "value")
    }
    
    @Test("when fetching single resource")
    func fetchingSingleResource() async throws {
        let client = RecordingClient(json: singleResourceJSON)
        let router = MockRouter()
        let sut = DataSource<MockResource>(strategy: .router(router), client: client)
        
        try await fetchConfigured(id: "mock", from: sut)
        
        let request = try #require(client.requests.first)
        #expect(client.requests.count == 1)
        #expect(router.invocation.fetchSingle.isInvokedOnce)
        #expect(router.inspector.singleFetchType != nil)
        #expect(router.inspector.singleFetchId == "mock")
        #expect(request.method == "GET")
        #expect(request.target == .path(fetchSinglePath))
        try expectConfiguredFetchQueryItems(request.queryItems)
    }
    
    @Test("when fetching resource collection")
    func fetchingResourceCollection() async throws {
        let client = RecordingClient(json: collectionJSON)
        let router = MockRouter()
        let sut = DataSource<MockResource>(strategy: .router(router), client: client)
        
        _ = try await sut.fetch().paginate(MockPaginationStrategy()).result()
        
        let request = try #require(client.requests.first)
        #expect(router.invocation.fetchCollection.isInvokedOnce)
        #expect(router.inspector.collectionFetchType != nil)
        #expect(request.target == .path(fetchCollectionPath))
        
        // http://jsonapi.org/format/#fetching-pagination
        #expect(request.queryItems == [paginationQueryItem])
    }
    
    @Test("when updating resource")
    func updatingResource() async throws {
        let client = RecordingClient()
        let router = MockRouter()
        let sut = DataSource<MockResource>(strategy: .router(router), client: client)
        let resource = MockResource()
        
        _ = try await sut.update(resource).result()
        
        let request = try #require(client.requests.first)
        #expect(router.invocation.update.isInvokedOnce)
        #expect(router.inspector.updateResource === resource)
        #expect(request.method == "PATCH")
        #expect(request.target == .path(updatePath))
    }
    
    @Test("when deleting resource")
    func deletingResource() async throws {
        let client = RecordingClient()
        let router = MockRouter()
        let sut = DataSource<MockResource>(strategy: .router(router), client: client)
        
        try await sut.delete(id: "mock").result()
        
        let request = try #require(client.requests.first)
        #expect(router.invocation.delete.isInvokedOnce)
        #expect(router.inspector.deleteId == "mock")
        #expect(router.inspector.deleteType != nil)
        #expect(request.method == "DELETE")
        #expect(request.target == .path(deletePath))
    }
}

@Suite("DataSource with path and client")
struct DataSourceWithPathSpec {
    @Test("when creating resource")
    func creatingResource() async throws {
        let client = RecordingClient()
        let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
        
        _ = try await sut.create(MockResource()).result()
        
        #expect(client.requests.map(\.target) == [.path("path/mock-resource")])
    }
    
    @Test("when fetching single resource")
    func fetchingSingleResource() async throws {
        let client = RecordingClient(json: singleResourceJSON)
        let sut = DataSource<MockResource>(strategy: .path("path/<type>/<id>"), client: client)
        
        try await fetchConfigured(id: "mock", from: sut)
        
        let request = try #require(client.requests.first)
        #expect(request.target == .path("path/mock-resource/mock"))
        try expectConfiguredFetchQueryItems(request.queryItems)
    }
    
    @Test("when fetching resource collection with custom pagination")
    func fetchingWithCustomPagination() async throws {
        let client = RecordingClient(json: collectionJSON)
        let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
        
        _ = try await sut.fetch().paginate(MockPaginationStrategy()).result()
        
        let request = try #require(client.requests.first)
        #expect(request.target == .path("path/mock-resource"))
        
        // http://jsonapi.org/format/#fetching-pagination
        #expect(request.queryItems == [paginationQueryItem])
    }
    
    @Test("when fetching resource collection with page based pagination")
    func fetchingWithPageBasedPagination() async throws {
        let client = RecordingClient(json: collectionJSON)
        let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
        
        _ = try await sut.fetch().paginate(Pagination.PageBased(number: 1, size: 2)).result()
        
        // http://jsonapi.org/format/#fetching-pagination
        #expect(client.requests.first?.queryItems == [
            URLQueryItem(name: "page[number]", value: "1"),
            URLQueryItem(name: "page[size]", value: "2")
        ])
    }
    
    @Test("when fetching resource collection with offset based pagination")
    func fetchingWithOffsetBasedPagination() async throws {
        let client = RecordingClient(json: collectionJSON)
        let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
        
        _ = try await sut.fetch().paginate(Pagination.OffsetBased(offset: 1, limit: 2)).result()
        
        // http://jsonapi.org/format/#fetching-pagination
        #expect(client.requests.first?.queryItems == [
            URLQueryItem(name: "page[offset]", value: "1"),
            URLQueryItem(name: "page[limit]", value: "2")
        ])
    }
    
    @Test("when fetching resource collection with cursor based pagination")
    func fetchingWithCursorBasedPagination() async throws {
        let client = RecordingClient(json: collectionJSON)
        let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
        
        _ = try await sut.fetch().paginate(Pagination.CursorBased(cursor: "mock-cursor")).result()
        
        // http://jsonapi.org/format/#fetching-pagination
        #expect(client.requests.first?.queryItems == [
            URLQueryItem(name: "page[cursor]", value: "mock-cursor")
        ])
    }
    
    @Test("when updating resource")
    func updatingResource() async throws {
        let client = RecordingClient()
        let sut = DataSource<MockResource>(strategy: .path("path/<type>/<id>"), client: client)
        let resource = MockResource()
        resource.id = "mock"
        
        _ = try await sut.update(resource).result()
        
        #expect(client.requests.map(\.target) == [.path("path/mock-resource/mock")])
    }
    
    @Test("when deleting resource")
    func deletingResource() async throws {
        let client = RecordingClient()
        let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
        
        try await sut.delete(id: "mock").result()
        
        #expect(client.requests.map(\.target) == [.path("path/mock-resource")])
    }
}
