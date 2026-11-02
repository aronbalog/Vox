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
    
    @Test("members without a property hold related resources, arrays of them and null")
    func undeclaredMembers() throws {
        let album = Album()
        let band = Band()
        band.id = "b1"
        let producer = Band()
        producer.id = "b2"
        
        album["musicians"] = [band, producer]
        album["producer"] = producer
        album["genres"] = [String]()
        
        #expect((album["musicians"] as? [Resource])?.map(\.id) == ["b1", "b2"])
        #expect(album["producer"] as? Band === producer)
        #expect(album.attributes["genres"] as? [String] == [])
        #expect(album["unknown"] == nil)
        
        album["musicians"] = [Band]()
        album["guests"] = [Band].null
        album["producer"] = Band.null()
        album["label"] = String.null
        
        #expect((album["musicians"] as? [Resource])?.isEmpty == true)
        #expect((album["guests"] as? [Resource])?.isEmpty == true)
        #expect(album["producer"] == nil)
        #expect(album["label"] == nil)
        
        let data = try #require(try album.documentDictionary()["data"] as? [String: Any])
        let relationships = try #require(data["relationships"] as? [String: Any])
        #expect(((relationships["musicians"] as? [String: Any])?["data"] as? [Any])?.isEmpty == true)
        #expect(((relationships["guests"] as? [String: Any])?["data"] as? [Any])?.isEmpty == true)
        #expect((relationships["producer"] as? [String: Any])?["data"] is NSNull)
        #expect((data["attributes"] as? [String: Any])?["label"] is NSNull)
    }
    
    @Test("id and lid can be set, type is read-only")
    func identity() {
        let album = Album()
        
        album["id"] = "a1"
        album["lid"] = "local"
        album["type"] = "other"
        
        #expect(album.id == "a1")
        #expect(album.lid == "local")
        #expect(album["id"] as? String == "a1")
        #expect(album["lid"] as? String == "local")
        #expect(album["type"] as? String == "subscript-albums")
    }
}
