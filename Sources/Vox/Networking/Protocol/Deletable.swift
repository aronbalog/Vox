import Foundation

/// Creates requests that delete resources.
public protocol Deletable {
    associatedtype DeletableResourceTypeCompletable
    
    func delete(id: String) -> DeletableResourceTypeCompletable
}
