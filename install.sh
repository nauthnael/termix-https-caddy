#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-tuan.gg}"
TERMIX_PORT="${TERMIX_PORT:-8044}"
TERMIX_IMAGE="${TERMIX_IMAGE:-ghcr.io/lukegus/termix:latest}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run this script as root."
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script supports Debian/Ubuntu servers with apt-get."
  exit 1
fi

echo "==> Updating apt packages"
apt-get update

echo "==> Installing required packages"
apt-get install -y ca-certificates curl gnupg debian-keyring debian-archive-keyring apt-transport-https

if ! command -v docker >/dev/null 2>&1; then
  echo "==> Installing Docker"
  apt-get install -y docker.io
  systemctl enable --now docker
else
  echo "==> Docker is already installed"
fi

echo "==> Installing Caddy repository"
rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -fsSL "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

curl -fsSL "https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt" \
  > /etc/apt/sources.list.d/caddy-stable.list

echo "==> Installing Caddy"
apt-get update
apt-get install -y caddy

echo "==> Starting Termix on localhost:${TERMIX_PORT}"
docker rm -f termix >/dev/null 2>&1 || true
docker run -d --name termix --restart unless-stopped \
  -p "127.0.0.1:${TERMIX_PORT}:${TERMIX_PORT}" \
  -v termix-data:/app/data \
  -e "PORT=${TERMIX_PORT}" \
  "${TERMIX_IMAGE}"

echo "==> Writing Caddyfile for ${DOMAIN}"
cat > /etc/caddy/Caddyfile <<EOF
${DOMAIN} {
    reverse_proxy localhost:${TERMIX_PORT}
}
EOF

echo "==> Enabling firewall ports if UFW is available"
if command -v ufw >/dev/null 2>&1; then
  ufw allow 80/tcp
  ufw allow 443/tcp
else
  echo "UFW is not installed, skipping firewall changes"
fi

echo "==> Starting Caddy"
systemctl enable caddy
caddy fmt --overwrite /etc/caddy/Caddyfile
systemctl restart caddy

echo
echo "Done. Open: https://${DOMAIN}"
echo "Caddy may need a short moment to issue the Let's Encrypt certificate."
