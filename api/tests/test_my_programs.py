"""Tests for GET /me/programs (the caller's joined + hosted programs)."""

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


def _my_program_ids(client: TestClient, headers: dict[str, str]) -> list[int]:
    res = client.get("/me/programs", headers=headers)
    assert res.status_code == 200
    return [p["program_id"] for p in res.json()]


def test_my_programs_requires_auth(client: TestClient) -> None:
    assert client.get("/me/programs").status_code == 401


def test_fresh_user_join_and_leave_roundtrip(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_register(client, 'mine@example.com')}"}

    assert _my_program_ids(client, headers) == []

    assert client.post("/programs/2/participations", headers=headers).status_code == 201
    assert _my_program_ids(client, headers) == [2]

    assert (
        client.delete("/programs/2/participations", headers=headers).status_code == 204
    )
    assert _my_program_ids(client, headers) == []


def test_seeded_host_sees_joined_and_hosted_programs(client: TestClient) -> None:
    # Jane (user 1) holds an APPROVED row on program 1 and created programs 2-4
    # without participation rows (pre-auto-enrolment), so all of them are hers.
    headers = {"Authorization": f"Bearer {_token(client)}"}
    ids = _my_program_ids(client, headers)
    assert {1, 2, 3, 4}.issubset(set(ids))


def test_withdrawn_host_program_is_excluded(client: TestClient) -> None:
    # Joining then leaving a hosted program leaves a WITHDRAWN row — the host
    # left on purpose, so the program must not resurface via the legacy
    # no-row host fallback.
    headers = {"Authorization": f"Bearer {_token(client)}"}
    assert client.post("/programs/2/participations", headers=headers).status_code == 201
    assert (
        client.delete("/programs/2/participations", headers=headers).status_code == 204
    )
    assert 2 not in _my_program_ids(client, headers)


def test_deleted_program_is_excluded(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    assert 3 in _my_program_ids(client, headers)
    assert client.delete("/programs/3", headers=headers).status_code == 204
    assert 3 not in _my_program_ids(client, headers)


def test_rows_carry_capacity_and_banner_enrichment(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    res = client.get("/me/programs", headers=headers)
    assert res.status_code == 200
    by_id = {p["program_id"]: p for p in res.json()}

    # Program 1 has the host + 3 seeded volunteers and a three-image gallery.
    program_1 = by_id[1]
    assert program_1["participant_count"] == 4
    assert program_1["is_full"] is False
    assert len(program_1["banner_image_urls"]) >= 1
    assert program_1["banner_image_url"] == program_1["banner_image_urls"][0]
