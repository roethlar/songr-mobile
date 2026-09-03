import XCTest
@testable import SongrKit

/// Dictionary-backed `KeychainItemStoring`: these tests exercise the store's
/// own logic (string/URL encoding, delete-on-nil, migration gating). Real
/// SecItem calls run only inside the app on iOS/simulator.
final class InMemoryKeychainItems: KeychainItemStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    func data(forAccount account: String) -> Data? {
        lock.withLock { storage[account] }
    }

    func setData(_ data: Data?, forAccount account: String) {
        lock.withLock { storage[account] = data }
    }

    var accountCount: Int { lock.withLock { storage.count } }
}

final class KeychainCredentialStoreTests: XCTestCase {
    /// The five legacy UserDefaults keys, which the keychain store reuses as
    /// account names — part of the migration contract, so spelled out here.
    private static let legacyKeys = [
        "plex.clientIdentifier", "plex.authToken", "plex.serverURL",
        "plex.serverMachineIdentifier", "plex.musicSectionKey",
    ]

    private var items: InMemoryKeychainItems!
    private var store: KeychainCredentialStore!
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        items = InMemoryKeychainItems()
        store = KeychainCredentialStore(items: items)
        suiteName = "songr-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: Round trip

    func testRoundTripsEveryCredentialField() {
        store.clientIdentifier = "client-1"
        store.authToken = "token-1"
        store.serverURL = URL(string: "https://10-0-0-2.abc.plex.direct:32400")
        store.serverMachineIdentifier = "machine-1"
        store.musicSectionKey = "5"

        XCTAssertEqual(store.clientIdentifier, "client-1")
        XCTAssertEqual(store.authToken, "token-1")
        XCTAssertEqual(store.serverURL?.absoluteString,
                       "https://10-0-0-2.abc.plex.direct:32400")
        XCTAssertEqual(store.serverMachineIdentifier, "machine-1")
        XCTAssertEqual(store.musicSectionKey, "5")
    }

    func testSettingNilDeletesTheBackingItem() {
        store.authToken = "token-1"
        XCTAssertEqual(items.accountCount, 1)
        store.authToken = nil
        XCTAssertNil(store.authToken)
        XCTAssertEqual(items.accountCount, 0, "nil must delete, not store empty")
    }

    func testEnsureClientIdentifierMintsOnceIntoTheKeychain() {
        let first = PlexClientIdentity.ensureClientIdentifier(in: store)
        let second = PlexClientIdentity.ensureClientIdentifier(in: store)
        XCTAssertEqual(first, second)
        XCTAssertEqual(store.clientIdentifier, first)
    }

    // MARK: Migration

    func testMigrationImportsLegacyValuesAndDeletesThem() {
        let legacy = UserDefaultsCredentialStore(defaults: defaults)
        legacy.clientIdentifier = "client-legacy"
        legacy.authToken = "token-legacy"
        legacy.serverURL = URL(string: "https://server.local:32400")
        legacy.serverMachineIdentifier = "machine-legacy"
        legacy.musicSectionKey = "7"

        store.migrateFromUserDefaults(defaults)

        XCTAssertEqual(store.clientIdentifier, "client-legacy")
        XCTAssertEqual(store.authToken, "token-legacy")
        XCTAssertEqual(store.serverURL?.absoluteString, "https://server.local:32400")
        XCTAssertEqual(store.serverMachineIdentifier, "machine-legacy")
        XCTAssertEqual(store.musicSectionKey, "7")
        for key in Self.legacyKeys {
            XCTAssertNil(defaults.object(forKey: key),
                         "\(key) must be deleted after import")
        }
    }

    func testMigrationImportsPartialLegacyState() {
        // The real-world shape after the token loss: only the client
        // identifier survived in UserDefaults. It must still come across —
        // plex.tv ties any future token to it.
        let legacy = UserDefaultsCredentialStore(defaults: defaults)
        legacy.clientIdentifier = "client-survivor"

        store.migrateFromUserDefaults(defaults)

        XCTAssertEqual(store.clientIdentifier, "client-survivor")
        XCTAssertNil(store.authToken)
        XCTAssertNil(defaults.object(forKey: "plex.clientIdentifier"))
    }

    func testMigrationRefusedOnceKeychainHoldsAnyValue() {
        store.authToken = "token-keychain"
        let legacy = UserDefaultsCredentialStore(defaults: defaults)
        legacy.authToken = "token-stale"
        legacy.clientIdentifier = "client-stale"

        store.migrateFromUserDefaults(defaults)

        XCTAssertEqual(store.authToken, "token-keychain",
                       "keychain truth must never be overwritten")
        XCTAssertNil(store.clientIdentifier, "no partial import either")
        XCTAssertEqual(legacy.authToken, "token-stale",
                       "defaults untouched when migration does not run")
    }

    func testMigrationWithEmptyDefaultsIsANoOp() {
        store.migrateFromUserDefaults(defaults)
        XCTAssertEqual(items.accountCount, 0)
        XCTAssertNil(store.authToken)
    }
}
