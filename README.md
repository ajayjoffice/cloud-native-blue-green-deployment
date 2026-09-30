# Cloud-Native Blue-Green Deployment Pipeline

A learning project that demonstrates how to release a web application with little or no visible downtime. It combines a small FastAPI service, Docker, GitHub Actions, AWS EC2, and Nginx.

The project is intentionally operated from the terminal. Use `curl` to see the release receiving traffic, deploy an update, and switch back to the previous release. There is no web dashboard or deployment button.

## What the project does

The application runs in two slots, called **Blue** and **Green**. Only one slot receives live requests through Nginx. During a release, the deployment script starts the new version in the inactive slot, checks its health and version, and changes Nginx to route traffic to it. The former live slot stays available as a rollback target.

```text
Developer pushes code
        |
        v
GitHub Actions: lint, tests, Docker build, health/version check

EC2 deployment (started manually from the EC2 terminal)
        |
        v
Public HTTP :80 --> Nginx --> Blue :8001 or Green :8002
```

On EC2, Nginx is installed on the host. The application containers bind to `127.0.0.1` on ports 8001 and 8002, so those ports are not directly exposed to the internet. The security group only needs HTTP port 80 for visitors and SSH port 22 restricted to the administrator's IP (or EC2 Instance Connect).

## Why blue-green deployment?

Updating a live application in place can interrupt requests or leave users on a release that has not passed its health check. Blue-green deployment gives the new release a separate slot to start and be checked first. Nginx switches traffic only after the new slot responds with the expected version. If a release causes problems, traffic can be returned to the other healthy slot.

This small project makes each step visible and helps demonstrate:

- Continuous integration (CI) checks before a change is merged or pushed.
- Container images and application versions.
- Health checks as a deployment gate.
- Reverse-proxy routing and traffic switching.
- Keeping the previous release available for rollback.
- Restricting application ports behind a public Nginx endpoint.

## Technology used

- Python 3.12, FastAPI, and Uvicorn for the API.
- Pytest and Ruff for tests and linting.
- Docker and Docker Compose for packaging and local runs.
- GitHub Actions on GitHub-hosted runners for CI.
- AWS EC2 and Nginx for the demonstration deployment.
- Bash scripts for deployment, health checks, traffic switching, and rollback.

## API endpoints

| Method and path | Purpose | Example response |
| --- | --- | --- |
| `GET /` | Application name and version | `{"application":"cloud-native-blue-green","version":"v1.0.0"}` |
| `GET /health` | Health check and version | `{"status":"ok","version":"v1.0.0"}` |
| `GET /version` | Version served by this app instance | `{"version":"v1.0.0"}` |
| `POST /greet` | Example request accepting a name | `{"message":"Hello, Ada!","version":"v1.0.0"}` |

The interactive API documentation is available at `/docs` while the service is running.

## Requirements

For local development:

- Git
- Python 3.12 or a compatible recent Python version
- `pip`

For Docker examples, install Docker Desktop (Mac/Windows) or Docker Engine with the Compose plugin (Linux). For the AWS demonstration, use an Ubuntu EC2 instance with a public IPv4 address and security group rules for HTTP and administrator access, as described in the [EC2 deployment guide](deployment/aws/deployment-guide.md).

## Run the API directly with Python

Clone the repository and enter its directory:

```bash
git clone https://github.com/ajayjoffice/cloud-native-blue-green-deployment.git
cd cloud-native-blue-green-deployment
```

