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
    assert (
        client.post("/programs/999/participations", headers=headers).status_code == 404
    )


def test_join_when_not_full(client: TestClient) -> None:
    # Program 2 (Bondi Beach Cleanup) has capacity 50 and no seeded volunteer
    # rows. Its host (user 1) is counted implicitly, so the count starts at 1; a
    # fresh volunteer joining takes it to 2.
    headers = {"Authorization": f"Bearer {_register(client, 'joiner@example.com')}"}

    before = client.get("/programs/2/participations", headers=headers).json()
    assert before["participant_count"] == 1  # host counted, no rows yet
    assert before["joined"] is False
    assert before["is_full"] is False

    res = client.post("/programs/2/participations", headers=headers)
    assert res.status_code == 201
    body = res.json()
    assert body["program_id"] == 2
    assert body["participant_count"] == 2  # host + this volunteer
    assert body["joined"] is True
    assert body["is_full"] is False

    after = client.get("/programs/2/participations", headers=headers).json()
    assert after["participant_count"] == 2
    assert after["joined"] is True
    assert after["is_full"] is False


def test_host_counted_without_participation_row(client: TestClient) -> None:
    # Regression: programs created before creator auto-enrolment have no host
    # participation row (seeded programs 2-4 mirror that state). The host must
    # still be counted, so a lone volunteer reads as 2 (host + them), not 1.
    detail = client.get("/programs/2").json()
    assert detail["participant_count"] == 1  # host only, despite zero rows

    volunteer = {"Authorization": f"Bearer {_register(client, 'lone@example.com')}"}
    assert (
        client.post("/programs/2/participations", headers=volunteer).status_code == 201
    )

    after = client.get("/programs/2").json()
    assert after["participant_count"] == 2  # host (no row) + the volunteer


def test_join_twice_conflicts(client: TestClient) -> None:
    # User 1 is already APPROVED in program 1.
    headers = {"Authorization": f"Bearer {_token(client)}"}
    res = client.post("/programs/1/participations", headers=headers)
    assert res.status_code == 409


def test_join_rejected_when_full(client: TestClient) -> None:
    # Create a two-seat program; creator is auto-enrolled (occupies slot 1).
    # A second volunteer fills slot 2, then a third is refused.
    owner = {"Authorization": f"Bearer {_token(client)}"}
    created = client.post(
        "/programs",
        json={
            "category_id": 1,
            "program_name": "Duo Shift",
            "description": "Only two volunteers needed.",
            "start_datetime": "2026-08-01T08:00:00Z",
            "end_datetime": "2026-08-01T11:00:00Z",
            "max_volunteers": 2,
        },
        headers=owner,
    )
    assert created.status_code == 201
    body = created.json()
    program_id = body["program_id"]
    # Creator is auto-enrolled: count=1, not yet full.
    assert body["participant_count"] == 1
    assert body["is_full"] is False

    # A second volunteer fills the last slot.
    second = {"Authorization": f"Bearer {_register(client, 'second@example.com')}"}
    assert (
        client.post(f"/programs/{program_id}/participations", headers=second).status_code
        == 201
    )
    full = client.get(f"/programs/{program_id}/participations", headers=owner).json()
    assert full["is_full"] is True

    # A third volunteer is turned away.
    third = {"Authorization": f"Bearer {_register(client, 'third@example.com')}"}
    res = client.post(f"/programs/{program_id}/participations", headers=third)
    assert res.status_code == 409
    assert "full" in res.json()["detail"].lower()


def test_list_participants_returns_profiles(client: TestClient) -> None:
    # Program 1 is seeded with the host plus three members, each with a profile.
    # The Members row needs name + avatar, so the endpoint must carry those.
    res = client.get("/programs/1/participants")
    assert res.status_code == 200
    rows = res.json()
    assert len(rows) == 4
    assert {r["user_id"] for r in rows} == {1, 2, 3, 4}
    host = next(r for r in rows if r["user_id"] == 1)
    assert host["first_name"] == "Jane"
    assert host["last_name"] == "Doe"
    assert "profile_image_url" in host


def test_list_participants_unknown_program(client: TestClient) -> None:
    assert client.get("/programs/999/participants").status_code == 404


def test_leave_frees_a_slot(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    # Program 1 is seeded with four participants (host + three members).
    before = client.get("/programs/1/participations", headers=headers).json()
    assert before["joined"] is True

    # User 1 leaves program 1, freeing exactly one slot.
    assert (
        client.delete("/programs/1/participations", headers=headers).status_code == 204
    )

    summary = client.get("/programs/1/participations", headers=headers).json()
    assert summary["participant_count"] == before["participant_count"] - 1
    assert summary["joined"] is False

    # Leaving again is a 404 (no active participation to withdraw).
    assert (
        client.delete("/programs/1/participations", headers=headers).status_code == 404
    )
