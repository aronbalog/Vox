import UIKit
import Quick
import Nimble

@testable import Vox

fileprivate class Person: Resource {
    override class var resourceType: String {
        return "Person"
    }
    
    @objc dynamic var name: String?
    @objc dynamic var age: NSNumber?
    @objc dynamic var isHappy: NSNumber?
    @objc dynamic var bestFriend: Person?
    @objc dynamic var goodFriends: [Person]?
    @objc dynamic var favoriteWords: [String]?
    @objc dynamic var items: [Resource]?
}

fileprivate class Cellphone: Resource {
    override class var resourceType: String {
        return "Cellphone"
    }
}

fileprivate class Wallet: Resource {
    override class var resourceType: String {
        return "Wallet"
    }
}

class PropertyAccessorSpec: QuickSpec {
    override func spec() {
        describe("resource") {
            let person = Person()
            
            context("when values are set to properties", {
                person.id = "MOCK-ID"
                person.name = "MOCK"
                person.age = 28
                person.isHappy = true
                person.favoriteWords = ["vox", "bucks"]

                let bestFriend = Person()
                bestFriend.id = "FRIEND-ID"
                
                let anotherFriend = Person()
                anotherFriend.id = "ANOTHER-FRIEND-ID"
                
                person.bestFriend = bestFriend
                person.goodFriends = [bestFriend, anotherFriend]
                
                let wallet = Wallet(context: person.context)
                wallet.id = "wallet id"
                let cellphone = Cellphone()
                cellphone.id = "cellphone id"
                
                person.items = [wallet, cellphone]

                it("values are accessible", closure: {
                    expect(person.name).to(equal("MOCK"))
                    expect(person["name"] as? String).to(equal("MOCK"))
                    
                    expect(person.age).to(equal(28))
                    expect(person["age"] as? Int).to(equal(28))
                    
                    expect(person.isHappy as? Bool).to(beTrue())
                    expect(person["isHappy"] as? Bool).to(beTrue())
                    
                    expect(person.favoriteWords).to(equal(["vox", "bucks"]))
                    expect(person["favoriteWords"] as? [String]).to(equal(["vox", "bucks"]))

                    expect(person.bestFriend).to(equal(bestFriend))
                    expect(person["bestFriend"] as? Resource).to(equal(bestFriend))

                    expect(person.goodFriends).to(haveCount(2))
                    expect(person.goodFriends?[0] === bestFriend).to(beTrue())
                    expect(person.goodFriends?[1] === anotherFriend).to(beTrue())
                    
                    expect(person.items).to(haveCount(2))
                    expect(person.items?[0] === wallet).to(beTrue())
                    expect(person.items?[1] === cellphone).to(beTrue())

                })
                
                let documentDictionary = person.documentDictionary
                
                let data = person.documentData
                
                let string = String(data: data, encoding: .utf8)!
                
                print(string)
                
                it("can export document dictionary", closure: {
                    expect(documentDictionary).notTo(beNil())
                })
            })
        }
        
        describe("resource") {
            let person = Person()
            
            let anotherPerson = Person()
            anotherPerson.id = "123"
            anotherPerson.age = 20
            
            person.bestFriend = anotherPerson
            
            context("when setting relationship", {
                it("is accessible", closure: {
                    expect(person.bestFriend === anotherPerson).to(beTrue())
                })
            })
            
        }
    }
}
