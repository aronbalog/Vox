import UIKit
import Quick
import Nimble

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

class DeserializerSinglePolymorphic: QuickSpec {
    lazy var data = Data(jsonFileName: "DeserializerSinglePolymorphic")
    
    override func spec() {
        let sut = Deserializer.Single<Player>()

        describe("Deserializer") {
            context("when deserializing document with polymorphic objects in relationships", {
                let document = try? sut.deserialize(data: self.data)
                
                it("maps correctly", closure: {
                    let player = document?.data
                    expect(player).notTo(beNil())
                    
                    let items = player?.items
                    expect(items).notTo(beNil())
                    
                    let weapon = items?.first as? Weapon
                    let shield = items?.last as? Shield
                    
                    expect(weapon).to(beAKindOf(Weapon.self))
                    expect(weapon?.hint).to(equal("A hint"))
                    expect(weapon?.shield).notTo(beNil())
                    expect(shield).to(beAKindOf(Shield.self))
                    expect(shield?.name).to(equal("A name"))
                    
                    expect(weapon?.shield === shield).to(beTrue())
                })
            })
        }
    }
}
