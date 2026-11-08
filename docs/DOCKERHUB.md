# HeaderGrade

[HeaderGrade](https://github.com/cybercrewinc/headergrade) is a self-hosted web application for scanning HTTP security headers. This image packages HeaderGrade for easy deployment with Docker.

- **Docker Hub:** <https://hub.docker.com/r/wydler/headergrade>
- **Source code and issue tracker:** <https://github.com/wydler/headergrade-docker>
- **Default port:** `3000`
- **Persistent data:** `/app/data`

## Quick start

Pull and start the latest image:

```bash
docker pull wydler/headergrade:latest

mkdir -p data
sudo chown 1000:1000 data

docker run -d \
  --name headergrade \
  --restart unless-stopped \
  -p 127.0.0.1:3000:3000 \
  -v "$PWD/data:/app/data" \
  --read-only \
  --tmpfs /tmp:size=16m,noexec,nosuid,nodev \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  wydler/headergrade:latest
```

Open <http://127.0.0.1:3000> on the Docker host. The port is bound to localhost by default so the unauthenticated web interface is not exposed to the network. To make it available on another interface, change the host side of the port mapping (for example, `-p 3000:3000`) and protect access with a firewall and an authentication proxy.

The application runs as the unprivileged user `node` (UID/GID `1000:1000`). The mounted data directory must be writable by this user. Scan history is stored in `/app/data` and persists across container restarts; initial seed data is provided when there is no scan history yet.

## Docker Compose

The [source repository](https://github.com/wydler/headergrade-docker) includes a Compose configuration with the same security settings and persistent data volume. Clone it and start the image:

```bash
git clone https://github.com/wydler/headergrade-docker.git
cd headergrade-docker
mkdir -p data
sudo chown 1000:1000 data
docker compose pull
docker compose up -d
```

The Compose configuration binds to `127.0.0.1:3000` by default. You can override the host port, bind address, and image tag with a `.env` file:

```dotenv
BIND_ADDRESS=127.0.0.1
HOST_PORT=3000
IMAGE_TAG=latest
```

## Configuration

The image listens on port `3000`. These optional environment variables can be passed with `-e NAME=value` to `docker run`, or configured in the Compose `.env` file:

| Variable | Default | Description |
|---|---|---|
| `SEED_TOKEN` | Unset | Optional shared token for the upstream bulk seeder. |
| `ZAP_API_URL` | Unset | Base URL of an optional OWASP ZAP daemon. |
| `ZAP_API_KEY` | Unset | API key for the OWASP ZAP daemon. |

For the Compose deployment, add the optional integration settings to `.env`:

```dotenv
ZAP_API_URL=http://zap:8080
ZAP_API_KEY=your-api-key
```

Treat `SEED_TOKEN` and `ZAP_API_KEY` as secrets. The upstream bulk seeder sends `SEED_TOKEN` as a query parameter, which may be recorded in request logs.

## Image details

- Images are published to Docker Hub as `wydler/headergrade:<tag>`.
- Regular releases publish their release tag and update `latest`; pre-releases do not update `latest`.
- The container runs as a non-root user and includes a Docker health check against `/api/stats`.
- Scan data is written to `/app/data`; mount this path to persist it outside the container.

## Security notes

The web interface does not include authentication. Keep it bound to localhost or place it behind an authentication proxy before exposing it to a network. The scanner makes outbound requests to the targets you submit; only scan systems you are authorized to test. HeaderGrade's score reflects selected HTTP security headers and is not a complete security audit.

## License

This Docker wrapper is licensed under the [MIT License](https://github.com/wydler/headergrade-docker/blob/master/LICENSE). HeaderGrade is maintained by [cybercrewinc](https://github.com/cybercrewinc/headergrade); see the upstream project for its license and notices.
