import Foundation
import XCTest
@testable import SongrKit

/// URLProtocol stub: no real network ever leaves the test process. Tests
/// register routes keyed by (method, path); every handled request is recorded
/// so request shapes (headers, query) can be asserted.
final class StubURLProtocol: URLProtocol {
    struct Response {
        var status: Int = 200
        var data: Data = Data()
    }

    typealias Handler = @Sendable (URLRequest) -> Response

    private static let lock = NSLock()
    nonisolated(unsafe) private static var routes: [String: Handler] = [:]
    nonisolated(unsafe) private static var recorded: [URLRequest] = []

    static func key(_ method: String, _ path: String) -> String {
        "\(method) \(path)"
    }

    static func route(_ method: String, _ path: String, _ handler: @escaping Handler) {
        lock.lock(); defer { lock.unlock() }
        routes[key(method, path)] = handler
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        routes = [:]
        recorded = []
    }

    static var recordedRequests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    static func requests(matchingPath path: String) -> [URLRequest] {
        recordedRequests.filter { $0.url?.path == path }
    }

    private static func handler(for request: URLRequest) -> Handler? {
        lock.lock(); defer { lock.unlock() }
        guard let url = request.url, let method = request.httpMethod else { return nil }
        recorded.append(request)
        return routes[key(method, url.path)]
    }

    /// A URLSession whose traffic is answered exclusively by this stub.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        guard let handler = Self.handler(for: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let response = handler(request)
        let http = HTTPURLResponse(url: url, statusCode: response.status,
                                   httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLRequest {
    /// Decoded query items of the request URL, for shape assertions.
    var queryPairs: [String: String] {
        guard let url,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }
}
