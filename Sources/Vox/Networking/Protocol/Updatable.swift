import Foundation

typealias UpdatableSuccessBlock<DocumentType> = (_ document: DocumentType?) -> Void

public protocol Updatable {
    associatedtype ResourceType
    associatedtype UpdatableResourceTypeCompletable
    
    func update(_ resource: ResourceType) -> UpdatableResourceTypeCompletable
}

