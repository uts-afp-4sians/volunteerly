import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// Factory for the generated OpenAPI `Client`.
///
/// The client is generated from `api/openapi.json` via `mise gen:api` into
/// `Generated/`. This coexists with `HTTPClient`/`MockHTTPClient`; screens can
/// migrate to it as the backend endpoints stabilise.
enum API {
    /// FastAPI dev server (see `api` mise `dev` task, `--port 8000`). The spec
    /// declares no `servers`, so the base URL is supplied here.
    static let defaultServerURL = URL(string: "http://localhost:8000")!

    static func makeClient(serverURL: URL = defaultServerURL) -> Client {
        Client(serverURL: serverURL, transport: URLSessionTransport())
    }
}
