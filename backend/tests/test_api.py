def test_liveness_never_needs_db(client, db):
    db.down = True
    r = client.get("/api/live")
    assert r.status_code == 200
    assert r.json()["status"] == "alive"


def test_readiness_ok(client):
    r = client.get("/api/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok", "db": "up", "version": "dev"}


def test_readiness_fails_when_db_down(client, db):
    db.down = True
    r = client.get("/api/health")
    assert r.status_code == 503
    assert "database unreachable" in r.json()["detail"]


def test_crud_flow(client):
    assert client.get("/api/items").json() == []

    r = client.post("/api/items",
                    json={"title": "Blue bottle", "location": "Library", "kind": "lost"})
    assert r.status_code == 201
    item = r.json()
    assert item["id"] == 1 and item["status"] == "open"

    r = client.post("/api/items",
                    json={"title": "Calculator", "location": "Exam hall", "kind": "found"})
    assert r.status_code == 201

    items = client.get("/api/items").json()
    assert [i["title"] for i in items] == ["Blue bottle", "Calculator"]

    r = client.patch("/api/items/1", json={"status": "returned"})
    assert r.status_code == 200 and r.json()["status"] == "returned"

    assert client.delete("/api/items/2").status_code == 204
    assert client.delete("/api/items/2").status_code == 404
    assert client.patch("/api/items/99", json={"status": "returned"}).status_code == 404


def test_validation(client):
    bad_kind = {"title": "x", "location": "y", "kind": "stolen"}
    assert client.post("/api/items", json=bad_kind).status_code == 422
    assert client.post("/api/items", json={"title": "  ", "location": "y"}).status_code == 422
    assert client.post("/api/items", json={"title": "x"}).status_code == 422
    assert client.patch("/api/items/1", json={"status": "vanished"}).status_code == 422


def test_metrics_endpoint(client):
    client.get("/api/live")
    body = client.get("/metrics").text
    assert 'http_requests_total{method="GET",path="/api/live",status="200"}' in body
    assert "http_request_duration_seconds_bucket" in body
    assert "lostfound_db_up" in body
