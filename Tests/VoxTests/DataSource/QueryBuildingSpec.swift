import Foundation
import Testing

@testable import Vox

fileprivate final class Song: Resource {
    override class var resourceType: String {
        "query-songs"
    }
}

@Suite("Query building")
struct QueryBuildingSpec {
    private let dataSource = DataSource<Song>(strategy: .path("songs"), client: RecordingClient())
    
    private func queryItems(of request: (DataSource<Song>) -> FetchRequest<Song, Document<[Song]>>) -> [URLQueryItem] {
        request(dataSource).makeQueryItems()
    }
    
    @Test("parameters are sent once, in a fixed order")
    func order() {
        let queryItems = queryItems {
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
    func includes() {
        let queryItems = queryItems {
            $0.fetch().include(["album", "artist"]).include(["artist", "album.label"])
        }
        
        #expect(queryItems == [URLQueryItem(name: "include", value: "album,artist,album.label")])
    }
    
    @Test("sort, filter and pagination are replaced by later calls")
    func replacements() {
        let queryItems = queryItems {
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
    func fields() {
        let queryItems = queryItems {
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
    func emptyParameters() {
        let queryItems = queryItems {
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
