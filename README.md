# scion-deploy

Public deploy artifacts for **SCION** — Structural Change Intelligence
for Teradata. The application source code lives in a private repo;
the compose, nginx config, and bootstrap scripts are kept here so the
one-liner installers can fetch them anonymously.

The container images this repo references are public on GHCR:

- `ghcr.io/guillealbella/scion-backend`
- `ghcr.io/guillealbella/scion-frontend`

---

## Quick start

### Linux (recommended for prod VMs)

```bash
curl -fsSL https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main/install.sh | bash
```

Detects the distro (Ubuntu / Debian / RHEL / CentOS / Rocky / Alma /
Fedora), installs Docker if missing, drops everything in `/opt/scion`,
prompts for region and port, auto-generates an admin `API_KEY`,
pulls images and starts the stack. The TAISA assistant comes
pre-configured inside the backend image — no extra setup.

### Windows (for early testing on dev machines with Docker Desktop)

```powershell
irm https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main/install.ps1 | iex
```

Docker Desktop **must** already be installed (the script verifies and
refuses to proceed otherwise — Windows EULA + reboot make unattended
Docker install impossible). Files land under `%USERPROFILE%\scion\`.

If PowerShell complains about execution policy, the `irm | iex`
pattern bypasses it because the script is piped through
`Invoke-Expression` rather than executed from disk.

### Updating

Run the update script when you want the latest images. The Sidebar's
version pill (v1.22+) shows when an update is available; until then,
just run the script periodically.

```bash
# Linux
curl -fsSL https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main/update.sh | bash
```

```powershell
# Windows
irm https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main/update.ps1 | iex
```

### Uninstalling

```bash
# Linux
curl -fsSL https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main/uninstall.sh | bash
```

```powershell
# Windows
irm https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main/uninstall.ps1 | iex
```

The uninstaller asks before removing the data volume — declining keeps
the SQLite database on disk so a fresh install resumes where you left.

---

## What gets deployed

| Container          | Image                                    | Purpose                           |
| ------------------ | ---------------------------------------- | --------------------------------- |
| `scion-backend`    | `ghcr.io/guillealbella/scion-backend`    | FastAPI + uvicorn                 |
| `scion-frontend`   | `ghcr.io/guillealbella/scion-frontend`   | Next.js standalone server         |
| `scion-nginx`      | `nginx:1.29-alpine`                      | Single public port reverse proxy  |

State lives in the named volume `scion_data`, mounted at `/data` on
the backend container. It contains `/data/scion.db`. Container
rebuilds and image upgrades preserve it; `docker compose down -v`
wipes it.

---

## Manual deploy (cross-platform fallback)

Use this when the one-liner can't run as-is (airgapped VM, locked-down
sudo, or just to inspect every step).

```bash
# 1. Create deploy directory
mkdir -p /opt/scion && cd /opt/scion           # Linux
# or
mkdir $HOME\scion ; cd $HOME\scion             # Windows

# 2. Download the three deploy files
curl -fsSL https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main/nginx.conf         -o nginx.conf
curl -fsSL https://raw.githubusercontent.com/GuilleAlbella/scion-deploy/main/.env.example       -o .env.example

# 3. Configure
cp .env.example .env
$EDITOR .env
#   At minimum set:
#     - API_KEY (generate with: openssl rand -hex 32)
#     - DATA_REGION
#     - SCION_PUBLIC_PORT (default 80)

# 4. Pull and start
docker compose pull
docker compose up -d

# 5. Verify
docker compose ps
curl -fsS http://localhost/healthz
```

---

## VM sizing

Confirmed in the v1.21 deploy planning meeting:

- **Test environment (Teradata CloudBolt)**: 8 core / 32 GB RAM / SSD.
- **Production (Azure AKS option)**: 8 core / 64 GB RAM / 200 GB NVMe SSD.

The Parser pipeline (separate component, ships independently) and
SCION are intended to share one VM; SCION is mostly idle outside
ingest windows, so the co-tenancy is fine.

---

## Pinning a specific version

The shipped `docker-compose.yml` defaults to `:latest` for both
images. For production environments we recommend pinning. Edit your
`/opt/scion/.env`:

```
SCION_BACKEND_IMAGE=ghcr.io/guillealbella/scion-backend:1.21.0
SCION_FRONTEND_IMAGE=ghcr.io/guillealbella/scion-frontend:1.21.0
```

Then `docker compose up -d`. Pinned tags stay pinned — the update
script only pulls whatever the compose says.

---

## Troubleshooting

**Port 80 already in use.** Edit `SCION_PUBLIC_PORT` in `.env`, then
`docker compose up -d` (Compose recreates only nginx).

**Backend container restarting.** `docker compose logs backend`. The
most common cause is `DATABASE_URL` pointing at an unwritable
location. The default `/data/scion.db` is on the named volume and
should always be writable.

**`db_init.py init` fails with "legacy".** A previous SQLite file on
the volume was created without Alembic. Either restore from backup or
`docker compose down -v` (destroys data) and start fresh.

**Need to roll back to an earlier version.** Pin the image tags in
`.env` (see "Pinning" above) and `docker compose up -d`.
