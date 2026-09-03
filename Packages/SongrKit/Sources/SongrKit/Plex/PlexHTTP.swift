import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Thin JSON-over-HTTP helper shared by the pin, discovery, and source
/// clients. Sessions are injected so tests can stub with URLProtocol.
struct PlexHTTP: Sendable {
    let session: URLSession

    func send(_ method: String,
              _ url: URL,
              headers: [String: String],
              timeout: TimeInterval? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let timeout { request.timeoutInterval = timeout }
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LibrarySourceError.badResponse(status: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LibrarySourceError.badResponse(status: http.statusCode)
        }
        return data
    }

    func get<T: Decodable>(_ type: T.Type, _ url: URL,
                           headers: [String: String]) async throws -> T {
        let data = try await send("GET", url, headers: headers)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw LibrarySourceError.malformedPayload(String(describing: error))
        }
    }

    static func url(_ base: URL, path: String,
                    query: [(String, String)] = []) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        // Plex part/thumb keys arrive as server-relative paths ("/library/…").
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        }
        return components.url!
    }
}
