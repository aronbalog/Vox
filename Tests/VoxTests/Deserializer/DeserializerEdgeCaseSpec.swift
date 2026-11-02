import Foundation
import Testing

@testable import Vox

fileprivate final class Planet: Resource {
    override class var resourceType: String {
        "edge-planets"
    }
    
    var name: String?
    var moons: [Moon]?
    var neighbours: [Resource]?
}

fileprivate final class Moon: Resource {
    override class var resourceType: String {
        "edge-moons"
    }
    
    var name: String?
}

@Suite("Deserializer edge cases")
struct DeserializerEdgeCaseSpec {
    init() {
        ResourceRuntime.register(Planet.self)
        ResourceRuntime.register(Moon.self)
    }
    
    private func single(_ json: String) throws -> Document<Planet> {
        try Deserializer.Single<Planet>().deserialize(data: Data(json.utf8))
    }
    
    private func collection(_ json: String) throws -> Document<[Planet]> {
        try Deserializer.Collection<Planet>().deserialize(data: Data(json.utf8))
    }
    
    private func expectInvalidDocument(_ reasonFragment: String, sourceLocation: SourceLocation = #_sourceLocation, _ body: () throws -> Void) {
        do {
            try body()
            Issue.record("Expected JSONAPIError.invalidDocument", sourceLocation: sourceLocation)
        } catch JSONAPIError.invalidDocument(let reason) {
            #expect(reason.contains(reasonFragment), "\(reason)", sourceLocation: sourceLocation)
        } catch {
            Issue.record("Unexpected error \(error)", sourceLocation: sourceLocation)
        }
    }
    
    @Test("null primary data decodes to nil")
    func nullData() throws {
        #expect(try single(#"{ "data": null }"#).data == nil)
        #expect(try collection(#"{ "data": null }"#).data == nil)
    }
    
    @Test("an empty collection decodes to an empty array")
    func emptyCollection() throws {
        #expect(try collection(#"{ "data": [] }"#).data?.isEmpty == true)
    }
    
