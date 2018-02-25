import UIKit
import Quick
import Nimble

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
        var singleFetchId: String!
        var singleFetchType: Resource.Type!
        var collectionFetchType: Resource.Type!
        var createResource: Resource!
        var updateResource: Resource!
        var deleteId: String!
        var deleteType: Resource.Type!
        
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
        var path: String!
        var queryItems: [URLQueryItem] = []
    }
    
    let invocation = Invocation()
    let executeRequestInspector = ExecuteRequestInspector()
    
    func executeRequest(_ path: String, method: String, queryItems: [URLQueryItem], parameters: [String : Any]?, success: @escaping ClientSuccessBlock, _ failure: @escaping ClientFailureBlock) {
        invocation.executeRequest.invoke()
        executeRequestInspector.path = path
        executeRequestInspector.queryItems = queryItems
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

class DataSourceSpec: QuickSpec {
    
    override func spec() {
        describe("DataSource with router and client") {
            context("when creating resource", {
                let client = MockClient()
                let router = MockRouter()
                let sut = DataSource(strategy: .router(router), client: client)
                let resource = MockResource()
                
                try! sut.create(resource).result({ (document) in
                    
                }, { (error) in
                    
                })
                
                it("invokes execute request on client", closure: {
                    expect(client.invocation.executeRequest.isInvokedOnce).to(beTrue())
                })
                
                it("invokes correct method on router", closure: {
                    expect(router.invocation.create.isInvokedOnce).to(beTrue())
                })
                
                it("passes correct parameters to router", closure: {
                    expect(router.inspector.createResource === resource).to(beTrue())
                })
                
                it("client receives correct data from router for execution", closure: {
                    expect(client.executeRequestInspector.path).to(equal(createPath))
                })
            })
            
            context("when fetching single resource", {
                let client = MockClient()
                let router = MockRouter()
                let filterStrategy = MockFilterStrategy()
                let sut = DataSource<MockResource>(strategy: .router(router), client: client)
                
                try! sut
                    .fetch(id: "mock")
                    .fields([
                        "key": ["value1", "value2"]
                        ])
                    .filter(filterStrategy)
                    .include(["include1", "include2"])
                    .sort([
                        .ascending("value1"),
                        .descending("value2")
                        ])
                    .result({ (document) in
                        
                    }, { (error) in
                        
                    })
                
                
                it("invokes execute request on client", closure: {
                    expect(client.invocation.executeRequest.isInvokedOnce).to(beTrue())
                })
                
                it("invokes correct method on router", closure: {
                    expect(router.invocation.fetchSingle.isInvokedOnce).to(beTrue())
                })
                
                it("passes correct parameters to router", closure: {
                    expect(router.inspector.singleFetchType).notTo(beNil())
                    expect(router.inspector.singleFetchId).to(equal("mock"))
                })
                
                it("client receives correct data from router for execution", closure: {
                    expect(client.executeRequestInspector.path).to(equal(fetchSinglePath))
                    
                    let queryItems = client.executeRequestInspector.queryItems
                    
                    expect(queryItems.count).to(equal(4))
                    
                    let fieldsQueryItem = queryItems[0]
                    
                    // http://jsonapi.org/format/#fetching-sparse-fieldsets
                    expect(fieldsQueryItem.name).to(equal("fields[key]"))
                    expect(fieldsQueryItem.value).to(equal("value1,value2"))
                    
                    let filterQueryItem = queryItems[1]
                    
                    // http://jsonapi.org/format/#fetching-filtering
                    expect(filterQueryItem.name).to(equal(filterQueryItem.name))
                    expect(filterQueryItem.value).to(equal(filterQueryItem.value))
                    
                    let includeQueryItem = queryItems[2]
                    
                    // http://jsonapi.org/format/#fetching-includes
                    expect(includeQueryItem.name).to(equal("include"))
                    expect(includeQueryItem.value).to(equal("include1,include2"))
                    
                    let sortQueryItem = queryItems[3]
                    
                    // http://jsonapi.org/format/#fetching-sorting
                    expect(sortQueryItem.name).to(equal("sort"))
                    expect(sortQueryItem.value).to(equal("value1,-value2"))
                })
            })
            
            context("when fetching resource collection", {
                let client = MockClient()
                let router = MockRouter()
                let paginationStrategy = MockPaginationStrategy()
                
                let sut = DataSource<MockResource>(strategy: .router(router), client: client)
                
                try! sut.fetch().paginate(paginationStrategy).result({ (document) in
                    
                }, { (error) in
                    
                })
                
                it("invokes execute request on client", closure: {
                    expect(client.invocation.executeRequest.isInvokedOnce).to(beTrue())
                })
                
                it("invokes correct method on router", closure: {
                    expect(router.invocation.fetchCollection.isInvokedOnce).to(beTrue())
                })
                
                it("passes correct parameters to router", closure: {
                    expect(router.inspector.collectionFetchType).notTo(beNil())
                })
                
                it("client receives correct data from router for execution", closure: {
                    expect(client.executeRequestInspector.path).to(equal(fetchCollectionPath))
                    expect(client.executeRequestInspector.path).to(equal(fetchCollectionPath))
                    
                    let queryItems = client.executeRequestInspector.queryItems

                    let _paginationQueryItem = queryItems[0]
                    
                    // http://jsonapi.org/format/#fetching-pagination
                    expect(_paginationQueryItem.name).to(equal(paginationQueryItem.name))
                    expect(_paginationQueryItem.value).to(equal(paginationQueryItem.value))
                })
            })
            
            context("when updating resource", {
                let client = MockClient()
                let router = MockRouter()
                let sut = DataSource(strategy: .router(router), client: client)
                let resource = MockResource()
                
                try! sut.update(resource).result({ (document) in
                    
                }, { (error) in
                    
                })
                
                it("invokes execute request on client", closure: {
                    expect(client.invocation.executeRequest.isInvokedOnce).to(beTrue())
                })
                
                it("invokes correct method on router", closure: {
                    expect(router.invocation.update.isInvokedOnce).to(beTrue())
                })
                
                it("passes correct parameters to router", closure: {
                    expect(router.inspector.updateResource === resource).to(beTrue())
                })
                
                it("client receives correct data from router for execution", closure: {
                    expect(client.executeRequestInspector.path).to(equal(updatePath))
                })
            })
            
            context("when deleting resource", {
                let client = MockClient()
                let router = MockRouter()
                let sut = DataSource<MockResource>(strategy: .router(router), client: client)
                
                try! sut.delete(id: "mock").result({
                    
                }, { (error) in
                    
                })
                
                it("invokes execute request on client", closure: {
                    expect(client.invocation.executeRequest.isInvokedOnce).to(beTrue())
                })
                
                it("invokes correct method on router", closure: {
                    expect(router.invocation.delete.isInvokedOnce).to(beTrue())
                })
                
                it("passes correct parameters to router", closure: {
                    expect(router.inspector.deleteId).to(equal("mock"))
                    expect(router.inspector.deleteType).notTo(beNil())
                })
                
                it("client receives correct data from router for execution", closure: {
                    expect(client.executeRequestInspector.path).to(equal(deletePath))
                })
            })
        }
        
        describe("DataSource with path and client") {
            context("when creating resource", {
                let client = MockClient()
                let sut = DataSource(strategy: .path(immutablePath), client: client)
                let resource = MockResource()
                
                try! sut.create(resource).result({ (document) in
                    
                }, { (error) in
                    
                })
                
                it("invokes execute request on client", closure: {
                    expect(client.invocation.executeRequest.isInvokedOnce).to(beTrue())
                })

                it("client receives correct data for execution", closure: {
                    expect(client.executeRequestInspector.path).to(equal("path/mock-resource"))
                })
            })
            
            context("when fetching single resource", {
                let client = MockClient()
                let filterStrategy = MockFilterStrategy()
                let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
                try! sut
                    .fetch(id: "mock")
                    .fields([
                        "key": ["value1", "value2"]
                        ])
                    .filter(filterStrategy)
                    .include(["include1", "include2"])
                    .sort([
                        .ascending("value1"),
                        .descending("value2")
                        ])
                    .result({ (document) in
                        
                    }, { (error) in
                        
                    })
                
                
                it("invokes execute request on client", closure: {
                    expect(client.invocation.executeRequest.isInvokedOnce).to(beTrue())
                })
                
                it("client receives correct data for execution", closure: {
                    expect(client.executeRequestInspector.path).to(equal("path/mock-resource"))
                    
                    let queryItems = client.executeRequestInspector.queryItems
                    
                    expect(queryItems.count).to(equal(4))
                    
                    let fieldsQueryItem = queryItems[0]
                    
                    // http://jsonapi.org/format/#fetching-sparse-fieldsets
                    expect(fieldsQueryItem.name).to(equal("fields[key]"))
                    expect(fieldsQueryItem.value).to(equal("value1,value2"))
                    
                    let filterQueryItem = queryItems[1]
                    
                    // http://jsonapi.org/format/#fetching-filtering
                    expect(filterQueryItem.name).to(equal(filterQueryItem.name))
                    expect(filterQueryItem.value).to(equal(filterQueryItem.value))
                    
                    let includeQueryItem = queryItems[2]
                    
                    // http://jsonapi.org/format/#fetching-includes
                    expect(includeQueryItem.name).to(equal("include"))
                    expect(includeQueryItem.value).to(equal("include1,include2"))
                    
                    let sortQueryItem = queryItems[3]
                    
                    // http://jsonapi.org/format/#fetching-sorting
                    expect(sortQueryItem.name).to(equal("sort"))
                    expect(sortQueryItem.value).to(equal("value1,-value2"))
                    
                })
            })
            
            context("when fetching resource collection with custom pagination", {
                let client = MockClient()
                let paginationStrategy = MockPaginationStrategy()
                let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
                
                try! sut.fetch().paginate(paginationStrategy).result({ (document) in
                    
                }, { (error) in
                    
                })
                
                it("invokes execute request on client", closure: {
                    expect(client.invocation.executeRequest.isInvokedOnce).to(beTrue())
                })
                
                it("client receives correct data for execution", closure: {
                    expect(client.executeRequestInspector.path).to(equal("path/mock-resource"))
                    
                    let queryItems = client.executeRequestInspector.queryItems

                    let _paginationQueryItem = queryItems[0]
                    
                    // http://jsonapi.org/format/#fetching-pagination
                    expect(_paginationQueryItem.name).to(equal(paginationQueryItem.name))
                    expect(_paginationQueryItem.value).to(equal(paginationQueryItem.value))
                })
            })
            
            context("when fetching resource collection with page based pagination", {
                let client = MockClient()
                let paginationStrategy = Pagination.PageBased(number: 1, size: 2)
                let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
                
                try! sut.fetch().paginate(paginationStrategy).result({ (document) in
                    
                }, { (error) in
                    
                })
                
                it("invokes execute request on client", closure: {
                    expect(client.invocation.executeRequest.isInvokedOnce).to(beTrue())
                })
                
                it("client receives correct data for execution", closure: {
                    expect(client.executeRequestInspector.path).to(equal("path/mock-resource"))
                    
                    let queryItems = client.executeRequestInspector.queryItems
                    
                    var _paginationQueryItem = queryItems[0]
                    
                    // http://jsonapi.org/format/#fetching-pagination
                    expect(_paginationQueryItem.name).to(equal("page[number]"))
                    expect(_paginationQueryItem.value).to(equal("1"))
                    
                    _paginationQueryItem = queryItems[1]
                    
                    // http://jsonapi.org/format/#fetching-pagination
                    expect(_paginationQueryItem.name).to(equal("page[size]"))
                    expect(_paginationQueryItem.value).to(equal("2"))
                })
            })
            
            context("when fetching resource collection with offset based pagination", {
                let client = MockClient()
                let paginationStrategy = Pagination.OffsetBased(offset: 1, limit: 2)
                let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
                
                try! sut.fetch().paginate(paginationStrategy).result({ (document) in
                    
                }, { (error) in
                    
                })
                
                it("invokes execute request on client", closure: {
                    expect(client.invocation.executeRequest.isInvokedOnce).to(beTrue())
                })
                
                it("client receives correct data for execution", closure: {
                    expect(client.executeRequestInspector.path).to(equal("path/mock-resource"))
                    
                    let queryItems = client.executeRequestInspector.queryItems
                    
                    var _paginationQueryItem = queryItems[0]
                    
                    // http://jsonapi.org/format/#fetching-pagination
                    expect(_paginationQueryItem.name).to(equal("page[offset]"))
                    expect(_paginationQueryItem.value).to(equal("1"))
                    
                    _paginationQueryItem = queryItems[1]
                    
                    // http://jsonapi.org/format/#fetching-pagination
                    expect(_paginationQueryItem.name).to(equal("page[limit]"))
                    expect(_paginationQueryItem.value).to(equal("2"))
                })
            })
            
            context("when fetching resource collection with cursor based pagination", {
                let client = MockClient()
                let paginationStrategy = Pagination.CursorBased(cursor: "mock-cursor")
                let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
                
                try! sut.fetch().paginate(paginationStrategy).result({ (document) in
                    
                }, { (error) in
                    
                })
                
                it("invokes execute request on client", closure: {
                    expect(client.invocation.executeRequest.isInvokedOnce).to(beTrue())
                })
                
                it("client receives correct data for execution", closure: {
                    expect(client.executeRequestInspector.path).to(equal("path/mock-resource"))
                    
                    let queryItems = client.executeRequestInspector.queryItems
                    
                    let _paginationQueryItem = queryItems[0]
                    
                    // http://jsonapi.org/format/#fetching-pagination
                    expect(_paginationQueryItem.name).to(equal("page[cursor]"))
                    expect(_paginationQueryItem.value).to(equal("mock-cursor"))
                })
            })
            
            context("when updating resource", {
                let client = MockClient()
                let sut = DataSource(strategy: .path(immutablePath), client: client)
                let resource = MockResource()
                
                try! sut.update(resource).result({ (document) in
                    
                }, { (error) in
                    
                })
                
                it("invokes execute request on client", closure: {
                    expect(client.invocation.executeRequest.isInvokedOnce).to(beTrue())
                })
                
                it("client receives correct data for execution", closure: {
                    expect(client.executeRequestInspector.path).to(equal("path/mock-resource"))
                })
            })
            
            context("when deleting resource", {
                let client = MockClient()
                let sut = DataSource<MockResource>(strategy: .path(immutablePath), client: client)
                
                try! sut.delete(id: "mock").result({
                    
                }, { (error) in
                    
                })
                
                it("invokes execute request on client", closure: {
                    expect(client.invocation.executeRequest.isInvokedOnce).to(beTrue())
                })
                
                
                it("client receives correct data for execution", closure: {
                    expect(client.executeRequestInspector.path).to(equal("path/mock-resource"))
                })
            })
        }
    }
}
