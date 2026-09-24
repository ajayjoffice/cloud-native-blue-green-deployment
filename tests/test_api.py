from fastapi.testclient import TestClient

from app.main import VERSION, app

client = TestClient(app)


def test_root_includes_application_and_version() -> None:
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"application": "cloud-native-blue-green", "version": VERSION}


def test_health() -> None:
    assert client.get("/health").json() == {"status": "ok", "version": VERSION}


def test_version() -> None:
    assert client.get("/version").json() == {"version": VERSION}


def test_greet() -> None:
    assert client.post("/greet", json={"name": "Ada"}).json() == {
        "message": "Hello, Ada!", "version": VERSION
    }


def test_greet_rejects_empty_name() -> None:
    assert client.post("/greet", json={"name": ""}).status_code == 422
