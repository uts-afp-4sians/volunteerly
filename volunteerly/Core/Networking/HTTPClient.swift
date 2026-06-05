import Foundation

// MARK: - Protocol

protocol HTTPClient {
    func get<T: Decodable>(_ path: String) async throws -> T
    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T
    func put<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T
    func delete(_ path: String) async throws
}

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Invalid URL"
        case .unauthorized:     return "Unauthorized. Please log in again."
        case .serverError(let code): return "Server error: \(code)"
        case .decodingFailed(let err): return "Decoding failed: \(err.localizedDescription)"
        }
    }
}

// MARK: - Live Client

final class LiveHTTPClient: HTTPClient {
    static let shared = LiveHTTPClient()

    // Single source of truth for the backend origin (see APIClient.swift).
    // Routes are root-level (`/auth/login`, `/programs`), so no path prefix.
    private let baseURL = API.defaultServerURL
    private let session = URLSession.shared
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

    var authToken: String?

    func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", body: Optional<String>.none)
        return try await perform(request)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let request = try makeRequest(path: path, method: "POST", body: body)
        return try await perform(request)
    }

    func put<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let request = try makeRequest(path: path, method: "PUT", body: body)
        return try await perform(request)
    }

    func delete(_ path: String) async throws {
        let request = try makeRequest(path: path, method: "DELETE", body: Optional<String>.none)
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    // MARK: Private

    private func makeRequest<B: Encodable>(path: String, method: String, body: B?) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try encoder.encode(body)
        }
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validate(response)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: break
        case 401: throw APIError.unauthorized
        default: throw APIError.serverError(http.statusCode)
        }
    }
}
