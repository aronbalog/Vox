import Vox

class Cellphone: Resource {
    override class var resourceType: String {
        return "Cellphone"
    }
}

class Weed: Resource {
    override class var resourceType: String {
        return "Weed"
    }
}

class Person: Resource {
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
    @objc dynamic var favoriteWeed: Resource?
}

Resource.load()


let person = Person()
person.id = "MOCK-ID"
person.name = "MOCK"
person.age = .null
person.isHappy = true
person.favoriteWords = ["vox", "bucks"]

let bestFriend = Person()
bestFriend.id = "FRIEND-ID"

let anotherFriend = Person()
anotherFriend.id = "ANOTHER-FRIEND-ID"

person.bestFriend = bestFriend
person.goodFriends = [bestFriend, anotherFriend]

let weed = Weed()
weed.id = "weed"
let cellphone = Cellphone()
cellphone.id = "cellphone"
person.items = [weed, cellphone]

person.favoriteWeed = weed

let documentDictionary = try! person.documentDictionary()

//print(documentDictionary!
print(String(data: try! JSONSerialization.data(withJSONObject: documentDictionary, options: .prettyPrinted), encoding: .utf8 )!)
