import Foundation

/// A plex.tv device PIN claimed via the hosted Plex auth page.
public struct PlexPin: Hashable, Sendable {
    public let id: Int
    public let code: String

    public init(id: Int, code: String) {
        self.id = id
        self.code = code
    }
}

/// plex.tv PIN OAuth, one-tap hosted flow (what real Plex clients ship):
///   POST /api/v2/pins?strong=true   → { id, code }
///   open https://app.plex.tv/auth#?clientID=…&code=…  (user signs in, taps Accept)
///   GET  /api/v2/pins/{id}          → { authToken } once authorized
/// `strong=true` is required: the hosted auth app rejects weak PINs. The user
/// never sees or types the code.
public struct PlexPinClient: Sendable {
    public let identity: PlexClientIdentity
    private let http: PlexHTTP
    private let baseURL: URL

    public init(identity: PlexClientIdentity,
                session: URLSession = .shared,
                baseURL: URL = URL(string: "https://plex.tv")!) {
        self.identity = identity
        self.http = PlexHTTP(session: session)
        self.baseURL = baseURL
    }

    private struct PinPayload: Decodable {
        let id: Int
        let code: String
        let authToken: String?
    }

    /// `strong: true` → long code for the hosted auth page; `strong: false` →
    /// short code the plex.tv/link entry page accepts.
    public func requestPin(strong: Bool = true) async throws -> PlexPin {
        let url = PlexHTTP.url(baseURL, path: "/api/v2/pins",
                               query: [("strong", strong ? "true" : "false")])
        let data = try await http.send("POST", url, headers: identity.headers(token: nil))
        let payload: PinPayload
        do {
            payload = try JSONDecoder().decode(PinPayload.self, from: data)
        } catch {
            throw LibrarySourceError.malformedPayload(String(describing: error))
        }
        return PlexPin(id: payload.id, code: payload.code)
    }

    /// Hosted auth page: the user signs in and taps Accept; the pin is claimed
    /// server-side. Parameters live in the URL *fragment* (after `#?`), which
    /// the auth app reads client-side — they are never sent over the wire.
    public func authAppURL(for pin: PlexPin) -> URL {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        func enc(_ s: String) -> String {
            s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
        }
        let params = [
            "clientID=\(enc(identity.clientIdentifier))",
            "code=\(enc(pin.code))",
            "context%5Bdevice%5D%5Bproduct%5D=\(enc(identity.product))",
            "context%5Bdevice%5D%5BdeviceName%5D=\(enc(identity.deviceName))",
            "context%5Bdevice%5D%5Bplatform%5D=\(enc(identity.platform))",
        ].joined(separator: "&")
        return URL(string: "https://app.plex.tv/auth#?\(params)")!
    }

    /// Code-entry page for external browsers (pre-fills a weak pin's code).
    public func linkURL(for pin: PlexPin) -> URL {
        PlexHTTP.url(baseURL, path: "/link/", query: [("pin", pin.code)])
    }

    /// One poll; returns the token when the user has authorized, nil while pending.
    public func pollToken(pinID: Int) async throws -> String? {
        let url = PlexHTTP.url(baseURL, path: "/api/v2/pins/\(pinID)")
        let payload = try await http.get(PinPayload.self, url,
                                         headers: identity.headers(token: nil))
        guard let token = payload.authToken, !token.isEmpty else { return nil }
        return token
    }
}
