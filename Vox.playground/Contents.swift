import Vox

class Cellphone: Resource {
    override class var resourceType: String {
        return "Cellphone"
    }
}

class Wallet: Resource {
    override class var resourceType: String {
        return "Wallet"
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
    @objc dynamic var favoriteItem: Resource?
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

let wallet = Wallet()
wallet.id = "wallet"
let cellphone = Cellphone()
cellphone.id = "cellphone"
person.items = [wallet, cellphone]

person.favoriteItem = wallet

let documentDictionary = try! person.documentDictionary()

//print(documentDictionary!
print(String(data: try! JSONSerialization.data(withJSONObject: documentDictionary, options: .prettyPrinted), encoding: .utf8 )!)
