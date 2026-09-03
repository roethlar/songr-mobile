import Foundation

/// One advertised connection to one Plex server machine.
public struct PlexServerCandidate: Hashable, Sendable {
    public let name: String
    public let machineIdentifier: String
    public let uri: URL
    public let local: Bool
    public let relay: Bool

    public init(name: String, machineIdentifier: String, uri: URL,
                local: Bool, relay: Bool) {
        self.name = name
        self.machineIdentifier = machineIdentifier
        self.uri = uri
        self.local = local
        self.relay = relay
    }
}

/// plex.tv resource discovery + reachable-connection choice, mirroring the
/// ordering vela ships (the flow the owner already trusts):
///   https only; then plex.direct+local < plex.direct+remote < other+local
///   < other+remote < relay (relay only when allowed).
/// Each candidate is probed via GET {uri}/identity (3s timeout) and must echo
/// the machineIdentifier it was advertised under.
public struct PlexDiscovery: Sendable {
    public let identity: PlexClientIdentity
    private let token: String
    private let http: PlexHTTP
    private let plexTVBaseURL: URL

    public init(identity: PlexClientIdentity,
                token: String,
                session: URLSession = .shared,
                plexTVBaseURL: URL = URL(string: "https://plex.tv")!) {
        self.identity = identity
        self.token = token
        self.http = PlexHTTP(session: session)
        self.plexTVBaseURL = plexTVBaseURL
    }

    // MARK: plex.tv resources

    private struct Resource: Decodable {
        struct Connection: Decodable {
            let uri: String
            let local: Bool
            let relay: Bool
        }
        let name: String?
        let provides: String
        let clientIdentifier: String
        let connections: [Connection]
    }

    /// All server connections the account can reach, flattened.
    public func fetchServerCandidates() async throws -> [PlexServerCandidate] {
        let url = PlexHTTP.url(plexTVBaseURL, path: "/api/v2/resources", query: [
            ("includeHttps", "1"),
            ("includeRelay", "1"),
            ("includeIPv6", "1"),
        ])
        let resources = try await http.get([Resource].self, url,
                                           headers: identity.headers(token: token))
        return resources
            .filter { $0.provides.split(separator: ",").contains("server") }
            .flatMap { resource in
                resource.connections.compactMap { connection -> PlexServerCandidate? in
                    guard let uri = URL(string: connection.uri) else { return nil }
                    return PlexServerCandidate(
                        name: resource.name ?? "Plex Server",
                        machineIdentifier: resource.clientIdentifier,
                        uri: uri,
                        local: connection.local,
                        relay: connection.relay
                    )
                }
            }
    }

    // MARK: Ordering (pure — unit tested)

    /// nil = excluded; lower = try first. Constants mirror vela exactly.
    public static func candidatePriority(_ candidate: PlexServerCandidate,
                                         allowRelay: Bool) -> Int? {
        guard candidate.uri.scheme == "https" else { return nil }
        if candidate.relay {
            return allowRelay ? 40 : nil
        }
        let plexDirect = (candidate.uri.host ?? "").hasSuffix(".plex.direct")
        switch (plexDirect, candidate.local) {
        case (true, true): return 0
        case (true, false): return 10
        case (false, true): return 20
        case (false, false): return 30
        }
    }

    /// Stable sort by priority, excluding ineligible connections.
    public static func ordered(_ candidates: [PlexServerCandidate],
                               allowRelay: Bool) -> [PlexServerCandidate] {
        candidates
            .enumerated()
            .compactMap { index, candidate in
                candidatePriority(candidate, allowRelay: allowRelay)
                    .map { (priority: $0, index: index, candidate: candidate) }
            }
            .sorted { ($0.priority, $0.index) < ($1.priority, $1.index) }
            .map(\.candidate)
    }

    // MARK: Probing

    private struct IdentityEnvelope: Decodable {
        struct Container: Decodable {
            let machineIdentifier: String?
        }
        let MediaContainer: Container
    }

    /// Whether {uri}/identity answers and matches the advertised machine.
    public func probe(_ candidate: PlexServerCandidate) async -> Bool {
        let url = PlexHTTP.url(candidate.uri, path: "/identity")
        do {
            let data = try await http.send("GET", url,
                                           headers: identity.headers(token: token),
                                           timeout: 3)
            let envelope = try JSONDecoder().decode(IdentityEnvelope.self, from: data)
            guard !candidate.machineIdentifier.isEmpty else { return true }
            return envelope.MediaContainer.machineIdentifier == candidate.machineIdentifier
        } catch {
            return false
        }
    }

    /// First reachable candidate in trusted order; relay only as last resort.
    public func chooseServer(from candidates: [PlexServerCandidate],
                             allowRelay: Bool = true) async -> PlexServerCandidate? {
        for candidate in Self.ordered(candidates, allowRelay: allowRelay) {
            if await probe(candidate) {
                return candidate
            }
        }
        return nil
    }
}
