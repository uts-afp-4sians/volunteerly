"""Contract tests: assert the live API matches the iOS mock contract.

Field sets below mirror the `CodingKeys` in volunteerly/Core/Models/*.swift and
the handlers registered in Core/Networking/MockData.swift.
"""

from fastapi.testclient import TestClient

PROGRAM_KEYS = {
    "program_id",
    "creator_user_id",
    "category_id",
    "location_id",
    "program_name",
    "description",
    "banner_image_url",
    "start_datetime",
    "end_datetime",
    "max_volunteers",
    "commitment_frequency",
    "commitment_duration",
    "status",
    "is_deleted",
    "deleted_at",
    "created_at",
    # Optional enrichments, null in list responses unless requested:
    "participant_count",
    "is_full",
    "distance_km",
}


def test_list_programs(client: TestClient) -> None:
    res = client.get("/programs")
    assert res.status_code == 200
    body = res.json()
    assert len(body) == 4
    first = body[0]
    assert set(first.keys()) == PROGRAM_KEYS
    assert first["program_id"] == 1
    assert first["program_name"] == "Centennial Park Tree Planting"
    assert first["status"] == "open"
    assert body[3]["status"] == "full"


def test_get_program(client: TestClient) -> None:
    res = client.get("/programs/1")
    assert res.status_code == 200
    assert set(res.json().keys()) == PROGRAM_KEYS
    assert res.json()["program_id"] == 1


def test_get_program_not_found(client: TestClient) -> None:
    assert client.get("/programs/999").status_code == 404


def test_datetimes_are_iso8601_with_timezone(client: TestClient) -> None:
    # iOS decodes with .iso8601, which requires a timezone designator.
    program = client.get("/programs/1").json()
    assert program["start_datetime"] == "2026-07-01T08:00:00Z"
    assert program["created_at"].endswith("Z")
    assert program["deleted_at"] is None


LOCATION_KEYS = {
    "location_id",
    "city",
    "state_region",
    "country",
    "latitude",
    "longitude",
}


def test_get_location(client: TestClient) -> None:
    res = client.get("/locations/1")
    assert res.status_code == 200
    body = res.json()
    assert set(body.keys()) == LOCATION_KEYS
    assert body["city"] == "Sydney"
    assert body["state_region"] == "NSW"
    assert body["country"] == "Australia"


def test_get_location_not_found(client: TestClient) -> None:
    assert client.get("/locations/999").status_code == 404


def test_list_categories(client: TestClient) -> None:
    res = client.get("/categories")
    assert res.status_code == 200
    body = res.json()
    assert len(body) == 8
    assert set(body[0].keys()) == {"category_id", "category_name"}
    assert body[0] == {"category_id": 1, "category_name": "Environment"}


def test_list_keywords(client: TestClient) -> None:
    res = client.get("/keywords")
    assert res.status_code == 200
    body = res.json()
    # 3 program-tagging keywords + 9 profile interest keywords.
    assert len(body) == 12
    assert set(body[0].keys()) == {"keyword_id", "category_id", "keyword_name"}
    assert body[0] == {
        "keyword_id": 1,
        "category_id": 1,
        "keyword_name": "Tree Planting",
    }
    # The interest catalog the profile picker offers.
    interest_names = {row["keyword_name"] for row in body if row["keyword_id"] >= 4}
    assert {"Animal Care", "Education", "Technology"} <= interest_names


def test_list_interests(client: TestClient) -> None:
    res = client.get("/interests")
    assert res.status_code == 200
    body = res.json()
    # Only the 9 profile-interest keywords (is_interest=True) — program-tagging
    # keywords like "Tree Planting" are excluded.
    assert len(body) == 9
    assert set(body[0].keys()) == {"keyword_id", "category_id", "keyword_name"}
    names = [row["keyword_name"] for row in body]
    assert names == [
        "Animal Care",
        "Arts & Creativity",
        "Community Building",
        "Education",
        "Aged Care",
        "Environment",
        "Food",
        "Social Justice",
        "Technology",
    ]
    assert "Tree Planting" not in names


def test_get_user(client: TestClient) -> None:
    res = client.get("/users/1")
    assert res.status_code == 200
    body = res.json()
    assert set(body.keys()) == {
        "user_id",
        "email",
        "is_deleted",
        "deleted_at",
        "created_at",
    }
    assert body["user_id"] == 1
    assert body["email"] == "jane.doe@example.com"
    assert body["is_deleted"] is False
    assert body["deleted_at"] is None


def test_get_user_profile(client: TestClient) -> None:
    res = client.get("/users/1/profile")
    assert res.status_code == 200
    body = res.json()
    assert set(body.keys()) == {
        "user_id",
        "first_name",
        "last_name",
        "date_of_birth",
        "profile_image_url",
        "occupation",
        "goal_text",
        "bio",
        "instagram",
        "key_skills",
        "location_id",
    }
    assert body["first_name"] == "Jane"
    assert body["last_name"] == "Doe"
    assert body["location_id"] == 1


def test_list_user_interests(client: TestClient) -> None:
    res = client.get("/users/1/interests")
    assert res.status_code == 200
    body = res.json()
    assert len(body) == 2
    assert set(body[0].keys()) == {"user_id", "keyword_id"}
    assert {row["keyword_id"] for row in body} == {4, 7}


def test_list_program_keywords(client: TestClient) -> None:
    res = client.get("/programs/1/keywords")
    assert res.status_code == 200
    body = res.json()
    assert body == [{"program_id": 1, "keyword_id": 1}]


def test_list_program_posts(client: TestClient) -> None:
    res = client.get("/programs/1/posts")
    assert res.status_code == 200
    body = res.json()
    assert len(body) == 6
    assert set(body[0].keys()) == {
        "post_id",
        "program_id",
        "author_user_id",
        "title",
        "body",
        "created_at",
    }
    assert body[0]["title"] == "What should I bring?"


def test_list_post_comments(client: TestClient) -> None:
    res = client.get("/programs/1/posts/1/comments")
    assert res.status_code == 200
    body = res.json()
    assert len(body) == 5
    assert set(body[0].keys()) == {
        "comment_id",
        "post_id",
        "author_user_id",
        "body",
        "created_at",
        "parent_comment_id",
        "like_count",
        "liked_by_me",
    }
    assert body[0]["comment_id"] == 1
    # Comment 1 is a root (no parent); comment 2 replies to it.
    assert body[0]["parent_comment_id"] is None
    assert body[1]["parent_comment_id"] == 1
    # Comment 5 has four seeded likes; an anonymous read isn't "liked_by_me".
    assert body[4]["like_count"] == 4
    assert body[4]["liked_by_me"] is False
