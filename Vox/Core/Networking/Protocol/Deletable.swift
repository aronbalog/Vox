import Foundation

typealias DeletableSuccessBlock = () -> Void

public protocol Deletable {
    associatedtype DeletableResourceTypeCompletable
    
    func delete(id: String) -> DeletableResourceTypeCompletable
}
