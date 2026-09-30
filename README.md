# Cloud-Native Blue-Green Deployment Pipeline

A small FastAPI service and deployment pipeline that demonstrates safe releases with Docker, GitHub Actions, EC2, and Nginx. Blue and Green are two copies of the same application running side by side; the Nginx upstream decides which one receives production requests.

## Why blue-green?

Replacing a live application in place can interrupt requests or expose users to an untested release. This project starts the new version beside the current one, checks it directly, and changes Nginx only after validation. The old version stays running as a simple rollback target.

## Architecture

```text
                         Public :80
                            |
                          Nginx
                 active upstream config
                    /             \
          Blue :8001               Green :8002
          standby/live             standby/live
```

Only the selected upstream receives user traffic. Both containers run the same API; `APP_VERSION` distinguishes releases (for example `v1.0.0` and `v2.0.0`).

## Stack

- Python 3.12, FastAPI, Uvicorn, Pytest, Ruff
- Docker and Docker Compose
- GitHub Actions
- AWS EC2 and Nginx
- Bash deployment and health-check scripts

## API

| Route | Purpose |
| --- | --- |
| `GET /` | Application name and version |
| `GET /health` | Liveness response and version |
| `GET /version` | Current release identifier |
| `POST /greet` | Small functional API; accepts `{"name":"Ada"}` |

## Release dashboard

Open `/dashboard` to see the live version, active color, health status, and the steps each release follows. The dashboard is read-only. Use its rollback link to open the authenticated GitHub Actions workflow and start a rollback there; the workflow checks the standby version before switching traffic.

## Run locally

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
pytest
ruff check app tests
uvicorn app.main:app --reload
```

Visit <http://127.0.0.1:8000/docs>. Set another version with `APP_VERSION=v2.0.0 uvicorn app.main:app`.

## Docker

```bash
docker build -t blue-green-demo:local .
docker run --rm -p 8000:8000 -e APP_VERSION=v1.0.0 blue-green-demo:local
curl http://localhost:8000/health
curl http://localhost:8000/version
```

The image uses a slim Python base, installs dependencies without retaining pip cache, and runs as an unprivileged user.

## Try blue-green locally

Docker Compose runs Blue and Green plus Nginx. Nginx is published on port 8080; the app ports are bound to loopback on 8001 and 8002 for direct validation.

```bash
docker compose up -d --build
curl http://localhost:8080/version    # initially v1.0.0 (Blue)
deployment/blue-green/health-check.sh http://localhost:8080 v1.0.0
deployment/blue-green/switch.sh green
curl http://localhost:8080/version    # now v2.0.0 (Green)
deployment/blue-green/rollback.sh
curl http://localhost:8080/version    # back to Blue
docker compose down
```

To deploy a new image build into the inactive Compose color and switch after its version check:

```bash
deployment/blue-green/deploy.sh v3.0.0
```

The active color is read from the Nginx config. The other service is recreated with the requested version. If its health check fails, the script exits before switching traffic.

## CI/CD flow

`.github/workflows/ci-cd.yml` runs on pull requests and pushes to `main`: checkout, Python setup, dependency install, Ruff, Pytest, Docker build, then a container health/version check. For pushes to `main`, a dependent job publishes the commit image to GitHub Container Registry and a job on the repository's self-hosted EC2 runner deploys it to the inactive slot. It validates `/health` and `/version` before reloading Nginx. A manual workflow dispatch runs the guarded rollback script.

Keep the repository private while it uses a self-hosted runner. The EC2 runner needs Docker and Nginx installed and must be registered in the repository's Actions runner settings. The workflow uses its automatically provided `GITHUB_TOKEN` for GHCR access, so no SSH or GHCR secrets are needed. Details are in [the AWS guide](deployment/aws/deployment-guide.md).

## Rollback

Local Compose:

```bash
deployment/blue-green/rollback.sh
```

EC2:

```bash
sudo /opt/blue-green/rollback-ec2.sh
```

Rollback changes the Nginx upstream to the other slot and reloads Nginx. Check the version currently receiving requests with `curl http://YOUR_HOST/version`.

## Testing and health checks

Pytest covers root, health, version, successful greeting, and invalid greeting input. `health-check.sh BASE_URL EXPECTED_VERSION` checks that health reports OK and that the expected version is served.

## Screenshots

Add screenshots here after running the demo, such as the GitHub Actions run and `/version` responses before and after switching.

## Key DevOps concepts demonstrated

- CI versus CD and pipeline stages
- Immutable, version-tagged container images
- Environment-based application configuration
- Health checks and deployment gates
- Reverse proxy routing and traffic switching
- Blue-green deployment, rollback, and least-privilege container execution
- GitHub Actions secrets and remote deployment

## Future improvements

- Add HTTPS with a domain and Let's Encrypt
- Add a smoke test against the public endpoint after deployment
- Add deployment history and an approval gate for production
- Add metrics and centralized logs

The initial project intentionally uses one EC2 instance and two app containers so each deployment step stays visible and explainable.
