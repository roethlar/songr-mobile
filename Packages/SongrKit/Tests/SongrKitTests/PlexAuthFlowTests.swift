import XCTest
@testable import SongrKit

final class PlexAuthFlowTests: XCTestCase {
    private var identity: PlexClientIdentity!
    private var client: PlexPinClient!

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        identity = PlexClientIdentity(clientIdentifier: "songr-client-1")
        client = PlexPinClient(identity: identity,
                               session: StubURLProtocol.makeSession())
    }

    // MARK: Client identifier persistence

    func testClientIdentifierMintedOnceAndPersisted() {
        let store = InMemoryCredentialStore()
        let first = PlexClientIdentity.ensureClientIdentifier(in: store)
        let second = PlexClientIdentity.ensureClientIdentifier(in: store)
        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first, second, "identifier must never be re-minted")
        XCTAssertEqual(store.clientIdentifier, first)
    }

    func testExistingClientIdentifierIsReused() {
        let store = InMemoryCredentialStore()
        store.clientIdentifier = "already-minted"
        XCTAssertEqual(PlexClientIdentity.ensureClientIdentifier(in: store),
                       "already-minted")
    }

    // MARK: Header set

    func testCommonHeadersCarryIdentityAndOptionalToken() {
        let anonymous = identity.headers(token: nil)
        XCTAssertEqual(anonymous["X-Plex-Product"], "Songr")
        XCTAssertEqual(anonymous["X-Plex-Client-Identifier"], "songr-client-1")
        XCTAssertEqual(anonymous["Accept"], "application/json")
        XCTAssertNil(anonymous["X-Plex-Token"])

        let authed = identity.headers(token: "tok")
        XCTAssertEqual(authed["X-Plex-Token"], "tok")
    }

    // MARK: PIN request

    func testRequestPinPostsStrongPinWithIdentityHeaders() async throws {
        StubURLProtocol.route("POST", "/api/v2/pins") { _ in
            .init(status: 201, data: Fixtures.pinCreated)
        }

        let pin = try await client.requestPin()
        XCTAssertEqual(pin, PlexPin(id: 987654, code: "ABCD"))

        let request = try XCTUnwrap(StubURLProtocol.requests(matchingPath: "/api/v2/pins").first)
        XCTAssertEqual(request.queryPairs["strong"], "true",
                       "the hosted auth app rejects weak PINs")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Plex-Product"), "Songr")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Plex-Client-Identifier"),
                       "songr-client-1")
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Plex-Token"),
                     "pin creation is pre-auth; no token may be sent")
    }

    func testRequestPinWeakVariantForCodeEntry() async throws {
        StubURLProtocol.route("POST", "/api/v2/pins") { _ in
            .init(status: 201, data: Fixtures.pinCreated)
        }

        _ = try await client.requestPin(strong: false)

        let request = try XCTUnwrap(StubURLProtocol.requests(matchingPath: "/api/v2/pins").first)
        XCTAssertEqual(request.queryPairs["strong"], "false",
                       "plex.tv/link takes the short weak-pin code")
    }

    func testLinkURLPreFillsPinCode() {
        let url = client.linkURL(for: PlexPin(id: 987654, code: "ABCD"))
        XCTAssertEqual(url.absoluteString, "https://plex.tv/link/?pin=ABCD")
    }

    func testAuthAppURLCarriesClientIDCodeAndContextInFragment() {
        let url = client.authAppURL(for: PlexPin(id: 987654, code: "c0de-with~chars"))
        XCTAssertEqual(url.absoluteString,
                       "https://app.plex.tv/auth#?clientID=songr-client-1"
                       + "&code=c0de-with~chars"
                       + "&context%5Bdevice%5D%5Bproduct%5D=Songr"
                       + "&context%5Bdevice%5D%5BdeviceName%5D=Songr"
                       + "&context%5Bdevice%5D%5Bplatform%5D=iOS")
    }

    // MARK: Polling

    func testPollTokenPendingReturnsNil() async throws {
        StubURLProtocol.route("GET", "/api/v2/pins/987654") { _ in
            .init(data: Fixtures.pinPending)
        }
        let token = try await client.pollToken(pinID: 987654)
        XCTAssertNil(token)
    }

    func testPollTokenLinkedReturnsToken() async throws {
        StubURLProtocol.route("GET", "/api/v2/pins/987654") { _ in
            .init(data: Fixtures.pinLinked)
        }
        let token = try await client.pollToken(pinID: 987654)
        XCTAssertEqual(token, "tok-secret-1")
    }

    func testPollTokenSurfacesHTTPFailure() async {
        StubURLProtocol.route("GET", "/api/v2/pins/987654") { _ in
            .init(status: 404, data: Data())
        }
        do {
            _ = try await client.pollToken(pinID: 987654)
            XCTFail("expected badResponse")
        } catch let error as LibrarySourceError {
            XCTAssertEqual(error, .badResponse(status: 404))
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }
}
