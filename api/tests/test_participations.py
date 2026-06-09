"""Tests for joining/leaving a program (program participation endpoints)."""

from fastapi.testclient import TestClient


def _token(client: TestClient) -> str:
    # The seeded fixture user (scripts/seed.py).
    res = client.post(
        "/auth/login",
        json={"email": "jane.doe@example.com", "password": "password123"},
    )
    assert res.status_code == 200
    return str(res.json()["token"])


def _register(client: TestClient, email: str) -> str:
    res = client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "password123",
            "first_name": "Test",
            "last_name": "User",
        },
    )
    assert res.status_code == 201
    return str(res.json()["token"])


# Seeded participation (scripts/seed.py): user 1 is APPROVED in program 1.


def test_join_requires_auth(client: TestClient) -> None:
    assert client.post("/programs/2/participations").status_code == 401
    assert client.get("/programs/2/participations").status_code == 401


def test_join_unknown_program(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    assert client.post("/programs/999/participations", headers=headers).status_code == 404


def test_join_when_not_full(client: TestClient) -> None:
    # Program 2 (Bondi Beach Cleanup) has capacity 50 and no seeded volunteers.
    headers = {"Authorization": f"Bearer {_token(client)}"}

    before = client.get("/programs/2/participations", headers=headers).json()
    assert before["participant_count"] == 0
    assert before["joined"] is False
    assert before["is_full"] is False

    res = client.post("/programs/2/participations", headers=headers)
    assert res.status_code == 201
    body = res.json()
    assert body["program_id"] == 2
    assert body["participant_count"] == 1
    assert body["joined"] is True
    assert body["is_full"] is False

    after = client.get("/programs/2/participations", headers=headers).json()
    assert after["participant_count"] == 1
    assert after["joined"] is True
    assert after["is_full"] is False


def test_join_twice_conflicts(client: TestClient) -> None:
    # User 1 is already APPROVED in program 1.
    headers = {"Authorization": f"Bearer {_token(client)}"}
    res = client.post("/programs/1/participations", headers=headers)
    assert res.status_code == 409


def test_join_rejected_when_full(client: TestClient) -> None:
    # Create a single-seat program, fill it, then a second user is refused.
    owner = {"Authorization": f"Bearer {_token(client)}"}
    created = client.post(
        "/programs",
        json={
            "category_id": 1,
            "program_name": "Solo Shift",
            "description": "Only one volunteer needed.",
            "start_datetime": "2026-08-01T08:00:00Z",
            "end_datetime": "2026-08-01T11:00:00Z",
            "max_volunteers": 1,
        },
        headers=owner,
    )
    assert created.status_code == 201
    program_id = created.json()["program_id"]

    # Owner takes the only slot.
    assert client.post(f"/programs/{program_id}/participations", headers=owner).status_code == 201
    full = client.get(f"/programs/{program_id}/participations", headers=owner).json()
    assert full["is_full"] is True

    # A second volunteer is turned away.
    other = {"Authorization": f"Bearer {_register(client, 'second@example.com')}"}
    res = client.post(f"/programs/{program_id}/participations", headers=other)
    assert res.status_code == 409
    assert "full" in res.json()["detail"].lower()


def test_leave_frees_a_slot(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    # User 1 leaves program 1 (was the only seeded participant).
    assert client.delete("/programs/1/participations", headers=headers).status_code == 204

    summary = client.get("/programs/1/participations", headers=headers).json()
    assert summary["participant_count"] == 0
    assert summary["joined"] is False

    # Leaving again is a 404 (no active participation to withdraw).
    assert client.delete("/programs/1/participations", headers=headers).status_code == 404
