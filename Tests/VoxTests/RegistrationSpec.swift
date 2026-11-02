import Foundation
import Testing

@testable import Vox

fileprivate final class Galaxy: Resource, @unchecked Sendable {
    override class var resourceType: String {
        return "registration-galaxies"
    }
    
    var stars: [Star]?
}

fileprivate final class Star: Resource, @unchecked Sendable {
    override class var resourceType: String {
        return "registration-stars"
    }
    
    var name: String?
}

fileprivate let galaxyJSON = #"""
{
    "data": {
        "type": "registration-galaxies",
        "id": "1",
        "relationships": {
            "stars": { "data": [{ "type": "registration-stars", "id": "s1" }] }
        }
    },
    "included": [{ "type": "registration-stars", "id": "s1", "attributes": { "name": "Sol" } }]
}
"""#

@Suite("Registration")
struct RegistrationSpec {
    @Test("registered classes are used for related and included resources")
    func registered() throws {
        Star.register()
        
        let galaxy = try #require(try Deserializer.Single<Galaxy>().deserialize(data: Data(galaxyJSON.utf8)).data)
        let star = try #require((galaxy["stars"] as? [Star])?.first)
        
        #expect(star["name"] as? String == "Sol")
    }
    
    @Test("registering Resource itself does nothing")
    func base() {
        Resource.register()
        
        #expect(ResourceRuntime.resourceClass(for: "registration-unknown") == nil)
    }
}
