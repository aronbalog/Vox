import Foundation

public protocol Updatable {
    associatedtype ResourceType
    associatedtype UpdatableResourceTypeCompletable
    
    func update(_ resource: ResourceType) -> UpdatableResourceTypeCompletable
}
