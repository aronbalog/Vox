import Foundation
import Testing

import Vox

fileprivate final class Album: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "subscript-albums"
    }
    
    override class var codingKeys: [String: String] {
        ["releaseYear": "release-year"]
    }
    
    var title: String?
    var releaseYear: Int?
    var band: Band?
}

fileprivate final class Band: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "subscript-bands"
    }
}

@Suite("Member subscript")
struct SubscriptSpec {
    @Test("attributes and relationships are read and written by name")
    func readWrite() throws {
        let album = Album()
        let band = Band()
        band.id = "b1"
        
        album["title"] = "Kind of Blue"
        album["releaseYear"] = 1959
        album["band"] = band
        album["label"] = "Columbia"
        
        #expect(album["title"] as? String == "Kind of Blue")
        #expect(album["release-year"] as? Int == 1959)
        #expect(album["band"] as? Band === band)
        #expect(album.attributes["release-year"] as? Int == 1959)
        #expect(album.attributes["label"] as? String == "Columbia")
        
        album["title"] = String.null
        album["label"] = nil
        
        let attributes = try #require(try album.documentDictionary()["data"] as? [String: Any])["attributes"] as? [String: Any]
        #expect(attributes?["title"] is NSNull)
        #expect(attributes?["label"] == nil)
    }
    
    @Test("id and lid can be set, type is read-only")
    func identity() {
        let album = Album()
        
        album["id"] = "a1"
        album["lid"] = "local"
        album["type"] = "other"
        
        #expect(album.id == "a1")
        #expect(album.lid == "local")
        #expect(album["type"] as? String == "subscript-albums")
    }
}
