import Foundation

/// Subconjunto do `NSUbiquitousKeyValueStore` usado pelo app; permite trocar por um fake nos testes.
protocol CloudKeyValueStoring: AnyObject {
    func dictionary(forKey key: String) -> [String: Any]?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    @discardableResult
    func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudKeyValueStoring {}