Create a virtual environment, install dependencies, run the tests and lint check, then start the development server:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
pytest -q
ruff check app tests
uvicorn app.main:app --reload
```

Open <http://127.0.0.1:8000/docs> for the API docs. In a second terminal, check the service:

```bash
curl http://localhost:8000/health
curl http://localhost:8000/version
```

Set a different version by starting Uvicorn with an `APP_VERSION` value, for example:

```bash
APP_VERSION=v2.0.0 uvicorn app.main:app --reload
```

## Build and run one Docker container

```bash
docker build -t blue-green-demo:local .
docker run --rm -p 8000:8000 -e APP_VERSION=v1.0.0 blue-green-demo:local
```

In a second terminal, call its endpoints:

```bash
curl http://localhost:8000/health
curl http://localhost:8000/version
```

The Docker image uses a slim Python base image and runs the application as an unprivileged user.

## Run a local Blue-Green demonstration

Docker Compose starts Blue, Green, and an Nginx container. Nginx is available at port 8080. The application slots are available on loopback ports 8001 and 8002 for health checks and direct inspection.

Start the containers:

```bash
docker compose up -d --build
```

The default versions are `v1.0.0` (Blue) and `v2.0.0` (Green). View the live version, switch traffic, and view it again:

```bash
curl http://localhost:8080/version
deployment/blue-green/switch.sh green
curl http://localhost:8080/version
deployment/blue-green/rollback.sh
curl http://localhost:8080/version
```

Expected sequence: `v1.0.0`, then `v2.0.0`, then `v1.0.0` again. The rollback script switches Nginx to the other local slot. Stop the local containers when finished:

```bash
docker compose down
```

To build and deploy a new version into the inactive local slot, validate it, and then switch traffic:

```bash
deployment/blue-green/deploy.sh v3.0.0
curl http://localhost:8080/version
```

## GitHub Actions continuous integration

The workflow in `.github/workflows/ci.yml` runs on pushes to `main` and pull requests. On a GitHub-hosted runner it:

1. Installs the Python dependencies.
2. Runs Ruff and Pytest.
3. Builds the Docker image.
4. Starts the image and checks `/health` and `/version`.

CI does not deploy to EC2. Deployment and rollback are started manually from the EC2 terminal. This keeps AWS credentials out of GitHub Actions and avoids attaching a self-hosted runner to a public repository. No GitHub Actions secrets are required for CI.

## Deploy to AWS EC2 and demonstrate rollback

Follow the [EC2 deployment guide](deployment/aws/deployment-guide.md) to create the instance, install Docker and Nginx, clone this repository, and configure the host Nginx service. Once set up, run each release from the repository directory on EC2:

```bash
cd ~/cloud-native-blue-green-deployment
git pull --ff-only
VERSION="$(git rev-parse --short HEAD)"
IMAGE="blue-green-demo:$VERSION"
sudo docker build -t "$IMAGE" .
sudo env PULL_IMAGE=false bash deployment/blue-green/deploy-ec2.sh "$IMAGE" "$VERSION"
```

The deploy script uses the locally built image, starts it in the inactive slot, checks its health and expected version, then switches and reloads Nginx. On a new EC2 setup, the first deploy starts the initial app slot; after the next successful deployment, the previous release remains in the other slot for rollback. Check the version and health that are now receiving traffic:

```bash
curl http://localhost/health
curl http://localhost/version
```

To demonstrate rollback, switch traffic back to the other slot and check its version:

```bash
sudo bash deployment/blue-green/rollback-ec2.sh
curl http://localhost/version
```

Rollback validates the standby slot before switching Nginx. After the demonstration, deploy the latest release again using the build and deploy commands above. Repeating deployments replaces the inactive slot with the new release, while keeping the currently active slot available during validation.

The public endpoint can be checked from your own computer using the EC2 instance's current public IPv4 address:

```bash
curl http://YOUR_EC2_PUBLIC_IPV4/health
curl http://YOUR_EC2_PUBLIC_IPV4/version
```

Do not open ports 8001 or 8002 in the EC2 security group. Only Nginx on port 80 should receive public HTTP traffic.

## Repository layout

```text
app/                         FastAPI application
tests/                       API tests
deployment/blue-green/       Local and EC2 deploy, switch, health, rollback scripts
deployment/nginx/            Nginx configuration
deployment/aws/              EC2 setup and deployment guide
.github/workflows/ci.yml     GitHub-hosted CI workflow
Dockerfile                   Application container image definition
docker-compose.yml           Local Blue, Green, and Nginx services
requirements.txt             Python dependencies
```

## Troubleshooting

- **`docker: command not found`** — install and start Docker Desktop locally, or Docker Engine and Compose on EC2.
- **Docker Hub pull access denied for `blue-green-demo`** — for the EC2 local-image workflow, build the image first and run the deploy script with `sudo env PULL_IMAGE=false ...` as shown above.
- **The version did not change** — check the deploy output and `curl http://localhost/version` on EC2. Nginx only switches after the standby app passes health and version checks.
- **`/dashboard` returns 404** — expected. The dashboard was removed; status and demonstration output are shown in the terminal through `/health` and `/version`.
- **Cannot connect from the browser** — verify the instance is running, Nginx is active, the instance has a public IPv4 address, and the security group allows inbound HTTP on port 80.

## License

See [LICENSE](LICENSE).
