import XCTest
@testable import SongrKit

final class PlexDiscoveryTests: XCTestCase {
    private var discovery: PlexDiscovery!

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        discovery = PlexDiscovery(
            identity: PlexClientIdentity(clientIdentifier: "songr-client-1"),
            token: "tok",
            session: StubURLProtocol.makeSession()
        )
    }

    private func candidate(_ uri: String, local: Bool, relay: Bool,
                           machine: String = "machine-1") -> PlexServerCandidate {
        PlexServerCandidate(name: "halcyon", machineIdentifier: machine,
                            uri: URL(string: uri)!, local: local, relay: relay)
    }

    // MARK: Ordering (local → remote → relay, https only — vela's exact rule)

    func testOrderingPrefersLocalPlexDirectThenRemoteThenRelay() {
        let relay = candidate("https://relay-1.plex.direct:8443", local: false, relay: true)
        let remoteDirect = candidate("https://a.plex.direct:32400", local: false, relay: false)
        let localDirect = candidate("https://b.plex.direct:32400", local: true, relay: false)
        let localPlain = candidate("https://192.168.1.10:32400", local: true, relay: false)
        let remotePlain = candidate("https://203.0.113.7:32400", local: false, relay: false)

        let ordered = PlexDiscovery.ordered(
            [relay, remotePlain, remoteDirect, localPlain, localDirect],
            allowRelay: true
        )
        XCTAssertEqual(ordered, [localDirect, remoteDirect, localPlain,
                                 remotePlain, relay])
    }

    func testOrderingExcludesHTTPAndOptionallyRelay() {
        let http = candidate("http://192.168.1.10:32400", local: true, relay: false)
        let relay = candidate("https://relay-1.plex.direct:8443", local: false, relay: true)
        let good = candidate("https://a.plex.direct:32400", local: true, relay: false)

        XCTAssertEqual(PlexDiscovery.ordered([http, relay, good], allowRelay: false),
                       [good], "plain http and relays must be dropped")
        XCTAssertEqual(PlexDiscovery.ordered([http, relay, good], allowRelay: true),
                       [good, relay], "relay allowed only as last resort")
    }

    func testOrderingIsStableWithinPriority() {
        let first = candidate("https://a.plex.direct:32400", local: true, relay: false)
        let second = candidate("https://b.plex.direct:32400", local: true, relay: false)
        XCTAssertEqual(PlexDiscovery.ordered([first, second], allowRelay: true),
                       [first, second])
    }

    // MARK: plex.tv resources parsing

    func testFetchServerCandidatesFlattensServerResourcesOnly() async throws {
        StubURLProtocol.route("GET", "/api/v2/resources") { _ in
            .init(data: Fixtures.resources)
        }

        let candidates = try await discovery.fetchServerCandidates()
        XCTAssertEqual(candidates.count, 3, "client resources are excluded")
        XCTAssertEqual(Set(candidates.map(\.machineIdentifier)), ["machine-1"])
        XCTAssertEqual(candidates.filter(\.relay).count, 1)

        let request = try XCTUnwrap(
            StubURLProtocol.requests(matchingPath: "/api/v2/resources").first
        )
        XCTAssertEqual(request.queryPairs["includeHttps"], "1")
        XCTAssertEqual(request.queryPairs["includeRelay"], "1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Plex-Token"), "tok")
        XCTAssertNil(request.url?.query?.range(of: "tok"),
                     "token must never appear in the URL")
    }

    // MARK: Probe + choice

    func testChooseServerSkipsUnreachableAndVerifiesMachineIdentity() async throws {
        StubURLProtocol.route("GET", "/identity") { request in
            switch request.url?.host {
            case "wrong-machine.plex.direct":
                return .init(data: Fixtures.identity(machineIdentifier: "impostor"))
            case "dead.plex.direct":
                return .init(status: 502, data: Data())
            default:
                return .init(data: Fixtures.identity(machineIdentifier: "machine-1"))
            }
        }

        let impostor = candidate("https://wrong-machine.plex.direct:32400",
                                 local: true, relay: false)
        let dead = candidate("https://dead.plex.direct:32400", local: true, relay: false)
        let live = candidate("https://live.plex.direct:32400", local: false, relay: false)

        let chosen = await discovery.chooseServer(from: [impostor, dead, live])
        XCTAssertEqual(chosen, live,
                       "identity mismatch and HTTP failure must both be skipped")
    }

    func testChooseServerReturnsNilWhenNothingAnswers() async {
        StubURLProtocol.route("GET", "/identity") { _ in
            .init(status: 500, data: Data())
        }
        let dead = candidate("https://dead.plex.direct:32400", local: true, relay: false)
        let chosen = await discovery.chooseServer(from: [dead])
        XCTAssertNil(chosen)
    }
}
