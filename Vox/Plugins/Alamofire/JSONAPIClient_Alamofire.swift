import Foundation
import Alamofire

extension JSONAPIClient {
    #if ALAMOFIRE
    open class Alamofire: Client {
        public let baseURL: URL
        
        public init(baseURL: URL) {
            self.baseURL = baseURL
        }
        
        open func executeRequest(path: String, method: String, queryItems: [URLQueryItem], bodyParameters: [String : Any]?, success: @escaping ClientSuccessBlock, failure: @escaping ClientFailureBlock, userInfo: [String: Any]) {
            let sessionManager = SessionManager.default
            let url = baseURL.appendingPathComponent(path)
            let headers: HTTPHeaders = getHeaders()
            
            let request = multiEncodedURLRequest(url: url, method: method, queryItems: queryItems, bodyParameters: bodyParameters, headers: headers)
            
            sessionManager
                .request(request)
                .validate(statusCode: 200..<300)
                .validate(contentType: ["application/vnd.api+json"])
                .responseData { (data) in
                    self.responseHandler(data, success, failure)
            }
        }
        
        open func getHeaders() -> HTTPHeaders {
            return [
                "Content-Type": "application/vnd.api+json"
            ]
        }
        
        open func responseHandler(_ dataResponse: DataResponse<Data>, _ success: @escaping ClientSuccessBlock, _ failure: @escaping ClientFailureBlock) {
            let response = dataResponse.response
            let data = dataResponse.data
            let error = dataResponse.error
            
            dataResponse
                .result
                .ifSuccess {
                    success(response, data)
                }
                .ifFailure {
                    failure(error, data)
            }
        }
        
        open func multiEncodedURLRequest(url: URL, method: String, queryItems: [URLQueryItem], bodyParameters: [String: Any]?, headers: HTTPHeaders) -> URLRequest {
            let temporaryRequest = URLRequest(url: url)
            
            var parameters: [String: Any] = [:]
            
            queryItems.forEach({ (item) in
                parameters[item.name] = item.value ?? ""
            })
            
            let urlEncoding = try! URLEncoding.default.encode(temporaryRequest, with: parameters)
            let bodyEncoding = try! JSONEncoding.default.encode(temporaryRequest, with: bodyParameters)
            
            var compositeRequest = urlEncoding.urlRequest
            
            compositeRequest?.httpMethod = method
            compositeRequest?.httpBody = bodyEncoding.httpBody
            
            headers.forEach({ (header) in
                compositeRequest?.addValue(header.value, forHTTPHeaderField: header.key)
            })
            
            return compositeRequest!
        }
    }
    #endif
}
