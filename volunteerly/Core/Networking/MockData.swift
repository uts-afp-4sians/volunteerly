import Foundation

// MARK: - Mock Data

enum MockData {

    // MARK: Location
    /// Distinct Sydney-area spots (mirrors scripts/seed.py) so each program has
    /// its own coordinates and the list can show a per-card distance.
    static let locations: [Location] = [
        Location(id: 1, city: "Sydney", stateRegion: "NSW", country: "Australia",
                 latitude: -33.8688, longitude: 151.2093),
        Location(id: 2, city: "Bondi Beach", stateRegion: "NSW", country: "Australia",
                 latitude: -33.8908, longitude: 151.2743),
        Location(id: 3, city: "Newtown", stateRegion: "NSW", country: "Australia",
                 latitude: -33.8983, longitude: 151.1784),
        Location(id: 4, city: "Chatswood", stateRegion: "NSW", country: "Australia",
                 latitude: -33.7969, longitude: 151.1803)
    ]

    /// The primary location, kept for call sites that want a single default.
    static let location = locations[0]

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
        bio: "I am a Student, I can bring social media management.",
        instagram: "jane.doe",
        keySkills: "Social media, Communication",
        locationId: 1,
        interests: [
            UserInterestDetail(keywordId: 4, keywordName: "Animal Care"),
            UserInterestDetail(keywordId: 7, keywordName: "Education"),
        ]
    )

    /// A few extra members so the Member board and forum thread show varied
    /// authors (and the Author A-Z / Z-A sort chips have something to do).
    static let memberProfiles: [UserProfile] = [
        userProfile,
        UserProfile(userId: 2, firstName: "Marcus", lastName: "Lee",
                    dateOfBirth: nil, profileImageURL: "https://i.pravatar.cc/150?img=12",
                    occupation: "Teacher", goalText: nil, bio: nil, instagram: nil,
                    keySkills: nil, locationId: 1),
        UserProfile(userId: 3, firstName: "Aisha", lastName: "Khan",
                    dateOfBirth: nil, profileImageURL: "https://i.pravatar.cc/150?img=5",
                    occupation: "Nurse", goalText: nil, bio: nil, instagram: nil,
                    keySkills: nil, locationId: 1),
        UserProfile(userId: 4, firstName: "Tom", lastName: "Becker",
                    dateOfBirth: nil, profileImageURL: "https://i.pravatar.cc/150?img=15",
                    occupation: "Designer", goalText: nil, bio: nil, instagram: nil,
                    keySkills: nil, locationId: 1)
    ]

    // MARK: Category & Keywords
    static let category = ProgramCategory(id: 1, name: "Environment")

    static let categories: [ProgramCategory] = [
        ProgramCategory(id: 1, name: "Environment"),
        ProgramCategory(id: 2, name: "Community"),
        ProgramCategory(id: 3, name: "Education"),
        ProgramCategory(id: 4, name: "Health"),
        ProgramCategory(id: 5, name: "Animals"),
        ProgramCategory(id: 6, name: "Seniors"),
        ProgramCategory(id: 7, name: "Food"),
        ProgramCategory(id: 8, name: "Arts")
    ]

    static let keywords: [Keyword] = [
        // Program-tagging keywords.
        Keyword(id: 1, categoryId: 1, name: "Tree Planting"),
        Keyword(id: 2, categoryId: 1, name: "Beach Cleanup"),
        Keyword(id: 3, categoryId: 1, name: "Recycling"),
        // Profile interest catalogue (mirrors scripts/seed.py).
        Keyword(id: 4, categoryId: 5, name: "Animal Care"),
        Keyword(id: 5, categoryId: 8, name: "Arts & Creativity"),
        Keyword(id: 6, categoryId: 2, name: "Community Building"),
        Keyword(id: 7, categoryId: 3, name: "Education"),
        Keyword(id: 8, categoryId: 6, name: "Aged Care"),
        Keyword(id: 9, categoryId: 1, name: "Environment"),
        Keyword(id: 10, categoryId: 7, name: "Food"),
        Keyword(id: 11, categoryId: 2, name: "Social Justice"),
        Keyword(id: 12, categoryId: 4, name: "Technology")
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
            bannerImageURLs: [
                "https://picsum.photos/seed/prog1/800/400",
                "https://picsum.photos/seed/prog1b/800/400",
                "https://picsum.photos/seed/prog1c/800/400",
            ],
            startDatetime: ISO8601DateFormatter().date(from: "2026-07-01T08:00:00Z")!,
            endDatetime: ISO8601DateFormatter().date(from: "2026-07-01T12:00:00Z")!,
            maxVolunteers: 30,
            commitmentFrequency: .monthly,
            commitmentDuration: .threeToSix,
            status: .open,
            isDeleted: false,
            deletedAt: nil,
            createdAt: .now,
            participantCount: 12
        ),
        Program(
            id: 2,
            creatorUserId: 1,
            categoryId: 1,
            locationId: 2,
            name: "Bondi Beach Cleanup",
            description: "Help keep Bondi Beach clean by joining our monthly cleanup crew.",
            bannerImageURL: "https://picsum.photos/seed/prog2/800/400",
            startDatetime: ISO8601DateFormatter().date(from: "2026-07-15T07:00:00Z")!,
            endDatetime: ISO8601DateFormatter().date(from: "2026-07-15T10:00:00Z")!,
            maxVolunteers: 50,
            commitmentFrequency: .monthly,
            commitmentDuration: .continuous,
            status: .open,
            isDeleted: false,
            deletedAt: nil,
            createdAt: .now,
            participantCount: 8
        ),
        Program(
            id: 3,
            creatorUserId: 1,
            categoryId: 3,
            locationId: 3,
            name: "After-School Reading Club",
            description: "Help local primary students build confidence by reading together once a week.",
            bannerImageURL: "https://picsum.photos/seed/prog3/800/400",
            startDatetime: ISO8601DateFormatter().date(from: "2026-07-08T15:30:00Z")!,
            endDatetime: ISO8601DateFormatter().date(from: "2026-07-08T17:00:00Z")!,
            maxVolunteers: 12,
            commitmentFrequency: .weekly,
            commitmentDuration: .sevenToNine,
            status: .open,
            isDeleted: false,
            deletedAt: nil,
            createdAt: .now,
            participantCount: 5
        ),
        Program(
            id: 4,
            creatorUserId: 1,
            categoryId: 6,
            locationId: 4,
            name: "Senior Tech Support Drop-In",
            description: "Spend an afternoon helping seniors get comfortable with their phones and laptops.",
            bannerImageURL: "https://picsum.photos/seed/prog4/800/400",
            startDatetime: ISO8601DateFormatter().date(from: "2026-07-20T13:00:00Z")!,
            endDatetime: ISO8601DateFormatter().date(from: "2026-07-20T16:00:00Z")!,
            maxVolunteers: 8,
            commitmentFrequency: .weekly,
            commitmentDuration: .under2,
            status: .full,
            isDeleted: false,
            deletedAt: nil,
            createdAt: .now,
            participantCount: 8
        ),
        Program(
            id: 5,
            creatorUserId: 1,
            categoryId: 2,
            locationId: 2,
            name: "Harbour Foreshore Restoration",
            description: "A weekend spent clearing weeds and replanting natives along the foreshore.",
            bannerImageURL: "https://picsum.photos/seed/prog5/800/400",
            startDatetime: ISO8601DateFormatter().date(from: "2026-03-14T08:00:00Z")!,
            endDatetime: ISO8601DateFormatter().date(from: "2026-03-14T13:00:00Z")!,
            maxVolunteers: 40,
            commitmentFrequency: .monthly,
            commitmentDuration: .continuous,
            status: .closed,
            isDeleted: false,
            deletedAt: nil,
            createdAt: .now,
            participantCount: 22
        ),
        Program(
            id: 6,
            creatorUserId: 1,
            categoryId: 7,
            locationId: 3,
            name: "Community Kitchen Lunch Service",
            description: "Prepared and served hot meals for those doing it tough in the inner city.",
            bannerImageURL: "https://picsum.photos/seed/prog6/800/400",
            startDatetime: ISO8601DateFormatter().date(from: "2026-04-22T10:00:00Z")!,
            endDatetime: ISO8601DateFormatter().date(from: "2026-04-22T14:00:00Z")!,
            maxVolunteers: 20,
            commitmentFrequency: .weekly,
            commitmentDuration: .threeToSix,
            status: .closed,
            isDeleted: false,
            deletedAt: nil,
            createdAt: .now,
            participantCount: 20
        ),
        Program(
            id: 7,
            creatorUserId: 1,
            categoryId: 5,
            locationId: 4,
            name: "Wildlife Shelter Open Day",
            description: "Awaiting confirmation to help out at the local wildlife shelter open day.",
            bannerImageURL: "https://picsum.photos/seed/prog7/800/400",
            startDatetime: ISO8601DateFormatter().date(from: "2026-08-09T09:00:00Z")!,
            endDatetime: ISO8601DateFormatter().date(from: "2026-08-09T15:00:00Z")!,
            maxVolunteers: 15,
            commitmentFrequency: .monthly,
            commitmentDuration: .under2,
            status: .draft,
            isDeleted: false,
            deletedAt: nil,
            createdAt: .now,
            participantCount: 1
        )
    ]

    // MARK: User Interests (USER_INTEREST junction)
    static let userInterests: [UserInterest] = [
        UserInterest(userId: 1, keywordId: 4),  // Animal Care
        UserInterest(userId: 1, keywordId: 7)   // Education
    ]

    // MARK: Program Keywords (PROGRAM_KEYWORD junction)
    static let programKeywords: [ProgramKeyword] = [
        ProgramKeyword(programId: 1, keywordId: 1),
        ProgramKeyword(programId: 2, keywordId: 2)
    ]

    // MARK: Participation
    static let participation = ProgramParticipation(
        id: 1,
        programId: 1,
        userId: 1,
        status: .approved,
        joinedAt: .now
    )

    /// Capacity snapshot the detail screen reads from
    /// `/programs/{id}/participations`. Program 1 reflects the seeded join.
    static func participationSummary(for program: Program) -> ProgramParticipationSummary {
        let joined = program.id == 1
        let count = joined ? 1 : 0
        return ProgramParticipationSummary(
            programId: program.id,
            participantCount: count,
            maxVolunteers: program.maxVolunteers,
            isFull: count >= program.maxVolunteers,
            joined: joined
        )
    }

    // MARK: Forum
    /// Stagger the timestamps so the date sort chips produce a visible reorder.
    private static func forumDate(_ daysAgo: Int) -> Date {
        Date(timeIntervalSinceNow: TimeInterval(-daysAgo * 86_400))
    }

    static let forumPosts: [ForumPost] = [
        ForumPost(id: 1, programId: 1, authorUserId: 1,
                  title: "What should I bring?",
                  body: "Hi everyone, should I bring my own gloves and tools?",
                  createdAt: forumDate(1)),
        ForumPost(id: 2, programId: 1, authorUserId: 3,
                  title: "Parking nearby?",
                  body: "Is there parking available near the park entrance?",
                  createdAt: forumDate(2)),
        ForumPost(id: 3, programId: 1, authorUserId: 2,
                  title: "Dress code?",
                  body: "What should we wear — is there a recommended outfit for the day?",
                  createdAt: forumDate(3)),
        ForumPost(id: 4, programId: 1, authorUserId: 4,
                  title: "Carpool?",
                  body: "Anyone coming from the north shore keen to share a ride?",
                  createdAt: forumDate(4)),
        ForumPost(id: 5, programId: 1, authorUserId: 3,
                  title: "Lunch provided?",
                  body: "Will food be provided or should we pack our own?",
                  createdAt: forumDate(5)),
        ForumPost(id: 6, programId: 1, authorUserId: 2,
                  title: "Kids welcome?",
                  body: "Can I bring my two kids along to help out?",
                  createdAt: forumDate(6))
    ]

    /// A threaded conversation for post 1: top-level comments, indented
    /// replies (`parentCommentId`), and a few likes — exercising the full
    /// forum thread design.
    static let forumComments: [ForumComment] = [
        ForumComment(id: 1, postId: 1, authorUserId: 2,
                     body: "Yes, please bring gloves! Tools will be provided on site.",
                     createdAt: forumDate(1), parentCommentId: nil, likeCount: 0, likedByMe: false),
        ForumComment(id: 2, postId: 1, authorUserId: 3,
                     body: "Great, thanks for confirming.",
                     createdAt: forumDate(1), parentCommentId: 1, likeCount: 2, likedByMe: true),
        ForumComment(id: 3, postId: 1, authorUserId: 4,
                     body: "Are gardening gloves fine, or do we need heavy-duty ones?",
                     createdAt: forumDate(1), parentCommentId: 1, likeCount: 1, likedByMe: false),
        ForumComment(id: 4, postId: 1, authorUserId: 1,
                     body: "Sturdy gardening gloves are perfect.",
                     createdAt: forumDate(1), parentCommentId: 3, likeCount: 3, likedByMe: false),
        ForumComment(id: 5, postId: 1, authorUserId: 3,
                     body: "Also bring a refillable water bottle — it gets warm by midday.",
                     createdAt: forumDate(1), parentCommentId: nil, likeCount: 4, likedByMe: true)
    ]

    // MARK: - Registered Handlers for MockHTTPClient

    static func registerAll(in client: MockHTTPClient) {
        client.handlers = [
            "/programs":            programs,
            "/programs/1":          programs[0],
            "/programs/2":          programs[1],
            "/programs/3":          programs[2],
            "/programs/4":          programs[3],
            "/programs/5":          programs[4],
            "/programs/6":          programs[5],
            "/programs/7":          programs[6],
            "/users/1":             user,
            "/users/1/profile":     userProfile,
            "/me/profile":          userProfile,
            "/programs/1/posts":    forumPosts,
            "/categories":          categories,
            "/keywords":            keywords,
            "/users/1/interests":   userInterests,
            "/programs/1/keywords": programKeywords,
            "/programs/2/keywords": [programKeywords[1]]
        ]
        for program in programs {
            client.handlers["/programs/\(program.id)/participations"] =
                participationSummary(for: program)
            // Member profiles for the avatar row. Program 1 mirrors the seed
            // (host + three members); the rest have no extra members yet.
            client.handlers["/programs/\(program.id)/participants"] =
                program.id == 1 ? memberProfiles : [UserProfile]()
        }
        for location in locations {
            client.handlers["/locations/\(location.id)"] = location
        }
        // Member profiles drive forum author names + avatars.
        for profile in memberProfiles {
            client.handlers["/users/\(profile.userId)/profile"] = profile
        }
        // Every board question resolves to the same seeded thread.
        for post in forumPosts {
            client.handlers["/programs/1/posts/\(post.id)/comments"] = forumComments
        }
        // Like endpoints just need to decode as a ForumComment so the mobile's
        // optimistic toggle isn't reverted in previews/mock runs.
        for comment in forumComments {
            client.handlers["/programs/1/posts/1/comments/\(comment.id)/like"] = comment
        }
    }
}
