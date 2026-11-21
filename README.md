# Task Tracker API

[![CI](https://github.com/syedalz/task-tracker/actions/workflows/build-deploy.yml/badge.svg)](https://github.com/syedalz/task-tracker/actions/workflows/build-deploy.yml)

A REST API for managing tasks, built with **FastAPI** and **PostgreSQL**, containerized with **Docker**, tested and published by a **GitHub Actions** CI/CD pipeline, and deployed to **AWS** on infrastructure defined in **Terraform**.

This project is a DevOps portfolio pipeline: the application is intentionally simple so the focus can be on how it is built, tested, packaged, and deployed.

## Architecture

How a request reaches the app once deployed:

```mermaid
flowchart LR
    user["Browser"] -->|"HTTP :8000"| igw["Internet gateway"]
    subgraph aws["AWS us-east-2"]
        subgraph vpc["VPC 10.0.0.0/16"]
            igw --> sg["Security group"]
            subgraph subnet["Public subnet 10.0.1.0/24"]
                sg --> api
                subgraph ec2["EC2 t3.micro, Ubuntu 24.04"]
                    api["api container (FastAPI)"] --> db[("postgres container")]
                end
            end
        end
    end
```

How code gets from a commit to the cloud:

```mermaid
flowchart LR
    push["git push"] --> test["CI: pytest with Postgres"]
    test --> build["Build Docker image"]
    build -->|"push (main only)"| hub["Docker Hub"]
    tf["terraform apply"] --> ec2["EC2 instance"]
    hub -->|"pulled on first boot"| ec2
```

## Tech Stack

- **Application:** Python 3.14, FastAPI, PostgreSQL 17, SQLAlchemy 2 (ORM), psycopg 3 (driver), Pydantic v2 and pydantic-settings
- **Testing:** pytest with FastAPI's TestClient
- **Containers:** Docker, Docker Compose, Docker Hub
- **CI/CD:** GitHub Actions
- **Infrastructure:** Terraform, AWS (VPC, EC2), IAM Identity Center

## API Endpoints

| Method | Path            | Description                                   | Success |
|--------|-----------------|-----------------------------------------------|---------|
| GET    | `/health`       | Health check                                  | 200     |
| GET    | `/tasks/`       | List tasks (`?limit=N`, default 10)           | 200     |
| POST   | `/tasks/`       | Create a task (`completed` defaults to false) | 201     |
| GET    | `/tasks/{id}`   | Get one task                                  | 200     |
| PUT    | `/tasks/{id}`   | Replace a task                                | 200     |
| DELETE | `/tasks/{id}`   | Delete a task                                 | 204     |

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
├── .github/
│   └── workflows/
│       └── build-deploy.yml  # CI/CD: test, then build and publish the image
├── app/
│   ├── main.py               # FastAPI app and router registration
│   ├── config.py             # Settings loaded from environment variables
│   ├── database.py           # Engine, sessions, and the get_db dependency
│   ├── models.py             # SQLAlchemy database models
│   ├── schemas.py            # Pydantic request/response models
│   └── routers/
│       └── task.py           # /tasks endpoints
├── tests/
│   ├── conftest.py           # Fixtures: test database, client, sample tasks
│   └── test_tasks.py         # API tests
├── infra/
│   ├── providers.tf          # Terraform settings and AWS provider
│   ├── main.tf               # Network, security group, key pair, EC2 instance
│   ├── data.tf               # Ubuntu AMI lookup
│   ├── variables.tf          # Input variables
│   ├── outputs.tf            # The instance's public IP
│   └── userdata.tpl          # Instance bootstrap script (template)
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

| Variable            | Description                                       |
|---------------------|---------------------------------------------------|
| `DATABASE_HOSTNAME` | Database host (`localhost` when running locally)  |
| `DATABASE_PORT`     | Database port (default PostgreSQL port: 5432)     |
| `DATABASE_USERNAME` | Database user                                     |
| `DATABASE_PASSWORD` | Database password                                 |
| `DATABASE_NAME`     | Database name                                     |

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

## CI/CD Pipeline

The GitHub Actions workflow runs on every push and pull request, with three jobs:

1. **`secret-scan`:** scans the commits for leaked credentials with **gitleaks**, running in parallel with the tests.
2. **`test`:** starts a PostgreSQL 17 **service container**, creates the test database, installs dependencies, and runs the full pytest suite. Database settings come from environment variables, with the password stored as a GitHub secret.
3. **`build`:** runs only if **both** `secret-scan` and `test` pass. It builds the Docker image and, on pushes to `main`, publishes it to Docker Hub with two tags: `latest`, and the **commit SHA**, so every published image can be traced back to the exact commit it came from. Pull requests build the image without publishing it.

Required repository secrets: `DATABASE_PASSWORD`, `DOCKER_HUB_USERNAME`, and `DOCKER_HUB_ACCESS_TOKEN` (a Docker Hub access token, not the account password).

## Deploying to AWS with Terraform

### What Terraform creates

| Resource | Details |
|----------|---------|
| VPC | `10.0.0.0/16`, with DNS support and DNS hostnames enabled |
| Public subnet | `10.0.1.0/24` in `us-east-2a`; instances get a public IP automatically |
| Internet gateway | The VPC's connection to the internet |
| Route table | A default route (`0.0.0.0/0`) to the internet gateway, associated with the public subnet |
| Security group | Inbound TCP 8000 from anywhere; inbound SSH (22) **only from the deployer's IP**; all outbound traffic |
| Key pair | Public half of a local SSH key, for logging in to the instance |
| EC2 instance | `t3.micro`, the latest Canonical Ubuntu 24.04 image, 10 GB disk, bootstrapped with user data |

### How the instance sets itself up

On first boot, the instance runs `userdata.tpl`, a template rendered by Terraform's `templatefile()`. It:

1. Installs Docker and the Compose plugin from Docker's official repository.
2. Writes a Compose file to `/opt/task-tracker` that runs the **published image from Docker Hub** alongside PostgreSQL.
3. Writes a `.env` file with the database settings, with the password injected by Terraform from a variable, and restricts it with `chmod 600`.
4. Starts everything with `docker compose up -d`.

User data runs only once, on an instance's first boot. After changing the template, replace the instance so the new script runs: `terraform apply -replace=aws_instance.app`.

### Prerequisites

- **AWS CLI** logged in through **IAM Identity Center** (temporary credentials; no long-lived access keys). The provider is configured for a profile named `admin`.
- **Terraform** installed.
- An **SSH key** at `~/.ssh/task-tracker-key` (`ssh-keygen -t ed25519 -f ~/.ssh/task-tracker-key`); only the `.pub` half is uploaded.
- An `infra/terraform.tfvars` file (excluded from Git) with your values:

```hcl
my_ip  = "203.0.113.25/32"   # your public IP, for SSH access
dbpass = "a-strong-password"
```

Find your public IP with `curl https://checkip.amazonaws.com`.

### Deploy, use, and tear down

```bash
aws sso login                   # renew AWS credentials
cd infra
terraform init                  # first time only: download the AWS provider
terraform plan                  # preview the changes
terraform apply                 # create everything

terraform output app_public_ip  # the instance's public IP
```

After a few minutes (while the startup script finishes), open `http://<public-ip>:8000/docs`.

To log in to the instance:

```bash
ssh -i ~/.ssh/task-tracker-key ubuntu@<public-ip>
```

If the app doesn't come up, check the startup script's output in `/var/log/cloud-init-output.log`, and `docker compose ps` / `docker compose logs` from `/opt/task-tracker`.

When finished:

```bash
terraform destroy
```

## Cost and Security Notes

- **Destroy after each session.** The network resources are free, but the instance and its public IPv4 address are billed hourly. Running everything for a few hours costs a few cents.
- **No long-lived AWS credentials.** Terraform and the AWS CLI use temporary credentials from IAM Identity Center.
- **Secrets stay out of Git.** `terraform.tfvars`, Terraform state files, and `.env` are all gitignored. The database password variable is marked `sensitive`, so Terraform hides it in its output.
- **Least-privilege network access.** Only the app's port is open to the internet; SSH is limited to a single IP address.
- **Known limitations** of this demo setup: the API has no authentication, so anyone with the address can modify tasks; user data (including the rendered password) is visible to anyone with access to the AWS account; and the database lives on the same instance with no backups. The roadmap below addresses these.

## Design Decisions

- **Configuration through environment variables.** Database settings are read with pydantic-settings, following the Twelve-Factor App approach. Moving between environments only changes configuration, never code.
- **Isolated tests.** Fixtures use function scope, so every test gets a clean database. Test data is inserted directly through the database session rather than through the API, so a bug in one endpoint can't break tests for another.
- **A small, reproducible image.** The Dockerfile uses a pinned `python:3.14-slim` base image, installs dependencies before copying the source code so code changes don't trigger a full reinstall, and uses `.dockerignore` to keep the virtual environment and `.env` (with its secrets) out of the image.
- **Container networking.** The API listens on `0.0.0.0` so it can accept connections arriving from outside its container, and reaches the database by its Compose service name (`postgres`).
- **Startup ordering.** The `postgres` service has a health check using `pg_isready`, and the `api` service waits for it with `depends_on: condition: service_healthy`.
- **Deploy what was tested.** The instance runs the image published by the CI pipeline rather than building from source, so what runs in the cloud is exactly what passed the tests.
- **Trustworthy machine images.** The Ubuntu AMI is looked up dynamically, filtered to Canonical's official publisher account, so the instance always starts from the latest genuine image with current security updates.
- **Infrastructure as code.** The whole environment is defined in Terraform, so it can be rebuilt identically in minutes and removed completely with one command.

## Roadmap

- [x] REST API with PostgreSQL
- [x] Automated tests with pytest
- [x] Docker image and Docker Compose setup
- [x] CI pipeline with GitHub Actions (run tests, build and publish image)
- [x] AWS infrastructure with Terraform (VPC, security group, EC2)
- [x] Secret scanning in the CI pipeline (e.g. gitleaks)
- [ ] Continuous deployment: deploy automatically after a successful pipeline run
- [ ] Remote Terraform state in S3 with locking
- [ ] Secrets in AWS Systems Manager Parameter Store instead of user data
- [ ] Managed database (RDS) in a private subnet
- [ ] Load balancer with HTTPS
- [ ] Kubernetes deployment and monitoring
- [ ] Database migrations with Alembic
- [ ] PATCH endpoint for partial updates