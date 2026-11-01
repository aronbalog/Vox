import Foundation

public protocol Deletable {
    associatedtype DeletableResourceTypeCompletable
    
    func delete(id: String) -> DeletableResourceTypeCompletable
}
