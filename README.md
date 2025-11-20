# 🐳 qBittorrent + HTTPS Caddy Telepítő (.env + Watch Mappa)

Ez a Bash szkript automatizálja a **qBittorrent** torrent kliens Docker konténerben történő telepítését, egy **Caddy** webkiszolgálóval együtt, amely **HTTPS** fordított proxyt (reverse proxy) biztosít, és beállít egy automatikusan figyelt **Watch mappát**.

* **TESZTELVE:** Debian 13 rendszeren.

## ✨ Főbb jellemzők

* **Teljesen automatizált telepítés:** Elvégzi a Docker, qBittorrent és Caddy telepítését (Debian alapú rendszereken).
* **HTTPS/SSL:** A Caddy automatikusan igényli és megújítja a Let's Encrypt tanúsítványt a biztonságos HTTPS hozzáféréshez.
* **.env fájl támogatás:** Az konfigurációs változók (`DOMAIN`, `WEBUI_PASSWORD`) a `/opt/qbittorrent/.env` fájlban tárolódnak.
* **Dedikált felhasználó:** Létrehozza a `qbittorrent` felhasználót a jogosultságok megfelelő kezeléséhez.
* **Watch mappa:** Beállít egy automatikusan figyelt mappát (`/opt/qbittorrent/watch`) a `.torrent` fájlok egyszerű hozzáadásához.

---

## 🚀 Telepítés és Indítás

### Előfeltételek
* Debian-alapú operációs rendszer (a Docker és Caddy telepítés ehhez lett optimalizálva).
* **Root** jogosultságok a szkript futtatásához.
* Egy domain név, amelynek **A rekordja** a szervered IP-címére mutat (például `torrent.domain.hu`). A Caddy-nek szüksége van erre a HTTPS tanúsítvány igényléséhez.

### Használat

1.  **Hozz létre egy fájlt, például `qbittorrent-docker-telepito.sh` néven:**
    ```bash
    nano qbittorrent-docker-telepito.sh 
    ```
    - Majd illeszd be az itt található script tartalmát, és mentsd el.

2.  **Adj neki futási jogot:**

    ```bash
    chmod +x qbittorrent-docker-telepito.sh
    ```
    
3. **Most pedig indítsd el:**
    ```bash
    sudo ./qbittorrent-docker-telepito.sh
    ```

    A szkript először **bekéri a használni kívánt domaint** (pl. `torrent.domain.hu`).

    *Ha a `/opt/qbittorrent/.env` fájl már létezik és tartalmazza a `DOMAIN` változót, akkor azt használja.*

---

## ⚙️ A szkript működése

### 1. Inicializálás és Ellenőrzések
* Ellenőrzi, hogy **rootként** fut-e.
* Létrehozza a `/opt/qbittorrent/.env` fájlt, ha még nem létezik, és bekéri a **domaint**.

### 2. Felhasználó és Mappák
* Létrehozza a `qbittorrent` rendszert, ha még nem létezik.
* Meghatározza a **PUID** és **PGID** értékeket a konténer jogosultságaihoz.
* Létrehozza a szükséges mappákat és beállítja a jogosultságokat:
    * `/opt/qbittorrent/config`
    * `/opt/qbittorrent/downloads`
    * `/opt/qbittorrent/watch`

### 3. Docker Telepítés
* Ha a **Docker** nincs telepítve, telepíti a legújabb verziót a hivatalos Docker repositoryból (Debian-alapú rendszereken).

### 4. qBittorrent Konténer Indítása
* Törli a korábbi `qbittorrent` nevű konténert (ha van).
* Indítja a `lscr.io/linuxserver/qbittorrent:latest` Docker konténert:
    * **Portok:** A webes felület a **127.0.0.1:8080** címen érhető el (csak helyileg).
    * **Környezeti változók:** `PUID`, `PGID`, `TZ=Europe/Budapest`.
    * **Volume-ok:**
        * `/opt/qbittorrent/config` -> `/config`
        * `/opt/qbittorrent/downloads` -> `/downloads`
        * `/opt/qbittorrent/watch` -> `/watch`

### 5. Ideiglenes Jelszó Mentése
* Figyeli a qBittorrent konténer logjait, amíg meg nem jelenik az **ideiglenes jelszó**.
* A jelszót menti a `.env` fájlba (`WEBUI_PASSWORD=...`).

### 6. Caddy (HTTPS Reverse Proxy) Telepítése
* Telepíti a **Caddy** webkiszolgálót.
* Létrehozza a `/etc/caddy/Caddyfile` konfigurációt:
    * **HTTP -> HTTPS** átirányítás.
    * **HTTPS fordított proxy** a `127.0.0.1:8080` (qBittorrent) címre.
* Újraindítja és engedélyezi a Caddy szolgáltatást.

### 7. Watch Mappa Automatikus Beállítása
* A szkript beállítja a `qBittorrent.conf` fájlban, hogy a `/watch` mappát automatikusan figyelje:
    ```ini
    [Preferences]
    AutoTMM_Enable=true
    AutoTMM_Rule_Enabled=true
    ScanDirs=/watch
    ```

---

## ✅ Végeredmény

A szkript befejezésekor a következő adatok jelennek meg a képernyőn:

| Leírás | Érték |
| :--- | :--- |
| **WebUI (HTTPS)** | `https://<a te domained>` |
| **Felhasználónév** | `admin` |
| **Jelszó** | `<Ideiglenes jelszó a .env-ből>` |
| **Letöltések Mappája** | `/opt/qbittorrent/downloads` |
| **Watch Mappa** | `/opt/qbittorrent/watch` (ide másolhatod a `.torrent` fájlokat) |
| **Caddy Konfiguráció** | `/etc/caddy/Caddyfile` |
| **Környezeti fájl** | `/opt/qbittorrent/.env` |

---

## 💡 Tippek

* **Jelszó módosítása:** Az első bejelentkezés után **azonnal** változtasd meg az ideiglenes jelszót a qBittorrent WebUI beállításaiban!
* **Port Forwarding:** A qBittorrent konténer portjai (8999 TCP/UDP) nem publikusak. Ha szükséged van rájuk (pl. port forwardinghez), szerkesztened kell a `docker run` parancsot a szkriptben.
