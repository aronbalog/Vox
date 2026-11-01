import Foundation

public protocol Router {
    func fetch(id: String, type: Resource.Type) -> String
    func fetch(type: Resource.Type) -> String
    func create(resource: Resource) -> String
    func update(resource: Resource) -> String
    func delete(id: String, type: Resource.Type) -> String
}

