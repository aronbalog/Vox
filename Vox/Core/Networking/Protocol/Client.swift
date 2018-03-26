import Foundation

public typealias ClientSuccessBlock = (_ response: HTTPURLResponse?, _ data: Data?) -> Void
public typealias ClientFailureBlock = (_ error: Error?, _ data: Data?) -> Void

public protocol Client: class {
    func executeRequest(path: String, method: String, queryItems: [URLQueryItem], bodyParameters: [String: Any]?, success: @escaping ClientSuccessBlock, failure: @escaping ClientFailureBlock, userInfo: [String: Any])
}

