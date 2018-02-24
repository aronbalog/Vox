import UIKit
import Quick
import Nimble

@testable import Vox


fileprivate class Player: Resource {
    override class var resourceType: String {
        return "Player"
    }
    
    @objc dynamic var items: [Resource]?
    @objc dynamic var titles: [String]?
}

fileprivate class Weapon: Resource {
    override class var resourceType: String {
        return "Weapon"
    }
    
    @objc dynamic var hint: String?
    @objc dynamic var shield: Shield?
}

fileprivate class Shield: Resource {
    override class var resourceType: String {
        return "Shield"
    }
    
    @objc dynamic var name: String?
}

class DeserializingSpec: QuickSpec {
    let data = Data(jsonFileName: "Player")
    
    override func spec() {
        let deserializer = Deserializer.Single<Player>()
        
        describe("Deserializer") {
            context("when deserializing document with polymorphic objects in relationships", {
                let document: Document<Player> = try! deserializer.deserialize(data: self.data)
                
                it("maps correctly", closure: {
                    let player = document.data
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

