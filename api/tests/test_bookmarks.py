"""Tests for program bookmarks (POST/DELETE /programs/{id}/bookmark, GET /me/bookmarks)."""

from fastapi.testclient import TestClient


def _token(client: TestClient) -> str:
    res = client.post(
        "/auth/login",
        json={"email": "jane.doe@example.com", "password": "password123"},
    )
    assert res.status_code == 200
    return str(res.json()["token"])


def _bookmarked_ids(client: TestClient, headers: dict) -> set[int]:
    res = client.get("/me/bookmarks", headers=headers)
    assert res.status_code == 200
    return {p["program_id"] for p in res.json()}


def test_bookmarks_require_auth(client: TestClient) -> None:
    assert client.get("/me/bookmarks").status_code == 401
    assert client.post("/programs/1/bookmark").status_code == 401
    assert client.delete("/programs/1/bookmark").status_code == 401


def test_bookmark_add_list_remove_roundtrip(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    assert 1 not in _bookmarked_ids(client, headers)

    assert client.post("/programs/1/bookmark", headers=headers).status_code == 204
    listed = _bookmarked_ids(client, headers)
    assert 1 in listed
    # The listed program carries the same enrichment as GET /programs.
    detail = next(p for p in client.get("/me/bookmarks", headers=headers).json())
    assert detail["participant_count"] is not None
    assert "banner_image_urls" in detail

    assert client.delete("/programs/1/bookmark", headers=headers).status_code == 204
    assert 1 not in _bookmarked_ids(client, headers)


def test_bookmark_add_is_idempotent(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    assert client.post("/programs/2/bookmark", headers=headers).status_code == 204
    assert client.post("/programs/2/bookmark", headers=headers).status_code == 204
    # Still exactly one entry for program 2.
    assert [p["program_id"] for p in client.get("/me/bookmarks", headers=headers).json()].count(2) == 1


def test_bookmark_remove_is_idempotent(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    # Removing a bookmark that isn't there is a no-op, not an error.
    assert client.delete("/programs/3/bookmark", headers=headers).status_code == 204


def test_bookmark_nonexistent_program_404(client: TestClient) -> None:
    headers = {"Authorization": f"Bearer {_token(client)}"}
    assert client.post("/programs/999999/bookmark", headers=headers).status_code == 404


def test_bookmarks_exclude_soft_deleted_program(client: TestClient) -> None:
    # Bookmark a program the caller owns, then delete it — it must drop out of
    # the bookmarks list (which filters soft-deleted rows).
    headers = {"Authorization": f"Bearer {_token(client)}"}
    created = client.post(
        "/programs",
        json={
            "category_id": 1,
            "program_name": "Temp Program",
            "description": "To be deleted.",
            "start_datetime": "2026-09-01T08:00:00Z",
            "end_datetime": "2026-09-01T11:00:00Z",
            "max_volunteers": 5,
        },
        headers=headers,
    ).json()
    pid = created["program_id"]

    assert client.post(f"/programs/{pid}/bookmark", headers=headers).status_code == 204
    assert pid in _bookmarked_ids(client, headers)

    assert client.delete(f"/programs/{pid}", headers=headers).status_code == 204
    assert pid not in _bookmarked_ids(client, headers)
