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


def test_create_program_with_commitment(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    payload = {
        **VALID_PROGRAM,
        "commitment_frequency": "weekly",
        "commitment_duration": "three_to_six",
    }
    res = client.post("/programs", json=payload, headers=headers)
    assert res.status_code == 201
    body = res.json()
    assert body["commitment_frequency"] == "weekly"
    assert body["commitment_duration"] == "three_to_six"


def _ids(client: TestClient, query: str) -> set[int]:
    res = client.get(f"/programs{query}")
    assert res.status_code == 200
    return {p["program_id"] for p in res.json()}


# Seeded programs (scripts/seed.py):
#   1 Tree Planting   cat1 max30 monthly/three_to_six
#   2 Beach Cleanup   cat1 max50 monthly/continuous
#   3 Reading Club    cat3 max12 weekly/seven_to_nine
#   4 Tech Support    cat6 max8  weekly/under_2


def test_filter_by_search_query(client: TestClient) -> None:
    assert _ids(client, "?q=beach") == {2}


def test_filter_by_category(client: TestClient) -> None:
    assert _ids(client, "?category_id=1") == {1, 2}


def test_filter_by_commitment_frequency(client: TestClient) -> None:
    assert _ids(client, "?commitment_frequency=weekly") == {3, 4}
    assert _ids(client, "?commitment_frequency=monthly") == {1, 2}


def test_filter_by_commitment_duration_multi(client: TestClient) -> None:
    # Repeated params are OR-ed within the group.
    query = "?commitment_duration=under_2&commitment_duration=continuous"
    assert _ids(client, query) == {2, 4}


def test_filter_by_team_size_bucket(client: TestClient) -> None:
    assert _ids(client, "?team_size=large") == {4}  # max_volunteers 8 ∈ 7..10
    assert _ids(client, "?team_size=open") == {1, 2, 3}  # 11+


def test_filters_combine_with_and(client: TestClient) -> None:
    query = "?category_id=1&commitment_frequency=monthly&team_size=open"
    assert _ids(client, query) == {1, 2}


def test_list_omits_distance_without_coords(client: TestClient) -> None:
    # No lat/lng → nothing to measure against, so distance_km stays null.
    body = client.get("/programs").json()
    assert body and all(p["distance_km"] is None for p in body)


def test_list_includes_distance_with_coords(client: TestClient) -> None:
    # Caller sitting on program 1's coordinates (location 1) → 0 km for it, and
    # the other programs sit at their own spots, so distances vary per card.
    body = client.get("/programs?lat=-33.8688&lng=151.2093").json()
    by_id = {p["program_id"]: p["distance_km"] for p in body}
    assert all(isinstance(d, (int, float)) for d in by_id.values())
    assert by_id[1] == 0.0  # sits exactly on the query point
    assert by_id[2] > 0  # a different location is measurably farther


def test_list_distance_grows_with_separation(client: TestClient) -> None:
    # ~1 degree of latitude is ~111 km, so every Sydney program is >100 km away.
    body = client.get("/programs?lat=-32.8688&lng=151.2093").json()
    assert body
    assert all(program["distance_km"] > 100 for program in body)
