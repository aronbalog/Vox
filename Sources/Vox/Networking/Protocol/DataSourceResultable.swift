import Foundation

/// A request that can be sent.
public protocol DataSourceResultable: Sendable {
    associatedtype Output: Sendable
    
    /// Sends the request.
    func result() async throws -> Output
}

extension DataSourceResultable {
    /// Sends the request and calls `success` or `failure` on the main actor.
    public func result(_ success: @escaping @MainActor (Output) -> Void, _ failure: (@MainActor (Error) -> Void)? = nil) {
        Task { @MainActor in
            do {
                success(try await self.result())
            } catch {
                failure?(error)
            }
        }
    }
}

extension DataSourceResultable where Output == Void {
    /// Sends the request and calls `success` or `failure` on the main actor.
    public func result(_ success: @escaping @MainActor () -> Void, _ failure: (@MainActor (Error) -> Void)? = nil) {
        Task { @MainActor in
            do {
                try await self.result()
                success()
            } catch {
                failure?(error)
            }
        }
    }
}
