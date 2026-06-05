"""Tests for GET /programs/{id}/similar — the "nearby" suggestion."""

from fastapi.testclient import TestClient


def test_similar_returns_a_different_program(client: TestClient) -> None:
    res = client.get("/programs/1/similar")
    assert res.status_code == 200
    body = res.json()
    assert "program" in body
    assert body["program"]["program_id"] != 1


def test_similar_includes_distance_when_coordinates_exist(client: TestClient) -> None:
    # The seeded location carries coordinates, so the nearest-by-distance path is
    # taken and distance_km is populated (0.0 when programs share a location).
    body = client.get("/programs/1/similar").json()
    assert body["distance_km"] is not None
    assert isinstance(body["distance_km"], (int, float))


def test_similar_404_for_unknown_program(client: TestClient) -> None:
    assert client.get("/programs/999999/similar").status_code == 404
