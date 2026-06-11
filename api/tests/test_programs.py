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


def test_create_program_host_auto_enrolled(client: TestClient) -> None:
    # Creating a program must auto-enroll the creator so participant_count
    # starts at 1 and the program card never shows 0.
    headers = {"Authorization": f"Bearer {_token(client)}"}
    res = client.post("/programs", json=VALID_PROGRAM, headers=headers)
    assert res.status_code == 201
    body = res.json()
    assert body["participant_count"] == 1
    assert body["is_full"] is False  # 1 of 15 slots taken

    # The list endpoint must also reflect the enrollment.
    listing = client.get("/programs").json()
    created = next(p for p in listing if p["program_name"] == "Harbour Cleanup Crew")
    assert created["participant_count"] == 1


def test_create_program_with_image_gallery(client: TestClient) -> None:
    # A multi-image program round-trips the ordered gallery, and the legacy
    # single banner mirrors the first image.
    headers = {"Authorization": f"Bearer {_token(client)}"}
    urls = [
        "https://cdn.example.com/program_banner/1/a.webp",
        "https://cdn.example.com/program_banner/1/b.webp",
        "https://cdn.example.com/program_banner/1/c.webp",
    ]
    payload = {**VALID_PROGRAM, "banner_image_urls": urls}
    res = client.post("/programs", json=payload, headers=headers)
    assert res.status_code == 201
    body = res.json()
    assert body["banner_image_urls"] == urls
    assert body["banner_image_url"] == urls[0]

    # The detail fetch returns the same ordered gallery.
    detail = client.get(f"/programs/{body['program_id']}").json()
    assert detail["banner_image_urls"] == urls
    assert detail["banner_image_url"] == urls[0]


def test_create_program_legacy_single_banner_seeds_gallery(client: TestClient) -> None:
    # The legacy single-banner field still works and produces a one-image gallery.
    headers = {"Authorization": f"Bearer {_token(client)}"}
    url = "https://cdn.example.com/program_banner/1/solo.webp"
    payload = {**VALID_PROGRAM, "banner_image_url": url}
    res = client.post("/programs", json=payload, headers=headers)
    assert res.status_code == 201
    assert res.json()["banner_image_urls"] == [url]


