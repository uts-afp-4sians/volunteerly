//
//  volunteerlyTests.swift
//  volunteerlyTests
//
//  Created by Tevai Clavel on 4/6/2026.
//

import CoreLocation
import SwiftUI
import Testing
import UIKit
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

    /// Regression: a joined program in any state `GET /me/programs` can return
    /// must show up in My Page. The Active list once required
    /// `status ∈ {open, full}`, so a joined `.draft` program with a future end
    /// date matched neither Active (wrong status) nor Past (not yet ended) and
    /// vanished from the profile — the user had joined it but couldn't see it.
    /// Active and Past now split on a single "is past" predicate, so it lands in
    /// Active.
    @Test func activePrograms_includesJoinedDraftWithFutureEnd() {
        let viewModel = MyPageViewModel(httpClient: RecordingHTTPClient())
        let future = Date(timeIntervalSinceNow: 7 * 24 * 3600)
        let draft = Program(
            id: 11,
            creatorUserId: 99,
            categoryId: 1,
            locationId: 1,
            name: "Pacific Showcase",
            description: "Joined but unpublished",
            bannerImageURL: nil,
            startDatetime: Date(timeIntervalSinceNow: 6 * 24 * 3600),
            endDatetime: future,
            maxVolunteers: 10,
            commitmentFrequency: nil,
            commitmentDuration: nil,
            status: .draft,
            isDeleted: false,
            deletedAt: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        viewModel.myPrograms = [draft]

        #expect(viewModel.activePrograms.contains { $0.id == 11 })
        #expect(viewModel.pastPrograms.contains { $0.id == 11 } == false)
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

// MARK: - ProgramCard layout

@MainActor
struct ProgramCardLayoutTests {
    /// Regression: the card banner uses `.aspectRatio(contentMode: .fill)` at a
    /// fixed height, and as a direct layout child its ideal width (height ×
    /// the photo's aspect ratio) widened the whole card past the screen — the
    /// list and the detail's "Similar programs nearby" section lost their 20pt
    /// horizontal padding. The image must stay layout-neutral (overlay).
    @Test func card_keepsProposedWidth_withWideBannerImage() {
        let url = URL(string: "https://example.com/test-wide-banner.png")!
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let wideBanner = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 500), format: format)
            .image { context in
                UIColor.gray.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 2000, height: 500))
            }
        ImageCache.shared.store(wideBanner, for: url)

        let program = Program(
            id: 999,
            creatorUserId: 1,
            categoryId: 1,
            locationId: 1,
            name: "Layout test program",
            description: "Card must not exceed its proposed width",
            bannerImageURL: url.absoluteString,
            startDatetime: Date(timeIntervalSince1970: 0),
            endDatetime: Date(timeIntervalSince1970: 3600),
            maxVolunteers: 10,
            commitmentFrequency: .weekly,
            commitmentDuration: nil,
            status: .open,
            isDeleted: false,
            deletedAt: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )

        let renderer = ImageRenderer(content: ProgramCard(program: program, categoryEmoji: "🌱"))
        renderer.proposedSize = ProposedViewSize(width: 390, height: nil)
        renderer.scale = 1

        let rendered = renderer.uiImage
        #expect(rendered != nil)
        #expect(rendered?.size.width == 390)
    }
}

// MARK: - SignupFormViewModel finalising

/// Delegates to seeded mock data but rejects `PATCH /me/profile`, modelling a
/// backend that registered the account and then dropped the profile save.
private final class ProfileSaveFailingHTTPClient: HTTPClient {
    private let inner: MockHTTPClient

    init() {
        inner = MockHTTPClient()
        MockData.registerAll(in: inner)
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await inner.get(path)
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
        throw APIError.serverError(500)
    }

    func delete(_ path: String) async throws {
        try await inner.delete(path)
    }
}

@MainActor
struct SignupFormFinalisingTests {
    private final class RegisterSpy {
        var calls = 0
    }

    private func makeViewModel(spy: RegisterSpy) -> SignupFormViewModel {
        let vm = SignupFormViewModel(
            basics: SignupBasics(
                firstName: "New",
                lastName: "User",
                dateOfBirth: Date(timeIntervalSince1970: 718_848_000)
            )
        )
        vm.minimumSpinnerNanos = 0
        vm.registerAccount = { _, _, _, _ in spy.calls += 1 }
        return vm
    }

    /// Regression: a failed profile save after a successful registration used
    /// to be swallowed ("best-effort") and the user was routed onward — losing
    /// the birthday/city forever, since the My Page identity line is read-only
    /// by design. It must surface on the finalising screen instead.
    @Test func finalising_surfacesProfileSaveFailure_insteadOfRoutingOn() async {
        let spy = RegisterSpy()
        let vm = makeViewModel(spy: spy)
        let store = UserProfileStore(
            service: ProfileService(client: ProfileSaveFailingHTTPClient())
        )
        let router = AppRouter()

        vm.startFinalisingIfNeeded(profileStore: store, router: router)
        await vm.finalisingTask?.value

        #expect(spy.calls == 1)
        #expect(vm.finalisingError != nil)
        #expect(router.route == .splash)   // unchanged — no silent advance
    }

    /// "Try again" after a failed save must not hit `/auth/register` again —
    /// the account already exists, so a second attempt would 409 on our own
    /// email and bounce the user back to the account step.
    @Test func retry_afterSaveFailure_skipsReRegistration() async {
        let spy = RegisterSpy()
        let vm = makeViewModel(spy: spy)
        let store = UserProfileStore(
            service: ProfileService(client: ProfileSaveFailingHTTPClient())
        )

        vm.startFinalisingIfNeeded(profileStore: store, router: nil)
        await vm.finalisingTask?.value
        // What the finalising screen's "Try again" button does:
        vm.finalisingError = nil
        vm.hasStartedFinalising = false
        vm.startFinalisingIfNeeded(profileStore: store, router: nil)
        await vm.finalisingTask?.value

        #expect(spy.calls == 1)
        #expect(vm.finalisingError != nil)
    }

    /// Happy path: a successful save still routes to onboarding.
    @Test func finalising_routesToOnboarding_whenSaveSucceeds() async {
        let spy = RegisterSpy()
        let vm = makeViewModel(spy: spy)
        let store = UserProfileStore(
            service: ProfileService(client: RecordingHTTPClient())
        )
        let router = AppRouter()

        vm.startFinalisingIfNeeded(profileStore: store, router: router)
        await vm.finalisingTask?.value

        #expect(vm.finalisingError == nil)
        #expect(router.route == .onboarding)
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
