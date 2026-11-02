import Foundation
#if canImport(ObjectiveC)
import ObjectiveC
#endif
import Testing

@testable import Vox

#if canImport(ObjectiveC)

fileprivate class Person: Resource {
    override class var resourceType: String {
        "Person"
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
        "Cellphone"
    }
}

fileprivate class Wallet: Resource {
    override class var resourceType: String {
        "Wallet"
    }
}

/// `level` is a primitive, so it keeps its own storage. `serial` is read-only, so only its getter
/// is replaced.
fileprivate final class CoverageGauge: Resource {
    override class var resourceType: String {
        "coverage-gauges"
    }
    
    @objc var level: Int = 0
    @objc let serial: String? = "fixed"
    @objc dynamic var name: String?
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
    
    @Test("key-value coding reads and writes properties and other members")
    func keyValueCoding() {
        let attributeName = strdup("T")!
        let attributeValue = strdup("@\"NSString\"")!
        let getterName = strdup("G")!
        let getterValue = strdup("coverageLabel")!
        let setterName = strdup("S")!
        let setterValue = strdup("updateCoverageLabel:")!
        defer {
            free(attributeName)
            free(attributeValue)
            free(getterName)
            free(getterValue)
            free(setterName)
            free(setterValue)
        }
        var attributes = [
            objc_property_attribute_t(name: attributeName, value: attributeValue),
            objc_property_attribute_t(name: getterName, value: getterValue),
            objc_property_attribute_t(name: setterName, value: setterValue)
        ]
        _ = class_addProperty(CoverageGauge.self, "coverageAlias", &attributes, UInt32(attributes.count))
        
        let gauge = CoverageGauge()
        
        gauge.setValue("Ada", forKey: "name")
        #expect(gauge.value(forKey: "name") as? String == "Ada")
        #expect(gauge.name == "Ada")
        
        #expect(gauge.value(forProperty: "missing") == nil)
        gauge.setValue("ignored", forProperty: "missing")
        #expect(gauge.name == "Ada")
        
        gauge.setValue(NSNumber(value: 7), forKey: "level")
        #expect(gauge.level == 7)
        #expect((gauge.value(forKey: "level") as? NSNumber)?.intValue == 7)
        
        gauge.setValue("extra", forKey: "coverageExtra")
        #expect(gauge.value(forKey: "coverageExtra") as? String == "extra")
        
        _ = gauge.serial
    }
}

#endif