    @Test("meta-only documents decode without data")
    func metaOnly() throws {
        let document = try single(#"{ "meta": { "count": 3 } }"#)
        
        #expect(document.data == nil)
        #expect(document.meta?["count"] as? Int == 3)
    }
    
    @Test("the jsonapi member is decoded")
    func jsonapiMember() throws {
        let document = try single(#"{ "data": null, "jsonapi": { "version": "1.1" } }"#)
        
        #expect(document.jsonapi?["version"] as? String == "1.1")
    }
    
    @Test("data that isn't a JSON:API document throws a descriptive error")
    func invalidDocuments() {
        expectInvalidDocument("valid JSON") { _ = try single("not json") }
        expectInvalidDocument("must be an object") { _ = try single("[]") }
        expectInvalidDocument("at least one of data, errors and meta") { _ = try single("{}") }
        expectInvalidDocument("primary data must be") { _ = try single(#"{ "data": 1 }"#) }
        expectInvalidDocument("data[1] isn't a resource object") { _ = try collection(#"{ "data": [{ "type": "edge-planets", "id": "1" }, 2] }"#) }
        expectInvalidDocument("data has no type") { _ = try single(#"{ "data": { "id": "1" } }"#) }
        expectInvalidDocument("included[0] has no type") { _ = try single(#"{ "data": null, "included": [{ "id": "1" }] }"#) }
        expectInvalidDocument("included member must be") { _ = try single(#"{ "data": null, "included": {} }"#) }
    }
    
    @Test("primary data of the wrong shape throws")
    func wrongShape() {
        expectInvalidDocument("primary data is an array") {
            _ = try single(#"{ "data": [] }"#)
        }
        expectInvalidDocument("primary data is a single resource") {
            _ = try collection(#"{ "data": { "type": "edge-planets", "id": "1" } }"#)
        }
    }
    
    @Test("primary data of another class throws")
    func unexpectedType() {
        expectInvalidDocument("type \"edge-moons\"") {
            _ = try single(#"{ "data": { "type": "edge-moons", "id": "1" } }"#)
        }
        expectInvalidDocument("type \"edge-moons\"") {
            _ = try collection(#"{ "data": [{ "type": "edge-planets", "id": "1" }, { "type": "edge-moons", "id": "2" }] }"#)
        }
    }
    
    @Test("resources of several classes decode as Resource")
    func heterogeneousCollection() throws {
        let json = #"{ "data": [{ "type": "edge-planets", "id": "1" }, { "type": "edge-moons", "id": "2" }, { "type": "edge-comets", "id": "3" }] }"#
        let resources = try #require(try Deserializer.Collection<Resource>().deserialize(data: Data(json.utf8)).data)
        
        #expect(resources.count == 3)
        #expect(resources[0] is Planet)
        #expect(resources[1] is Moon)
        #expect(resources[2].type == "edge-comets")
    }
    
    @Test("resources of types without a class decode as plain resources")
    func unknownTypes() throws {
        let document = try single("""
        {
            "data": {
                "type": "edge-planets",
                "id": "earth",
                "relationships": {
                    "moons": { "data": [{ "type": "edge-moons", "id": "moon" }, { "type": "edge-asteroids", "id": "ceres" }] },
                    "neighbours": { "data": [{ "type": "edge-planets", "id": "mars" }, { "type": "edge-asteroids", "id": "ceres" }] }
                }
            },
            "included": [
                { "type": "edge-moons", "id": "moon", "attributes": { "name": "Moon" } },
                { "type": "edge-planets", "id": "mars", "attributes": { "name": "Mars" } },
                { "type": "edge-asteroids", "id": "ceres", "attributes": { "name": "Ceres" } }
            ]
        }
        """)
        let planet = try #require(document.data)
        
        let moons = try #require(planet["moons"] as? [Moon])
        #expect(moons.map(\.id) == ["moon"])
        
        let neighbours = try #require(planet["neighbours"] as? [Resource])
        #expect(neighbours.map(\.type) == ["edge-planets", "edge-asteroids"])
        #expect(neighbours[1].attributes["name"] as? String == "Ceres")
    }
    
    @Test("integer ids are converted to strings")
    func integerIdentifiers() throws {
        let document = try single("""
        {
            "data": {
                "type": "edge-planets",
                "id": 3,
                "relationships": { "moons": { "data": [{ "type": "edge-moons", "id": 1 }] } }
            },
            "included": [{ "type": "edge-moons", "id": 1, "attributes": { "name": "Moon" } }]
        }
        """)
        let planet = try #require(document.data)
        
        #expect(planet.id == "3")
        #expect((planet["moons"] as? [Moon])?.first?["name"] as? String == "Moon")
    }
    
    @Test("resource objects without id are decoded")
    func missingIdentifier() throws {
        let planet = try #require(try single(#"{ "data": { "type": "edge-planets", "attributes": { "name": "X" } } }"#).data)
        
        #expect(planet.id == nil)
        #expect(planet["name"] as? String == "X")
    }
    
    @Test("a resource contained more than once is merged")
    func duplicates() throws {
        let document = try single("""
        {
            "data": {
                "type": "edge-planets",
                "id": "earth",
                "attributes": { "name": "Earth" }
            },
            "included": [
                {
                    "type": "edge-planets",
                    "id": "earth",
                    "attributes": { "name": "Terra", "radius": 6371 },
                    "relationships": { "moons": { "data": [] } }
                }
            ]
        }
        """)
        let planet = try #require(document.data)
        
        #expect(planet["name"] as? String == "Earth")
        #expect(planet.attributes["radius"] as? Int == 6371)
        #expect((planet["moons"] as? [Moon])?.isEmpty == true)
    }
    
    @Test("errors take precedence over data")
    func errorsAndData() throws {
        let json = #"{ "data": null, "errors": [{ "status": 422, "code": 7, "source": { "header": "Authorization" } }, "garbage"] }"#
        
        do {
            _ = try single(json)
            Issue.record("Expected JSONAPIError.API")
        } catch JSONAPIError.API(let errors) {
            #expect(errors.count == 1)
            #expect(errors.first?.status == "422")
            #expect(errors.first?.code == "7")
            #expect(errors.first?.source?.header == "Authorization")
        }
    }
}
