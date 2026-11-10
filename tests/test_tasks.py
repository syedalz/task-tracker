import pytest
from app import schemas


def test_health(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_get_all_tasks(client, test_tasks):
    res = client.get("/tasks/")
    assert res.status_code == 200

    data = res.json()
    assert len(data) == len(test_tasks)
    assert data[0]["title"] == test_tasks[0].title
    assert data[0]["description"] == test_tasks[0].description
    assert data[0]["completed"] == test_tasks[0].completed


def test_get_limited_tasks(client, test_tasks):
    res = client.get("/tasks/?limit=2")
    assert res.status_code == 200
    assert len(res.json()) == 2


def test_get_one_task_not_exist(client, test_tasks):
    res = client.get("/tasks/123456")
    assert res.status_code == 404


def test_get_one_task(client, test_tasks):
    res = client.get(f"/tasks/{test_tasks[2].id}")
    assert res.status_code == 200

    data = res.json()
    assert data["id"] == test_tasks[2].id
    assert data["title"] == test_tasks[2].title
    assert data["description"] == test_tasks[2].description
    assert data["completed"] == test_tasks[2].completed


@pytest.mark.parametrize("title, description, completed", [
    ("Book dentist appointment", "Call before Friday", False),
    ("Renew passport", "Bring two photos", True),
    ("Café visit", "Try the crème brûlée", False),
    ("A" * 200, "Very long title to check nothing gets cut off", False),
])
def test_create_task(client, title, description, completed):
    res = client.post(
        "/tasks/",
        json={"title": title, "description": description, "completed": completed},
    )
    assert res.status_code == 201

    created_task = schemas.Task(**res.json())
    assert created_task.title == title
    assert created_task.description == description
    assert created_task.completed == completed


def test_create_task_default_completed(client):
    res = client.post(
        "/tasks/",
        json={"title": "Scholarship Application", "description": "Finish filling out remaining forms"},
    )
    assert res.status_code == 201

    created_task = schemas.Task(**res.json())
    assert created_task.completed is False


def test_delete_task(client, test_tasks):
    deleted_id = test_tasks[0].id
    res = client.delete(f"/tasks/{deleted_id}")
    assert res.status_code == 204

    deletion = client.get(f"/tasks/{deleted_id}")
    assert deletion.status_code == 404


def test_delete_task_not_exist(client, test_tasks):
    res = client.delete("/tasks/987654321")
    assert res.status_code == 404


def test_update_task(client, test_tasks):
    data = {
        "title": "Resume Review",
        "description": "Ask professional to review resume",
        "completed": False,
    }

    res = client.put(f"/tasks/{test_tasks[0].id}", json=data)
    assert res.status_code == 200

    updated_task = schemas.Task(**res.json())
    assert updated_task.title == data["title"]
    assert updated_task.description == data["description"]
    assert updated_task.completed == data["completed"]


def test_update_task_not_exist(client, test_tasks):
    data = {
        "title": "Resume Review",
        "description": "Ask professional to review resume",
        "completed": False,
    }

    res = client.put("/tasks/12354", json=data)
    assert res.status_code == 404