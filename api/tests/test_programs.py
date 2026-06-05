"""Tests for program creation (POST /programs)."""

from fastapi.testclient import TestClient

VALID_PROGRAM = {
    "category_id": 1,
    "program_name": "Harbour Cleanup Crew",
    "description": "Spend a morning clearing litter along the foreshore.",
    "start_datetime": "2026-08-01T08:00:00Z",
    "end_datetime": "2026-08-01T11:00:00Z",
    "max_volunteers": 15,
}


def _token(client: TestClient) -> str:
    # The seeded fixture user (scripts/seed.py).
    res = client.post(
        "/auth/login",
        json={"email": "jane.doe@example.com", "password": "password123"},
    )
    assert res.status_code == 200
    return str(res.json()["token"])


def test_create_program_requires_auth(client: TestClient) -> None:
    assert client.post("/programs", json=VALID_PROGRAM).status_code == 401


def test_create_program(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    res = client.post("/programs", json=VALID_PROGRAM, headers=headers)
    assert res.status_code == 201
    body = res.json()
    assert body["program_name"] == "Harbour Cleanup Crew"
    assert body["creator_user_id"] == 1  # taken from the token, not the body
    assert body["status"] == "open"
    assert body["location_id"] == 1  # defaulted to the only seeded location

    # It now shows up in the list.
    listing = client.get("/programs").json()
    assert any(p["program_name"] == "Harbour Cleanup Crew" for p in listing)


def test_create_program_unknown_category(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    payload = {**VALID_PROGRAM, "category_id": 999}
    assert client.post("/programs", json=payload, headers=headers).status_code == 404


def test_create_program_end_before_start(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    payload = {
        **VALID_PROGRAM,
        "start_datetime": "2026-08-01T11:00:00Z",
        "end_datetime": "2026-08-01T08:00:00Z",
    }
    assert client.post("/programs", json=payload, headers=headers).status_code == 422
