import Foundation

/// A recursive lock that can be shared across concurrency domains.
final class Lock: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    
    func withLock<T, E: Error>(_ body: () throws(E) -> T) throws(E) -> T {
        lock.lock()
        defer { lock.unlock() }
        
        return try body()
    }
}

/// A value that can be accessed only while its lock is held, like the standard library's `Mutex`,
/// which requires iOS 18, macOS 15, tvOS 18 and watchOS 11.
///
/// Unlike `Mutex`, it doesn't prevent values that aren't `Sendable` from escaping `withLock`.
final class Locked<Value>: @unchecked Sendable {
    private let lock: Lock
    private var value: Value
    
    /// - Parameter lock: The lock that guards the value, which may guard other state as well.
    init(_ value: Value, guardedBy lock: Lock = Lock()) {
        self.value = value
        self.lock = lock
    }
    
    /// Calls `body` with exclusive access to the value, so `body` must not call `withLock` on the
    /// same instance.
    func withLock<T, E: Error>(_ body: (inout Value) throws(E) -> T) throws(E) -> T {
        try lock.withLock { () throws(E) -> T in
            try body(&value)
        }
    }
}
