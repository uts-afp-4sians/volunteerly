"""Auth flow tests: register, login, /me, and the failure paths.

The seeded fixture user is jane.doe@example.com / "password123" (see
scripts/seed.py).
"""

from fastapi.testclient import TestClient

USER_KEYS = {"user_id", "email", "is_deleted", "deleted_at", "created_at"}


def test_login_success(client: TestClient) -> None:
    res = client.post(
        "/auth/login",
        json={"email": "jane.doe@example.com", "password": "password123"},
    )
    assert res.status_code == 200
    body = res.json()
    assert body["token"]
    assert set(body["user"].keys()) == USER_KEYS
    assert body["user"]["user_id"] == 1
    # The hash must never leak into the wire payload.
    assert "password_hash" not in body["user"]


def test_login_wrong_password(client: TestClient) -> None:
    res = client.post(
        "/auth/login",
        json={"email": "jane.doe@example.com", "password": "wrongpassword"},
    )
    assert res.status_code == 401


def test_login_unknown_email(client: TestClient) -> None:
    res = client.post(
        "/auth/login",
        json={"email": "nobody@example.com", "password": "password123"},
    )
    assert res.status_code == 401


def test_register_then_login(client: TestClient) -> None:
    payload = {
        "email": "new.user@example.com",
        "password": "supersecret",
        "first_name": "New",
        "last_name": "User",
    }
    res = client.post("/auth/register", json=payload)
    assert res.status_code == 201
    body = res.json()
    assert body["token"]
    assert body["user"]["email"] == "new.user@example.com"

    # The new account's profile was created and is fetchable.
    new_id = body["user"]["user_id"]
    profile = client.get(f"/users/{new_id}/profile")
    assert profile.status_code == 200
    assert profile.json()["first_name"] == "New"

    # And the new credentials authenticate.
    login = client.post(
        "/auth/login",
        json={"email": payload["email"], "password": payload["password"]},
    )
    assert login.status_code == 200


def test_register_duplicate_email(client: TestClient) -> None:
    res = client.post(
        "/auth/register",
        json={
            "email": "jane.doe@example.com",
            "password": "password123",
            "first_name": "Jane",
            "last_name": "Doe",
        },
    )
    assert res.status_code == 409


def test_register_rejects_short_password(client: TestClient) -> None:
    res = client.post(
        "/auth/register",
        json={
            "email": "short.pw@example.com",
            "password": "short",
            "first_name": "Short",
            "last_name": "Pw",
        },
    )
    assert res.status_code == 422


def test_me_with_token(client: TestClient) -> None:
    token = client.post(
        "/auth/login",
        json={"email": "jane.doe@example.com", "password": "password123"},
    ).json()["token"]

    res = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    assert res.json()["user_id"] == 1


def test_me_without_token(client: TestClient) -> None:
    assert client.get("/auth/me").status_code == 401


def test_me_with_invalid_token(client: TestClient) -> None:
    res = client.get("/auth/me", headers={"Authorization": "Bearer not-a-real-token"})
    assert res.status_code == 401
