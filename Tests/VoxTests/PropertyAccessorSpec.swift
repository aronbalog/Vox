import Foundation
import Testing

@testable import Vox

#if canImport(ObjectiveC)

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

@Suite("Resource property accessors")
struct PropertyAccessorSpec {
    @Test("values set to properties are accessible")
    func valuesAreAccessible() throws {
        let person = Person()
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
        
        let wallet = Wallet()
        wallet.id = "wallet id"
        let cellphone = Cellphone()
        cellphone.id = "cellphone id"
        
        person.items = [wallet, cellphone]
        
        #expect(person.name == "MOCK")
        #expect(person["name"] as? String == "MOCK")
        
        #expect(person.age == 28)
        #expect(person["age"] as? Int == 28)
        
        #expect(person.isHappy?.boolValue == true)
        #expect(person["isHappy"] as? Bool == true)
        
        #expect(person.favoriteWords == ["vox", "bucks"])
        #expect(person["favoriteWords"] as? [String] == ["vox", "bucks"])
        
        #expect(person.bestFriend === bestFriend)
        #expect(person["bestFriend"] as? Resource === bestFriend)
        
        #expect(person.goodFriends?.count == 2)
        #expect(person.goodFriends?[0] === bestFriend)
        #expect(person.goodFriends?[1] === anotherFriend)
        
        #expect(person.items?.count == 2)
        #expect(person.items?[0] === wallet)
        #expect(person.items?[1] === cellphone)
        
        #expect(try !person.documentData().isEmpty)
        #expect(try person.documentDictionary()["data"] != nil)
    }
    
    @Test("relationship set to a resource is accessible")
    func relationshipIsAccessible() {
        let person = Person()
        
        let anotherPerson = Person()
        anotherPerson.id = "123"
        anotherPerson.age = 20
        
        person.bestFriend = anotherPerson
        
        #expect(person.bestFriend === anotherPerson)
    }
}

#endif
