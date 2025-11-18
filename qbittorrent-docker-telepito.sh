#!/bin/bash

echo "=== qBittorrent + HTTPS Caddy Telepítő (.env + Watch mappa) indul ==="

# Root ellenőrzés
if [ "$EUID" -ne 0 ]; then
    echo "Kérlek rootként futtasd!"
    exit 1
fi

# .env fájl létrehozása, ha nincs
ENV_FILE="/opt/qbittorrent/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Nincs .env fájl, létrehozás..."
    mkdir -p /opt/qbittorrent
    touch $ENV_FILE
    read -p "Add meg a domaint (pl. torrent.domain.hu): " DOMAIN
    echo "DOMAIN=$DOMAIN" >> $ENV_FILE
else
    DOMAIN=$(grep DOMAIN $ENV_FILE | cut -d'=' -f2)
fi

echo "Domain: $DOMAIN"

# qBittorrent user létrehozása
if ! id "qbittorrent" >/dev/null 2>&1; then
    useradd -m -s /bin/bash qbittorrent
fi
PUID=$(id -u qbittorrent)
PGID=$(id -g qbittorrent)
echo "qbittorrent user ID: $PUID , group ID: $PGID"

# Mappák létrehozása
mkdir -p /opt/qbittorrent/config
mkdir -p /opt/qbittorrent/downloads
mkdir -p /opt/qbittorrent/watch
chown -R qbittorrent:qbittorrent /opt/qbittorrent

# Docker telepítés ellenőrzés
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker telepítése..."
    apt update
    apt install -y ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Régi konténer törlése
docker rm -f qbittorrent >/dev/null 2>&1

echo "=== qBittorrent konténer indítása ==="
docker run -d \
  --name=qbittorrent \
  --env-file $ENV_FILE \
  -e PUID=$PUID \
  -e PGID=$PGID \
  -e TZ=Europe/Budapest \
  -p 127.0.0.1:8080:8080 \
  -p 127.0.0.1:8999:8999 \
  -p 127.0.0.1:8999:8999/udp \
  -v /opt/qbittorrent/config:/config \
  -v /opt/qbittorrent/downloads:/downloads \
  -v /opt/qbittorrent/watch:/watch \
  --restart unless-stopped \
  lscr.io/linuxserver/qbittorrent:latest

# Log figyelés a temporary password megjelenéséig (ha nincs .env-ben)
if ! grep -q WEBUI_PASSWORD $ENV_FILE; then
    echo "Várakozás a WebUI jelszóra a logban..."
    PASSWORD=""
    while [ -z "$PASSWORD" ]; do
        PASSWORD=$(docker logs qbittorrent 2>&1 | grep -i "temporary password" | awk -F': ' '{print $2}' | tr -d ' ')
        sleep 2
    done
    echo "WEBUI_PASSWORD=$PASSWORD" >> $ENV_FILE
else
    PASSWORD=$(grep WEBUI_PASSWORD $ENV_FILE | cut -d'=' -f2)
fi

############################################################
# Caddy telepítése (HTTPS reverse proxy, http->https)
############################################################
echo "=== Caddy telepítése (HTTPS Reverse Proxy) ==="
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

apt update
apt install -y caddy

# Caddy domain konfiguráció
cat >/etc/caddy/Caddyfile <<EOF
# HTTP -> HTTPS redirect
http://$DOMAIN {
    redir https://$DOMAIN{uri} permanent
}

# HTTPS proxy, csak domainről elérhető
https://$DOMAIN {
    reverse_proxy 127.0.0.1:8080
}
EOF

systemctl restart caddy
systemctl enable caddy

############################################################
# Watch mappa automatikus beállítása a qBittorrentban
############################################################
CONFIG_FILE="/opt/qbittorrent/config/qBittorrent.conf"
docker exec qbittorrent bash -c "mkdir -p /config; touch /config/qBittorrent.conf"
docker cp $CONFIG_FILE qbittorrent:/config/qBittorrent.conf >/dev/null 2>&1 || true

docker exec qbittorrent bash -c "
mkdir -p /watch
CONFIG='/config/qBittorrent.conf'
if ! grep -q 'AutoTMM_Enable' \$CONFIG; then
  echo -e '[Preferences]\nAutoTMM_Enable=true\nAutoTMM_Rule_Enabled=true\nScanDirs=/watch' >> \$CONFIG
fi
"

############################################################
# WebUI elérhetőség ellenőrzése
############################################################
echo "Ellenőrizzük a WebUI elérhetőségét HTTPS-en..."
for i in {1..10}; do
    sleep 2
    if curl -ks https://$DOMAIN > /dev/null; then
        echo "✅ WebUI elérhető HTTPS-en: https://$DOMAIN"
        break
    else
        echo "Várakozás, próbáljuk újra... ($i/10)"
    fi
done

echo ""
echo "===================================================="
echo "   qBittorrent + HTTPS Reverse Proxy + Watch mappa készen van!"
echo ""
echo " WebUI (HTTPS):  https://$DOMAIN"
echo " Felhasználónév: admin"
echo " Jelszó: $PASSWORD"
echo ""
echo " Letöltések:   /opt/qbittorrent/downloads"
echo " Watch mappa:  /opt/qbittorrent/watch (automatikusan figyelt, új .torrent fájlok hozzáadódnak)"
echo " Caddy config: /etc/caddy/Caddyfile"
echo " .env fájl:    $ENV_FILE"
echo "===================================================="
