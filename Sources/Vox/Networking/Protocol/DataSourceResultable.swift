import Foundation

public protocol DataSourceResultable {
    associatedtype DataSourceResourceSuccessfulBlock
    
    func result(_ success: DataSourceResourceSuccessfulBlock, _ failure: ((Error?) -> Void)?) throws
}
