import Foundation

@testable import Vox

extension Int {
    mutating func invoke() {
        self += 1
    }
    
    var isInvokedOnce: Bool {
        return self == 1
    }
}

extension Data {
    init(jsonFileName: String) {
        let url = Bundle.module.url(forResource: jsonFileName, withExtension: "json")!
        
        self = try! Data(contentsOf: url)
    }
}

/// Whether the caller runs on the main dispatch queue, which executes the jobs of the main actor.
/// `Thread.isMainThread` can't tell on Linux, where another thread drains the main queue.
func isOnMainQueue() -> Bool {
    let key = DispatchSpecificKey<Bool>()
    DispatchQueue.main.setSpecific(key: key, value: true)
    defer { DispatchQueue.main.setSpecific(key: key, value: nil) }
    
    return DispatchQueue.getSpecific(key: key) == true
}

/// A client that records requests and responds to each with the next of `responses`, repeating
/// the last one.
final class RecordingClient: Client, @unchecked Sendable {
    private let lock = Lock()
    private var _requests: [ClientRequest] = []
    private var responses: [Result<ClientResponse, Error>]
    
    init(responses: [Result<ClientResponse, Error>]) {
        self.responses = responses
    }
    
    convenience init(response: ClientResponse = ClientResponse(statusCode: 204, data: Data())) {
        self.init(responses: [.success(response)])
    }
    
    convenience init(statusCode: Int = 200, json: String) {
        self.init(response: ClientResponse(statusCode: statusCode, data: Data(json.utf8)))
    }
    
    convenience init(statusCode: Int = 200, jsonFileNames: [String]) {
        self.init(responses: jsonFileNames.map { .success(ClientResponse(statusCode: statusCode, data: Data(jsonFileName: $0))) })
    }
    
    convenience init(error: Error) {
        self.init(responses: [.failure(error)])
    }
    
    var requests: [ClientRequest] {
        return lock.withLock { _requests }
    }
    
    func execute(_ request: ClientRequest) async throws -> ClientResponse {
        let response = lock.withLock {
            _requests.append(request)
            
            return responses.count > 1 ? responses.removeFirst() : responses[0]
        }
        
        return try response.get()
    }
}
