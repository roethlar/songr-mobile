import Foundation
import Security

/// Raw item storage under `KeychainCredentialStore`: bytes by account name.
/// Production uses SecItem (`SecItemKeychain` below); tests substitute a
/// dictionary-backed fake so `swift test` never touches a real keychain.
public protocol KeychainItemStoring: Sendable {
    func data(forAccount account: String) -> Data?
    /// `nil` deletes the item.
    func setData(_ data: Data?, forAccount account: String)
}

/// kSecClassGenericPassword items, one per account, under a fixed service.
/// Deliberately not `kSecAttrSynchronizable` (no iCloud Keychain sync) and
/// not `…ThisDeviceOnly` (an encrypted device backup restored to a new phone
/// still carries the link — the owner should never have to sign in again).
/// `AfterFirstUnlock` keeps the token readable for background audio.
/// Exercised for real only inside the app on iOS/simulator; unit tests use a
/// fake, so no `#if` guards are needed — the API compiles everywhere.
public struct SecItemKeychain: KeychainItemStoring {
    public let service: String

    public init(service: String) {
        self.service = service
    }

    public func data(forAccount account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    public func setData(_ data: Data?, forAccount account: String) {
        guard let data else {
            SecItemDelete(baseQuery(account: account) as CFDictionary)
            return
        }
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(account: account) as CFDictionary,
                                   update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery(account: account)
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}

/// Keychain-backed credentials: unlike the original UserDefaults store, the
/// keychain survives app reinstalls and rebuilds on both device and
/// simulator, so a rebuild never costs the owner the Plex link again.
/// Account names reuse the legacy `plex.*` UserDefaults keys one-for-one.
public final class KeychainCredentialStore: PlexCredentialStoring, @unchecked Sendable {
    public static let defaultService = "com.draegloth.Songr.plex"

    private enum Key {
        static let clientIdentifier = "plex.clientIdentifier"
        static let authToken = "plex.authToken"
        static let serverURL = "plex.serverURL"
        static let serverMachine = "plex.serverMachineIdentifier"
        static let musicSection = "plex.musicSectionKey"
        static let all = [clientIdentifier, authToken, serverURL,
                          serverMachine, musicSection]
    }

    private let items: KeychainItemStoring

    public convenience init(service: String = KeychainCredentialStore.defaultService) {
        self.init(items: SecItemKeychain(service: service))
    }

    public init(items: KeychainItemStoring) {
        self.items = items
    }

    public var clientIdentifier: String? {
        get { string(Key.clientIdentifier) }
        set { setString(newValue, Key.clientIdentifier) }
    }

    public var authToken: String? {
        get { string(Key.authToken) }
        set { setString(newValue, Key.authToken) }
    }

    public var serverURL: URL? {
        get { string(Key.serverURL).flatMap(URL.init(string:)) }
        set { setString(newValue?.absoluteString, Key.serverURL) }
    }

    public var serverMachineIdentifier: String? {
        get { string(Key.serverMachine) }
        set { setString(newValue, Key.serverMachine) }
    }

    public var musicSectionKey: String? {
        get { string(Key.musicSection) }
        set { setString(newValue, Key.musicSection) }
    }

    /// One-time import from the legacy UserDefaults store: only while the
    /// keychain holds none of the five values, copy whatever UserDefaults
    /// has and delete the plaintext copies. Once anything lives in the
    /// keychain it is the sole truth and stale defaults are never re-read.
    public func migrateFromUserDefaults(_ defaults: UserDefaults = .standard) {
        let keychainEmpty = Key.all.allSatisfy { items.data(forAccount: $0) == nil }
        guard keychainEmpty else { return }
        let legacy = UserDefaultsCredentialStore(defaults: defaults)
        clientIdentifier = legacy.clientIdentifier
        authToken = legacy.authToken
        serverURL = legacy.serverURL
        serverMachineIdentifier = legacy.serverMachineIdentifier
        musicSectionKey = legacy.musicSectionKey
        legacy.clientIdentifier = nil
        legacy.authToken = nil
        legacy.serverURL = nil
        legacy.serverMachineIdentifier = nil
        legacy.musicSectionKey = nil
    }

    private func string(_ account: String) -> String? {
        items.data(forAccount: account).flatMap { String(data: $0, encoding: .utf8) }
    }

    private func setString(_ value: String?, _ account: String) {
        items.setData(value?.data(using: .utf8), forAccount: account)
    }
}
