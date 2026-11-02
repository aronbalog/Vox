import Foundation

/// Creates requests that update resources.
public protocol Updatable {
    associatedtype ResourceType
    associatedtype UpdatableResourceTypeCompletable
    
    func update(_ resource: ResourceType) -> UpdatableResourceTypeCompletable
}
