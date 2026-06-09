import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// Factory for the generated OpenAPI `Client`.
///
/// The client is generated from `api/openapi.json` via `mise gen:api` into
/// `Generated/`. This coexists with `HTTPClient`/`MockHTTPClient`; screens can
/// migrate to it as the backend endpoints stabilise.
enum API {
    /// Backend origin. The spec declares no `servers`, so the base URL is
    /// supplied here. Hosted on Render (Turso-backed); for local development
    /// against the FastAPI dev server, swap to `http://localhost:8000`.
    static let defaultServerURL = URL(string: "https://volunteerly-bl7n.onrender.com")!

    /// Builds the generated client with the session token from `SessionManager`
    /// injected via `URLSessionConfiguration.httpAdditionalHeaders`.
    static func makeClient(serverURL: URL = defaultServerURL) -> Client {
        let config = URLSessionConfiguration.default
        if let token = SessionManager.shared.token {
            config.httpAdditionalHeaders = ["Authorization": "Bearer \(token)"]
        }
        let session = URLSession(configuration: config)
        return Client(
            serverURL: serverURL,
            transport: URLSessionTransport(configuration: .init(session: session))
        )
    }
}
