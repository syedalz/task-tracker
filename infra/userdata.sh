#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
# Add Docker's official GPG key:
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker ubuntu

# Create folder for app instance
mkdir /opt/task-tracker
cat > /opt/task-tracker/compose.yaml <<'EOF'
services:
  api:
    image: syedalz/task-tracker:latest
    ports:
      - "8000:8000"
    env_file: ./.env
    environment:
      DATABASE_HOSTNAME: postgres
    depends_on:
      postgres:
        condition: service_healthy

  postgres:
    image: postgres:17
    environment:
      POSTGRES_USER: ${DATABASE_USERNAME}
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD}
      POSTGRES_DB: ${DATABASE_NAME}

    volumes:
      - postgres-db:/var/lib/postgresql/data

    healthcheck:
      test: ["CMD", "pg_isready", "-h", "localhost", "-U", "${DATABASE_USERNAME}","-d", "${DATABASE_NAME}"]
      interval: 5s
      retries: 3
      timeout: 5s
      start_period: 40s
      start_interval: 5s
  
volumes:
  postgres-db: 

EOF

cat > .env <<'EOF'
DATABASE_HOSTNAME=localhost
DATABASE_PORT=5432
DATABASE_PASSWORD=manager1
DATABASE_NAME=tasks
DATABASE_USERNAME=taskuser