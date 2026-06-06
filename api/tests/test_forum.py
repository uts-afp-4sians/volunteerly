"""Tests for the forum write paths: posting questions, replying, and likes."""

from fastapi.testclient import TestClient


def _token(client: TestClient) -> str:
    # The seeded fixture user (scripts/seed.py): user 1.
    res = client.post(
        "/auth/login",
        json={"email": "jane.doe@example.com", "password": "password123"},
    )
    assert res.status_code == 200
    return str(res.json()["token"])


def _headers(client: TestClient) -> dict[str, str]:
    return {"Authorization": f"Bearer {_token(client)}"}


# MARK: - Posts


def test_create_post_requires_auth(client: TestClient) -> None:
    res = client.post(
        "/programs/1/posts", json={"title": "Q", "body": "Body"}
    )
    assert res.status_code == 401


def test_create_post(client: TestClient) -> None:
    res = client.post(
        "/programs/1/posts",
        json={"title": "New question", "body": "Some details"},
        headers=_headers(client),
    )
    assert res.status_code == 201
    body = res.json()
    assert body["title"] == "New question"
    assert body["program_id"] == 1
    assert body["author_user_id"] == 1
    # It now shows up on the board.
    listed = client.get("/programs/1/posts").json()
    assert any(p["title"] == "New question" for p in listed)


def test_create_post_unknown_program(client: TestClient) -> None:
    res = client.post(
        "/programs/999/posts",
        json={"title": "Q", "body": "B"},
        headers=_headers(client),
    )
    assert res.status_code == 404


# MARK: - Comments & replies


def test_create_comment(client: TestClient) -> None:
    res = client.post(
        "/programs/1/posts/1/comments",
        json={"body": "Thanks for the info!"},
        headers=_headers(client),
    )
    assert res.status_code == 201
    body = res.json()
    assert body["body"] == "Thanks for the info!"
    assert body["parent_comment_id"] is None
    assert body["like_count"] == 0
    assert body["liked_by_me"] is False


def test_create_reply(client: TestClient) -> None:
    res = client.post(
        "/programs/1/posts/1/comments",
        json={"body": "Replying here", "parent_comment_id": 1},
        headers=_headers(client),
    )
    assert res.status_code == 201
    assert res.json()["parent_comment_id"] == 1


def test_reply_to_foreign_comment_rejected(client: TestClient) -> None:
    # Comment 1 belongs to post 1, so it can't parent a comment on post 2.
    res = client.post(
        "/programs/1/posts/2/comments",
        json={"body": "Mismatched", "parent_comment_id": 1},
        headers=_headers(client),
    )
    assert res.status_code == 422


def test_comment_on_unknown_post(client: TestClient) -> None:
    res = client.post(
        "/programs/1/posts/999/comments",
        json={"body": "Nope"},
        headers=_headers(client),
    )
    assert res.status_code == 404


# MARK: - Likes


def test_like_and_unlike_comment(client: TestClient) -> None:
    headers = _headers(client)
    like_url = "/programs/1/posts/1/comments/1/like"

    # Comment 1 starts with no seeded likes.
    res = client.post(like_url, headers=headers)
    assert res.status_code == 200
    body = res.json()
    assert body["like_count"] == 1
    assert body["liked_by_me"] is True

    # Liking again is idempotent — still a single like.
    res = client.post(like_url, headers=headers)
    assert res.json()["like_count"] == 1

    # Unlike removes it.
    res = client.delete(like_url, headers=headers)
    assert res.status_code == 200
    body = res.json()
    assert body["like_count"] == 0
    assert body["liked_by_me"] is False


def test_like_requires_auth(client: TestClient) -> None:
    assert (
        client.post("/programs/1/posts/1/comments/1/like").status_code == 401
    )


def test_liked_by_me_reflects_caller(client: TestClient) -> None:
    # Comment 2 is seeded as liked by user 1, so the authed read sees it.
    headers = _headers(client)
    body = client.get("/programs/1/posts/1/comments", headers=headers).json()
    comment_2 = next(c for c in body if c["comment_id"] == 2)
    assert comment_2["like_count"] == 2
    assert comment_2["liked_by_me"] is True
