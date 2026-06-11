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

    func postExpectingNoContent<B: Encodable>(_ path: String, body: B) async throws {
        try await inner.postExpectingNoContent(path, body: body)
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

private final class CancellingHTTPClient: HTTPClient {
    func get<T: Decodable>(_ path: String) async throws -> T {
        throw CancellationError()
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        throw CancellationError()
    }

    func postExpectingNoContent<B: Encodable>(_ path: String, body: B) async throws {
        throw CancellationError()
    }

    func put<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        throw CancellationError()
    }

    func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        throw CancellationError()
    }

    func delete(_ path: String) async throws {
        throw CancellationError()
    }
}

/// Throws `URLError.cancelled` on every request — models `URLSession` aborting
/// an in-flight call when a view's `.task` is torn down (e.g. a tab switch).
private final class URLCancellingHTTPClient: HTTPClient {
    private func cancelled() -> URLError { URLError(.cancelled) }

    func get<T: Decodable>(_ path: String) async throws -> T { throw cancelled() }
    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T { throw cancelled() }
    func postExpectingNoContent<B: Encodable>(_ path: String, body: B) async throws { throw cancelled() }
    func put<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T { throw cancelled() }
    func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T { throw cancelled() }
    func delete(_ path: String) async throws { throw cancelled() }
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

// MARK: - UserProfileStore

@MainActor
struct UserProfileStoreTests {
    @Test func load_doesNotShowError_whenTaskIsCancelled() async {
        let store = UserProfileStore(
            service: ProfileService(client: CancellingHTTPClient())
        )

        await store.load()

        #expect(store.isLoading == false)
        #expect(store.errorMessage == nil)
    }

    /// Regression: `currentUserId` is nil until `load()` hydrates it from
    /// `/me/profile`. `ProgramDetailView.isHost` compares this against the
    /// program's `creatorUserId`, so a view reaching the detail screen before
    /// the profile is hydrated reads `isHost == false` — hiding the host "…"
    /// menu and showing the join bar to the program's own owner. The app root
    /// now calls `load()` so the id is available on every tab.
    @Test func load_populatesCurrentUserId_forHostDetection() async {
        let store = UserProfileStore(
            service: ProfileService(client: RecordingHTTPClient())
        )

        #expect(store.currentUserId == nil)

        await store.load()

        #expect(store.currentUserId == 1)   // mock /me/profile → user_id 1
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

// MARK: - MyPageViewModel

/// Serves `/programs` from seeded mock data but throws on the auth-gated
/// `/me/programs`, modelling an expired token or cold-started backend.
private final class MyProgramsFailingHTTPClient: HTTPClient {
    private let inner: MockHTTPClient
    private(set) var requestedPaths: [String] = []

    init() {
        inner = MockHTTPClient()
        MockData.registerAll(in: inner)
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        requestedPaths.append(path)
        if path.hasPrefix("/me/programs") { throw APIError.unauthorized }
        return try await inner.get(path)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await inner.post(path, body: body)
    }

    func postExpectingNoContent<B: Encodable>(_ path: String, body: B) async throws {
        try await inner.postExpectingNoContent(path, body: body)
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

@MainActor
struct MyPageViewModelTests {
    /// Regression: the Bookmarks screen depends only on `/programs`, so a failure
    /// of the auth-gated `/me/programs` must not blank it with "Something went
    /// wrong". Loading without `includeMyPrograms` never touches that endpoint.
    @Test func bookmarksLoad_ignoresMyProgramsFailure() async {
        let http = MyProgramsFailingHTTPClient()
        let viewModel = MyPageViewModel(httpClient: http)

        await viewModel.load(includeMyPrograms: false)

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.programs.isEmpty == false)
        #expect(http.requestedPaths.contains { $0.hasPrefix("/me/programs") } == false)
    }

    /// The full My Page load still surfaces a `/me/programs` failure, since the
    /// active/Past lists genuinely need it.
    @Test func fullLoad_surfacesMyProgramsFailure() async {
        let http = MyProgramsFailingHTTPClient()
        let viewModel = MyPageViewModel(httpClient: http)

        await viewModel.load()

        #expect(viewModel.errorMessage != nil)
    }

    /// Regression: rapidly switching away from the Bookmarks tab cancels its
    /// `.task` mid-request, so `URLSession` throws `URLError.cancelled`. That is
    /// not a real failure and must not surface as "Something went wrong" on the
    /// persisted view model when the user returns.
    @Test func load_doesNotShowError_whenRequestIsCancelled() async {
        let viewModel = MyPageViewModel(httpClient: URLCancellingHTTPClient())

        await viewModel.load(includeMyPrograms: false)

        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    /// The bookmarks list is derived from the cached program pool and the shared
    /// bookmark id set — so it re-filters when the set changes, with no refetch.
    @Test func bookmarkPrograms_derivesFromGivenIds() async {
        let viewModel = MyPageViewModel(httpClient: RecordingHTTPClient())
        await viewModel.load(includeMyPrograms: false)
        let target = viewModel.programs.first!.id

        #expect(viewModel.bookmarkPrograms(bookmarkedIds: []).isEmpty)

        let shown = viewModel.bookmarkPrograms(bookmarkedIds: [target])
        #expect(shown.allSatisfy { $0.id == target })
        #expect(shown.contains { $0.id == target })
    }
}

// MARK: - BookmarkStore

@MainActor
struct BookmarkStoreTests {
    /// The shared source of truth toggles membership; both the Bookmarks list
    /// and a program's detail read this same set, so a toggle in one is seen by
    /// the other instantly.
    @Test func toggle_addsAndRemoves() {
        let store = BookmarkStore(ids: [])

        #expect(store.isBookmarked(7) == false)
        #expect(store.toggle(7) == true)
        #expect(store.isBookmarked(7) == true)
        #expect(store.toggle(7) == false)
        #expect(store.isBookmarked(7) == false)
    }
}
