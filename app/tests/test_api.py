import os

os.environ["DATABASE_URL"] = "sqlite:///./test_tasks.db"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from tasks_api.main import Base, app, engine  # noqa: E402


@pytest.fixture()
def client():
    Base.metadata.drop_all(engine)
    with TestClient(app) as c:
        yield c
    Base.metadata.drop_all(engine)


def test_probes(client):
    assert client.get("/healthz").json() == {"status": "ok"}
    ready = client.get("/readyz")
    assert ready.status_code == 200
    assert ready.json()["status"] == "ready"


def test_task_crud(client):
    created = client.post("/api/tasks", json={"title": "Deploy to EKS"})
    assert created.status_code == 201
    task_id = created.json()["id"]

    assert [t["title"] for t in client.get("/api/tasks").json()] == ["Deploy to EKS"]

    updated = client.put(f"/api/tasks/{task_id}", json={"title": "Deploy to EKS", "done": True})
    assert updated.json()["done"] is True

    assert client.delete(f"/api/tasks/{task_id}").status_code == 204
    assert client.get(f"/api/tasks/{task_id}").status_code == 404


def test_validation(client):
    assert client.post("/api/tasks", json={"title": ""}).status_code == 422


def test_metrics_use_route_template(client):
    client.get("/api/tasks/999")
    body = client.get("/metrics").text
    assert 'route="/api/tasks/{task_id}"' in body
    assert 'route="/api/tasks/999"' not in body
