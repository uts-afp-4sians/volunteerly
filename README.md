# Volunteerly

A volunteering platform: a SwiftUI iOS app backed by a FastAPI server, with
Turso (libSQL/SQLite) for data and Cloudflare R2 for media.

- `volunteerly/` + `volunteerly.xcodeproj` — SwiftUI iOS app
- `api/` — FastAPI backend (Python, uv, `mise` tasks)
- `api/openapi.json` — the API contract (OpenAPI 3.0), single source of truth for codegen

See [CLAUDE.md](CLAUDE.md) for build/run commands and repo conventions.

## Architecture

```mermaid
flowchart LR
    subgraph ios["iOS App (SwiftUI)"]
        features["Features<br/>Auth · Onboarding · Programs<br/>Forum · MyPage · Settings"]
        generated["Generated API Client<br/>(swift-openapi-generator)"]
        httpclient["HTTPClient / MockHTTPClient<br/>(legacy mock layer)"]
        upload["UploadService<br/>(WebP convert + presigned PUT)"]
        features --> generated
        features --> httpclient
        features --> upload
    end

    subgraph api["FastAPI Backend (api/)"]
        routers["Routers<br/>auth · users · programs · forum<br/>categories · locations · uploads"]
        services["Services (business logic)"]
        models["SQLAlchemy Models"]
        routers --> services --> models
    end

    db[("Turso<br/>libSQL / SQLite")]
    r2[("Cloudflare R2<br/>volunteerly-media")]

    generated -- "HTTPS + JWT" --> routers
    httpclient -. "HTTPS + JWT" .-> routers
    models --> db
    routers -- "presign (TTL 300s)" --> r2
    upload -- "PUT image/webp" --> r2
    ios -- "public r2.dev URLs" --> r2

    subgraph codegen["Codegen (mise gen:api)"]
        spec["api/openapi.json<br/>(3.1 → 3.0 down-convert)"]
    end
    api -. "gen:openapi" .-> spec
    spec -. "swift-openapi-generator" .-> generated
```

## ERD

```mermaid
erDiagram
    users {
        int user_id PK
        string email UK
        string password_hash "nullable, bcrypt"
        bool is_deleted
        datetime deleted_at
        datetime created_at
    }
    user_profiles {
        int user_id PK, FK
        string first_name
        string last_name
        datetime date_of_birth
        string profile_image_url
        string occupation
        string goal_text
        string bio
        string instagram
        string key_skills
        int location_id FK
    }
    user_interests {
        int user_id PK, FK
        int category_id PK, FK
    }
    categories {
        int category_id PK
        string category_name
    }
    keywords {
        int keyword_id PK
        int category_id FK
        string keyword_name
    }
    locations {
        int location_id PK
        string city
        string state_region
        string country
        float latitude
        float longitude
    }
    programs {
        int program_id PK
        int creator_user_id FK
        int category_id FK
        int location_id FK
        string program_name
        text description
        string banner_image_url
        datetime start_datetime
        datetime end_datetime
        int max_volunteers
        enum commitment_frequency
        enum commitment_duration
        enum status
        bool is_deleted
        datetime deleted_at
        datetime created_at
    }
    program_images {
        int image_id PK
        int program_id FK
        string image_url
        int sort_order
        datetime created_at
    }
    program_keywords {
        int program_id PK, FK
        int keyword_id PK, FK
    }
    program_participations {
        int participation_id PK
        int program_id FK
        int user_id FK
        enum participation_status
        datetime joined_at
    }
    program_bookmarks {
        int user_id PK, FK
        int program_id PK, FK
        datetime bookmarked_at
    }
    forum_posts {
        int post_id PK
        int program_id FK
        int author_user_id FK
        string title
        text body
        datetime created_at
    }
    forum_comments {
        int comment_id PK
        int post_id FK
        int author_user_id FK
        int parent_comment_id FK "nullable, self-ref"
        text body
        datetime created_at
    }
    forum_comment_likes {
        int comment_id PK, FK
        int user_id PK, FK
        datetime created_at
    }

    users ||--o| user_profiles : "has"
    users ||--o{ user_interests : "picks"
    categories ||--o{ user_interests : "tagged in"
    locations |o--o{ user_profiles : "based in"
    categories ||--o{ keywords : "groups"
    users ||--o{ programs : "creates"
    categories ||--o{ programs : "classifies"
    locations ||--o{ programs : "hosts"
    programs ||--o{ program_images : "gallery"
    programs ||--o{ program_keywords : "tagged with"
    keywords ||--o{ program_keywords : "tags"
    programs ||--o{ program_participations : "has"
    users ||--o{ program_participations : "joins"
    users ||--o{ program_bookmarks : "bookmarks"
    programs ||--o{ program_bookmarks : "bookmarked as"
    programs ||--o{ forum_posts : "discussed in"
    users ||--o{ forum_posts : "writes"
    forum_posts ||--o{ forum_comments : "has"
    users ||--o{ forum_comments : "writes"
    forum_comments |o--o{ forum_comments : "replies to"
    forum_comments ||--o{ forum_comment_likes : "liked via"
    users ||--o{ forum_comment_likes : "likes"
```

Notes:

- `user_interests` references `categories` directly — interests and program
  categories are one taxonomy.
- `forum_comments.parent_comment_id` is a self-referential FK that drives the
  threaded conversation UI (`NULL` = top-level comment).
- `locations` has a case-insensitive unique index on
  `(city, state_region, country)` for find-or-create dedup.
- The iOS code uses `Forum*` naming even though the original ERD called these
  tables `BOARD_*` — keep "Forum" in iOS and API code.
