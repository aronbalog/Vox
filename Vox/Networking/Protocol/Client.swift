import Foundation

public typealias ClientSuccessBlock = (_ response: HTTPURLResponse?, _ data: Data?) -> Void
public typealias ClientFailureBlock = (_ error: Error, _ data: Data?) -> Void

public protocol Client {
    func executeRequest(_ path: String, method: String, queryItems: [URLQueryItem], parameters: [String: Any]?, success: @escaping ClientSuccessBlock, _ failure: @escaping ClientFailureBlock)
}

