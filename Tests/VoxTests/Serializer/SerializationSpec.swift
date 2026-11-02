import Foundation
import Testing

@testable import Vox

fileprivate final class Track: Resource {
    override class var resourceType: String {
        "serialization-tracks"
    }
    
    var title: String?
    var plays: NSNumber?
    var tags: [String]?
    var credits: [String: Any]?
    var artist: Artist?
    var remixes: [Track]?
}

fileprivate final class Artist: Resource {
    override class var resourceType: String {
        "serialization-artists"
    }
}

@Suite("Serialization")
struct SerializationSpec {
    private func data(of resource: Resource) throws -> [String: Any] {
        try #require(try resource.documentDictionary()["data"] as? [String: Any])
    }
    
    private func expectSerializationError(_ reasonFragment: String, sourceLocation: SourceLocation = #_sourceLocation, _ body: () throws -> Void) {
        do {
            try body()
            Issue.record("Expected JSONAPIError.serialization", sourceLocation: sourceLocation)
        } catch JSONAPIError.serialization(let reason) {
            #expect(reason.contains(reasonFragment), "\(reason)", sourceLocation: sourceLocation)
        } catch {
            Issue.record("Unexpected error \(error)", sourceLocation: sourceLocation)
        }
    }
    
    @Test("null placeholders are sent as null and nil leaves members out")
    func nullPlaceholders() throws {
        let track = Track()
        track["title"] = String.null
        track["plays"] = NSNumber.null
        track["tags"] = [String].null
        track["credits"] = [String: Any].null
        track["artist"] = Artist.null()
        track["remixes"] = [Track].null
        track["subtitle"] = "set"
        track["subtitle"] = nil
        
        let data = try data(of: track)
        let attributes = try #require(data["attributes"] as? [String: Any])
        let relationships = try #require(data["relationships"] as? [String: Any])
        
        #expect(Set(attributes.keys) == ["title", "plays", "tags", "credits"])
        #expect(attributes.values.allSatisfy { $0 is NSNull })
        #expect((relationships["artist"] as? [String: Any])?["data"] is NSNull)
        #expect(((relationships["remixes"] as? [String: Any])?["data"] as? [Any])?.isEmpty == true)
    }
    
    @Test("the largest 32-bit integer is sent as a number")
    func largeNumbers() throws {
        let track = Track()
        track["plays"] = NSNumber(value: Int32.max)
        
        let attributes = try #require(try data(of: track)["attributes"] as? [String: Any])
        #expect(attributes["plays"] as? Int == Int(Int32.max))
    }
    
    @Test("meta is sent with the resource")
    func meta() throws {
        let track = Track()
        track.id = "1"
        track.meta = ["revision": 2]
        
        #expect((try data(of: track)["meta"] as? [String: Any])?["revision"] as? Int == 2)
    }
    
    @Test("values that can't be represented in JSON throw instead of crashing")
    func invalidValues() {
        expectSerializationError("attribute \"title\"") {
            let track = Track()
            track["title"] = Data()
            _ = try track.documentData()
        }
        expectSerializationError("attribute \"plays\"") {
            let track = Track()
            track["plays"] = NSNumber(value: Double.infinity)
            _ = try track.documentDictionary()
        }
        expectSerializationError("meta") {
            let track = Track()
            track.meta = ["value": Data()]
            _ = try track.documentData()
        }
    }
    
    @Test("serialization errors name what's missing")
    func missingIdentifiers() {
        expectSerializationError("relationship \"artist\"") {
            let track = Track()
            track["artist"] = Artist()
            _ = try track.documentData()
        }
        expectSerializationError("neither id nor lid") {
            _ = try [Track()].documentData()
        }
    }
    
    @Test("received relationships without data are not sent")
    func relationshipsWithoutData() throws {
        let json = """
        {
            "data": {
                "type": "serialization-tracks",
                "id": "1",
                "relationships": {
                    "artist": { "links": { "related": "/tracks/1/artist" } },
                    "remixes": { "data": [{ "type": "serialization-tracks", "id": "2", "meta": { "order": 1 } }] }
                }
            }
        }
        """
        ResourceRuntime.register(Track.self)
        let track = try #require(try Deserializer.Single<Track>().deserialize(data: Data(json.utf8)).data)
        
        let relationships = try #require(try data(of: track)["relationships"] as? [String: Any])
        #expect(Set(relationships.keys) == ["remixes"])
        
        let remixes = try #require((relationships["remixes"] as? [String: Any])?["data"] as? [[String: Any]])
        #expect((remixes.first?["meta"] as? [String: Any])?["order"] as? Int == 1)
    }
    
    @Test("document data is valid JSON")
    func documentData() throws {
        let artist = Artist()
        artist.id = "a"
        
        let track = Track()
        track.id = "t"
        track["title"] = "Song"
        track["tags"] = ["a", "b"]
        track["artist"] = artist
        
        let json = try JSONSerialization.jsonObject(with: try track.documentData()) as? [String: Any]
        let data = try #require(json?["data"] as? [String: Any])
        
        #expect(data["id"] as? String == "t")
        #expect((data["attributes"] as? [String: Any])?["tags"] as? [String] == ["a", "b"])
    }
}
