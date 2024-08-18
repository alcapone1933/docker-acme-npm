# docker-acme-npm

[![Build Status](https://shields.cosanostra-cloud.de/drone/build/alcapone1933/docker-acme-npm?logo=drone&server=https%3A%2F%2Fdrone.docker-for-life.de)](https://drone.docker-for-life.de/alcapone1933/docker-acme-npm)
[![Build Status Branch Master](https://shields.cosanostra-cloud.de/drone/build/alcapone1933/docker-acme-npm/master?logo=drone&label=build%20%5Bbranch%20master%5D&server=https%3A%2F%2Fdrone.docker-for-life.de)](https://drone.docker-for-life.de/alcapone1933/docker-acme-npm/branches)
[![Docker Pulls](https://shields.cosanostra-cloud.de/docker/pulls/alcapone1933/acme-npm?logo=docker&logoColor=blue)](https://hub.docker.com/r/alcapone1933/acme-npm/tags)
![Docker Image Version (latest semver)](https://shields.cosanostra-cloud.de/docker/v/alcapone1933/acme-npm?sort=semver&logo=docker&logoColor=blue&label=dockerhub%20version)

&nbsp;

# ACME-NPM Updater

Dieses Projekt stellt einen Docker-Container bereit, der für die automatische Verwaltung von SSL-Zertifikaten über [ACME.SH](https://github.com/acmesh-official/acme.sh) aktualisiert wird und \
die Integration mit dem Nginx Proxy Manager (NPM) per API die SSL-Zertifikate Custom einzupflegen. \
Der Container führt regelmäßige Überprüfungen und Updates durch und kann bei Bedarf auch Benachrichtigungen über [Shoutrrr](https://containrrr.dev/shoutrrr) senden.

&nbsp;

## Voraussetzungen

- Docker und Docker Compose müssen installiert sein.
- Eine Instanz von Nginx Proxy Manager sollte bereits eingerichtet sein.

&nbsp;

### Erster Schritt wenn ACME Ordner noch nicht vorhadnen ist.

Starten die den Docker Container und richten sie acme.sh ein.

```bash
docker run --rm -it -v /your/path/acme.sh:/acme.sh --net=host alcapone1933/acme-npm /bin/bash
```

<details>
<summary markdown="span">ACME.SH Beispiele</summary>

```bash
acme.sh --set-default-ca --server letsencrypt

acme.sh --register-account --server letsencrypt -m user@example.com

acme.sh --issue --standalone -d example.com
acme.sh --issue --dns dns_ddnss -d example.com
acme.sh --issue --dns dns_ddnss -d example.com -d '*.example.com'

acme.sh --issue --dns dns_ipv64 -d example.com --server letsencrypt
acme.sh --issue --dns dns_ipv64 -d example.com -d '*.example.com' --server letsencrypt

acme.sh --issue --alpn --tlsport 8443 --server letsencrypt --keylength 3072 -d example.com

acme.sh --cron
acme.sh --renew-all
acme.sh --renew-all --staging --force
acme.sh --renew -d example.com --force


acme.sh --set-notify --notify-source myservername --notify-mode 0 --notify-level 2 --notify-hook gotify
export GOTIFY_URL="https://gotify.example.com"
export GOTIFY_TOKEN="123456789ABCDEF"
```
</details>

[ACME.SH-WIKI](https://github.com/acmesh-official/acme.sh/wiki)

&nbsp;

## Docker CLI

```bash
docker run -d \
  --name acme.sh \
  --restart unless-stopped \
  --network host \
  -v /your/path/acme.sh:/acme.sh \
  -e TZ=Europe/Berlin \
  -e DOMAIN=example.de \
  -e SHOUTRRR_URL= \
  alcapone1933/acme-npm:latest

```
## Docker Compose

```yaml
services:
  acme:
    image: alcapone1933/acme-npm:latest
    container_name: acme.sh
    network_mode: "host"
    restart: unless-stopped
    volumes:
      - /your/path/acme.sh:/acme.sh
      # - ./output:/output
      # - /var/run/docker.sock:/var/run/docker.sock:ro
      # - ./data:/data #Optional
    environment:
      - TZ=Europe/Berlin
      - DOMAIN=example.de
      - SHOUTRRR_URL=
      - SHOUTRRR_SKIP_TEST=no
      # - NPM_API=http://<nginx-proxy-manager-ip>:81/api
      # - NPM_USER=<dein_nginx_proxymanager_benutzername>
      # - NPM_PASS=<dein_nginx_proxymanager_passwort>
      # - DOCKER_CONTAINER=
      # - OUTPUT_YES=yes
      # - CERT_CER_NAME=example.de.cer
      # - CERT_KEY_NAME=example.de.key
      # - CERT_CSR_NAME=example.de.csr
```



## Volume Parameter

| Name (Beschreibung)                          | Wert    | Standard                                       |
| -------------------------------------------- | ------- | ---------------------------------------------- |
| Speicherort acme conf und SSL-Zertifikaten   | volume  | `acme.sh:/acme.sh`                             |
| Speicherort für OUTPUT von SSL-Zertifikaten  | volume  | `output:/output`                               |
| Speicherort für Logs #Optional               | volume  | `acme-npm_logs:/data`                          |
| DOCKER SOCKET                                | PFAD    | `/var/run/docker.sock:/var/run/docker.sock:ro` |


## Umgebungsvariablen
Hier ist eine Liste der unterstützten Umgebungsvariablen:
Hier ist eine Liste der verfügbaren Umgebungsvariablen, die du in der `docker-compose.yml` oder direkt in der Docker-Umgebung setzen kannst:

| Variable             | Beschreibung                                                                   | Standardwert    | Beispiel                 |
| -------------------- | ------------------------------------------------------------------------------ | --------------- | ------------------------ |
| `TZ`                 | Zeitzone                                                                       | `Europe/Berlin` | `Europe/Berlin`          |
| `DOMAIN`             | Domainname für das SSL-Zertifikat                                              | --------------- | `example.com`            |
| `CRON_TIME`          | Cron-Schedule für Zertifikat-Updates                                           | `*/60 * * * *`  | `* 8 * * 1`              |        
| `SHOUTRRR_URL`       | URL für Shoutrrr-Benachrichtigungen                                            | --------------- | `gotify://...`           |
| `SHOUTRRR_SKIP_TEST` | Überspringt den Shoutrrr-Test beim Start (`yes` oder `no`)                     | `no`            | `yes`                    |
| `NPM_API`            | API-URL des Nginx Proxy Managers                                               | --------------- | `http://home.lan:81/api` |
| `NPM_USER`           | Benutzername für die Nginx Proxy Manager API                                   | --------------- | `admin@example.com`      |
| `NPM_PASS`           | Passwort für die Nginx Proxy Manager API                                       | --------------- | `changeme`               |
| `DOCKER_CONTAINER`   | Name des Docker-Containers, der gestoppt und gestartet werden soll             | --------------- | `npm nginx`              |
| `OUTPUT_YES`         | Bestimmt, ob Zertifikate nach `/output` exportiert werden (`yes` oder `no`)    | `no`            | `yes`                    |
| `CERT_CER_NAME`      | Dateiname für das Zertifikat (Standardwert ist der Domainname `.cer`)          | `$DOMAIN.cer`   | `example.de.cer`         |
| `CERT_KEY_NAME`      | Dateiname für den Zertifikatschlüssel (Standardwert ist der Domainname `.key`) | `$DOMAIN.key`   | `example.de.key`         |
| `CERT_CSR_NAME`      | Dateiname für die CSR-Datei (Standardwert ist der Domainname `.csr`)           | `$DOMAIN.csr`   | `example.de.csr`         |
| `PUID`               | Benutzer-ID, für den `/data` Pfad                                              | `0`             | `1000`                   |
| `PGID`               | Gruppen-ID,  für den `/data` Pfad                                              | `0`             | `1000`                   |


#### `SHOUTRRR_URL` URL Beispiele [Shoutrrr-DOCS](https://containrrr.dev/shoutrrr/latest/services/overview/)
