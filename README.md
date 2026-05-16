# Termix HTTPS Caddy

Script cai Termix sau Caddy reverse proxy voi HTTPS tu dong bang Let's Encrypt.

## Yeu cau

- VPS Ubuntu/Debian
- Domain da tro A record ve IP cua VPS
- Chay script bang user `root`

## Cai nhanh

Thay `t.0x.am` bang domain cua ban:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nauthnael/termix-https-caddy/main/install.sh) t.0x.am
```

Sau khi chay xong, mo:

```text
https://t.0x.am
```

## Tuy chinh port noi bo

Mac dinh Termix chay noi bo o port `8044`. Neu muon doi:

```bash
TERMIX_PORT=9000 bash <(curl -fsSL https://raw.githubusercontent.com/nauthnael/termix-https-caddy/main/install.sh) t.0x.am
```

## Script se lam gi?

- Cai Docker neu VPS chua co Docker
- Cai Caddy tu repository chinh thuc
- Chay container `ghcr.io/lukegus/termix:latest`
- Bind Termix vao `127.0.0.1` de khong public truc tiep ra internet
- Tao `/etc/caddy/Caddyfile`
- Mo port `80` va `443` neu VPS co UFW
- Restart Caddy de tu dong xin SSL certificate
