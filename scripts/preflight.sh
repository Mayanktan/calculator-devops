#!/usr/bin/env bash
# Pre-demo checks. Stops at the first failure.
# Usage: ./scripts/preflight.sh [github-user] [dockerhub-user] [jenkins-url]   (defaults: Mayanktan mayanktan http://localhost:8080)
set -e
cd "$(dirname "$0")/.."     # repo root, so 'docker compose' finds its file

GH_USER=${1:-Mayanktan}
DH_USER=${2:-mayanktan}
JENKINS=${3:-http://localhost:8080}

echo "=== 1. docker daemon ==="
docker info > /dev/null
echo OK

echo "=== 2. jenkins up ==="
curl -fsS "$JENKINS/login" > /dev/null
echo OK

echo "=== 3. ngrok tunnel ==="
TUNNEL=$(curl -s http://localhost:4040/api/tunnels | grep -o 'https://[^"]*ngrok[^"]*' | head -1)
echo "${TUNNEL:-none (fine if you use Poll SCM)}"

echo "=== 4. compose stack healthy ==="
docker compose ps
curl -fsS http://localhost/actuator/health
echo "" && echo OK

echo "=== 5. GitHub repo reachable ==="
curl -fsSI "https://github.com/$GH_USER/calculator-devops" > /dev/null
echo OK

echo "=== 6. Docker Hub repo exists ==="
curl -fsSI "https://hub.docker.com/r/$DH_USER/calculator-devops" > /dev/null
echo OK

echo "" && echo "All preflight checks passed — ready to demo."
