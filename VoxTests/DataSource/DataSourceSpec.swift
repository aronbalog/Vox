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

fileprivate class MockRouter: Router {
    class Invocation {
        var fetchCollection: Int = 0
        var fetchSingle: Int = 0
        var create: Int = 0
        var update: Int = 0
        var delete: Int = 0
    }
    
    class Inspector {
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

fileprivate class MockClient: Client {
    class Invocation {
        var executeRequest: Int = 0
    }
    
    class ExecuteRequestInspector {
        var path: String?
        var queryItems: [URLQueryItem] = []
        var userInfo: [String: Any] = [:]
    }
    
    let invocation = Invocation()
    let executeRequestInspector = ExecuteRequestInspector()
    
    func executeRequest(path: String, method: String, queryItems: [URLQueryItem], bodyParameters: [String : Any]?, success: @escaping ClientSuccessBlock, failure: @escaping ClientFailureBlock, userInfo: [String: Any]) {
        invocation.executeRequest.invoke()
        executeRequestInspector.path = path
        executeRequestInspector.queryItems = queryItems
        executeRequestInspector.userInfo = userInfo
    }
}

fileprivate class MockFilterStrategy: FilterStrategy {
    func filterURLQueryItems() -> [URLQueryItem] {
        return [filterQueryItem]
    }
}

fileprivate class MockPaginationStrategy: PaginationStrategy {
    func paginationURLQueryItems() -> [URLQueryItem] {
        return [paginationQueryItem]
    }
}

fileprivate class MockResource: Resource {
    override class var resourceType: String {
        return "mock-resource"
    }
}

fileprivate extension Request {
    func mockConfiguration() -> Self {
        self.userInfo["key"] = "value"
        return self
    }
}

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

fileprivate func fetchConfigured(id: String, from dataSource: DataSource<MockResource>) throws {
    try dataSource
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
        .result({ _ in }, { _ in })
}

@Suite("DataSource with router and client")
struct DataSourceWithRouterSpec {
    @Test("when creating resource")
    func creatingResource() throws {
        let client = MockClient()
        let router = MockRouter()
        let sut = DataSource<MockResource>(strategy: .router(router), client: client)
        let resource = MockResource()
        
        try sut
            .create(resource)
            .mockConfiguration()
            .result({ _ in }, { _ in })
        
        #expect(client.invocation.executeRequest.isInvokedOnce)
        #expect(router.invocation.create.isInvokedOnce)
        #expect(router.inspector.createResource === resource)
        #expect(client.executeRequestInspector.path == createPath)
        #expect((client.executeRequestInspector.userInfo as NSDictionary).isEqual(["key": "value"]))
    }
    
    @Test("when fetching single resource")
    func fetchingSingleResource() throws {
        let client = MockClient()
        let router = MockRouter()
        let sut = DataSource<MockResource>(strategy: .router(router), client: client)
        
        try fetchConfigured(id: "mock", from: sut)
        
        #expect(client.invocation.executeRequest.isInvokedOnce)
        #expect(router.invocation.fetchSingle.isInvokedOnce)
        #expect(router.inspector.singleFetchType != nil)
        #expect(router.inspector.singleFetchId == "mock")
        #expect(client.executeRequestInspector.path == fetchSinglePath)
        try expectConfiguredFetchQueryItems(client.executeRequestInspector.queryItems)
    }
    
    @Test("when fetching resource collection")
    func fetchingResourceCollection() throws {
        let client = MockClient()
        let router = MockRouter()
        let sut = DataSource<MockResource>(strategy: .router(router), client: client)
        
        try sut.fetch().paginate(MockPaginationStrategy()).result({ _ in }, { _ in })
        
        #expect(client.invocation.executeRequest.isInvokedOnce)
        #expect(router.invocation.fetchCollection.isInvokedOnce)
        #expect(router.inspector.collectionFetchType != nil)
        #expect(client.executeRequestInspector.path == fetchCollectionPath)
        
        // http://jsonapi.org/format/#fetching-pagination
        let queryItem = try #require(client.executeRequestInspector.queryItems.first)
        #expect(queryItem.name == paginationQueryItem.name)
        #expect(queryItem.value == paginationQueryItem.value)
    }
    
    @Test("when updating resource")
    func updatingResource() throws {
        let client = MockClient()
        let router = MockRouter()
        let sut = DataSource<MockResource>(strategy: .router(router), client: client)
        let resource = MockResource()
        
        try sut.update(resource).result({ _ in }, { _ in })
        
        #expect(client.invocation.executeRequest.isInvokedOnce)
        #expect(router.invocation.update.isInvokedOnce)
        #expect(router.inspector.updateResource === resource)
        #expect(client.executeRequestInspector.path == updatePath)
    }
    
    @Test("when deleting resource")
    func deletingResource() throws {
        let client = MockClient()
        let router = MockRouter()
        let sut = DataSource<MockResource>(strategy: .router(router), client: client)
        
        try sut.delete(id: "mock").result({}, { _ in })
        
        #expect(client.invocation.executeRequest.isInvokedOnce)
        #expect(router.invocation.delete.isInvokedOnce)
        #expect(router.inspector.deleteId == "mock")
        #expect(router.inspector.deleteType != nil)
        #expect(client.executeRequestInspector.path == deletePath)
    }
}

@Suite("DataSource with path and client")
struct DataSourceWithPathSpec {
    @Test("when creating resource")
    func creatingResource() throws {
        let client = MockClient()
        let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
        
        try sut.create(MockResource()).result({ _ in }, { _ in })
        
        #expect(client.invocation.executeRequest.isInvokedOnce)
        #expect(client.executeRequestInspector.path == "path/mock-resource")
    }
    
    @Test("when fetching single resource")
    func fetchingSingleResource() throws {
        let client = MockClient()
        let sut = DataSource<MockResource>(strategy: .path("path/<type>/<id>"), client: client)
        
        try fetchConfigured(id: "mock", from: sut)
        
        #expect(client.invocation.executeRequest.isInvokedOnce)
        #expect(client.executeRequestInspector.path == "path/mock-resource/mock")
        try expectConfiguredFetchQueryItems(client.executeRequestInspector.queryItems)
    }
    
    @Test("when fetching resource collection with custom pagination")
    func fetchingWithCustomPagination() throws {
        let client = MockClient()
        let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
        
        try sut.fetch().paginate(MockPaginationStrategy()).result({ _ in }, { _ in })
        
        #expect(client.invocation.executeRequest.isInvokedOnce)
        #expect(client.executeRequestInspector.path == "path/mock-resource")
        
        // http://jsonapi.org/format/#fetching-pagination
        let queryItem = try #require(client.executeRequestInspector.queryItems.first)
        #expect(queryItem.name == paginationQueryItem.name)
        #expect(queryItem.value == paginationQueryItem.value)
    }
    
    @Test("when fetching resource collection with page based pagination")
    func fetchingWithPageBasedPagination() throws {
        let client = MockClient()
        let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
        
        try sut.fetch().paginate(Pagination.PageBased(number: 1, size: 2)).result({ _ in }, { _ in })
        
        #expect(client.invocation.executeRequest.isInvokedOnce)
        #expect(client.executeRequestInspector.path == "path/mock-resource")
        
        // http://jsonapi.org/format/#fetching-pagination
        #expect(client.executeRequestInspector.queryItems == [
            URLQueryItem(name: "page[number]", value: "1"),
            URLQueryItem(name: "page[size]", value: "2")
        ])
    }
    
    @Test("when fetching resource collection with offset based pagination")
    func fetchingWithOffsetBasedPagination() throws {
        let client = MockClient()
        let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
        
        try sut.fetch().paginate(Pagination.OffsetBased(offset: 1, limit: 2)).result({ _ in }, { _ in })
        
        #expect(client.invocation.executeRequest.isInvokedOnce)
        #expect(client.executeRequestInspector.path == "path/mock-resource")
        
        // http://jsonapi.org/format/#fetching-pagination
        #expect(client.executeRequestInspector.queryItems == [
            URLQueryItem(name: "page[offset]", value: "1"),
            URLQueryItem(name: "page[limit]", value: "2")
        ])
    }
    
    @Test("when fetching resource collection with cursor based pagination")
    func fetchingWithCursorBasedPagination() throws {
        let client = MockClient()
        let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
        
        try sut.fetch().paginate(Pagination.CursorBased(cursor: "mock-cursor")).result({ _ in }, { _ in })
        
        #expect(client.invocation.executeRequest.isInvokedOnce)
        #expect(client.executeRequestInspector.path == "path/mock-resource")
        
        // http://jsonapi.org/format/#fetching-pagination
        #expect(client.executeRequestInspector.queryItems == [
            URLQueryItem(name: "page[cursor]", value: "mock-cursor")
        ])
    }
    
    @Test("when updating resource")
    func updatingResource() throws {
        let client = MockClient()
        let sut = DataSource<MockResource>(strategy: .path("path/<type>/<id>"), client: client)
        let resource = MockResource()
        resource.id = "mock"
        
        try sut.update(resource).result({ _ in }, { _ in })
        
        #expect(client.invocation.executeRequest.isInvokedOnce)
        #expect(client.executeRequestInspector.path == "path/mock-resource/mock")
    }
    
    @Test("when deleting resource")
    func deletingResource() throws {
        let client = MockClient()
        let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
        
        try sut.delete(id: "mock").result({}, { _ in })
        
        #expect(client.invocation.executeRequest.isInvokedOnce)
        #expect(client.executeRequestInspector.path == "path/mock-resource")
    }
}
