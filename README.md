# Termix HTTPS Caddy

Script cai Termix sau Caddy reverse proxy voi HTTPS tu dong bang Let's Encrypt.

## Yeu cau

- VPS Ubuntu/Debian
- Domain da tro A record ve IP cua VPS
- Chay script bang user `root`

## Cai nhanh voi tuan.gg

Chay lenh nay tren VPS:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nauthnael/termix-https-caddy/main/install.sh) tuan.gg
```

Sau khi chay xong, mo:

```text
https://tuan.gg
```

## Dung domain khac

Truyen domain o cuoi lenh:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nauthnael/termix-https-caddy/main/install.sh) example.com
```

Neu khong truyen domain, script se hoi ban nhap domain:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nauthnael/termix-https-caddy/main/install.sh)
```

## Tuy chinh port noi bo

Mac dinh Termix chay noi bo o port `8044`. Neu muon doi:

```bash
TERMIX_PORT=9000 bash <(curl -fsSL https://raw.githubusercontent.com/nauthnael/termix-https-caddy/main/install.sh) tuan.gg
```

## Script se lam gi?

- Cai Docker neu VPS chua co Docker
- Cai Caddy tu repository chinh thuc
- Chay container `ghcr.io/lukegus/termix:latest`
- Bind Termix vao `127.0.0.1` de khong public truc tiep ra internet
- Kiem tra port `80` va `443`; neu dang bi dung thi hoi xac nhan truoc khi tiep tuc
- Tao `/etc/caddy/Caddyfile`
- Mo port `80` va `443` neu VPS co UFW
- Restart Caddy de tu dong xin SSL certificate
