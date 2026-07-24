import pytest
import json
from app import app

@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client

def test_health_check(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    data = json.loads(resp.data)
    assert data["status"] == "healthy"
    assert "version" in data

def test_readiness_check(client):
    resp = client.get("/ready")
    assert resp.status_code == 200

def test_ingest_event_valid(client):
    payload = {"event_type": "page_view", "payload": {"page": "/dashboard"}}
    resp = client.post("/api/v1/events", data=json.dumps(payload), content_type="application/json")
    assert resp.status_code == 201
    data = json.loads(resp.data)
    assert data["status"] == "accepted"
    assert "event_id" in data

def test_ingest_event_missing_type(client):
    payload = {"payload": {"page": "/dashboard"}}
    resp = client.post("/api/v1/events", data=json.dumps(payload), content_type="application/json")
    assert resp.status_code == 400

def test_get_events(client):
    resp = client.get("/api/v1/events")
    assert resp.status_code == 200
    data = json.loads(resp.data)
    assert "total" in data
    assert "events" in data

def test_get_stats(client):
    for event_type in ["page_view", "page_view", "button_click"]:
        client.post("/api/v1/events", data=json.dumps({"event_type": event_type}), content_type="application/json")
    resp = client.get("/api/v1/stats")
    assert resp.status_code == 200
    data = json.loads(resp.data)
    assert data["by_type"]["page_view"] >= 2
    assert data["by_type"]["button_click"] >= 1
