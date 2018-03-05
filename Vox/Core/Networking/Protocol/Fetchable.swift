import Foundation

typealias FetchableSuccessBlock<DocumentType> = (_ document: DocumentType) -> Void

public protocol Fetchable {
    associatedtype FetchableResourceTypeConfigurable: FetchConfigurable
    associatedtype FetchableResourceCollectionTypeConfigurable: FetchConfigurable
    
    func fetch() -> FetchableResourceCollectionTypeConfigurable
    
    func fetch(id: String) -> FetchableResourceTypeConfigurable
}

