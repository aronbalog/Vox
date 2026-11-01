import Foundation
import Testing

@testable import Vox

fileprivate class Player: Resource {
    override class var resourceType: String {
        return "Players"
    }
    
    @objc dynamic var items: [Resource]?
    @objc dynamic var titles: [String]?
}

fileprivate class Weapon: Resource {
    override class var resourceType: String {
        return "Weapons"
    }
    
    @objc dynamic var hint: String?
    @objc dynamic var shield: Shield?
}

fileprivate class Shield: Resource {
    override class var resourceType: String {
        return "Shields"
    }
    
    @objc dynamic var name: String?
}

@Suite("Deserializer when deserializing document with polymorphic objects in relationships")
struct DeserializerSinglePolymorphicSpec {
    let data = Data(jsonFileName: "DeserializerSinglePolymorphic")
    
    @Test("maps correctly")
    func mapsCorrectly() throws {
        let document = try Deserializer.Single<Player>().deserialize(data: data)
        let player = try #require(document.data)
        let items = try #require(player.items)
        
        let weapon = try #require(items.first as? Weapon)
        let shield = try #require(items.last as? Shield)
        
        #expect(weapon.hint == "A hint")
        #expect(weapon.shield != nil)
        #expect(shield.name == "A name")
        #expect(weapon.shield === shield)
    }
}