def test_create_program_rejects_too_many_images(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    payload = {**VALID_PROGRAM, "banner_image_urls": [f"u{i}" for i in range(4)]}
    assert client.post("/programs", json=payload, headers=headers).status_code == 422


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
#   1 Tree Planting   cat1 (Nature)    max30 monthly/three_to_six
#   2 Beach Cleanup   cat1 (Nature)    max50 monthly/continuous
#   3 Reading Club    cat3 (Education) max12 weekly/seven_to_nine
#   4 Tech Support    cat7 (Elderly)   max8  weekly/under_2


def test_filter_by_search_query(client: TestClient) -> None:
    assert _ids(client, "?q=beach") == {2}


def test_filter_by_category(client: TestClient) -> None:
    assert _ids(client, "?category_id=1") == {1, 2}


def test_filter_by_category_multi(client: TestClient) -> None:
    # Repeated category_id is OR-ed: programs in any selected category match.
    # cat1 (Nature) -> {1, 2}, cat3 (Education) -> {3}, cat7 (Elderly) -> {4}.
    assert _ids(client, "?category_id=1&category_id=3") == {1, 2, 3}
    assert _ids(client, "?category_id=3&category_id=7") == {3, 4}


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


def test_list_carries_participant_count(client: TestClient) -> None:
    # The card shows how many volunteers joined (host included), so the list
    # must populate participant_count — not leave it null. Program 1 is seeded
    # with four participants (host + three members); programs with no joins read
    # 0, never null, and is_full mirrors the detail endpoint.
    by_id = {p["program_id"]: p for p in client.get("/programs").json()}
    assert by_id[1]["participant_count"] == 4
    assert by_id[1]["is_full"] is False
    assert all(p["participant_count"] is not None for p in by_id.values())
    # The list count matches what the detail endpoint computes for the same row.
    detail = client.get("/programs/1").json()
    assert by_id[1]["participant_count"] == detail["participant_count"]


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


def _create_program(client: TestClient, headers: dict, **overrides) -> dict:
    payload = {**VALID_PROGRAM, **overrides}
    res = client.post("/programs", json=payload, headers=headers)
    assert res.status_code == 201
    return res.json()


def test_update_program_replaces_image_gallery(client: TestClient) -> None:
    # Editing the gallery replaces it wholesale and mirrors the first image to
    # the legacy single banner, on both the PATCH response and the detail fetch.
    headers = {"Authorization": f"Bearer {_token(client)}"}
    created = _create_program(
        client, headers, banner_image_urls=["https://cdn.example.com/1/a.webp"]
    )
    pid = created["program_id"]

    new_urls = [
        "https://cdn.example.com/1/x.webp",
        "https://cdn.example.com/1/y.webp",
    ]
    res = client.patch(
        f"/programs/{pid}", json={"banner_image_urls": new_urls}, headers=headers
    )
    assert res.status_code == 200
    body = res.json()
    assert body["banner_image_urls"] == new_urls
    assert body["banner_image_url"] == new_urls[0]

    detail = client.get(f"/programs/{pid}").json()
    assert detail["banner_image_urls"] == new_urls
    assert detail["banner_image_url"] == new_urls[0]


def test_update_program_empty_list_clears_gallery(client: TestClient) -> None:
    # An explicit empty list removes every image (and nulls the legacy banner).
    headers = {"Authorization": f"Bearer {_token(client)}"}
    created = _create_program(
        client,
        headers,
        banner_image_urls=["https://cdn.example.com/1/a.webp"],
    )
    pid = created["program_id"]

    res = client.patch(
        f"/programs/{pid}", json={"banner_image_urls": []}, headers=headers
    )
    assert res.status_code == 200
    body = res.json()
    assert body["banner_image_urls"] == []
    assert body["banner_image_url"] is None

    detail = client.get(f"/programs/{pid}").json()
    assert detail["banner_image_urls"] == []


def test_update_program_preserves_gallery_when_untouched(client: TestClient) -> None:
    # A PATCH that doesn't mention either image field leaves the gallery intact.
    headers = {"Authorization": f"Bearer {_token(client)}"}
    urls = [
        "https://cdn.example.com/1/a.webp",
        "https://cdn.example.com/1/b.webp",
    ]
    created = _create_program(client, headers, banner_image_urls=urls)
    pid = created["program_id"]

    res = client.patch(
        f"/programs/{pid}", json={"program_name": "Renamed"}, headers=headers
    )
    assert res.status_code == 200
    body = res.json()
    assert body["program_name"] == "Renamed"
    assert body["banner_image_urls"] == urls


def test_update_program_rejects_too_many_images(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    pid = _create_program(client, headers)["program_id"]
    res = client.patch(
        f"/programs/{pid}",
        json={"banner_image_urls": [f"u{i}" for i in range(4)]},
        headers=headers,
    )
    assert res.status_code == 422


def test_update_program_rejects_overlong_url(client: TestClient) -> None:
    # A URL longer than the image_url column (500) must fail validation (422),
    # not slip through to a DB write error (500).
    headers = {"Authorization": f"Bearer {_token(client)}"}
    pid = _create_program(client, headers)["program_id"]
    res = client.patch(
        f"/programs/{pid}",
        json={"banner_image_urls": ["https://x/" + "a" * 600]},
        headers=headers,
    )
    assert res.status_code == 422


def test_update_program_rejects_blank_url(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    pid = _create_program(client, headers)["program_id"]
    res = client.patch(
        f"/programs/{pid}", json={"banner_image_urls": [""]}, headers=headers
    )
    assert res.status_code == 422


def test_update_program_non_creator_forbidden(client: TestClient) -> None:
    # Only the host may edit. A different authenticated user gets 403.
    owner = {"Authorization": f"Bearer {_token(client)}"}
    pid = _create_program(client, owner)["program_id"]

    intruder_token = client.post(
        "/auth/register",
        json={
            "email": "intruder@example.com",
            "password": "password123",
            "first_name": "Mal",
            "last_name": "Lory",
        },
    ).json()["token"]
    intruder = {"Authorization": f"Bearer {intruder_token}"}
    res = client.patch(
        f"/programs/{pid}", json={"program_name": "Hijacked"}, headers=intruder
    )
    assert res.status_code == 403


def test_update_nonexistent_program_404(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    res = client.patch(
        "/programs/999999", json={"program_name": "Ghost"}, headers=headers
    )
    assert res.status_code == 404
