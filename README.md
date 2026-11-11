# Task Tracker API

[![CI](https://github.com/syedalz/task-tracker/actions/workflows/build-deploy.yml/badge.svg)](https://github.com/syedalz/task-tracker/actions/workflows/build-deploy.yml)

A REST API for managing tasks, built with **FastAPI** and **PostgreSQL**, containerized with **Docker** and **Docker Compose**, and covered by an automated **pytest** suite.

This project is the foundation of a DevOps portfolio pipeline: the application is intentionally simple so the focus can be on how it is built, tested, packaged, and deployed.

## Tech Stack

- **Python 3.14**, **FastAPI**
- **PostgreSQL 17**, **SQLAlchemy 2** (ORM), **psycopg 3** (driver)
- **Pydantic v2** and **pydantic-settings** (validation and configuration)
- **pytest** with FastAPI's TestClient
- **Docker** and **Docker Compose**

## API Endpoints

| Method | Path            | Description                                  | Success |
|--------|-----------------|----------------------------------------------|---------|
| GET    | `/health`       | Health check                                 | 200     |
| GET    | `/tasks/`       | List tasks (`?limit=N`, default 10)          | 200     |
| POST   | `/tasks/`       | Create a task (`completed` defaults to false)| 201     |
| GET    | `/tasks/{id}`   | Get one task                                 | 200     |
| PUT    | `/tasks/{id}`   | Replace a task                               | 200     |
| DELETE | `/tasks/{id}`   | Delete a task                                | 204     |

Requests for a task that doesn't exist return **404**. Interactive API docs are available at `/docs` while the app is running.

Example task:

```json
{
  "id": 1,
  "title": "Buy groceries",
  "description": "Milk, eggs, and bread",
  "completed": false,
  "added_at": "2026-11-10T19:00:00Z"
}
```

## Project Structure

```
task-tracker/
├── app/
│   ├── main.py          # FastAPI app and router registration
│   ├── config.py        # Settings loaded from environment variables
│   ├── database.py      # Engine, sessions, and the get_db dependency
│   ├── models.py        # SQLAlchemy database models
│   ├── schemas.py       # Pydantic request/response models
│   └── routers/
│       └── task.py      # /tasks endpoints
├── tests/
│   ├── conftest.py      # Fixtures: test database, client, sample tasks
│   └── test_tasks.py    # API tests
├── Dockerfile
├── compose.yaml
├── .dockerignore
├── .env.example
└── requirements.txt
```

## Configuration

All configuration comes from environment variables, so the same code runs on a developer machine, in a container, or in the cloud without changes. Copy the example file and fill in your own values:

```bash
cp .env.example .env
```

| Variable            | Description                                   |
|---------------------|-----------------------------------------------|
| `DATABASE_HOSTNAME` | Database host (`localhost` when running locally) |
| `DATABASE_PORT`     | Database port (default PostgreSQL port: 5432) |
| `DATABASE_USERNAME` | Database user                                 |
| `DATABASE_PASSWORD` | Database password                             |
| `DATABASE_NAME`     | Database name                                 |

`.env` is excluded from both Git and the Docker image; only `.env.example`, with placeholder values, is committed.

## Running with Docker Compose

```bash
cp .env.example .env          # then edit .env with your own values
docker compose up --build -d
```

This starts two services:

- **`api`**: the FastAPI app, on port 8000
- **`postgres`**: PostgreSQL 17, with data stored in the `postgres-db` volume

Then open http://localhost:8000/docs, or check the health endpoint:

```bash
curl http://localhost:8000/health
```

Useful commands:

```bash
docker compose ps             # service status (postgres should show "healthy")
docker compose logs -f api    # follow the API logs
docker compose down           # stop everything; data is kept in the volume
docker compose down -v        # stop everything and delete the database volume
```

## Running Locally (without Docker for the app)

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
fastapi dev app/main.py
```

This needs a PostgreSQL server reachable at the host and port in your `.env` (for example, a `postgres:17` container with port 5432 published).

## Running the Tests

Tests run against a **separate database**, `tasks_test`, so they never touch development data. Create it once in your local PostgreSQL server:

```sql
CREATE DATABASE tasks_test;
```

Then run:

```bash
pytest -v
```

Each test starts with freshly created tables, so tests are independent of each other and of the order they run in. The suite covers every endpoint's success and error cases, the `completed` default, the `limit` parameter, and edge-case input such as accented characters and long titles.

## Design Decisions

- **Configuration through environment variables.** Database settings are read with pydantic-settings, following the Twelve-Factor App approach. Moving between environments only changes configuration, never code.
- **Isolated tests.** Fixtures use function scope, so every test gets a clean database. Test data is inserted directly through the database session rather than through the API, so a bug in one endpoint can't break tests for another.
- **A small, reproducible image.** The Dockerfile uses a pinned `python:3.14-slim` base image, installs dependencies before copying the source code so code changes don't trigger a full reinstall, and uses `.dockerignore` to keep the virtual environment and `.env` (with its secrets) out of the image.
- **Container networking.** The API listens on `0.0.0.0` so it can accept connections arriving from outside its container. In Compose, it reaches the database by its service name (`postgres`); the Compose file overrides `DATABASE_HOSTNAME` for the `api` service, so `.env` keeps working for local development.
- **Startup ordering.** The `postgres` service has a health check using `pg_isready`, and the `api` service waits for it with `depends_on: condition: service_healthy`, avoiding a race where the API starts before the database accepts connections.

## Roadmap

- [x] REST API with PostgreSQL
- [x] Automated tests with pytest
- [x] Docker image and Docker Compose setup
- [x] CI pipeline with GitHub Actions (run tests, build image)
- [ ] AWS infrastructure with Terraform
- [ ] Kubernetes deployment and monitoring
- [ ] Database migrations with Alembic
- [ ] PATCH endpoint for partial updates