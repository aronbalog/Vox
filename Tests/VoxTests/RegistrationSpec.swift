import Foundation
#if canImport(ObjectiveC)
import ObjectiveC
#endif
import Testing

@testable import Vox

fileprivate final class Galaxy: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "registration-galaxies"
    }
    
    var stars: [Star]?
}

fileprivate final class Star: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "registration-stars"
    }
    
    var name: String?
}

fileprivate class Planet: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "registration-planets"
    }
}

fileprivate final class DwarfPlanet: Planet, @unchecked Sendable {}

fileprivate final class GasGiant: Planet, @unchecked Sendable {
    override class var resourceType: String {
        "registration-gas-giants"
    }
}

fileprivate class RegistrationNebula: Resource, @unchecked Sendable {}

fileprivate final class RegistrationDarkNebula: RegistrationNebula, @unchecked Sendable {}

fileprivate final class Quasar: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "registration-quasars"
    }
}

fileprivate final class CoveragePrepared: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "coverage-prepared"
    }
}

fileprivate final class Blazar: Resource, @unchecked Sendable {
    override class var resourceType: String {
        "registration-quasars"
    }
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
        #expect(ResourceRuntime.resourceClass(for: "Resource") == nil)
    }
    
    @Test("classes that don't override resourceType are registered for their name")
    func defaultType() {
        RegistrationNebula.register()
        RegistrationDarkNebula.register()
        
        #expect(RegistrationNebula.resourceType == "RegistrationNebula")
        #expect(RegistrationDarkNebula.resourceType == "RegistrationDarkNebula")
        #expect(ResourceRuntime.resourceClass(for: "RegistrationNebula") == RegistrationNebula.self)
        #expect(ResourceRuntime.resourceClass(for: "RegistrationDarkNebula") == RegistrationDarkNebula.self)
        #expect(RegistrationDarkNebula().type == "RegistrationDarkNebula")
    }
    
    @Test("subclasses that inherit the type of their superclass aren't registered for it")
    func inheritedType() {
        DwarfPlanet.register()
        Planet.register()
        GasGiant.register()
        
        #expect(DwarfPlanet.resourceType == "registration-planets")
        #expect(ResourceRuntime.resourceClass(for: "registration-planets") == Planet.self)
        #expect(ResourceRuntime.resourceClass(for: "registration-gas-giants") == GasGiant.self)
    }
    
    @Test("the first class registered for a type keeps it")
    func duplicateType() {
        Quasar.register()
        let registeredClass = ResourceRuntime.resourceClass(for: "registration-quasars")
        Blazar.register()
        
        #expect(registeredClass == Quasar.self || registeredClass == Blazar.self)
        #expect(ResourceRuntime.resourceClass(for: "registration-quasars") == registeredClass)
    }
    
    @Test("creating an instance registers the class")
    func creatingRegisters() {
        _ = CoveragePrepared()
        
        #expect(ResourceRuntime.resourceClass(for: "coverage-prepared") == CoveragePrepared.self)
    }
    
    #if canImport(ObjectiveC)
    @Test("a class created after the last scan is found, and another miss does not scan again")
    func scanLoadedClasses() {
        let misses = ResourceGraph.lock.withLock {
            [
                ResourceRuntime.resourceClass(for: "coverage-absent-one"),
                ResourceRuntime.resourceClass(for: "coverage-absent-one"),
                ResourceRuntime.resourceClass(for: "coverage-absent-two")
            ]
        }
        
        #expect(misses.allSatisfy { $0 == nil })
        
        let found = ResourceGraph.lock.withLock { () -> Resource.Type? in
            let allocated: AnyClass = objc_allocateClassPair(Resource.self, "VoxCoverageDynamicResource", 0)!
            objc_registerClassPair(allocated)
            
            return ResourceRuntime.resourceClass(for: "VoxCoverageDynamicResource")
        }
        
        #expect(found == NSClassFromString("VoxCoverageDynamicResource") as? Resource.Type)
    }
    #endif
}
