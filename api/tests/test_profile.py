"""Tests for the signed-in user's profile + interest endpoints.

The seeded fixture user is jane.doe@example.com / "password123" (user_id 1)
with interests {keyword 4 "Animal Care", keyword 7 "Education"} — see
scripts/seed.py.
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


def test_get_my_interests(client: TestClient) -> None:
    res = client.get("/me/interests", headers=_auth(client))
    assert res.status_code == 200
    body = res.json()
    assert {row["keyword_id"] for row in body} == {4, 7}
    assert set(body[0].keys()) == {"keyword_id", "keyword_name"}
    assert {row["keyword_name"] for row in body} == {"Animal Care", "Education"}


def test_put_my_interests_replaces_set(client: TestClient) -> None:
    headers = _auth(client)
    res = client.put("/me/interests", headers=headers, json={"keyword_ids": [3]})
    assert res.status_code == 200
    assert {row["keyword_id"] for row in res.json()} == {3}

    # Replacement is reflected on a fresh read.
    again = client.get("/me/interests", headers=headers).json()
    assert {row["keyword_id"] for row in again} == {3}


def test_put_my_interests_rejects_unknown_keyword(client: TestClient) -> None:
    res = client.put(
        "/me/interests", headers=_auth(client), json={"keyword_ids": [99999]}
    )
    assert res.status_code == 422
