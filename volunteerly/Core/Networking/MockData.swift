import Foundation

// MARK: - Mock Data

enum MockData {

    // MARK: Location
    static let location = Location(
        id: 1,
        city: "Sydney",
        stateRegion: "NSW",
        country: "Australia",
        latitude: -33.8688,
        longitude: 151.2093
    )

    // MARK: User
    static let user = User(
        id: 1,
        email: "jane.doe@example.com",
        isDeleted: false,
        deletedAt: nil,
        createdAt: .now
    )

    static let userProfile = UserProfile(
        userId: 1,
        firstName: "Jane",
        lastName: "Doe",
        dateOfBirth: ISO8601DateFormatter().date(from: "1995-04-20T00:00:00Z"),
        profileImageURL: "https://i.pravatar.cc/150?img=1",
        occupation: "Software Engineer",
        goalText: "I want to give back to my community.",
        locationId: 1
    )

    // MARK: Category & Keywords
    static let category = ProgramCategory(id: 1, name: "Environment")

    static let keywords: [Keyword] = [
        Keyword(id: 1, categoryId: 1, name: "Tree Planting"),
        Keyword(id: 2, categoryId: 1, name: "Beach Cleanup"),
        Keyword(id: 3, categoryId: 1, name: "Recycling")
    ]

    // MARK: Programs
    static let programs: [Program] = [
        Program(
            id: 1,
            creatorUserId: 1,
            categoryId: 1,
            locationId: 1,
            name: "Centennial Park Tree Planting",
            description: "Join us for a morning of tree planting in Centennial Park to restore native bushland.",
            bannerImageURL: "https://picsum.photos/seed/prog1/800/400",
            startDatetime: ISO8601DateFormatter().date(from: "2026-07-01T08:00:00Z")!,
            endDatetime: ISO8601DateFormatter().date(from: "2026-07-01T12:00:00Z")!,
            maxVolunteers: 30,
            status: .open,
            isDeleted: false,
            deletedAt: nil,
            createdAt: .now
        ),
        Program(
            id: 2,
            creatorUserId: 1,
            categoryId: 1,
            locationId: 1,
            name: "Bondi Beach Cleanup",
            description: "Help keep Bondi Beach clean by joining our monthly cleanup crew.",
            bannerImageURL: "https://picsum.photos/seed/prog2/800/400",
            startDatetime: ISO8601DateFormatter().date(from: "2026-07-15T07:00:00Z")!,
            endDatetime: ISO8601DateFormatter().date(from: "2026-07-15T10:00:00Z")!,
            maxVolunteers: 50,
            status: .open,
            isDeleted: false,
            deletedAt: nil,
            createdAt: .now
        )
    ]

    // MARK: Participation
    static let participation = ProgramParticipation(
        id: 1,
        programId: 1,
        userId: 1,
        status: .approved,
        joinedAt: .now
    )

    // MARK: Forum
    static let forumPosts: [ForumPost] = [
        ForumPost(
            id: 1,
            programId: 1,
            authorUserId: 1,
            title: "What should I bring?",
            body: "Hi everyone, should I bring my own gloves and tools?",
            createdAt: .now
        ),
        ForumPost(
            id: 2,
            programId: 1,
            authorUserId: 1,
            title: "Parking nearby?",
            body: "Is there parking available near the park entrance?",
            createdAt: .now
        )
    ]

    static let forumComments: [ForumComment] = [
        ForumComment(
            id: 1,
            postId: 1,
            authorUserId: 1,
            body: "Yes, please bring gloves! Tools will be provided.",
            createdAt: .now
        )
    ]

    // MARK: - Registered Handlers for MockHTTPClient

    static func registerAll(in client: MockHTTPClient) {
        client.handlers = [
            "/programs":            programs,
            "/programs/1":          programs[0],
            "/programs/2":          programs[1],
            "/users/1":             user,
            "/users/1/profile":     userProfile,
            "/programs/1/posts":    forumPosts,
            "/programs/1/posts/1/comments": forumComments,
            "/categories":          [category],
            "/keywords":            keywords
        ]
    }
}
