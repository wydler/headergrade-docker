# HeaderGrade Docker

Docker-Wrapper für [HeaderGrade](https://github.com/cybercrewinc/headergrade), einen selbst hostbaren Scanner für HTTP-Sicherheitsheader. Der Upstream liegt als Git-Submodul unter `upstream/headergrade`; das Docker-Image enthält nur die für den Laufzeitbetrieb benötigten Dateien.

## Funktionen

- Laufzeit als unprivilegierter Benutzer (`node`, UID/GID 1000)
- Persistente Scan-Historie unter `./data`
- Schreibgeschütztes Root-Dateisystem, verworfene Linux-Capabilities und `no-new-privileges`
- Healthcheck über `GET /api/stats`
- Optionale Umgebungsvariablen für `SEED_TOKEN` und `OWASP ZAP`
- Docker-Smoke-Test bei passenden Pull Requests sowie manuell startbar

## Schnellstart

Für die Installation benötigst du `curl` sowie Debian oder Ubuntu mit `sudo`. Für den anschließenden Betrieb des fertigen Images genügt die Compose-Konfiguration aus diesem Repository; das Upstream-Submodul ist dafür nicht erforderlich.

Das folgende Skript installiert Docker, containerd sowie Docker Buildx und Compose. Es unterstützt Debian und Ubuntu und aktualisiert die Paketlisten, führt aber kein vollständiges Paket-Upgrade durch:
```bash
curl -fsSL https://raw.githubusercontent.com/wydler/headergrade-docker/refs/heads/master/misc/docker-shared/01-docker-installation.sh | bash
```

Für IPv6-Firewallregeln von Docker kannst du die Konfigurationsdatei des Docker-Daemons unter `/etc/docker/daemon.json` bearbeiten. Füge die folgenden Parameter in eine vorhandene Konfiguration ein, statt sie zu überschreiben. Sie aktivieren IPv6 jedoch nicht automatisch für das Standard-Bridge-Netz; dafür ist eine zusätzliche, auf dein Netzwerk abgestimmte Konfiguration erforderlich. Starte den Docker-Daemon anschließend mit `sudo systemctl restart docker.service` neu:
```bash
{
  "experimental": true,
  "ip6tables": true
}
```

Klone das Repository in das Verzeichnis für Docker-Container:
```bash
sudo mkdir -p /opt/containers/

cd /opt/containers/
sudo git clone --depth 1 https://github.com/wydler/headergrade-docker.git

cd headergrade-docker
sudo mkdir -p data
sudo chown -R 1000:1000 data
```

Erstelle die `.env`-Datei und starte den Container:
```bash
sudo cp .env.example .env
sudo chown "$(id -u):$(id -g)" .env
```

Anwendung starten:
```bash
sudo docker compose pull
sudo docker compose up -d
sudo docker compose ps
sudo docker compose logs -f headergrade
```

Das fertige Image ist öffentlich auf [Docker Hub](https://hub.docker.com/r/wydler/headergrade) verfügbar. Ein lokaler Build ist für den normalen Betrieb nicht erforderlich; Compose verwendet standardmäßig `wydler/headergrade:latest`.

Der Prozess im Container läuft mit UID/GID `1000:1000`. Auf Linux muss das Datenverzeichnis für diesen Benutzer beschreibbar sein.

Compose bindet die Weboberfläche standardmäßig nur an `127.0.0.1:3000`. Öffne lokal <http://127.0.0.1:3000>. Für den Zugriff aus einem vertrauenswürdigen LAN kann `BIND_ADDRESS` in `.env` auf die LAN-Adresse des Hosts gesetzt werden. `0.0.0.0` sollte nur mit passenden Firewall-Regeln und einer geeigneten Zugriffskontrolle verwendet werden.

## Konfiguration

Kopiere `.env.example` nach `.env`. Alle darin enthaltenen Werte sind optional:

| Variable | Standardwert | Beschreibung |
|---|---|---|
| `BIND_ADDRESS` | `127.0.0.1` | Host-Schnittstelle, an der der veröffentlichte Port lauscht |
| `HOST_PORT` | `3000` | Port auf dem Docker-Host |
| `IMAGE_TAG` | `latest` | Tag von `wydler/headergrade`, das Compose startet |
| `SEED_TOKEN` | leer | Optionales gemeinsames Geheimnis für den Upstream-Bulk-Seeder |
| `ZAP_API_URL` | leer | Optionale Basis-URL eines OWASP-ZAP-Daemons |
| `ZAP_API_KEY` | leer | API-Schlüssel für diesen ZAP-Daemon |

Der Container-Port ist in `docker-compose.yaml` auf `3000` festgelegt. `SEED_TOKEN` wird vom Upstream als Query-Parameter übertragen und kann deshalb in Zugriffslogs auftauchen. Schütze den Wert wie ein Geheimnis und committe die `.env`-Datei nicht. Für produktive Deployments sollte ein Secret-Store der Plattform verwendet werden, sofern dieser mit den erwarteten Umgebungsvariablen kompatibel ist.

Scan-Daten werden in `./data` gespeichert und bleiben durch das Volume `./data:/app/data` bei Container-Neustarts erhalten. Ist noch keine Historie vorhanden, verwendet die Anwendung ihre mitgelieferten Seed-Daten.

## Image beziehen

`docker-compose.yaml` verwendet standardmäßig `wydler/headergrade:${IMAGE_TAG:-latest}` von Docker Hub. Für den normalen Betrieb genügt `docker compose pull` gefolgt von `docker compose up -d`; das Image muss nicht lokal gebaut werden. Über `IMAGE_TAG` kann ein anderer veröffentlichter Tag gewählt werden.

Der folgende Abschnitt beschreibt den Release-Workflow für die Entwicklung und Veröffentlichung dieses Repositorys; er ist für den Betrieb des bereits veröffentlichten Images nicht erforderlich.

### Release-Publish in eine konfigurierte Registry

Der Workflow [build.docker.images.yml](.github/workflows/build.docker.images.yml) baut und veröffentlicht bei einem Release (auch Pre-Release) oder manuellem Start in die konfigurierte Registry. Er benötigt die Repository-Variablen `REGISTRY`, `REGISTRY_ACCOUNT`, `REGISTRY_REPO`, `REGISTRY_REPO_TAG_CACHE_NAME` und `REGISTRY_PLATFORMS` sowie die Secrets `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `cosign_private_key` und `cosign_password`. Das Image wird mit Cosign signiert und anschließend gegen `cosign.pub` im Repository verifiziert. Der Schlüssel und die erforderlichen Secrets müssen eingerichtet sein, bevor der Publish-Workflow erfolgreich laufen kann; der Workflow [tools_cosign_generate-keys.yml](.github/workflows/tools_cosign_generate-keys.yml) kann beim Erzeugen des Schlüsselpaares helfen.

Bei Release-Events wird der Release-Tag als Image-Tag verwendet; Pre-Releases erhalten kein `latest`, reguläre Releases setzen `latest` auf den Release-Stand. Der manuelle Workflow verwendet den Namen des ausgewählten Branches oder Tags als Image-Tag. Da der Promote-Schritt nicht ausdrücklich auf Release-Events beschränkt ist, kann auch ein manueller Lauf `latest` verändern. Der Workflow hängt außerdem SBOM- und Provenance-Metadaten an.

## Upstream aktualisieren

Die folgenden Schritte sind nur für Entwicklung und Image-Builds nötig, nicht für den Betrieb des fertigen Docker-Hub-Images. Klone dafür das Repository einschließlich Submodul:

```bash
git clone --recurse-submodules https://github.com/wydler/headergrade-docker.git
cd headergrade-docker
```

Das Submodul fixiert einen konkreten Upstream-Commit; ein Update ändert nicht automatisch ein bereits gebautes Image. In diesem Repository ist kein automatischer Upstream-Update- oder PR-Workflow eingerichtet. Aktualisiere das Submodul daher manuell, prüfe die Änderungen und erstelle anschließend einen Pull Request:

```bash
git -C upstream/headergrade fetch origin master
git -C upstream/headergrade checkout --detach origin/master
git add upstream/headergrade
git diff --cached --submodule=log
```

Baue und teste das aktualisierte Image vor dem Zusammenführen:

```bash
docker build -t headergrade-docker:test .
./tests/smoke-test.sh headergrade-docker:test
```

## Tests

Der Smoke-Test benötigt Docker und `curl`; er prüft den Nicht-Root-Betrieb, den Healthcheck, `/api/stats` und den Start mit schreibgeschütztem Root-Dateisystem. Der Workflow [tools_docker_build_image.yml](.github/workflows/tools_docker_build_image.yml) startet manuell oder bei Pull Requests nach `master`, wenn Dockerfile- oder Upstream-Dateien betroffen sind:

```bash
docker build -t headergrade-docker:test .
./tests/smoke-test.sh headergrade-docker:test
```

Das Skript ist ein POSIX-Shell-Skript und wird in CI unter Linux ausgeführt. Unter Windows kann es beispielsweise in WSL oder Git Bash gestartet werden; die Testumgebung muss dem Skript erlauben, den temporären Datenordner UID/GID `1000:1000` zuzuweisen.

## Sicherheit und Grenzen

- Die Upstream-Anwendung weist private und interne Zieladressen mit ihrem SSRF-Schutz zurück. Dieser Wrapper deaktiviert oder verändert den Schutz nicht.
- Der Scanner führt ausgehende Netzwerkzugriffe auf vom Benutzer angegebene Ziele aus. Die Oberfläche hat keine eingebaute Anmeldung. Betreibe sie daher nur lokal oder in einem vertrauenswürdigen Netz und verwende bei weitergehender Veröffentlichung eine vorgeschaltete Zugriffskontrolle.
- `SEED_TOKEN` wird als Query-Parameter übermittelt und kann in Logs sichtbar werden.
- Die Note bewertet das Vorhandensein bestimmter HTTP-Header und ist kein vollständiges Sicherheitsaudit.
- Das Dockerfile kopiert gezielt ausgewählte Laufzeitdateien aus dem Upstream. Werden dort weitere Dateien zur Laufzeit benötigt, müssen Dockerfile und Smoke-Test gemeinsam überprüft und aktualisiert werden.

## Upstream und Lizenz

Upstream-Projekt: <https://github.com/cybercrewinc/headergrade>

Das Upstream-Projekt steht laut dessen Repository unter der MIT-Lizenz. Die Upstream-Lizenz- und Copyright-Dateien bleiben im Submodul erhalten. Für die Dateien dieses Wrappers gilt die MIT-Lizenz; siehe [LICENSE](LICENSE).
