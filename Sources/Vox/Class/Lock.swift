import Foundation

/// A recursive lock that can be shared across concurrency domains.
final class Lock: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        
        return try body()
    }
}
