import Foundation

/// Creates requests that create resources.
public protocol Creatable {
    associatedtype ResourceType
    associatedtype CreatableResourceTypeCompletable
    
    func create(_ resource: ResourceType) -> CreatableResourceTypeCompletable
}

