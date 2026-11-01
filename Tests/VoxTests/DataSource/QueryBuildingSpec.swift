import Foundation
import Testing

@testable import Vox

fileprivate final class Song: Resource {
    override class var resourceType: String {
        return "query-songs"
    }
}

fileprivate final class QueryRecordingClient: Client {
    var queryItems: [URLQueryItem]?
    
    func executeRequest(path: String, method: String, queryItems: [URLQueryItem], bodyParameters: [String: Any]?, success: @escaping ClientSuccessBlock, failure: @escaping ClientFailureBlock, userInfo: [String: Any]) {
        self.queryItems = queryItems
    }
}

@Suite("Query building")
struct QueryBuildingSpec {
    private let client = QueryRecordingClient()
    
    private func queryItems(of request: (DataSource<Song>) -> FetchRequest<Song, DataSource<Song>.ResourceCollectionSuccessBlock>) throws -> [URLQueryItem] {
        try request(DataSource<Song>(strategy: .path("songs"), client: client)).result({ _ in }, nil)
        
        return try #require(client.queryItems)
    }
    
    @Test("parameters are sent once, in a fixed order")
    func order() throws {
        let queryItems = try queryItems {
            $0.fetch()
                .queryItems([URLQueryItem(name: "custom", value: "1")])
                .paginate(Pagination.PageBased(number: 2))
                .sort([.descending("year")])
                .include(["album"])
                .filter(Filter(["genre": "jazz"]))
                .fields(["query-songs": ["title"], "albums": ["name"]])
        }
        
        #expect(queryItems == [
            URLQueryItem(name: "fields[albums]", value: "name"),
            URLQueryItem(name: "fields[query-songs]", value: "title"),
            URLQueryItem(name: "filter[genre]", value: "jazz"),
            URLQueryItem(name: "include", value: "album"),
            URLQueryItem(name: "sort", value: "-year"),
            URLQueryItem(name: "page[number]", value: "2"),
            URLQueryItem(name: "custom", value: "1")
        ])
    }
    
    @Test("includes accumulate without duplicates")
    func includes() throws {
        let queryItems = try queryItems {
            $0.fetch().include(["album", "artist"]).include(["artist", "album.label"])
        }
        
        #expect(queryItems == [URLQueryItem(name: "include", value: "album,artist,album.label")])
    }
    
    @Test("sort, filter and pagination are replaced by later calls")
    func replacements() throws {
        let queryItems = try queryItems {
            $0.fetch()
                .sort([.ascending("title")])
                .sort([.descending("year"), .ascending("title")])
                .filter(Filter(["genre": "rock"]))
                .filter(Filter(["genre": "jazz"]))
                .paginate(Pagination.OffsetBased(offset: 0, limit: 10))
                .paginate(Pagination.CursorBased(cursor: "abc"))
        }
        
        #expect(queryItems == [
            URLQueryItem(name: "filter[genre]", value: "jazz"),
            URLQueryItem(name: "sort", value: "-year,title"),
            URLQueryItem(name: "page[cursor]", value: "abc")
        ])
    }
    
    @Test("fields are merged per type, and an empty list requests no fields")
    func fields() throws {
        let queryItems = try queryItems {
            $0.fetch()
                .fields(["query-songs": ["title"], "albums": ["name"]])
                .fields(["query-songs": ["title", "year"], "artists": []])
        }
        
        #expect(queryItems == [
            URLQueryItem(name: "fields[albums]", value: "name"),
            URLQueryItem(name: "fields[artists]", value: ""),
            URLQueryItem(name: "fields[query-songs]", value: "title,year")
        ])
    }
    
    @Test("empty includes and sorts are left out")
    func emptyParameters() throws {
        let queryItems = try queryItems {
            $0.fetch().include([]).sort([])
        }
        
        #expect(queryItems.isEmpty)
    }
    
    @Test("filters are sorted by field")
    func filterOrder() {
        let filter = Filter(["year": "1959", "artist": "Miles Davis", "genre": "jazz"])
        
        #expect(filter.filterURLQueryItems().map(\.name) == ["filter[artist]", "filter[genre]", "filter[year]"])
    }
}
