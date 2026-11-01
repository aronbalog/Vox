import Foundation

public protocol Creatable {
    associatedtype ResourceType
    associatedtype CreatableResourceTypeCompletable
    
    func create(_ resource: ResourceType) -> CreatableResourceTypeCompletable
}

