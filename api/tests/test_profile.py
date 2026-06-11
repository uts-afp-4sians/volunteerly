"""Tests for the signed-in user's profile endpoint.

The seeded fixture user is jane.doe@example.com / "password123" (user_id 1)
with interests {category 2 "Animals", category 3 "Education"} — see
scripts/seed.py.

Interests are embedded in the profile resource (read) and replaced via the same
``PATCH /me/profile`` (write); there is no separate ``/me/interests`` endpoint.
"""

from fastapi.testclient import TestClient

PROFILE_KEYS = {
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
    "location",
    "interests",
}


def _token(client: TestClient) -> str:
    res = client.post(
        "/auth/login",
        json={"email": "jane.doe@example.com", "password": "password123"},
    )
    assert res.status_code == 200
    return res.json()["token"]


def _auth(client: TestClient) -> dict[str, str]:
    return {"Authorization": f"Bearer {_token(client)}"}


def test_get_my_profile(client: TestClient) -> None:
    res = client.get("/me/profile", headers=_auth(client))
    assert res.status_code == 200
    body = res.json()
    assert set(body.keys()) == PROFILE_KEYS
    assert body["user_id"] == 1
    assert body["first_name"] == "Jane"
    # Interests are embedded, joined with their category name.
    assert {row["category_id"] for row in body["interests"]} == {2, 3}
    assert set(body["interests"][0].keys()) == {"category_id", "category_name"}
    assert {row["category_name"] for row in body["interests"]} == {
        "Animals",
        "Education",
    }


def test_get_my_profile_requires_auth(client: TestClient) -> None:
    assert client.get("/me/profile").status_code in (401, 403)


def test_patch_my_profile_partial_update(client: TestClient) -> None:
    headers = _auth(client)
    res = client.patch(
        "/me/profile",
        headers=headers,
        json={"bio": "I am a Student", "instagram": "jane.codes"},
    )
    assert res.status_code == 200
    body = res.json()
    assert body["bio"] == "I am a Student"
    assert body["instagram"] == "jane.codes"
    # Untouched fields are preserved.
    assert body["first_name"] == "Jane"
    assert body["last_name"] == "Doe"
    # Interests are left untouched when the field is omitted.
    assert {row["category_id"] for row in body["interests"]} == {2, 3}

    # The change persists on a fresh read.
    again = client.get("/me/profile", headers=headers).json()
    assert again["bio"] == "I am a Student"


def test_patch_my_profile_rejects_overlong_field(client: TestClient) -> None:
    res = client.patch(
        "/me/profile",
        headers=_auth(client),
        json={"instagram": "x" * 256},
    )
    assert res.status_code == 422


def test_patch_my_profile_replaces_interests(client: TestClient) -> None:
    headers = _auth(client)
    res = client.patch(
        "/me/profile", headers=headers, json={"interest_category_ids": [3]}
    )
    assert res.status_code == 200
    assert {row["category_id"] for row in res.json()["interests"]} == {3}

    # Replacement is reflected on a fresh read.
    again = client.get("/me/profile", headers=headers).json()
    assert {row["category_id"] for row in again["interests"]} == {3}


def test_patch_my_profile_rejects_unknown_interest(client: TestClient) -> None:
    res = client.patch(
        "/me/profile",
        headers=_auth(client),
        json={"interest_category_ids": [99999]},
    )
    assert res.status_code == 422
