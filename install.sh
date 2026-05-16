#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"
TERMIX_PORT="${TERMIX_PORT:-8044}"
TERMIX_IMAGE="${TERMIX_IMAGE:-ghcr.io/lukegus/termix:latest}"

if [[ -z "$DOMAIN" ]]; then
  read -r -p "Enter your domain, for example tuan.gg: " DOMAIN
fi

if [[ -z "$DOMAIN" ]]; then
  echo "Domain is required."
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run this script as root."
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script supports Debian/Ubuntu servers with apt-get."
  exit 1
fi

port_listeners() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    ss -ltnp "sport = :${port}" 2>/dev/null || true
    return
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true
    return
  fi

  return 0
}

check_required_ports() {
  local busy_ports=()
  local port
  local listeners

  for port in 80 443; do
    listeners="$(port_listeners "${port}")"
    if [[ -n "$listeners" ]]; then
      busy_ports+=("${port}")
      echo
      echo "Port ${port} is already in use:"
      echo "$listeners"
    fi
  done

  if [[ "${#busy_ports[@]}" -eq 0 ]]; then
    return
  fi

  echo
  read -r -p "One or more required ports are in use. Continue and overwrite Caddy setup? [y/N]: " OVERWRITE_PORTS
  case "${OVERWRITE_PORTS}" in
    y|Y|yes|YES)
      echo "Continuing. Make sure any conflicting web server is stopped if Caddy cannot start."
      ;;
    *)
      echo "Aborted. Free ports 80 and 443, then run the script again."
      exit 1
      ;;
  esac
}

get_public_ipv4() {
  curl -4fsS --max-time 10 https://api.ipify.org 2>/dev/null \
    || curl -4fsS --max-time 10 https://ifconfig.me/ip 2>/dev/null \
    || true
}

resolve_domain_ipv4() {
  getent ahostsv4 "$DOMAIN" \
    | awk '{print $1}' \
    | sort -u \
    || true
}

check_domain_dns() {
  local public_ip
  local domain_ips
  local confirm_dns

  echo "==> Checking DNS for ${DOMAIN}"
  public_ip="$(get_public_ipv4)"

  if [[ -z "$public_ip" ]]; then
    echo "Could not detect this VPS public IPv4. Skipping DNS check."
    return
  fi

  domain_ips="$(resolve_domain_ipv4)"

  echo "VPS public IPv4: ${public_ip}"
  if [[ -n "$domain_ips" ]]; then
    echo "Domain IPv4 records:"
    echo "$domain_ips"
  else
    echo "Domain IPv4 records: none found"
  fi

  if echo "$domain_ips" | grep -Fxq "$public_ip"; then
    echo "DNS looks good. ${DOMAIN} points to this VPS."
    return
  fi

  echo
  echo "${DOMAIN} does not currently point to this VPS public IP (${public_ip})."
  echo "Create or update an A record for ${DOMAIN} -> ${public_ip}, then wait for DNS propagation."
  read -r -p "Continue only if you will point the domain to this VPS now? [y/N]: " confirm_dns
  case "${confirm_dns}" in
    y|Y|yes|YES)
      echo "Continuing. Caddy SSL will work after DNS points to this VPS."
      ;;
    *)
      echo "Aborted. Point ${DOMAIN} to ${public_ip}, then run the script again."
      exit 1
      ;;
  esac
}

check_required_ports

echo "==> Updating apt packages"
apt-get update

echo "==> Installing required packages"
apt-get install -y ca-certificates curl gnupg debian-keyring debian-archive-keyring apt-transport-https

check_domain_dns

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
