# AWS EC2 deployment guide

This project uses one EC2 instance, Docker for two app containers, and host Nginx as the public reverse proxy. No AWS load balancer or other service is required.

## 1. Create the instance

Launch Ubuntu Server 24.04 LTS. Use a small instance for learning, allocate a public IPv4 address, and create an SSH key pair. In the security group allow inbound TCP 22 only from your IP and TCP 80 from the clients who should reach the demo. Do not expose ports 8001 or 8002 publicly; the containers bind those ports to loopback.

## 2. Install Docker and Nginx

SSH into the instance, then run:

```bash
sudo apt-get update
sudo apt-get install -y docker.io nginx curl
sudo systemctl enable --now docker nginx
sudo usermod -aG docker "$USER"
```

Log out and back in for Docker group membership to take effect. Install the two deployment scripts into `/opt/blue-green` (copy them from this repository), and make them executable:

```bash
sudo mkdir -p /opt/blue-green
sudo cp deployment/blue-green/{deploy-ec2.sh,health-check.sh,rollback-ec2.sh} /opt/blue-green/
sudo chmod +x /opt/blue-green/*.sh
```

Configure Nginx with `/etc/nginx/nginx.conf` from `deployment/nginx/nginx.conf`, and create `/etc/nginx/conf.d/active-upstream.conf`:

```nginx
upstream active_app { server 127.0.0.1:8001; }
```

Then validate and reload: `sudo nginx -t && sudo systemctl reload nginx`.

## 3. GitHub Actions secrets

Add repository secrets `EC2_HOST` (public IP or DNS), `EC2_USER` (usually `ubuntu`), `EC2_SSH_KEY` (private key contents), `GHCR_USER`, and `GHCR_READ_TOKEN` (a GitHub token with read access to packages). The workflow builds and pushes the commit image, logs the EC2 Docker daemon into GHCR for pulling, then SSHes to deploy it.

## 4. Manual deployment and rollback

On the instance, after logging in to GHCR when required:

```bash
sudo /opt/blue-green/deploy-ec2.sh ghcr.io/OWNER/REPOSITORY:COMMIT_SHA v2.0.0
curl http://localhost/version
sudo /opt/blue-green/rollback-ec2.sh
```

The deploy script chooses the inactive color, starts it on port 8001 or 8002, checks both `/health` and `/version`, and only then changes Nginx and reloads it. If validation or Nginx configuration fails, the previous Nginx config remains in place. The old container is retained to make rollback a quick traffic change.
