# AWS EC2 deployment guide

This guide runs a FastAPI app in two Docker containers on one EC2 instance. Host Nginx accepts HTTP on port 80 and routes requests to the active container. The blue and green ports are bound to loopback and should not be opened in the security group.

## 1. Create and secure the instance

Launch Ubuntu Server 24.04 LTS. Assign a public IPv4 address. In the instance security group, allow inbound TCP 22 from your current IP for SSH and TCP 80 from the internet for the demo website. Do not add inbound rules for ports 8001 or 8002. Keep the downloaded EC2 key pair private.

## 2. Install prerequisites

Connect to the instance using SSH or EC2 Instance Connect, then run:

```bash
sudo apt-get update
sudo apt-get install -y docker.io nginx curl git
sudo systemctl enable --now docker nginx
```

Clone the public repository over HTTPS:

```bash
git clone https://github.com/ajayjoffice/cloud-native-blue-green-deployment.git ~/cloud-native-blue-green-deployment
cd ~/cloud-native-blue-green-deployment
```

## 3. Configure host Nginx

Install the project Nginx configuration and set the initial active slot to Blue:

```bash
sudo install -m 0644 deployment/nginx/nginx.conf /etc/nginx/nginx.conf
printf 'upstream active_app {\n    server 127.0.0.1:8001;\n}\n' | sudo tee /etc/nginx/conf.d/active-upstream.conf
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx
```

Nginx listens on port 80. Confirm that the EC2 security group allows HTTP. The first deployment command below creates the initial app slot and switches Nginx to it; after a second successful deployment, the previous release is available in the other slot for rollback. Then check `http://YOUR_EC2_PUBLIC_IPV4/health` from your Mac browser or terminal.

## 4. Build and deploy a release

Run these commands in the repository directory on EC2 whenever you want to deploy the latest code:

```bash
cd ~/cloud-native-blue-green-deployment
git pull --ff-only
VERSION="$(git rev-parse --short HEAD)"
IMAGE="blue-green-demo:$VERSION"
sudo docker build -t "$IMAGE" .
sudo env PULL_IMAGE=false bash deployment/blue-green/deploy-ec2.sh "$IMAGE" "$VERSION"
curl http://localhost/version
```

The script starts the inactive color on its loopback port, checks `/health` and the expected `/version`, and then switches and reloads Nginx. If validation fails, Nginx keeps serving the old color. The final `curl` prints the version receiving traffic.

To deploy another release, pull a new commit and repeat the commands. Each build gets a commit-based version label.

## 5. Roll back and verify

The other slot keeps the previous app available. Run:

```bash
cd ~/cloud-native-blue-green-deployment
sudo bash deployment/blue-green/rollback-ec2.sh
curl http://localhost/version
```

Rollback checks the standby slot before changing Nginx. The `curl` result should now show the previous version. You can also check from your Mac using `curl http://YOUR_EC2_PUBLIC_IPV4/version`.

## GitHub Actions runner

The project uses GitHub-hosted Actions for CI only. It does not need an EC2 self-hosted runner, AWS credentials, or a container registry token. If an EC2 self-hosted runner was registered during earlier setup, remove it from the repository's **Settings → Actions → Runners** before making the repository public. Stop and uninstall its service on EC2 after removing it in GitHub:

```bash
cd ~/actions-runner
sudo ./svc.sh stop
sudo ./svc.sh uninstall
```
