import Foundation

/// Persisted Plex credentials + device identity. The client identifier is
/// minted once and reused forever — plex.tv ties the granted token to it, so
/// re-minting would orphan the token (vela mints per-link because it re-links
/// every time; we deliberately persist instead).
public protocol PlexCredentialStoring: AnyObject, Sendable {
    var clientIdentifier: String? { get set }
    var authToken: String? { get set }
    var serverURL: URL? { get set }
    var serverMachineIdentifier: String? { get set }
    /// User-chosen music library section key (nil until chosen; cleared on unlink).
    var musicSectionKey: String? { get set }
}

/// Legacy UserDefaults-backed store. A reinstall wipes UserDefaults, which
/// once cost the owner his Plex link — the app now persists credentials in
/// `KeychainCredentialStore` and keeps this class only as the read-and-erase
/// source for its one-time migration. Never wire it back into the app.
public final class UserDefaultsCredentialStore: PlexCredentialStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private enum Key {
        static let clientIdentifier = "plex.clientIdentifier"
        static let authToken = "plex.authToken"
        static let serverURL = "plex.serverURL"
        static let serverMachine = "plex.serverMachineIdentifier"
        static let musicSection = "plex.musicSectionKey"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var clientIdentifier: String? {
        get { defaults.string(forKey: Key.clientIdentifier) }
        set { defaults.set(newValue, forKey: Key.clientIdentifier) }
    }

    public var authToken: String? {
        get { defaults.string(forKey: Key.authToken) }
        set { defaults.set(newValue, forKey: Key.authToken) }
    }

    public var serverURL: URL? {
        get { defaults.string(forKey: Key.serverURL).flatMap(URL.init(string:)) }
        set { defaults.set(newValue?.absoluteString, forKey: Key.serverURL) }
    }

    public var serverMachineIdentifier: String? {
        get { defaults.string(forKey: Key.serverMachine) }
        set { defaults.set(newValue, forKey: Key.serverMachine) }
    }

    public var musicSectionKey: String? {
        get { defaults.string(forKey: Key.musicSection) }
        set { defaults.set(newValue, forKey: Key.musicSection) }
    }
}

/// In-memory store for tests and previews.
public final class InMemoryCredentialStore: PlexCredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var _clientIdentifier: String?
    private var _authToken: String?
    private var _serverURL: URL?
    private var _serverMachineIdentifier: String?
    private var _musicSectionKey: String?

    public init() {}

    public var clientIdentifier: String? {
        get { lock.withLock { _clientIdentifier } }
        set { lock.withLock { _clientIdentifier = newValue } }
    }
    public var authToken: String? {
        get { lock.withLock { _authToken } }
        set { lock.withLock { _authToken = newValue } }
    }
    public var serverURL: URL? {
        get { lock.withLock { _serverURL } }
        set { lock.withLock { _serverURL = newValue } }
    }
    public var serverMachineIdentifier: String? {
        get { lock.withLock { _serverMachineIdentifier } }
        set { lock.withLock { _serverMachineIdentifier = newValue } }
    }
    public var musicSectionKey: String? {
        get { lock.withLock { _musicSectionKey } }
        set { lock.withLock { _musicSectionKey = newValue } }
    }
}

/// The X-Plex-* identity this app presents. Product is "Songr" (the owner's
/// player), mirroring the header set vela sends on every request.
public struct PlexClientIdentity: Hashable, Sendable {
    public let clientIdentifier: String
    public let product: String
    public let version: String
    public let platform: String
    public let device: String
    public let deviceName: String

    public init(clientIdentifier: String,
                product: String = "Songr",
                version: String = "1.0",
                platform: String = "iOS",
                device: String = "iPhone",
                deviceName: String = "Songr") {
        self.clientIdentifier = clientIdentifier
        self.product = product
        self.version = version
        self.platform = platform
        self.device = device
        self.deviceName = deviceName
    }

    /// Returns the stored client identifier, minting + persisting one on
    /// first use.
    public static func ensureClientIdentifier(in store: PlexCredentialStoring) -> String {
        if let existing = store.clientIdentifier, !existing.isEmpty {
            return existing
        }
        let minted = UUID().uuidString
        store.clientIdentifier = minted
        return minted
    }

    /// Common request headers; token is added when present, never in URLs.
    public func headers(token: String?) -> [String: String] {
        var headers: [String: String] = [
            "X-Plex-Product": product,
            "X-Plex-Version": version,
            "X-Plex-Client-Identifier": clientIdentifier,
            "X-Plex-Platform": platform,
            "X-Plex-Device": device,
            "X-Plex-Device-Name": deviceName,
            "Accept": "application/json",
        ]
        if let token, !token.isEmpty {
            headers["X-Plex-Token"] = token
        }
        return headers
    }
}
