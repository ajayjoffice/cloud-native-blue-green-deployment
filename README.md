# Cloud-Native Blue-Green Deployment Pipeline

A small FastAPI service that demonstrates blue-green releases with Docker, GitHub Actions, EC2, and Nginx. There is no deployment dashboard: use the EC2 terminal and `curl` to see which version receives traffic, deploy an update, and roll back.

## How it works

```text
GitHub Actions (tests, lint, image and health check)
                         |
                 EC2 host Nginx :80
                    /          \
          Blue :8001            Green :8002
```

The app slots bind to loopback only. Nginx sends public requests to one slot. A deployment starts and validates the other slot before changing Nginx; the previous slot remains available for rollback.

## API

| Route | Purpose |
| --- | --- |
| `GET /` | Application name and version |
| `GET /health` | Health response and version |
| `GET /version` | Version currently served by this app slot |
| `POST /greet` | Small API example; accepts `{"name":"Ada"}` |

## Run locally

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
pytest
ruff check app tests
uvicorn app.main:app --reload
```

Open <http://127.0.0.1:8000/docs> for the API documentation.

## Local Docker and blue-green demo

```bash
docker compose up -d --build
curl http://localhost:8080/version
deployment/blue-green/switch.sh green
curl http://localhost:8080/version
deployment/blue-green/rollback.sh
curl http://localhost:8080/version
docker compose down
```

The default Compose versions are `v1.0.0` (Blue) and `v2.0.0` (Green). The output from each `curl` shows the version currently receiving traffic.

## EC2 console demonstration

The EC2 deployment guide explains initial setup. On the instance, clone the repository once and configure host Nginx as described there. For each release, use the commands below from the repository directory. They build the current source on EC2, deploy it to the inactive slot, check it, then switch Nginx only if it passes.

```bash
cd ~/cloud-native-blue-green-deployment
git pull --ff-only
VERSION="$(git rev-parse --short HEAD)"
IMAGE="blue-green-demo:$VERSION"
sudo docker build -t "$IMAGE" .
sudo env PULL_IMAGE=false bash deployment/blue-green/deploy-ec2.sh "$IMAGE" "$VERSION"
curl http://localhost/version
```

The `curl` output should be JSON with the deployed commit version. To demonstrate rollback, run:

```bash
sudo bash deployment/blue-green/rollback-ec2.sh
curl http://localhost/version
```

The second `curl` should show the prior release. To deploy another update, pull or edit a new commit, rebuild with its version, and run the deploy command again.

## GitHub Actions

`.github/workflows/ci.yml` runs on pushes to `main` and pull requests. It runs Ruff and Pytest, builds the Docker image, then starts it and checks `/health` and `/version` on a GitHub-hosted runner. Deployment and rollback are deliberately run from the EC2 terminal, so CI needs no AWS credentials, registry secrets, or self-hosted runner.

Before making this repository public, remove any registered self-hosted runner from **Settings → Actions → Runners**. A self-hosted runner should not remain attached to a public repository because public pull-request workflows can execute untrusted code.

## Project layout

- `app/` — FastAPI application
- `deployment/blue-green/` — local and EC2 deploy, switch, health, and rollback scripts
- `deployment/nginx/` — Nginx configuration
- `deployment/aws/deployment-guide.md` — EC2 setup and manual release walkthrough
- `.github/workflows/ci.yml` — hosted CI checks

## Concepts demonstrated

- CI checks and container health validation
- Versioned container images
- Blue-green deployment and health gates
- Nginx traffic switching and rollback
- Private app ports behind a public reverse proxy
