import Foundation

// MARK: - Mock Client

/// Swap LiveHTTPClient for MockHTTPClient during development.
/// Register path → Encodable response pairs in `handlers`.
final class MockHTTPClient: HTTPClient {
    static let shared = MockHTTPClient()

    /// Register mock responses: [path: Encodable]
    var handlers: [String: Any] = [:]

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    func get<T: Decodable>(_ path: String) async throws -> T {
        try resolve(path)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try resolve(path)
    }

    func postExpectingNoContent<B: Encodable>(_ path: String, body: B) async throws {
        // no-op for mock
    }

    func put<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try resolve(path)
    }

    func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try resolve(path)
    }

    func delete(_ path: String) async throws {
        // no-op for mock
    }

    private func resolve<T: Decodable>(_ path: String) throws -> T {
        // Match the most specific (longest) registered key that the path matches,
        // so nested routes like "/users/1/interests" win over "/users/1".
        let key = handlers.keys
            .filter { path == $0 || path.hasPrefix($0) }
            .max(by: { $0.count < $1.count }) ?? path
        guard let value = handlers[key] else {
            throw APIError.serverError(404)
        }
        let data = try encoder.encode(AnyEncodable(value))
        return try decoder.decode(T.self, from: data)
    }
}

// Utility to encode `Any` that is `Encodable`
private struct AnyEncodable: Encodable {
    let value: Any
    init(_ value: Any) { self.value = value }
    func encode(to encoder: Encoder) throws {
        guard let encodable = value as? Encodable else { return }
        try encodable.encode(to: encoder)
    }
}
