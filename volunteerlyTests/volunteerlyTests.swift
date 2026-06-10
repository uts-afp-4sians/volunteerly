//
//  volunteerlyTests.swift
//  volunteerlyTests
//
//  Created by Tevai Clavel on 4/6/2026.
//

import CoreLocation
import Testing
@testable import volunteerly

// MARK: - Auth validation

struct AuthValidationTests {
    @Test func registrationPasswordMatchesBackendMinimum() {
        #expect(!AuthValidation.isValidPassword("123456"))
        #expect(!AuthValidation.isValidPassword("1234567"))
        #expect(AuthValidation.isValidPassword("12345678"))
    }
}

// MARK: - Test doubles

/// Records every requested path while delegating to a seeded `MockHTTPClient`,
/// so tests can assert which queries the view model issued.
private final class RecordingHTTPClient: HTTPClient {
    private let inner: MockHTTPClient
    private(set) var requestedPaths: [String] = []

    init() {
        inner = MockHTTPClient()
        MockData.registerAll(in: inner)
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        requestedPaths.append(path)
        return try await inner.get(path)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await inner.post(path, body: body)
    }

    func put<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await inner.put(path, body: body)
    }

    func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await inner.patch(path, body: body)
    }

    func delete(_ path: String) async throws {
        try await inner.delete(path)
    }
}

/// Returns a fixed coordinate (or `nil` to model a denied prompt) immediately.
@MainActor
private final class StubLocationProvider: LocationProviding {
    let coordinate: CLLocationCoordinate2D?
    init(coordinate: CLLocationCoordinate2D?) { self.coordinate = coordinate }
    func currentCoordinate() async -> CLLocationCoordinate2D? { coordinate }
}

/// Never resolves until cancelled — models an unanswered permission prompt.
@MainActor
private final class HangingLocationProvider: LocationProviding {
    func currentCoordinate() async -> CLLocationCoordinate2D? {
        try? await Task.sleep(for: .seconds(3600))
        return nil
    }
}

// MARK: - ProgramListViewModel

@MainActor
struct ProgramListViewModelTests {
    private let seoul = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)

    /// Regression: the list must render even if the location prompt is never
    /// answered. Previously `load()` awaited the coordinate before fetching, so
    /// an unanswered prompt left the screen spinning forever.
    @Test func load_doesNotBlockOnUnresolvedLocation() async {
        let http = RecordingHTTPClient()
        let viewModel = ProgramListViewModel(
            httpClient: http,
            locationProvider: HangingLocationProvider()
        )

        await viewModel.load()

        #expect(viewModel.isLoading == false)
        #expect(viewModel.programs.isEmpty == false)

        // The background coordinate task is still suspended; cancel it so the
        // test doesn't leak the hanging sleep.
        viewModel.locationTask?.cancel()
    }

    /// Once the coordinate resolves, the view model re-fetches with lat/lng so
    /// cards can show distances.
    @Test func load_refetchesWithCoordinate_whenLocationResolves() async {
        let http = RecordingHTTPClient()
        let viewModel = ProgramListViewModel(
            httpClient: http,
            locationProvider: StubLocationProvider(coordinate: seoul)
        )

        await viewModel.load()
        await viewModel.locationTask?.value   // wait for the silent distance re-fetch

        #expect(viewModel.programs.isEmpty == false)
        #expect(http.requestedPaths.contains { $0.contains("lat=") && $0.contains("lng=") })
    }

    /// A denied prompt (nil coordinate) loads the list once and issues no
    /// distance query.
    @Test func load_skipsDistanceQuery_whenLocationDenied() async {
        let http = RecordingHTTPClient()
        let viewModel = ProgramListViewModel(
            httpClient: http,
            locationProvider: StubLocationProvider(coordinate: nil)
        )

        await viewModel.load()
        await viewModel.locationTask?.value

        #expect(viewModel.programs.isEmpty == false)
        #expect(http.requestedPaths.contains { $0.contains("lat=") } == false)
    }
}
